param(
    [switch]$Deep,
    [switch]$DryRun,
    [string]$OutDir = ".\solver_probe_out\comsol",
    [string]$ComsolBin = ""
)

$ErrorActionPreference = "Stop"

function Test-WindowsHost {
    if ($PSVersionTable.PSEdition -eq "Core") {
        return [bool]$IsWindows
    }
    return $true
}

if (-not (Test-WindowsHost)) {
    throw "probe_comsol.ps1 is for Windows PowerShell hosts. On Linux, use scripts/probe_comsol.sh."
}

function Find-ComsolBin {
    $candidates = New-Object System.Collections.Generic.List[string]

    function Add-Candidate {
        param([string]$Path)
        if (-not $Path) { return }
        if (-not ($candidates -contains $Path)) {
            [void]$candidates.Add($Path)
        }
    }

    if ($env:COMSOL_BIN) {
        Add-Candidate $env:COMSOL_BIN
    }
    foreach ($rootEnv in @($env:COMSOL_ROOT, $env:COMSOL_HOME, $env:COMSOL_INSTALL_ROOT)) {
        if ($rootEnv) {
            Add-Candidate (Join-Path $rootEnv "Multiphysics\bin\win64")
            Add-Candidate (Join-Path $rootEnv "bin\win64")
        }
    }

    $batchCommand = Get-Command comsolbatch.exe -ErrorAction SilentlyContinue
    $compileCommand = Get-Command comsolcompile.exe -ErrorAction SilentlyContinue
    if ($batchCommand -and $compileCommand) {
        Add-Candidate (Split-Path -Parent $batchCommand.Source)
    }

    $roots = New-Object System.Collections.Generic.List[string]
    [void]$roots.Add("D:\COMSOL")
    foreach ($programRoot in @($env:ProgramFiles, [Environment]::GetEnvironmentVariable("ProgramFiles(x86)"))) {
        if ($programRoot) {
            [void]$roots.Add((Join-Path $programRoot "COMSOL"))
        }
    }
    [void]$roots.Add("/opt/comsol")
    [void]$roots.Add("/usr/local/comsol")

    foreach ($root in $roots) {
        if (Test-Path $root) {
            Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                ForEach-Object {
                    Add-Candidate (Join-Path $_.FullName "Multiphysics\bin\win64")
                    Add-Candidate (Join-Path $_.FullName "bin\win64")
                    Add-Candidate (Join-Path $_.FullName "bin")
                }
        }
    }

    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $batch = Join-Path $candidate "comsolbatch.exe"
        $compile = Join-Path $candidate "comsolcompile.exe"
        if ((Test-Path $batch) -and (Test-Path $compile)) {
            return $candidate
        }
    }

    if ($candidates.Count -gt 0) {
        return $candidates[0]
    }
    return ""
}

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

function ConvertTo-RedactedText {
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return $null }
    $text = [string]$Value
    $userHome = [Environment]::GetFolderPath("UserProfile")
    $userName = [Environment]::UserName
    $machineName = $env:COMPUTERNAME
    if (-not $machineName) { $machineName = [Environment]::MachineName }

    if ($userHome) {
        $text = $text -replace [regex]::Escape($userHome), "%USERPROFILE%"
    }
    if ($userName) {
        $text = $text -replace [regex]::Escape($userName), "%USERNAME%"
    }
    if ($machineName) {
        $text = $text -replace [regex]::Escape($machineName), "%COMPUTERNAME%"
    }
    $text = $text -replace "\b(\d{2,5})@(?!localhost\b|127\.0\.0\.1\b)[^;,\s]+", '$1@<redacted-host>'
    $text
}

function ConvertTo-RedactedCommand {
    param([string[]]$Command)

    @($Command | ForEach-Object { ConvertTo-RedactedText $_ })
}

function Limit-ProbeText {
    param([AllowNull()]$Text)

    if ($null -eq $Text) { return $null }
    $value = [string]$Text
    if ($value.Length -gt 4000) {
        return $value.Substring($value.Length - 4000)
    }
    $value
}

