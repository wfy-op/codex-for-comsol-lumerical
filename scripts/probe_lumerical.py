from __future__ import annotations

import argparse
import importlib
import json
import os
import socket
import subprocess
import sys
from pathlib import Path


DEFAULT_ROOT = Path(r"C:\Program Files\Lumerical")
DEFAULT_LICENSE = "1055@localhost"


def discover_api_path(explicit: str | None) -> Path | None:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit))
    if os.environ.get("LUMERICAL_PYTHON_API"):
        candidates.append(Path(os.environ["LUMERICAL_PYTHON_API"]))
    if os.environ.get("LUMERICAL_ROOT"):
        candidates.append(Path(os.environ["LUMERICAL_ROOT"]) / "api" / "python" / "lumapi.py")
    if DEFAULT_ROOT.exists():
        for version_dir in sorted(DEFAULT_ROOT.glob("v*"), reverse=True):
            candidates.append(version_dir / "api" / "python" / "lumapi.py")
    for candidate in candidates:
        if candidate.exists():
            return candidate.resolve()
    return candidates[0] if candidates else None


def discover_cli(explicit: str | None) -> Path | None:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit))
    if os.environ.get("LUMERICAL_FDTD_EXECUTABLE"):
        candidates.append(Path(os.environ["LUMERICAL_FDTD_EXECUTABLE"]))
    if DEFAULT_ROOT.exists():
        for version_dir in sorted(DEFAULT_ROOT.glob("v*"), reverse=True):
            candidates.append(version_dir / "bin" / "fdtd-solutions.exe")
    for candidate in candidates:
        if candidate.exists():
            return candidate.resolve()
    return candidates[0] if candidates else None


def normalize_env(api_path: Path | None, cli_path: Path | None, license_server: str) -> dict[str, str]:
    env = os.environ.copy()
    install_root: Path | None = None
    if api_path and api_path.name.lower() == "lumapi.py":
        install_root = api_path.parents[2]
    elif cli_path:
        install_root = cli_path.parents[1]

    if install_root:
        prepend = [
            install_root / "bin",
            install_root / "licensingclient" / "winx64",
        ]
        existing = env.get("PATH") or env.get("Path") or ""
        env["PATH"] = os.pathsep.join(str(path) for path in prepend if path.exists()) + os.pathsep + existing
        env["Path"] = env["PATH"]
        env.setdefault("LUMERICAL_ROOT", str(install_root))
        env.setdefault("LUMERICAL_PYTHON_API", str(install_root / "api" / "python" / "lumapi.py"))

    env.setdefault("ANSYSLMD_LICENSE_FILE", license_server)
    env.setdefault("COMPUTERNAME", socket.gethostname().split(".")[0])
    return env


def import_lumapi(api_path: Path, env: dict[str, str]):
    os.environ.update(env)
    api_dir = str(api_path.parent)
    if api_dir not in sys.path:
        sys.path.insert(0, api_dir)
    return importlib.import_module("lumapi")


def run_cli_probe(executable: Path, out_dir: Path, env: dict[str, str]) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    sentinel = out_dir / "lumerical_cli_probe.txt"
    script = out_dir / "lumerical_cli_probe.lsf"
    script.write_text(f'write("{sentinel.as_posix()}", "LUMERICAL_CLI_PROBE_OK");\nexit;\n', encoding="utf-8")
    completed = subprocess.run(
        [str(executable), "-run", str(script)],
        cwd=str(out_dir),
        check=False,
        capture_output=True,
        text=True,
        env=env,
        timeout=180,
    )
    report = script.with_suffix(".xml")
    report_text = report.read_text(encoding="utf-8", errors="replace") if report.exists() else ""
    success = completed.returncode == 0 and sentinel.exists() and ("errors=\"0\"" in report_text if report_text else True)
    return {
        "name": "cli_lsf_run",
        "command": [str(executable), "-run", str(script)],
        "returncode": completed.returncode,
        "stdout": completed.stdout[-4000:],
        "stderr": completed.stderr[-4000:],
        "sentinel": str(sentinel),
        "sentinel_exists": sentinel.exists(),
        "report_file": str(report) if report.exists() else None,
        "success": success,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Probe local Ansys Lumerical FDTD automation.")
    parser.add_argument("--deep", action="store_true", help="Start a solver session or run a CLI LSF sentinel.")
    parser.add_argument("--cli", action="store_true", help="Use fdtd-solutions.exe -run instead of lumapi.")
    parser.add_argument("--dry-run", action="store_true", help="Resolve paths and environment without starting FDTD.")
    parser.add_argument("--out-dir", default="solver_probe_out/lumerical")
    parser.add_argument("--api-path")
    parser.add_argument("--executable")
    parser.add_argument("--license", default=DEFAULT_LICENSE)
    args = parser.parse_args()

    api_path = discover_api_path(args.api_path)
    cli_path = discover_cli(args.executable)
    env = normalize_env(api_path, cli_path, args.license)
    out_dir = Path(args.out_dir)

    payload: dict = {
        "backend": "lumerical",
        "probe_level": "dry_run" if args.dry_run else ("cli_lsf_run" if args.cli and args.deep else ("session_start" if args.deep else "module_import")),
        "dry_run": bool(args.dry_run),
        "api_path": str(api_path) if api_path else None,
        "cli_executable": str(cli_path) if cli_path else None,
        "checks": [],
        "success": False,
    }

    if args.dry_run:
        payload["checks"].append({
            "name": "path_resolution",
            "api_path_exists": bool(api_path and api_path.exists()),
            "cli_executable_exists": bool(cli_path and cli_path.exists()),
            "license_env": env.get("ANSYSLMD_LICENSE_FILE"),
            "success": bool((api_path and api_path.exists()) or (cli_path and cli_path.exists())),
        })
    elif args.cli:
        if not cli_path or not cli_path.exists():
            payload["checks"].append({"name": "cli_executable", "success": False, "stderr": "fdtd-solutions.exe was not found."})
        elif args.deep:
            payload["checks"].append(run_cli_probe(cli_path, out_dir, env))
        else:
            payload["checks"].append({"name": "cli_executable", "success": True, "executable": str(cli_path)})
    else:
        if not api_path or not api_path.exists():
            payload["checks"].append({"name": "api_path", "success": False, "stderr": "lumapi.py was not found."})
        else:
            try:
                lumapi = import_lumapi(api_path, env)
                payload["checks"].append({"name": "module_import", "success": True, "module_file": getattr(lumapi, "__file__", "unknown")})
                if args.deep:
                    session = lumapi.FDTD()
                    try:
                        payload["checks"].append({"name": "session_start", "success": True, "product": "FDTD"})
                    finally:
                        try:
                            session.close()
                        except Exception:
                            pass
            except Exception as exc:
                payload["checks"].append({"name": "probe_error", "success": False, "stderr": str(exc)})

    payload["success"] = bool(payload["checks"]) and all(check.get("success") for check in payload["checks"])
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "lumerical_probe.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    return 0 if payload["success"] or args.dry_run else 1


if __name__ == "__main__":
    raise SystemExit(main())
