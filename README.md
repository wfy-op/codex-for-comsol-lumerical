# codex-for-comsol-lumerical

A small Codex skill for connecting Codex to local COMSOL Multiphysics and Ansys Lumerical FDTD installations.

It is not a model template, device example library, or simulation case package. Its job is narrower: help Codex find the solver, normalize the Windows environment, run minimal probes, remember fragile COMSOL/Lumerical syntax, and produce small repair patches when solver automation fails.

## What It Includes

- `SKILL.md`: the main workflow for using the skill.
- `scripts/probe_comsol.ps1`: COMSOL path, version, Java compile, batch run, and save probes.
- `scripts/probe_lumerical.py`: Lumerical `lumapi`, FDTD session, and CLI LSF sentinel probes.
- `references/comsol-automation.md`: COMSOL Java API, batch, geometry, physics, mesh, Q, and table export notes.
- `references/lumerical-fdtd-automation.md`: Lumerical FDTD `lumapi`, LSF, object creation, Qanalysis, far-field, and sampled material notes.
- `references/solver-profiles.json`: public-safe example profile shapes, not machine-specific verified profiles.

## Install

Clone the repository into your Codex skills folder:

```powershell
git clone https://github.com/wfy-op/codex-for-comsol-lumerical.git "$env:USERPROFILE\.codex\skills\codex-for-comsol-lumerical"
```

Then ask Codex to use `$codex-for-comsol-lumerical` when working with local COMSOL or Lumerical FDTD automation.

## Quick Probes

Run dry-run checks before starting a real solver session:

```powershell
$skill = "$env:USERPROFILE\.codex\skills\codex-for-comsol-lumerical"
$out = ".\solver_probe_out"

powershell -ExecutionPolicy Bypass -File "$skill\scripts\probe_comsol.ps1" -DryRun -OutDir "$out\comsol"
py -3 "$skill\scripts\probe_lumerical.py" --dry-run --out-dir "$out\lumerical"
```

Run deeper probes only when you are ready to start local solver processes:

```powershell
powershell -ExecutionPolicy Bypass -File "$skill\scripts\probe_comsol.ps1" -Deep -OutDir "$out\comsol"
py -3 "$skill\scripts\probe_lumerical.py" --deep --out-dir "$out\lumerical"
py -3 "$skill\scripts\probe_lumerical.py" --cli --deep --out-dir "$out\lumerical_cli"
```

## Scope

This skill covers COMSOL automation and Lumerical FDTD automation only. It deliberately avoids device-specific design priors, paper-reproduction workflows, and project-specific geometry templates.

Always run a local probe before treating any solver profile as ready on a new machine.
