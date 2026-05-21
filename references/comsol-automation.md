# COMSOL Automation Reference

Use this reference for local COMSOL connection checks, Java API probes, batch runs, and result-table exports.

## Contents

- Recorded local example
- Windows environment normalization
- Command line
- Minimal Java API probe
- Model load/remove lifecycle
- Generic Java API patterns
- Selections and materials
- Physics syntax
- Mesh syntax
- Result and table export
- Far-field function export
- Failure signatures

## Recorded Local Example

- COMSOL: `6.3.0.290`
- Batch executable: `C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolbatch.exe`
- Java compiler wrapper: `C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolcompile.exe`
- Preferred workflow: write Java API file, compile with `comsolcompile.exe`, run the `.class` with `comsolbatch.exe`.
- Avoid MPh Python on the recorded Windows installation because it was observed to crash.
- Treat this as a recorded example, not a portable ready-to-use profile. Run `scripts/probe_comsol.ps1` locally before trusting a profile.

## Windows Environment Normalization

Codex desktop sessions can start with missing Windows variables. Before launching COMSOL, make sure these exist:

```text
APPDATA
LOCALAPPDATA
HOMEDRIVE
HOMEPATH
USERPROFILE
COMSPEC
OS
PROCESSOR_ARCHITECTURE
SystemRoot
windir
ProgramData
ProgramFiles
ProgramFiles(x86)
TEMP
TMP
```

Prepend these paths to `PATH`:

```text
C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64
C:\Windows\System32
C:\Windows
C:\Windows\System32\Wbem
C:\Windows\System32\WindowsPowerShell\v1.0
```

## Command Line

```powershell
& 'C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolbatch.exe' -version
& 'C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolcompile.exe' .\ComsolProbeMinimal.java
& 'C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolbatch.exe' -inputfile .\ComsolProbeMinimal.class
& 'C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolbatch.exe' -inputfile model.mph -outputfile output.mph -study std1
& 'C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolbatch.exe' -inputfile model.mph -outputfile output.mph -study std1 -paramfile params.txt
```

`-paramfile` expects table format:

```text
width height n_core
500[nm] 220[nm] 3.45
```

## Minimal Java API Probe

```java
import com.comsol.model.*;
import com.comsol.model.util.*;

public class ComsolProbeMinimal {
  public static void main(String[] args) throws Exception {
    Model model = ModelUtil.create("Model");
    model.label("comsol_probe_minimal");
    model.param().set("probe_one", "1", "Probe scalar");
    model.save("comsol_probe_minimal");
    System.out.println("COMSOL_PROBE_MINIMAL_OK");
  }
}
```

Expected artifact: `comsol_probe_minimal.mph`.

COMSOL batch can create a sibling model artifact such as `*_Model.mph` when running a compiled Java class, even when the Java code also calls `model.save(...)`. Treat unexpected solver output files as local artifacts and keep them out of source control.

## Java Sandbox Notes

Use explicit paths from the calling script rather than relying on Java-side discovery. In batch execution, avoid using `System.getProperty("user.dir")` as a source of truth for export paths, and do not delete or probe unrelated files from inside COMSOL Java. Pre-clean known output files in the wrapper script before launching COMSOL.

## Model Load and Remove

Load an existing model with a stable tag, then remove it when finished so repeated batch runs do not collide:

```java
Model model = ModelUtil.load("post", "C:\\path\\to\\input_model.mph");
try {
    model.study("std1").run();
    model.save("C:\\path\\to\\output_model.mph");
} finally {
    ModelUtil.remove("post");
}
```

## Generic Java API Patterns

Use this section as a syntax lookup before writing or repairing COMSOL Java builders. The examples are intentionally generic and are not tied to any device family.

## Java API Syntax Map

| Task | Recorded syntax |
| --- | --- |
| Create model | `Model model = ModelUtil.create("Model");` |
| Create component | `model.component().create("comp1", true);` |
| Create 2D geometry | `model.component("comp1").geom().create("geom1", 2);` |
| Create 3D geometry | `model.component("comp1").geom().create("geom1", 3);` |
| Set length unit | `model.component("comp1").geom("geom1").lengthUnit("nm");` |
| Create physics | `model.component("comp1").physics().create("ewfd", "ElectromagneticWavesFrequencyDomain", "geom1");` |
| Create mesh | `model.component("comp1").mesh().create("mesh1");` |
| Run geometry | `model.component("comp1").geom("geom1").run();` |
| Run mesh | `model.component("comp1").mesh("mesh1").run();` |
| Save model | `model.save("model_name");` |

