# codex solver skills

This repository contains two separate Codex skills:

- `comsol-multiphysics/` for COMSOL Multiphysics automation.
- `lumerical-fdtd/` for Ansys Lumerical FDTD automation.

The skills are intentionally separated. Each folder is a standalone skill with
its own `SKILL.md`, scripts, references, profile examples, and UI metadata.

## COMSOL Multiphysics

`comsol-multiphysics/` preserves the existing COMSOL command-line and Java API
probe workflow and adds the converted Python `mph` runtime from the original
COMSOL MCP server.

Important entry points:

- `comsol-multiphysics/scripts/probe_comsol.ps1`
- `comsol-multiphysics/scripts/comsol_mph_tool.py`
- `comsol-multiphysics/scripts/validate_comsol_skill.ps1`
- `comsol-multiphysics/scripts/comsol_mcp_runtime/`

The recorded local COMSOL path is:

```text
D:\COMSOL\COMSOL62\Multiphysics\bin\win64
```

## Lumerical FDTD

`lumerical-fdtd/` contains only Ansys Lumerical FDTD automation guidance and
the FDTD probe script.

Important entry points:

- `lumerical-fdtd/scripts/probe_lumerical.py`
- `lumerical-fdtd/references/lumerical-fdtd-automation.md`

## Validation

Validate skill structure:

```powershell
py -3 C:\Users\w1278\.codex\skills\.system\skill-creator\scripts\quick_validate.py .\comsol-multiphysics
py -3 C:\Users\w1278\.codex\skills\.system\skill-creator\scripts\quick_validate.py .\lumerical-fdtd
```

Validate COMSOL locally:

```powershell
powershell -ExecutionPolicy Bypass -File .\comsol-multiphysics\scripts\validate_comsol_skill.ps1 `
  -ModelPath "E:\comsol\2D_TE_suna.mph"
```
