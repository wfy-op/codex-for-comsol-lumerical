# Lumerical FDTD Automation Reference

Use this reference for Ansys Lumerical FDTD `lumapi`, FDTD session startup, LSF CLI fallback, and script-level result extraction.

## Contents

- Local discovery and profiles
- Environment normalization and import
- Session lifecycle
- Object creation and v241 local workarounds
- CLI fallback and LSF script syntax
- Source, monitor, and far-field syntax
- Qanalysis and data retrieval
- Sampled material data
- Failure signatures

## Local Discovery and Profiles

- Preferred Python API profile: `lumapi-python-fdtd-example`
- API path source: explicit user input, `LUMERICAL_PYTHON_API`, or the probe script's install-root scan.
- CLI fallback source: explicit user input, `LUMERICAL_FDTD_EXECUTABLE`, or the probe script's install-root scan.
- License source: explicit user input or `ANSYSLMD_LICENSE_FILE`.
- Treat any discovered path as local evidence only. Probe the local installation before running production scripts.

## Environment Normalization

Before importing `lumapi` or launching `fdtd-solutions.exe`:

```python
import os
import socket
from pathlib import Path

api_env = os.environ.get("LUMERICAL_PYTHON_API")
if not api_env:
    raise RuntimeError("Set LUMERICAL_PYTHON_API or run scripts/probe_lumerical.py to discover lumapi.py")
api_path = Path(api_env)
if not api_path.exists():
    raise FileNotFoundError("Set LUMERICAL_PYTHON_API or run the probe script to discover lumapi.py")
install_root = api_path.parents[2]
os.environ["PATH"] = os.pathsep.join([
    str(install_root / "bin"),
    str(install_root / "licensingclient" / "winx64"),
    os.environ.get("PATH", ""),
])
os.environ["Path"] = os.environ["PATH"]
os.environ.setdefault("LUMERICAL_ROOT", str(install_root))
os.environ.setdefault("LUMERICAL_PYTHON_API", str(api_path))
os.environ.setdefault("COMPUTERNAME", socket.gethostname().split(".")[0])
```

Import:

```python
import sys
sys.path.insert(0, str(api_path.parent))
import lumapi
```

## Session Lifecycle

```python
fdtd = lumapi.FDTD()
try:
    fdtd.switchtolayout()
    fdtd.save(r"C:\path\to\model.fsp")
    fdtd.run()
    fdtd.runanalysis()
    result = fdtd.getresult("Q_analysis", "Q")
finally:
    fdtd.close()
```

If `lumapi.FDTD()` fails with a session or license error, set `ANSYSLMD_LICENSE_FILE`, prepend the Lumerical binary and licensing client directories to `PATH`, and retry once.

For headless automation, probe whether the local version accepts:

```python
fdtd = lumapi.FDTD(hide=True)
# or, if the local profile supports server arguments:
fdtd = lumapi.FDTD(serverArgs={"platform": "offscreen"})
```

## Object Creation

Use attribute assignment or session-level `setnamed`. On some v241 profiles, `SimObject` wrappers did not expose a reliable `obj.set(...)`; treat this as a local workaround, not a universal Lumerical rule.

## lumapi Syntax Map

| Task | Recorded syntax |
| --- | --- |
| Start FDTD | `fdtd = lumapi.FDTD()` |
| Layout mode | `fdtd.switchtolayout()` |
| Execute LSF | `fdtd.eval("addrect;")` |
| Save project | `fdtd.save(str(fsp_path))` |
| Run simulation | `fdtd.run()` |
| Run analysis | `fdtd.runanalysis()` |
| Read result dict | `fdtd.getresult("object", "result")` |
| Read raw data | `fdtd.getdata("monitor", "Ex")` |
| Read script variable | `fdtd.getv("var_name")` |
| Set named property | `fdtd.setnamed("object", "property name", value)` |
| Close session | `fdtd.close()` |

```python
rect = fdtd.addrect()
rect.name = "layer_1"
rect.x = 0
rect.y = 0
rect.x_span = 2e-6
rect.y_span = 2e-6
rect.z = 0
rect.z_span = 220e-9
rect.material = "<Object defined dielectric>"
rect.index = 3.4
fdtd.setnamed("layer_1", "mesh order", 3)
```

Circle object:

```python
disk = fdtd.addcircle()
disk.name = "disk_1"
disk.x = 0
disk.y = 0
disk.z = 0
disk.radius = 200e-9
disk.z_span = 220e-9
disk.material = "<Object defined dielectric>"
disk.index = 1.5
```

Ring object:

```python
ring = fdtd.addring()
ring.name = "ring_1"
ring.x = 0
ring.y = 0
ring.z = 0
ring.inner_radius = 300e-9
ring.outer_radius = 450e-9
ring.z_span = 220e-9
ring.material = "<Object defined dielectric>"
ring.index = 1.5
```

Mesh-order fallbacks:

```python
try:
    rect.override_mesh_order = 1
except Exception:
    pass
try:
    rect.mesh_order = 3
except Exception:
    fdtd.setnamed("layer_1", "mesh order", 3)
```

