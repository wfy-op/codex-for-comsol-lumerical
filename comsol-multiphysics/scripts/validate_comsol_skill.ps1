param(
    [string]$SkillDir = (Split-Path -Parent $PSScriptRoot),
    [string]$Python = "",
    [string]$ModelPath = "",
    [string]$ComsolBin = "",
    [string]$OutDir = ".\solver_probe_out\comsol_skill_validation",
    [switch]$Deep
)

$ErrorActionPreference = "Stop"

function Test-WindowsHost {
    if ($PSVersionTable.PSEdition -eq "Core") {
        return [bool]$IsWindows
    }
    return $true
}

if (-not (Test-WindowsHost)) {
    throw "validate_comsol_skill.ps1 is for Windows PowerShell hosts. On Linux, use scripts/validate_comsol_skill.sh."
}

function Resolve-RequiredPath {
    param([string]$Path, [string]$Label)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label not found: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Resolve-Python {
    param([string]$ExplicitPython, [string]$SkillRoot)

    if ($ExplicitPython) {
        return (Resolve-RequiredPath -Path $ExplicitPython -Label "Python")
    }

    $pythonCandidates = New-Object System.Collections.Generic.List[string]
    if ($env:COMSOL_MPH_PYTHON) {
        [void]$pythonCandidates.Add($env:COMSOL_MPH_PYTHON)
    }
    if ($env:PYTHON) {
        [void]$pythonCandidates.Add($env:PYTHON)
    }
    if ($env:VIRTUAL_ENV) {
        [void]$pythonCandidates.Add((Join-Path $env:VIRTUAL_ENV "Scripts\python.exe"))
        [void]$pythonCandidates.Add((Join-Path $env:VIRTUAL_ENV "bin/python"))
    }
    if ($SkillRoot) {
        [void]$pythonCandidates.Add((Join-Path $SkillRoot ".venv\Scripts\python.exe"))
        [void]$pythonCandidates.Add((Join-Path $SkillRoot ".venv/bin/python"))
    }

    foreach ($candidate in $pythonCandidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $command = Get-Command python -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        return $pyLauncher.Source
    }

    throw "No Python interpreter found. Pass -Python or set COMSOL_MPH_PYTHON with an environment that can import mph and mcp."
}

function Invoke-CheckedCommand {
    param([string]$Label, [scriptblock]$Command)

    Write-Host "== $Label =="
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

$skillRoot = Resolve-RequiredPath -Path $SkillDir -Label "SkillDir"
$probeScript = Resolve-RequiredPath -Path (Join-Path $skillRoot "scripts\probe_comsol.ps1") -Label "probe_comsol.ps1"
$adapterScript = Resolve-RequiredPath -Path (Join-Path $skillRoot "scripts\comsol_mph_tool.py") -Label "comsol_mph_tool.py"
$runtimeDir = Resolve-RequiredPath -Path (Join-Path $skillRoot "scripts\comsol_mcp_runtime") -Label "comsol_mcp_runtime"
$modelFile = $null
if ($ModelPath) {
    $modelFile = Resolve-RequiredPath -Path $ModelPath -Label "ModelPath"
}
$pythonExe = Resolve-Python -ExplicitPython $Python -SkillRoot $skillRoot

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$resolvedOut = (Resolve-Path -LiteralPath $OutDir).Path

Resolve-RequiredPath -Path (Join-Path $skillRoot "SKILL.md") -Label "SKILL.md" | Out-Null
Resolve-RequiredPath -Path (Join-Path $skillRoot "references\comsol-automation.md") -Label "comsol-automation.md" | Out-Null
Resolve-RequiredPath -Path (Join-Path $runtimeDir "src\server.py") -Label "runtime server.py" | Out-Null
Resolve-RequiredPath -Path (Join-Path $runtimeDir "pdf") -Label "runtime pdf directory" | Out-Null

Invoke-CheckedCommand -Label "Python dependency import" -Command {
    & $pythonExe -c "import mph, mcp; print('python_runtime_ok')"
}

$probeArgs = @("-ExecutionPolicy", "Bypass", "-File", $probeScript, "-DryRun", "-OutDir", (Join-Path $resolvedOut "probe"))
if ($ComsolBin) {
    $probeArgs += @("-ComsolBin", $ComsolBin)
}
Invoke-CheckedCommand -Label "COMSOL dry-run probe" -Command {
    & powershell @probeArgs
}

if ($Deep) {
    $deepArgs = @("-ExecutionPolicy", "Bypass", "-File", $probeScript, "-Deep", "-OutDir", (Join-Path $resolvedOut "probe_deep"))
    if ($ComsolBin) {
        $deepArgs += @("-ComsolBin", $ComsolBin)
    }
    Invoke-CheckedCommand -Label "COMSOL deep probe" -Command {
        & powershell @deepArgs
    }
}

Invoke-CheckedCommand -Label "Adapter registry listing" -Command {
    & $pythonExe $adapterScript list-tools | Tee-Object -FilePath (Join-Path $resolvedOut "adapter_list_tools.json")
}

if ($modelFile) {
    $modelValidationScript = Join-Path $resolvedOut "validate_mph_model.py"
    @'
import json
import sys
from pathlib import Path

adapter_path = Path(sys.argv[1])
model_path = Path(sys.argv[2])
sys.path.insert(0, str(adapter_path.parent))

import comsol_mph_tool as adapter

registry = adapter.load_registry()
results = []

def record(kind, name, result):
    item = {"kind": kind, "name": name, "result": result}
    results.append(item)
    if isinstance(result, dict) and result.get("success") is False:
        raise RuntimeError(f"{kind} {name} failed: {result.get('error')}")
    return result

try:
    record("tool", "comsol_start", adapter.invoke_tool(registry, "comsol_start", {}))
    loaded = record(
        "tool",
        "model_load",
        adapter.invoke_tool(registry, "model_load", {"file_path": str(model_path), "set_current": True}),
    )
    model_name = loaded["model"]["name"]
    record("tool", "model_inspect", adapter.invoke_tool(registry, "model_inspect", {}))
    record("tool", "param_list", adapter.invoke_tool(registry, "param_list", {}))
    record("resource", f"comsol://model/{model_name}/tree", adapter.invoke_resource(registry, f"comsol://model/{model_name}/tree"))
    record("tool", "model_remove", adapter.invoke_tool(registry, "model_remove", {"model_name": model_name}))
finally:
    try:
        record("tool", "comsol_disconnect", adapter.invoke_tool(registry, "comsol_disconnect", {}))
    except Exception as exc:
        results.append({"kind": "tool", "name": "comsol_disconnect", "error": str(exc)})

print(json.dumps({"success": True, "model_path": str(model_path), "results": results}, indent=2, default=str))
'@ | Set-Content -Encoding UTF8 -Path $modelValidationScript

    Invoke-CheckedCommand -Label "MPh model load and inspect validation" -Command {
        & $pythonExe $modelValidationScript $adapterScript $modelFile |
            Tee-Object -FilePath (Join-Path $resolvedOut "mph_model_validation.json")
    }
} else {
    [ordered]@{
        success = $true
        skipped = $true
        reason = "No -ModelPath supplied; skipped model load and inspect validation."
    } | ConvertTo-Json -Depth 5 | Tee-Object -FilePath (Join-Path $resolvedOut "mph_model_validation.json")
}

$pdfCount = (Get-ChildItem -Path (Join-Path $runtimeDir "pdf") -Recurse -Filter "*.pdf" | Measure-Object).Count
[ordered]@{
    success = $true
    skill_dir = $skillRoot
    python = $pythonExe
    model_path = $modelFile
    pdf_count = $pdfCount
    out_dir = $resolvedOut
} | ConvertTo-Json -Depth 5 | Tee-Object -FilePath (Join-Path $resolvedOut "validation_summary.json")