function Invoke-ProbeCommand {
    param(
        [string[]]$Command,
        [string]$WorkingDirectory
    )

    function ConvertTo-ProcessArgument {
        param([string]$Value)

        if ($null -eq $Value) { return $null }
        if ($Value -notmatch '[\s"]') { return $Value }

        $escaped = $Value -replace '\\(?=")', '\\' -replace '"', '\"'
        return '"' + $escaped + '"'
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command[0]
    if ($Command.Length -gt 1) {
        $psi.Arguments = (($Command[1..($Command.Length - 1)] |
            Where-Object { $null -ne $_ } |
            ForEach-Object { ConvertTo-ProcessArgument $_ }) -join " ")
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
        command = (ConvertTo-RedactedCommand -Command $Command)
        returncode = $proc.ExitCode
        stdout = (ConvertTo-RedactedText (Limit-ProbeText $stdout))
        stderr = (ConvertTo-RedactedText (Limit-ProbeText $stderr))
        success = ($proc.ExitCode -eq 0)
    }
}

if (-not $ComsolBin) {
    $ComsolBin = Find-ComsolBin
}

if (-not $ComsolBin) {
    $payload = [ordered]@{
        backend = "comsol"
        probe_level = $(if ($DryRun) { "dry_run" } elseif ($Deep) { "deep_compile_run_save" } else { "version_check" })
        dry_run = [bool]$DryRun
        comsol_batch = $null
        comsol_compile = $null
        checks = @([ordered]@{
            name = "path_resolution"
            success = $false
            message = "Could not find COMSOL binaries. Pass -ComsolBin or set COMSOL_BIN, COMSOL_ROOT, or COMSOL_HOME."
        })
        success = $false
    }
    $payload | ConvertTo-Json -Depth 8
    exit 1
}

$comsolBatch = Join-Path $ComsolBin "comsolbatch.exe"
$comsolCompile = Join-Path $ComsolBin "comsolcompile.exe"
Set-ComsolEnv -BinDir $ComsolBin

$payload = [ordered]@{
    backend = "comsol"
    probe_level = $(if ($DryRun) { "dry_run" } elseif ($Deep) { "deep_compile_run_save" } else { "version_check" })
    dry_run = [bool]$DryRun
    comsol_batch = (ConvertTo-RedactedText $comsolBatch)
    comsol_compile = (ConvertTo-RedactedText $comsolCompile)
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
    if ($payload.success) { exit 0 } else { exit 1 }
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
    System.out.println("COMSOL_PROBE_MINIMAL_OK");
  }
}
"@ | Set-Content -Encoding UTF8 -Path $javaPath

    $compileCheck = Invoke-ProbeCommand -Command @($comsolCompile, $javaPath) -WorkingDirectory $resolvedOut
    $compileCheck["name"] = "minimal_compile"
    $payload.checks += $compileCheck

    if ($compileCheck["success"]) {
        $classPath = Join-Path $resolvedOut "ComsolProbeMinimal.class"
        $expectedArtifact = Join-Path $resolvedOut "comsol_probe_minimal.mph"
        $runCheck = Invoke-ProbeCommand -Command @($comsolBatch, "-inputfile", $classPath, "-outputfile", $expectedArtifact) -WorkingDirectory $resolvedOut
        $runCheck["name"] = "minimal_run_save"
        $actualJavaArtifact = Join-Path $resolvedOut "comsol_probe_minimal_Model.mph"
        $artifactCandidates = @($expectedArtifact, $actualJavaArtifact)
        $createdArtifact = $artifactCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        $runCheck["expected_artifacts"] = @($artifactCandidates | ForEach-Object { ConvertTo-RedactedText $_ })
        $runCheck["created_artifact"] = (ConvertTo-RedactedText $createdArtifact)
        $runCheck["artifact_exists"] = [bool]$createdArtifact
        $runCheck["sentinel_seen"] = ([string]$runCheck["stdout"]).Contains("COMSOL_PROBE_MINIMAL_OK")
        $runCheck["success"] = ($runCheck["success"] -and $runCheck["artifact_exists"] -and $runCheck["sentinel_seen"])
        $payload.checks += $runCheck
    }
}

$payload.success = -not ($payload.checks | Where-Object { -not $_["success"] })
$json = $payload | ConvertTo-Json -Depth 10
$jsonPath = Join-Path $resolvedOut "comsol_probe.json"
$json | Set-Content -Encoding UTF8 -Path $jsonPath
$json
if ($payload.success) { exit 0 } else { exit 1 }