Create a model and component:

```java
Model model = ModelUtil.create("Model");
model.component().create("comp1", true);
```

Set parameters:

```java
model.param().set("lambda0", "1550[nm]", "Target wavelength");
model.param().set("f0", "c_const/lambda0", "Search frequency");
```

Create 3D geometry:

```java
model.component("comp1").geom().create("geom1", 3);
model.component("comp1").geom("geom1").lengthUnit("nm");
model.component("comp1").geom("geom1").create("blk1", "Block");
model.component("comp1").geom("geom1").feature("blk1").set("size", new String[]{"500", "500", "220"});
model.component("comp1").geom("geom1").feature("blk1").set("base", "center");
model.component("comp1").geom("geom1").run();
```

2D primitives:

```java
model.component("comp1").geom().create("geom1", 2);
model.component("comp1").geom("geom1").lengthUnit("nm");

model.component("comp1").geom("geom1").create("sq1", "Square");
model.component("comp1").geom("geom1").feature("sq1").set("size", "500");
model.component("comp1").geom("geom1").feature("sq1").set("base", "center");

model.component("comp1").geom("geom1").create("c1", "Circle");
model.component("comp1").geom("geom1").feature("c1").set("r", "80");
model.component("comp1").geom("geom1").feature("c1").set("pos", new String[]{"0", "0"});

model.component("comp1").geom("geom1").run();
```

3D cylinder and boolean difference:

```java
model.component("comp1").geom("geom1").create("cyl1", "Cylinder");
model.component("comp1").geom("geom1").feature("cyl1").set("r", "80");
model.component("comp1").geom("geom1").feature("cyl1").set("h", "220");
model.component("comp1").geom("geom1").feature("cyl1").set("pos", new String[]{"0", "0", "-110"});

model.component("comp1").geom("geom1").create("dif1", "Difference");
model.component("comp1").geom("geom1").feature("dif1").selection("input").set("blk1");
model.component("comp1").geom("geom1").feature("dif1").selection("input2").set("cyl1");
model.component("comp1").geom("geom1").feature("dif1").set("keepsubtract", true);
model.component("comp1").geom("geom1").run();
```

`Cylinder` `pos` is the bottom center, not the geometric center. `Block` with `base="center"` uses center coordinates.

## Selections

Box selection for faces or domains:

```java
model.component("comp1").selection().create("sel_box", "Box");
model.component("comp1").selection("sel_box").set("entitydim", 3);
model.component("comp1").selection("sel_box").set("xmin", "-250");
model.component("comp1").selection("sel_box").set("xmax", "250");
model.component("comp1").selection("sel_box").set("ymin", "-250");
model.component("comp1").selection("sel_box").set("ymax", "250");
model.component("comp1").selection("sel_box").set("zmin", "-110");
model.component("comp1").selection("sel_box").set("zmax", "110");
model.component("comp1").selection("sel_box").set("condition", "inside");
```

Use `entitydim=2` for faces and `entitydim=3` for domains in 3D. Use `entitydim=1` for boundaries in 2D.

Ball selection:

```java
model.component("comp1").selection().create("sel_ball", "Ball");
model.component("comp1").selection("sel_ball").set("entitydim", 3);
model.component("comp1").selection("sel_ball").set("posx", "0");
model.component("comp1").selection("sel_ball").set("posy", "0");
model.component("comp1").selection("sel_ball").set("posz", "0");
model.component("comp1").selection("sel_ball").set("r", "50");
model.component("comp1").selection("sel_ball").set("condition", "intersects");
```

For elongated domains, prefer `condition="intersects"` over `inside`; `inside` requires the entire domain to fit in the selection volume.

Union selection:

```java
model.component("comp1").selection().create("sel_pair", "Union");
model.component("comp1").selection("sel_pair").set("entitydim", 2);
model.component("comp1").selection("sel_pair").set("input", new String[]{"sel_a", "sel_b"});
```

