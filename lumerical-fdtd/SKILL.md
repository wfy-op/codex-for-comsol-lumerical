---
name: lumerical-fdtd
description: Use when connecting Codex to Ansys Lumerical FDTD, probing lumapi or fdtd-solutions.exe, normalizing FDTD solver environments, running LSF CLI sentinels, scripting FDTD object creation, reading monitor or Qanalysis results, handling sampled materials, or repairing FDTD automation failures.
---

# Lumerical FDTD

## Overview

Use this skill to operate Ansys Lumerical FDTD through local Python API sessions or the `fdtd-solutions.exe` LSF command-line fallback. Keep the scope to solver connection, environment setup, object creation, monitor/source/analysis scripting, result extraction, material data handling, and failure repair.

## Workflow

1. Detect the operating system first:
   - On Windows PowerShell, run the Python probe directly with `py -3` or a chosen Python.
   - On Git Bash for Windows, use `scripts/probe_lumerical.sh`; it detects `MINGW/MSYS/CYGWIN` and chooses `py -3` when available.
   - On Linux, use `scripts/probe_lumerical.sh`; it chooses `python3` and searches Linux FDTD install roots.
2. Decide whether to use Python API or CLI LSF:
   - Prefer Python API when `lumapi` imports and an FDTD session starts.
   - Use CLI LSF when Python API startup is blocked but `fdtd-solutions.exe` can run scripts.
3. Load only the needed reference:
   - FDTD Python API, LSF, object creation, monitors, Qanalysis, data extraction, far-field projection, or materials: `references/lumerical-fdtd-automation.md`.
   - Example profile structure: `references/solver-profiles.json`.
4. Probe before real work unless the same profile already passed in the current session.
5. Normalize the local solver environment before launching binaries.
6. Run the smallest viable operation first: import check, executable check, session start, or CLI sentinel.
7. Store raw stdout/stderr, generated scripts, result files, and probe JSON near the caller's job artifacts, not inside this skill.
8. If a solver call fails, classify the signature, propose the smallest patch, retry once when safe, then report the exact command and artifacts.

## Quick Commands

```powershell
$skill = "C:\path\to\lumerical-fdtd"
$out = ".\solver_probe_out\lumerical"
py -3 "$skill\scripts\probe_lumerical.py" --dry-run --out-dir "$out"
py -3 "$skill\scripts\probe_lumerical.py" --deep --out-dir "$out"
py -3 "$skill\scripts\probe_lumerical.py" --cli --deep --out-dir "$out-cli"
```

If `py -3` is not the right interpreter, use a user-selected Python environment:

```powershell
conda run -n <env> python "$skill\scripts\probe_lumerical.py" --dry-run --out-dir "$out"
```

Git Bash or Linux:

```bash
skill="/path/to/lumerical-fdtd"
out="./solver_probe_out/lumerical"
bash "$skill/scripts/probe_lumerical.sh" --dry-run --out-dir "$out"
bash "$skill/scripts/probe_lumerical.sh" --deep --out-dir "$out"
bash "$skill/scripts/probe_lumerical.sh" --cli --deep --out-dir "$out-cli"
```

## Defaults

- Prefer `lumapi.FDTD()` after adding the local `api/python` directory to `sys.path`.
- Set `ANSYSLMD_LICENSE_FILE` when session startup fails with license/session errors.
- Prepend the FDTD `bin` and `licensingclient/winx64` directories to `PATH`.
- Keep `fdtd-solutions.exe -run <script.lsf>` as a CLI fallback.
- Use `.txt` as the safe LSF sentinel/export extension, then convert to JSON in Python if needed.

## Common Mistakes

- Do not edit files inside the solver installation directory.
- Do not assume a normal `python` command exists on Windows; prefer the discovered or user-specified Python.
- Do not trust old solver syntax without a local probe.
- Do not treat a solver exit code as enough; verify the expected sentinel, monitor data, or exported file exists.
- Do not add unrelated solver-family guidance to this FDTD-only skill.