On some v241 profiles, renaming the object returned by `addfdtd()` was unreliable. When this local behavior appears, keep the default region name and use the returned object id.

```python
region = fdtd.addfdtd()
region_name = getattr(getattr(region, "_id", None), "name", "::model::FDTD")
region.dimension = "3D"
region.x_span = 2e-6
region.y_span = 2e-6
region.z_span = 1e-6
region.x_min_bc = "PML"
region.x_max_bc = "PML"
region.y_min_bc = "PML"
region.y_max_bc = "PML"
region.z_min_bc = "PML"
region.z_max_bc = "PML"
```

Useful creation calls:

| Object | Python call |
| --- | --- |
| Rectangle | `fdtd.addrect()` |
| Circle | `fdtd.addcircle()` |
| Ring | `fdtd.addring()` |
| FDTD region | `fdtd.addfdtd()` |
| Structure group | `fdtd.addstructuregroup()` |
| Analysis group | `fdtd.addanalysisgroup()` |
| Power monitor | `fdtd.addpower()`; newer versions may prefer `fdtd.adddftmonitor()` |
| Q analysis | `fdtd.addobject("Qanalysis")` |

Structure group and grouping syntax:

```python
group = fdtd.addstructuregroup()
group.name = "group_1"
group.x = group.y = group.z = 0

obj = fdtd.addrect()
obj.name = "member_1"
fdtd.select("member_1")
fdtd.addtogroup("group_1")
```

For grouped objects, prefer full paths with `setnamed`:

```python
fdtd.setnamed("::model::group_1::member_1", "mesh order", 2)
```

## CLI Fallback

Use CLI LSF runs when Python API session startup is blocked:

```powershell
$fdtdExe = "<resolved fdtd-solutions executable>"
& $fdtdExe -hide -run .\script.lsf -exit
```

Use `-trust-script` only when the script needs trusted filesystem/resource access and the script source is known.

Safe sentinel example:

```lsf
write("lumerical_cli_probe.txt", "LUMERICAL_CLI_PROBE_OK");
exit;
```

In safe-mode contexts, arbitrary extensions can be rejected. Write `.txt` from LSF and convert to JSON in Python after the run.

## LSF Script Syntax

Use Lumerical script language inside `fdtd.eval(...)`, CLI `.lsf` files, and analysis-group setup scripts. It is not Python.

```lsf
addrect;
set("name", "layer_from_lsf");
set("x span", 2e-6);
set("y span", 2e-6);
set("z span", 220e-9);
set("material", "<Object defined dielectric>");
set("index", 3.4);
```

Analysis group setup script for sources:

```python
src = fdtd.addanalysisgroup()
src.name = "source_group"
src.setup_script = """
deleteall;
adddipole;
set("x", 0);
set("y", 0);
set("z", 0);
set("dipole type", "Electric dipole");
set("theta", 90);
set("phi", 0);
set("override global source settings", 0);
"""
```

LSF loops use Lumerical syntax:

```lsf
for(i=1:3) {
  addrect;
  set("name", "rect_"+num2str(i));
  set("x", i*1e-7);
}
```

## Global Source and Monitor Settings

```python
fdtd.setglobalsource("wavelength start", 1.45e-6)
fdtd.setglobalsource("wavelength stop", 1.65e-6)
fdtd.setglobalmonitor("frequency points", 401)
```

Top monitor:

```python
mon = fdtd.addpower()  # or fdtd.adddftmonitor() on newer versions
mon.name = "mon_top"
mon.monitor_type = "2D Z-normal"
mon.x = 0
mon.y = 0
mon.z = 0.5e-6
mon.x_span = 2e-6
mon.y_span = 2e-6
```

If direct attribute assignment fails for monitor properties with spaces, use `setnamed`:

```python
fdtd.setnamed("mon_top", "monitor type", "2D Z-normal")
fdtd.setnamed("mon_top", "override global monitor settings", 0)
```

Far-field projection:

```python
fdtd.eval(
    'farfieldsettings("far field filter",0);'
    'ff_E2=farfield3d("mon_top",1,401,401);'
    'ff_ux=farfieldux("mon_top",1,401,401);'
    'ff_uy=farfielduy("mon_top",1,401,401);'
)
e2 = fdtd.getv("ff_E2")
ux = fdtd.getv("ff_ux")
uy = fdtd.getv("ff_uy")
```

Periodic projection with an explicit finite aperture in period counts:

```python
fidx = 1
resolution = 801
periods_x = 100
periods_y = 100
index = 1
direction = 1
illumination = 2
fdtd.eval('farfieldsettings("far field filter",0);')
fdtd.eval(
    f'ff_E2=farfield3d("mon_top",{fidx},{resolution},{resolution},'
    f'{illumination},{periods_x},{periods_y},{index},{direction});'
    f'ff_ux=farfieldux("mon_top",{fidx},{resolution},{resolution},{index});'
    f'ff_uy=farfielduy("mon_top",{fidx},{resolution},{resolution},{index});'
)
```