Assign a default material before overrides:

```java
model.component("comp1").material().create("mat_default", "Common");
model.component("comp1").material("mat_default").selection().all();
model.component("comp1").material("mat_default").propertyGroup("def")
     .set("relpermittivity", new String[]{"eps_default"});
```

Use complex refractive index in `relpermittivity`:

```java
model.component("comp1").material("mat_default").propertyGroup("def")
     .set("relpermittivity", new String[]{"(n_mat+k_mat*i)^2"});
```

There is no reliable Java API material-database shortcut in the recorded local profile. Avoid `materialRef()`, `MaterialUtil.addMaterial()`, and `model.materialDatabase()`; define properties manually or use interpolation/table data.

## Physics Syntax

Electromagnetic Waves, Frequency Domain:

```java
model.component("comp1").physics().create("ewfd", "ElectromagneticWavesFrequencyDomain", "geom1");
```

Periodic condition on a boundary or face pair:

```java
model.component("comp1").physics("ewfd").create("pc1", "PeriodicCondition", 2);
model.component("comp1").physics("ewfd").feature("pc1").selection().named("sel_pair");
model.component("comp1").physics("ewfd").feature("pc1").set("PeriodicType", "Floquet");
model.component("comp1").physics("ewfd").feature("pc1").set("kFloquet", new String[]{"kx", "0", "0"});
```

Use dimension argument `1` for 2D boundaries and `2` for 3D faces.

For two independent periodic directions, create two separate `PeriodicCondition` features and bind each one to its own paired-boundary selection. Do not combine x- and y-direction boundary pairs into a single Floquet feature unless the local model has proven that combined selection behaves correctly.

Scattering boundary condition:

```java
model.component("comp1").physics("ewfd").create("sctr1", "Scattering", 2);
model.component("comp1").physics("ewfd").feature("sctr1").selection().named("sel_zmax");
model.component("comp1").physics("ewfd").feature("sctr1").set("Order", "SecondOrder");
```

Feature type is `"Scattering"`, not `"ScatteringBoundaryCondition"`.

PML coordinate system:

```java
model.component("comp1").coordSystem().create("pml1", "PML");
model.component("comp1").coordSystem("pml1").selection().named("sel_pml");
model.component("comp1").coordSystem("pml1").set("ScalingType", "Cartesian");
```

Keep PML domains in an explicit selection that is separate from the physical region. Exclude PML selections from mode-energy integrals, normalization denominators, and any postprocessing metric that is meant to describe the modeled physical domain.

Far-field domain and child calculation:

```java
model.component("comp1").physics("ewfd").create("ffd1", "FarFieldDomain", 3);
model.component("comp1").physics("ewfd").feature("ffd1").selection().named("sel_farfield_domain");
model.component("comp1").physics("ewfd").feature("ffd1").feature("ffc1").set("FarName", "Efar");
model.component("comp1").physics("ewfd").feature("ffd1").feature("ffc1").selection().named("sel_farfield_boundary");
```

`ffc1` is the common child tag created by `FarFieldDomain` in the recorded pattern. If a local model throws an unknown-feature error, inspect the child feature tags for `ffd1` and update only that child tag.

Create an eigenfrequency study:

```java
model.study().create("std1");
model.study("std1").create("eig", "Eigenfrequency");
model.study("std1").feature("eig").set("neigsactive", true);
model.study("std1").feature("eig").set("neigs", "6");
model.study("std1").feature("eig").set("shift", "f0");
model.sol().create("sol1");
model.sol("sol1").createAutoSequence("std1");
model.sol("sol1").runAll();
```

## Mesh Syntax

Generic automatic mesh:

```java
model.component("comp1").mesh().create("mesh1");
model.component("comp1").mesh("mesh1").autoMeshSize(3);
model.component("comp1").mesh("mesh1").run();
```

Explicit free tetrahedral mesh:

```java
model.component("comp1").mesh().create("mesh1");
model.component("comp1").mesh("mesh1").create("ftet1", "FreeTet");
model.component("comp1").mesh("mesh1").feature("ftet1").create("size1", "Size");
model.component("comp1").mesh("mesh1").feature("ftet1").feature("size1").set("hauto", 4);
model.component("comp1").mesh("mesh1").feature("ftet1").feature("size1").set("hmax", "100[nm]");
model.component("comp1").mesh("mesh1").feature("ftet1").feature("size1").set("hmin", "10[nm]");
model.component("comp1").mesh("mesh1").run();
```

