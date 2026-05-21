param(
    [switch]$Deep,
    [switch]$DryRun,
    [string]$OutDir = ".\solver_probe_out\comsol",
    [string]$ComsolBin = "C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64"
)

$ErrorActionPreference = "Stop"

function Set-ComsolEnv {
    param([string]$BinDir)

    $userHome = [Environment]::GetFolderPath("UserProfile")
    $windows = $env:SystemRoot
    if (-not $windows) { $windows = "C:\Windows" }
    $programFiles = $env:ProgramFiles
    if (-not $programFiles) { $programFiles = "C:\Program Files" }

    $defaults = @{
        APPDATA = Join-Path $userHome "AppData\Roaming"
        LOCALAPPDATA = Join-Path $userHome "AppData\Local"
        HOMEDRIVE = "C:"
        HOMEPATH = ("\Users\" + [Environment]::UserName)
        USERPROFILE = $userHome
        COMSPEC = Join-Path $windows "System32\cmd.exe"
        OS = "Windows_NT"
        PROCESSOR_ARCHITECTURE = "AMD64"
        SystemRoot = $windows
        windir = $windows
        ProgramData = "C:\ProgramData"
        ProgramFiles = $programFiles
        "ProgramFiles(x86)" = "C:\Program Files (x86)"
        TEMP = [IO.Path]::GetTempPath().TrimEnd("\")
        TMP = [IO.Path]::GetTempPath().TrimEnd("\")
    }

    foreach ($key in $defaults.Keys) {
        if (-not [Environment]::GetEnvironmentVariable($key, "Process")) {
            [Environment]::SetEnvironmentVariable($key, $defaults[$key], "Process")
        }
    }

    $pathEntries = @(
        $BinDir,
        (Join-Path $windows "System32"),
        $windows,
        (Join-Path $windows "System32\Wbem"),
        (Join-Path $windows "System32\WindowsPowerShell\v1.0"),
        $env:PATH
    ) | Where-Object { $_ -and $_.Trim() }

    $seen = @{}
    $clean = foreach ($entry in $pathEntries) {
        $lower = $entry.ToLowerInvariant()
        if (-not $seen.ContainsKey($lower)) {
            $seen[$lower] = $true
            $entry
        }
    }
    $env:PATH = ($clean -join [IO.Path]::PathSeparator)
}

function Invoke-ProbeCommand {
    param(
        [string[]]$Command,
        [string]$WorkingDirectory
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command[0]
    foreach ($arg in $Command[1..($Command.Length - 1)]) {
        if ($null -ne $arg) { [void]$psi.ArgumentList.Add($arg) }
    }
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    [ordered]@{
        command = $Command
        returncode = $proc.ExitCode
        stdout = $stdout
        stderr = $stderr
        success = ($proc.ExitCode -eq 0)
    }
}

$comsolBatch = Join-Path $ComsolBin "comsolbatch.exe"
$comsolCompile = Join-Path $ComsolBin "comsolcompile.exe"
Set-ComsolEnv -BinDir $ComsolBin

$payload = [ordered]@{
    backend = "comsol"
    probe_level = $(if ($Deep) { "deep_compile_run_save" } else { "version_check" })
    dry_run = [bool]$DryRun
    comsol_batch = $comsolBatch
    comsol_compile = $comsolCompile
    checks = @()
    success = $false
}

if ($DryRun) {
    $payload.checks += [ordered]@{
        name = "path_resolution"
        success = ((Test-Path $comsolBatch) -and (Test-Path $comsolCompile))
        comsol_batch_exists = (Test-Path $comsolBatch)
        comsol_compile_exists = (Test-Path $comsolCompile)
    }
    $payload.success = $payload.checks[0]["success"]
    $payload | ConvertTo-Json -Depth 8
    exit 0
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$resolvedOut = (Resolve-Path $OutDir).Path

$versionCheck = Invoke-ProbeCommand -Command @($comsolBatch, "-version") -WorkingDirectory $resolvedOut
$versionCheck["name"] = "version_check"
$payload.checks += $versionCheck

if ($Deep) {
    $javaPath = Join-Path $resolvedOut "ComsolProbeMinimal.java"
    @"
import com.comsol.model.*;
import com.comsol.model.util.*;

public class ComsolProbeMinimal {
  public static void main(String[] args) throws Exception {
    Model model = ModelUtil.create("Model");
    model.label("comsol_probe_minimal");
    model.param().set("probe_one", "1", "Probe scalar");
    model.save("comsol_probe_minimal");
    System.out.println("COMSOL_PROBE_MINIMAL_OK");
  }
}
"@ | Set-Content -Encoding UTF8 -Path $javaPath

    $compileCheck = Invoke-ProbeCommand -Command @($comsolCompile, $javaPath) -WorkingDirectory $resolvedOut
    $compileCheck["name"] = "minimal_compile"
    $payload.checks += $compileCheck

    if ($compileCheck["success"]) {
        $classPath = Join-Path $resolvedOut "ComsolProbeMinimal.class"
        $runCheck = Invoke-ProbeCommand -Command @($comsolBatch, "-inputfile", $classPath) -WorkingDirectory $resolvedOut
        $runCheck["name"] = "minimal_run_save"
        $runCheck["expected_artifact"] = (Join-Path $resolvedOut "comsol_probe_minimal.mph")
        $runCheck["artifact_exists"] = (Test-Path $runCheck["expected_artifact"])
        $runCheck["success"] = ($runCheck["success"] -and $runCheck["artifact_exists"])
        $payload.checks += $runCheck
    }
}

$payload.success = -not ($payload.checks | Where-Object { -not $_["success"] })
$json = $payload | ConvertTo-Json -Depth 10
$jsonPath = Join-Path $resolvedOut "comsol_probe.json"
$json | Set-Content -Encoding UTF8 -Path $jsonPath
$json