For non-periodic projections, omit the `illumination`, period-count, index, and direction arguments unless the Lumerical command requires them for the specific monitor.

## Q Analysis

`Qanalysis` creation can fail intermittently. Retry with bounded backoff.

```python
import time

last_error = None
for attempt in range(1, 9):
    try:
        q = fdtd.addobject("Qanalysis")
        q.name = "Q_analysis"
        q.x = q.y = q.z = 0
        q.x_span = 2e-6
        q.y_span = 2e-6
        q.z_span = 1e-6
        break
    except Exception as exc:
        last_error = exc
        time.sleep(min(1.0 * (1.5 ** (attempt - 1)), 8.0))
else:
    raise RuntimeError(f"Qanalysis creation failed: {last_error}")
```

Retrieve results:

```python
import numpy as np

c0 = 299792458.0
res = fdtd.getresult("Q_analysis", "Q")
q_values = np.asarray(res.get("Q", []), dtype=float).reshape(-1)
freq_values = np.asarray(res.get("f", []), dtype=float).reshape(-1)
lambda_m = c0 / freq_values if freq_values.size else np.asarray(res.get("lambda", []), dtype=float).reshape(-1)
```

Prefer `f` and `Q` for portable Qanalysis extraction. A `lambda` key may exist in some local results, but do not rely on it; compute `lambda_m = c/f` when `f` is available.

Make sure `t start` is inside the actual simulation time window when running short smoke tests.

When attribute assignment for `t start` is unreliable, set it after selection:

```python
fdtd.select("Q_analysis")
fdtd.set("t start", 50e-15)
```

or:

```python
fdtd.setnamed("Q_analysis", "t start", 50e-15)
```

## Data Retrieval

Use `getdata` for monitor arrays:

```python
z = fdtd.getdata("profile_z", "z")
ex = fdtd.getdata("profile_z", "Ex")
ey = fdtd.getdata("profile_z", "Ey")
ez = fdtd.getdata("profile_z", "Ez")
```

Use `getresult` for analysis/result dictionaries:

```python
result = fdtd.getresult("Q_analysis", "Q")
```

Use `getv` for variables created by `fdtd.eval(...)`:

```python
fdtd.eval('answer=42;')
answer = fdtd.getv("answer")
```

## Sampled Material Data

For portable sampled materials, prefer the official `Sampled data` material and set sampled data as frequency plus complex permittivity. The sampled data matrix has 2 columns for isotropic materials or 4 columns for anisotropic materials; the first column is frequency in Hz, and the remaining column(s) are complex-valued permittivity. If the source data is wavelength, n, and k, convert first:

```python
import numpy as np

wl_m = wavelength_m.astype(np.float64)
n = n_values.astype(np.float64)
k = k_values.astype(np.float64)
c0 = 299792458.0
freq_hz = c0 / wl_m
eps_complex = (n + 1j * k) ** 2

# Sort by ascending frequency for a predictable material table.
order = np.argsort(freq_hz)
sampled_data = np.column_stack([
    freq_hz[order].astype(np.float64),
    eps_complex[order].astype(np.complex128),
])

mat = fdtd.addmaterial("Sampled data")
fdtd.setmaterial(mat, "name", "Material_Custom")
fdtd.setmaterial("Material_Custom", "sampled data", sampled_data)
```

Lumerical material-property names vary by version. Before using sampled materials in production, run a small material probe such as `fdtd.eval('?setmaterial("Material_Custom");')` or inspect the material properties in the GUI/API.

Materials are stored per `.fsp`; copy sampled material data into the destination file before assigning it to objects there.

Copy material data between `.fsp` files:

```python
base = lumapi.FDTD(str(base_fsp))
src = lumapi.FDTD(str(source_fsp))
mat_data = src.getmaterial("Material_Custom", "sampled data")
src.close()

mat = base.addmaterial("Sampled data")
base.setmaterial(mat, "name", "Material_Custom")
base.setmaterial("Material_Custom", "sampled data", mat_data)
```

## Failure Signatures

| Signature | Classification | Smallest patch |
| --- | --- | --- |
| `Session not found` from `appOpened` | API startup or license environment | Set `ANSYSLMD_LICENSE_FILE`, prepend Lumerical binary/licensing paths, set `COMPUTERNAME`, retry once. |
| `No module named lumapi` | Python API path not loaded | Add the local `api/python` directory to `sys.path` or set `LUMERICAL_PYTHON_API`. |
| `obj.set` missing | v241 local wrapper API difference | Use attribute assignment or `fdtd.setnamed(...)`. |
| `name` change on FDTD region fails or breaks wrapper | v241 local inactive property | Keep the default FDTD region name and use the returned object id. |
| LSF cannot write requested extension | safe-mode extension block | Write `.txt` from LSF, postprocess to JSON in Python. |
| `runanalysis()` fails in a short smoke run | analysis start time outside simulation window | Clamp analysis start time to a fraction of the configured simulation time. |