Use explicit `FreeTet` sizing for thin 3D stacks or highly unequal dimensions.

## Result and Table Export

Export global results:

```java
model.result().numerical().create("gev1", "EvalGlobal");
model.result().numerical("gev1").set("data", "dset1");
model.result().numerical("gev1").set("expr", new String[]{
    "real(freq)",
    "imag(freq)",
    "c_const/real(freq)/1[nm]",
    "real(freq)/(2*imag(freq))",
    "abs(real(freq)/(2*imag(freq)))"
});
model.result().table().create("tbl1", "Table");
model.result().numerical("gev1").set("table", "tbl1");
model.result().numerical("gev1").setResult();
model.result().export().create("tbl_export", "Table");
model.result().export("tbl_export").set("table", "tbl1");
model.result().export("tbl_export").set("filename", "results.txt");
model.result().export("tbl_export").run();
```

Dataset selection matters when a model has multiple studies or solution sequences:

```java
model.result().numerical().create("gev2", "EvalGlobal");
model.result().numerical("gev2").set("data", "dset2");
model.result().numerical("gev2").set("expr", new String[]{"real(freq)"});
```

Set the dataset before `setResult()`.

Volume integral export:

```java
model.result().numerical().create("iv1", "IntVolume");
model.result().numerical("iv1").set("data", "dset1");
model.result().numerical("iv1").selection().named("sel_region");
model.result().numerical("iv1").set("expr", new String[]{"ewfd.normE^2"});
model.result().table().create("tbl_iv", "Table");
model.result().numerical("iv1").set("table", "tbl_iv");
model.result().numerical("iv1").setResult();
model.result().export().create("iv_export", "Table");
model.result().export("iv_export").set("table", "tbl_iv");
model.result().export("iv_export").set("filename", "volume_integral.txt");
model.result().export("iv_export").run();
```

Useful eigenfrequency expressions:

```java
new String[]{
    "real(freq)",
    "imag(freq)",
    "c_const/real(freq)/1[nm]",
    "ewfd.Qfactor",
    "real(freq)/(2*imag(freq))",
    "abs(real(freq)/(2*imag(freq)))"
}
```

Use global `freq` for complex-frequency formula cross-checks. Some model exports expose `ewfd.Qfactor`; if it is unavailable, compute both the signed value `real(freq)/(2*imag(freq))` and the magnitude `abs(real(freq)/(2*imag(freq)))`. The sign depends on the eigenfrequency convention and solver setup; use the magnitude for a portable nonnegative Q column unless the sign is being audited.

## Far-Field Function Export

For an `ElectromagneticWavesFrequencyDomain` model with a `FarFieldDomain`, exported functions can be used without a physics prefix:

```java
String expr = "abs(Efarx(dx,dy,dz))^2+abs(Efary(dx,dy,dz))^2+abs(Efarz(dx,dy,dz))^2";
model.result().numerical().create("gev_ff", "EvalGlobal");
model.result().numerical("gev_ff").set("data", "dset1");
model.result().numerical("gev_ff").set("expr", new String[]{expr});
```

Avoid `ewfd.Efarx(...)` and `comp1.ewfd.Efarx(...)` in this context; they were observed to fail with unknown-function errors.

## Failure Signatures

| Signature | Classification | Smallest patch |
| --- | --- | --- |
| `System.IO.FileLoadException`, HRESULT `0x8009001D`, silent `comsolbatch` exit | launcher or Windows provider failure | Stop retries, capture environment, use read-only inspection if available, and repair the Windows/COMSOL launch environment outside the model script. |
| `NullPointerException` during Eclipse/COMSOL startup | stripped Windows environment | Set the Windows variables above and prepend COMSOL/Windows system paths. |
| Table export cannot open output file | path resolution or overwrite issue | Use explicit project-local export paths and pre-clean existing table files outside COMSOL. |
| Solver returns code 0 but no expected artifact | incomplete export flow | Treat as failure; inspect model export paths and table creation. |
