#!/usr/bin/env bash
set -euo pipefail

deep=0
dry_run=0
out_dir="./solver_probe_out/comsol"
comsol_bin="${COMSOL_BIN:-}"

detect_os() {
  local kernel
  kernel="$(uname -s 2>/dev/null || echo unknown)"
  case "$kernel" in
    MINGW*|MSYS*|CYGWIN*) echo "windows-bash" ;;
    Linux*) echo "linux" ;;
    *) echo "unsupported" ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: probe_comsol.sh [--dry-run] [--deep] [--out-dir DIR] [--comsol-bin DIR]

Runs a COMSOL command-line probe from Bash. On Git Bash for Windows, this
delegates to probe_comsol.ps1. On Linux, this runs COMSOL CLI commands directly.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-DryRun) dry_run=1; shift ;;
    --deep|-Deep) deep=1; shift ;;
    --out-dir|-OutDir) out_dir="$2"; shift 2 ;;
    --comsol-bin|-ComsolBin) comsol_bin="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
skill_dir="$(cd "$script_dir/.." && pwd -P)"
os_name="$(detect_os)"

json_escape() {
  local text="${1-}"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\r'/\\r}"
  text="${text//$'\n'/\\n}"
  printf '%s' "$text"
}

to_unix_path() {
  local value="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$value" 2>/dev/null || printf '%s\n' "$value"
  else
    printf '%s\n' "$value"
  fi
}

to_windows_path() {
  local value="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$value" 2>/dev/null || printf '%s\n' "$value"
  else
    printf '%s\n' "$value"
  fi
}

if [[ "$os_name" == "windows-bash" ]]; then
  if ! command -v powershell >/dev/null 2>&1; then
    echo "PowerShell was not found. Install PowerShell or run the Linux branch on a Linux host." >&2
    exit 1
  fi

  ps_args=(-ExecutionPolicy Bypass -File "$(to_windows_path "$script_dir/probe_comsol.ps1")" -OutDir "$(to_windows_path "$out_dir")")
  [[ "$dry_run" -eq 1 ]] && ps_args+=(-DryRun)
  [[ "$deep" -eq 1 ]] && ps_args+=(-Deep)
  [[ -n "$comsol_bin" ]] && ps_args+=(-ComsolBin "$(to_windows_path "$comsol_bin")")
  exec powershell "${ps_args[@]}"
fi

if [[ "$os_name" != "linux" ]]; then
  echo "Unsupported OS from uname: $(uname -s 2>/dev/null || echo unknown). Supported: Git Bash on Windows, Linux." >&2
  exit 2
fi

