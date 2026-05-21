---
name: codex-for-comsol-lumerical
description: Use when connecting Codex to local COMSOL Multiphysics or Ansys Lumerical FDTD/MODE solvers, probing solver installations, normalizing Windows solver environments, running comsolbatch/comsolcompile, using lumapi or fdtd-solutions CLI, or repairing solver automation failures.
---

# Codex for COMSOL and Lumerical

## Overview

Use this skill to make Codex operate local COMSOL and Ansys Lumerical solver installations through verified automation paths. Keep the scope to solver connection, environment setup, command execution, result export, and failure repair; do not import device-family design priors, literature notes, or project-specific geometry examples.

## Workflow

1. Identify the requested backend: `comsol`, `lumerical-fdtd`, `lumerical-mode`, or mixed.
2. Load only the needed reference:
   - COMSOL batch, Java API, or table export: `references/comsol-automation.md`.
   - Lumerical FDTD/MODE, `lumapi`, or LSF CLI: `references/lumerical-fdtd-automation.md`.
   - Local profile names and expected executable paths: `references/solver-profiles.json`.
3. Probe before real work unless the same profile was verified in the current session.
4. Normalize the Windows environment before launching solver binaries.
5. Run the smallest viable operation first: version check, import check, session start, or compile/run/save probe.
6. Store raw stdout/stderr, generated scripts, result files, and probe JSON near the job artifacts.
7. If a solver call fails, classify the signature, propose the smallest patch, retry once when safe, then persist the lesson in the caller's project memory or report.

## Quick Commands

Run dry-run checks first:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/probe_comsol.ps1 -DryRun
python scripts/probe_lumerical.py --dry-run
```

Run deeper probes only when the user expects local solver startup:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/probe_comsol.ps1 -Deep -OutDir .\solver_probe_out\comsol
python scripts/probe_lumerical.py --deep --out-dir .\solver_probe_out\lumerical
python scripts/probe_lumerical.py --cli --deep --out-dir .\solver_probe_out\lumerical_cli
```

On this Windows machine, prefer the Anaconda environment Python when available:

```powershell
C:\ProgramData\anaconda3\envs\AI_group\python.exe scripts/probe_lumerical.py --deep
```

## COMSOL Defaults

- Prefer `comsolcompile.exe -> comsolbatch.exe -inputfile <class>` for Java API probes and builders.
- Use `comsolbatch.exe -version` as the first connection check.
- Avoid MPh Python on the recorded Windows installation because it was observed to crash.
- Use table-format `-paramfile`, not key-value format.
- If a Java postprocessor loads a model from another directory, use explicit output paths for table exports.

## Lumerical Defaults

- Prefer `lumapi.FDTD()` after adding the local `api/python` directory to `sys.path`.
- Set `ANSYSLMD_LICENSE_FILE` when sessions fail to start with license/session errors.
- Prepend the Lumerical `bin` and `licensingclient/winx64` directories to `PATH`.
- Keep `fdtd-solutions.exe -run <script.lsf>` as a CLI fallback.
- Use `.txt` as the safe LSF sentinel/export extension, then convert to JSON in Python if needed.

## Failure Repair

Return compact JSON patches for repair proposals:

```json
{
  "action": "set_environment",
  "target": "lumerical",
  "env_key": "ANSYSLMD_LICENSE_FILE",
  "env_value": "1055@localhost",
  "reason": "FDTD session startup failed with a license/session error; the verified local profile needs an explicit license server."
}
```

Required fields: `action`, `target`, `reason`. Add `profile_name`, `command`, `server_args`, `script_hint`, `env_key`, or `env_value` only when needed.

## Common Mistakes

- Do not edit files inside COMSOL or Lumerical installation directories.
- Do not assume a normal `python` command exists on Windows; prefer the discovered or user-specified Python.
- Do not trust old solver syntax without a local probe.
- Do not treat a solver exit code as enough; verify the expected artifact or exported table exists.
- Do not write domain-specific examples into this skill. Keep reusable solver automation knowledge here and leave model physics to the caller's project.
