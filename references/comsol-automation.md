# COMSOL Automation Reference

Use this reference for local COMSOL connection checks, Java API probes, batch runs, and result-table exports.

## Verified Local Environment

- COMSOL: `6.3.0.290`
- Batch executable: `C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolbatch.exe`
- Java compiler wrapper: `C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64\comsolcompile.exe`
- Preferred workflow: write Java API file, compile with `comsolcompile.exe`, run the `.class` with `comsolbatch.exe`.
- Avoid MPh Python on the recorded Windows installation because it was observed to crash.

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

## Generic Java API Patterns

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

Export global results:

```java
model.result().numerical().create("gev1", "EvalGlobal");
model.result().numerical("gev1").set("data", "dset1");
model.result().numerical("gev1").set("expr", new String[]{
    "real(freq)",
    "imag(freq)",
    "c_const/real(freq)/1[nm]",
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
