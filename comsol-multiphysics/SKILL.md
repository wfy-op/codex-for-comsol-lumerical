---
name: comsol-multiphysics
description: Use when connecting Codex to local or remote COMSOL Multiphysics, probing COMSOL installations, running comsolbatch or comsolcompile, using Java API automation, using Python mph session tools converted from the bundled MCP runtime, searching bundled COMSOL manuals, or repairing COMSOL automation failures.
---

# COMSOL Multiphysics

## Overview

Use this skill to operate COMSOL Multiphysics through two preserved backends:

- `comsolbatch` / `comsolcompile` command-line probes and Java API scripts.
- Python `mph` session operations converted from the bundled MCP runtime.

Keep the scope to solver connection, model/session management, parameter edits, geometry, physics, mesh, study, result export, documentation lookup, and failure repair. Do not add project-specific device templates or paper-specific modeling assumptions to this skill.

## Workflow

1. Detect the operating system first:
   - On Windows PowerShell, use `scripts/probe_comsol.ps1` and `scripts/validate_comsol_skill.ps1`.
   - On Git Bash for Windows, use the `.sh` scripts; they detect `MINGW/MSYS/CYGWIN` and delegate to the PowerShell scripts with path conversion.
   - On Linux, use `scripts/probe_comsol.sh` and `scripts/validate_comsol_skill.sh`; they run COMSOL CLI commands directly.
2. Decide which backend is needed:
   - Use the command-line backend for installation probes, Java API builders, batch runs, table exports, and robust local smoke tests.
   - Use the Python `mph` backend for interactive model/session tools, existing model inspection, parameter management, geometry/physics/mesh/study/result utilities, and documentation helpers.
3. Load only the needed reference:
   - Java API, batch, geometry, physics, mesh, result, dataset, or table export syntax: `references/comsol-automation.md`.
   - Example local profile structure: `references/solver-profiles.json`.
4. Probe before real work unless the same backend already passed in the current session.
5. Normalize the local solver environment before launching binaries.
6. Run the smallest viable operation first: version check, import check, session start, model load, or compile/run/save probe.
7. Store raw stdout/stderr, generated scripts, result files, and probe JSON near the caller's job artifacts, not inside this skill.
8. If a solver call fails, classify the signature, propose the smallest patch, retry once when safe, then report the exact command and artifacts.

## Quick Commands

Command-line probe:

```powershell
$skill = "C:\path\to\comsol-multiphysics"
$out = ".\solver_probe_out\comsol"
powershell -ExecutionPolicy Bypass -File "$skill\scripts\probe_comsol.ps1" -DryRun -OutDir "$out"
powershell -ExecutionPolicy Bypass -File "$skill\scripts\probe_comsol.ps1" -Deep -OutDir "$out"
```

Git Bash or Linux:

```bash
skill="/path/to/comsol-multiphysics"
out="./solver_probe_out/comsol"
bash "$skill/scripts/probe_comsol.sh" --dry-run --out-dir "$out"
bash "$skill/scripts/probe_comsol.sh" --deep --out-dir "$out"
```

The probe auto-discovers common Windows installs and honors `COMSOL_BIN` or `COMSOL_ROOT`. On the recorded local machine the working binary folder is:

```text
D:\COMSOL\COMSOL62\Multiphysics\bin\win64
```

Python runtime adapter:

```powershell
$python = "C:\Users\w1278\Desktop\COMSOL_Multiphysics_MCP-main\.venv\Scripts\python.exe"
$skill = "C:\path\to\comsol-multiphysics"
& $python "$skill\scripts\comsol_mph_tool.py" list-tools
& $python "$skill\scripts\comsol_mph_tool.py" tool model_load --json "{\"file_path\":\"E:\\comsol\\2D_TE_suna.mph\",\"set_current\":true}"
& $python "$skill\scripts\comsol_mph_tool.py" resource "comsol://session/info"
```

Use any Python environment that can import `mph` and `mcp`. The adapter reuses the bundled runtime under `scripts/comsol_mcp_runtime`; it does not reimplement the MCP tools. For stateful model work, use `batch --json [...]` or `scripts/validate_comsol_skill.ps1` so session state stays in one Python process.

## Preserved Runtime Capabilities

The bundled Python runtime preserves the original MCP categories:

- Session: start, connect, disconnect, status.
- Model: load, create, save, version, list, set current, clone, remove, inspect, components.
- Parameters: get, set, list, sweep setup, descriptions.
- Geometry: create sequences, add common features, boolean operations, CAD import, build, list features.
- Physics: available interfaces, add common interfaces, boundary setup, materials, multiphysics couplings, feature listing/removal.
- Mesh and study: mesh creation/info, study solve, async progress, cancellation, solutions, datasets.
- Results: expression evaluation, scalar evaluation, inner/outer values, data/image exports, export and plot listing.
- Knowledge: embedded guides, troubleshooting, best practices, PDF module list/status/search.
- Resources: session info, model tree, model parameters, model physics.

## Validation

Run the bundled validation script from a caller workspace:

```powershell
$skill = "C:\path\to\comsol-multiphysics"
powershell -ExecutionPolicy Bypass -File "$skill\scripts\validate_comsol_skill.ps1" `
  -SkillDir "$skill" `
  -Python "C:\Users\w1278\Desktop\COMSOL_Multiphysics_MCP-main\.venv\Scripts\python.exe" `
  -ModelPath "E:\comsol\2D_TE_suna.mph"
```

Git Bash or Linux validation:

```bash
skill="/path/to/comsol-multiphysics"
bash "$skill/scripts/validate_comsol_skill.sh" \
  --skill-dir "$skill" \
  --python "/path/to/python" \
  --model-path "/path/to/model.mph"
```

The validation script must not save over the supplied model. It may load, inspect, list parameters, read resources, and remove the model from memory.

## Common Mistakes

- Do not edit files inside the COMSOL installation directory.
- Do not assume `python` points to an environment with `mph`; use a discovered or user-selected interpreter.
- Do not treat solver exit code 0 as enough; verify the expected artifact or exported table exists.
- Do not save back to a user-supplied `.mph` unless the user explicitly requested it.
- Do not write project-specific geometry or physics assumptions into this reusable skill.