find_comsol_bin() {
  local candidates=()
  [[ -n "${COMSOL_BIN:-}" ]] && candidates+=("$COMSOL_BIN")
  if [[ -n "${COMSOL_ROOT:-}" ]]; then
    candidates+=("$COMSOL_ROOT/Multiphysics/bin/glnxa64")
    candidates+=("$COMSOL_ROOT/Multiphysics/bin")
    candidates+=("$COMSOL_ROOT/bin/glnxa64")
    candidates+=("$COMSOL_ROOT/bin")
  fi
  candidates+=(
    "/usr/local/comsol"*/Multiphysics/bin/glnxa64
    "/usr/local/comsol"*/Multiphysics/bin
    "/opt/comsol"*/Multiphysics/bin/glnxa64
    "/opt/comsol"*/Multiphysics/bin
    "/opt/COMSOL"*/Multiphysics/bin/glnxa64
    "/opt/COMSOL"*/Multiphysics/bin
  )
  for candidate in "${candidates[@]}"; do
    [[ -d "$candidate" ]] || continue
    if [[ -x "$candidate/comsolbatch" || -x "$candidate/comsol" || -x "$candidate/comsolcompile" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  if command -v comsolbatch >/dev/null 2>&1; then
    dirname "$(command -v comsolbatch)"
    return 0
  fi
  if command -v comsol >/dev/null 2>&1; then
    dirname "$(command -v comsol)"
    return 0
  fi
  return 1
}

run_capture() {
  local name="$1"; shift
  local stdout_file="$out_dir/${name}.stdout"
  local stderr_file="$out_dir/${name}.stderr"
  local rc=0
  "$@" >"$stdout_file" 2>"$stderr_file" || rc=$?
  command_stdout="$(cat "$stdout_file" 2>/dev/null || true)"
  command_stderr="$(cat "$stderr_file" 2>/dev/null || true)"
  command_rc="$rc"
}

mkdir -p "$out_dir"
if [[ -z "$comsol_bin" ]]; then
  comsol_bin="$(find_comsol_bin || true)"
fi

comsol_batch=""
comsol_compile=""
comsol_driver=""
if [[ -n "$comsol_bin" ]]; then
  [[ -x "$comsol_bin/comsolbatch" ]] && comsol_batch="$comsol_bin/comsolbatch"
  [[ -x "$comsol_bin/comsolcompile" ]] && comsol_compile="$comsol_bin/comsolcompile"
  [[ -x "$comsol_bin/comsol" ]] && comsol_driver="$comsol_bin/comsol"
fi

if [[ "$dry_run" -eq 1 ]]; then
  success=false
  [[ -n "$comsol_batch" || -n "$comsol_driver" ]] && [[ -n "$comsol_compile" || -n "$comsol_driver" ]] && success=true
  cat <<EOF
{
  "backend": "comsol",
  "host_os": "linux",
  "probe_level": "dry_run",
  "dry_run": true,
  "comsol_bin": "$(json_escape "$comsol_bin")",
  "checks": [
    {
      "name": "path_resolution",
      "success": $success,
      "comsol_batch": "$(json_escape "${comsol_batch:-$comsol_driver batch}")",
      "comsol_compile": "$(json_escape "${comsol_compile:-$comsol_driver compile}")"
    }
  ],
  "success": $success
}
EOF
  [[ "$success" == "true" ]]
  exit $?
fi

checks_json=""
if [[ -n "$comsol_batch" ]]; then
  version_cmd=("$comsol_batch" "-version")
elif [[ -n "$comsol_driver" ]]; then
  version_cmd=("$comsol_driver" "-version")
else
  echo "COMSOL command was not found. Set COMSOL_BIN or COMSOL_ROOT." >&2
  exit 1
fi

run_capture version_check "${version_cmd[@]}"
version_success=false
[[ "$command_rc" -eq 0 ]] && version_success=true
checks_json='{"name":"version_check","returncode":'"$command_rc"',"stdout":"'"$(json_escape "$command_stdout")"'","stderr":"'"$(json_escape "$command_stderr")"'","success":'"$version_success"'}'

if [[ "$deep" -eq 1 ]]; then
  java_path="$out_dir/ComsolProbeMinimal.java"
  cat >"$java_path" <<'EOF'
import com.comsol.model.*;
import com.comsol.model.util.*;

public class ComsolProbeMinimal {
  public static void main(String[] args) throws Exception {
    Model model = ModelUtil.create("Model");
    model.label("comsol_probe_minimal");
    model.param().set("probe_one", "1", "Probe scalar");
    System.out.println("COMSOL_PROBE_MINIMAL_OK");
  }
}
EOF

  if [[ -n "$comsol_compile" ]]; then
    compile_cmd=("$comsol_compile" "$java_path")
  else
    compile_cmd=("$comsol_driver" "compile" "$java_path")
  fi
  run_capture minimal_compile "${compile_cmd[@]}"
  compile_success=false
  [[ "$command_rc" -eq 0 ]] && compile_success=true
  checks_json+=',{"name":"minimal_compile","returncode":'"$command_rc"',"stdout":"'"$(json_escape "$command_stdout")"'","stderr":"'"$(json_escape "$command_stderr")"'","success":'"$compile_success"'}'

  if [[ "$compile_success" == "true" ]]; then
    class_path="$out_dir/ComsolProbeMinimal.class"
    expected_artifact="$out_dir/comsol_probe_minimal.mph"
    if [[ -n "$comsol_batch" ]]; then
      run_cmd=("$comsol_batch" "-inputfile" "$class_path" "-outputfile" "$expected_artifact")
    else
      run_cmd=("$comsol_driver" "batch" "-inputfile" "$class_path" "-outputfile" "$expected_artifact")
    fi
    run_capture minimal_run_save "${run_cmd[@]}"
    actual_artifact="$expected_artifact"
    [[ -f "$actual_artifact" ]] || actual_artifact="$out_dir/comsol_probe_minimal_Model.mph"
    artifact_exists=false
    [[ -f "$actual_artifact" ]] && artifact_exists=true
    sentinel_seen=false
    [[ "$command_stdout" == *"COMSOL_PROBE_MINIMAL_OK"* ]] && sentinel_seen=true
    run_success=false
    [[ "$command_rc" -eq 0 && "$artifact_exists" == "true" && "$sentinel_seen" == "true" ]] && run_success=true
    checks_json+=',{"name":"minimal_run_save","returncode":'"$command_rc"',"stdout":"'"$(json_escape "$command_stdout")"'","stderr":"'"$(json_escape "$command_stderr")"'","created_artifact":"'"$(json_escape "$actual_artifact")"'","artifact_exists":'"$artifact_exists"',"sentinel_seen":'"$sentinel_seen"',"success":'"$run_success"'}'
  fi
fi

payload_success=true
if [[ "$checks_json" == *'"success":false'* ]]; then
  payload_success=false
fi

cat >"$out_dir/comsol_probe.json" <<EOF
{
  "backend": "comsol",
  "host_os": "linux",
  "probe_level": "$([[ "$deep" -eq 1 ]] && echo deep_compile_run_save || echo version_check)",
  "dry_run": false,
  "comsol_bin": "$(json_escape "$comsol_bin")",
  "checks": [$checks_json],
  "success": $payload_success
}
EOF
cat "$out_dir/comsol_probe.json"
[[ "$payload_success" == "true" ]]
