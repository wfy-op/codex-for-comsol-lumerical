# Lumerical FDTD Automation Reference

Use this reference for Ansys Lumerical `lumapi`, FDTD/MODE session startup, LSF CLI fallback, and script-level result extraction.

## Verified Local Environment

- Preferred Python API profile: `lumapi-python-v241-local-license`
- API path: `C:\Program Files\Lumerical\v241\api\python\lumapi.py`
- CLI fallback: `C:\Program Files\Lumerical\v241\bin\fdtd-solutions.exe`
- License server used by the verified profile: `1055@localhost`
- Historical v242 syntax lessons remain useful, but probe the local v241 installation first.

## Environment Normalization

Before importing `lumapi` or launching `fdtd-solutions.exe`:

```python
import os
import socket
from pathlib import Path

api_path = Path(r"C:\Program Files\Lumerical\v241\api\python\lumapi.py")
install_root = api_path.parents[2]
os.environ["PATH"] = os.pathsep.join([
    str(install_root / "bin"),
    str(install_root / "licensingclient" / "winx64"),
    os.environ.get("PATH", ""),
])
os.environ["Path"] = os.environ["PATH"]
os.environ.setdefault("LUMERICAL_ROOT", str(install_root))
os.environ.setdefault("LUMERICAL_PYTHON_API", str(api_path))
os.environ.setdefault("ANSYSLMD_LICENSE_FILE", "1055@localhost")
os.environ.setdefault("COMPUTERNAME", socket.gethostname().split(".")[0])
```

Import:

```python
import sys
sys.path.insert(0, r"C:\Program Files\Lumerical\v241\api\python")
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

## Object Creation

Use attribute assignment or session-level `setnamed`. On the verified v241 installation, `SimObject` wrappers do not expose a reliable `obj.set(...)`.

## lumapi Syntax Map

| Task | Verified syntax |
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

Do not rename the object returned by `addfdtd()` on the verified v241 installation. The `name` property can be inactive and may leave the wrapper pointing to a stale object id.

```python
region = fdtd.addfdtd()
region_name = region._id.name
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
| Power monitor | `fdtd.addpower()` |
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
& 'C:\Program Files\Lumerical\v241\bin\fdtd-solutions.exe' -run .\script.lsf
```

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
mon = fdtd.addpower()
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
res = fdtd.getresult("Q_analysis", "Q")
q_values = res.get("Q", [])
lambda_values = res.get("lambda", [])
```

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

For sampled wavelength-dependent material data, cast all columns to `float64` before passing data to Lumerical:

```python
import numpy as np

mat = fdtd.addmaterial("Sampled 3D data")
fdtd.setmaterial(mat, "name", "Material_Custom")
fdtd.setmaterial("Material_Custom", "wavelength min", float(wavelength_m.min()))
fdtd.setmaterial("Material_Custom", "wavelength max", float(wavelength_m.max()))
data = np.column_stack([
    wavelength_m.astype(np.float64),
    n_values.astype(np.float64),
    k_values.astype(np.float64),
    np.zeros(len(wavelength_m), dtype=np.float64),
])
fdtd.setmaterial("Material_Custom", "sampled 3d data", data)
```

Materials are stored per `.fsp`; copy sampled material data into the destination file before assigning it to objects there.

Copy material data between `.fsp` files:

```python
base = lumapi.FDTD(str(base_fsp))
src = lumapi.FDTD(str(source_fsp))
mat_data = src.getmaterial("Material_Custom", "sampled 3d data")
wl_min = src.getmaterial("Material_Custom", "wavelength min")
wl_max = src.getmaterial("Material_Custom", "wavelength max")
src.close()

mat = base.addmaterial("Sampled 3D data")
base.setmaterial(mat, "name", "Material_Custom")
base.setmaterial("Material_Custom", "wavelength min", wl_min)
base.setmaterial("Material_Custom", "wavelength max", wl_max)
base.setmaterial("Material_Custom", "sampled 3d data", mat_data)
```

## Failure Signatures

| Signature | Classification | Smallest patch |
| --- | --- | --- |
| `Session not found` from `appOpened` | API startup or license environment | Set `ANSYSLMD_LICENSE_FILE`, prepend Lumerical binary/licensing paths, set `COMPUTERNAME`, retry once. |
| `No module named lumapi` | Python API path not loaded | Add the local `api/python` directory to `sys.path` or set `LUMERICAL_PYTHON_API`. |
| `obj.set` missing | v241 wrapper API difference | Use attribute assignment or `fdtd.setnamed(...)`. |
| `name` change on FDTD region fails or breaks wrapper | v241 inactive property | Keep the default FDTD region name and use `region._id.name`. |
| LSF cannot write requested extension | safe-mode extension block | Write `.txt` from LSF, postprocess to JSON in Python. |
| `runanalysis()` fails in a short smoke run | analysis start time outside simulation window | Clamp analysis start time to a fraction of the configured simulation time. |
