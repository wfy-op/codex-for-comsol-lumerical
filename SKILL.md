---
name: codex-for-comsol-lumerical
description: Use when connecting Codex to local COMSOL Multiphysics or Ansys Lumerical FDTD solvers, probing those solver installations, normalizing Windows solver environments, running comsolbatch/comsolcompile, using lumapi or fdtd-solutions CLI, or repairing COMSOL/Lumerical automation failures.
---

# Codex for COMSOL and Lumerical

## Overview

Use this skill to make Codex operate local COMSOL and Ansys Lumerical FDTD solver installations through locally probed automation paths. Keep the scope to solver connection, environment setup, command execution, result export, syntax lookup, and failure repair; do not import device-family design priors, literature notes, or project-specific geometry examples.

## Workflow

1. Identify the requested backend: `comsol`, `lumerical-fdtd`, or mixed.
2. Load only the needed reference:
   - COMSOL batch, Java API, geometry, physics, mesh, dataset, or table export syntax: `references/comsol-automation.md`.
   - Lumerical FDTD, `lumapi`, object creation, monitor, Qanalysis, material, or LSF CLI syntax: `references/lumerical-fdtd-automation.md`.
   - Example profile names and expected profile fields: `references/solver-profiles.json`.
3. Probe before real work unless the same profile already passed in the current session.
4. Normalize the Windows environment before launching solver binaries.
5. Run the smallest viable operation first: version check, import check, session start, or compile/run/save probe.
6. Store raw stdout/stderr, generated scripts, result files, and probe JSON near the job artifacts.
7. If a solver call fails, classify the signature, propose the smallest patch, retry once when safe, then persist the lesson in the caller's project memory or report.

## Quick Commands

Run dry-run checks first:

```powershell
$skill = "C:\path\to\codex-for-comsol-lumerical"
$out = ".\solver_probe_out"
powershell -ExecutionPolicy Bypass -File "$skill\scripts\probe_comsol.ps1" -DryRun -OutDir "$out\comsol"
py -3 "$skill\scripts\probe_lumerical.py" --dry-run --out-dir "$out\lumerical"
```

Run deeper probes only when the user expects local solver startup:

```powershell
$skill = "C:\path\to\codex-for-comsol-lumerical"
$out = ".\solver_probe_out"
powershell -ExecutionPolicy Bypass -File "$skill\scripts\probe_comsol.ps1" -Deep -OutDir "$out\comsol"
py -3 "$skill\scripts\probe_lumerical.py" --deep --out-dir "$out\lumerical"
py -3 "$skill\scripts\probe_lumerical.py" --cli --deep --out-dir "$out\lumerical_cli"
```

Resolve `scripts/` relative to this skill folder. Run probes from the caller job/artifact directory and set `-OutDir` or `--out-dir` explicitly so generated probe files do not land inside the skill repository. If `py -3` is not available, use a user-selected Python, for example:

```powershell
conda run -n <env> python "$skill\scripts\probe_lumerical.py" --dry-run --out-dir "$out\lumerical"
```

## COMSOL Defaults

- Prefer `comsolcompile.exe -> comsolbatch.exe -inputfile <class>` for Java API probes and builders.
- Use `comsolbatch.exe -version` as the first connection check.
- Avoid MPh Python on the recorded Windows installation because it was observed to crash.
- Use table-format `-paramfile`, not key-value format.
- If a Java postprocessor loads a model from another directory, use explicit output paths for table exports.
- For syntax-sensitive work, read the COMSOL reference before writing Java API calls. It contains recorded patterns for `Block`, `Cylinder`, `Difference`, `Box`, `Ball`, `Union`, `ElectromagneticWavesFrequencyDomain`, `Scattering`, PML coordinate systems, `FreeTet`, `EvalGlobal`, `IntVolume`, and table export.

## Lumerical Defaults

- Prefer `lumapi.FDTD()` after adding the local `api/python` directory to `sys.path`.
- Set `ANSYSLMD_LICENSE_FILE` when sessions fail to start with license/session errors.
- Prepend the Lumerical `bin` and `licensingclient/winx64` directories to `PATH`.
- Keep `fdtd-solutions.exe -run <script.lsf>` as a CLI fallback.
- Use `.txt` as the safe LSF sentinel/export extension, then convert to JSON in Python if needed.
- For syntax-sensitive work, read the Lumerical reference before writing Python or LSF calls. It contains recorded patterns for `addrect`, `addcircle`, `addring`, `addfdtd`, `addpower`, `addanalysisgroup`, `addobject("Qanalysis")`, `setnamed`, `getresult`, `getdata`, `farfield3d`, sampled materials, and LSF setup scripts.

## Not In Scope

- Only Lumerical FDTD automation is covered. Add a separate reference before using any other Lumerical product workflow.
- Device-family design priors, paper reproduction logic, and project-specific geometry templates do not belong in this skill.
- Do not use this skill as evidence that a solver profile is ready on another machine; always run a local probe first.

## Failure Repair

Return compact JSON patches for repair proposals:

```json
{
  "action": "set_environment",
  "target": "lumerical",
  "env_key": "ANSYSLMD_LICENSE_FILE",
  "env_value": "1055@localhost",
  "reason": "FDTD session startup failed with a license/session error; the current local profile needs an explicit license server."
}
```

Required fields: `action`, `target`, `reason`. Add `profile_name`, `command`, `server_args`, `script_hint`, `env_key`, or `env_value` only when needed.

## Common Mistakes

- Do not edit files inside COMSOL or Lumerical installation directories.
- Do not assume a normal `python` command exists on Windows; prefer the discovered or user-specified Python.
- Do not trust old solver syntax without a local probe.
- Do not treat a solver exit code as enough; verify the expected artifact or exported table exists.
- Do not write domain-specific examples into this skill. Keep reusable solver automation knowledge here and leave model physics to the caller's project.
