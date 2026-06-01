#!/usr/bin/env bash
set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
python_bin="${PYTHON:-}"
model_path="${MODEL_PATH:-}"
comsol_bin="${COMSOL_BIN:-}"
out_dir="./solver_probe_out/comsol_skill_validation"
deep=0

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
Usage: validate_comsol_skill.sh [--skill-dir DIR] [--python PYTHON] [--model-path MPH] [--comsol-bin DIR] [--out-dir DIR] [--deep]

Validates the COMSOL skill from Bash. On Git Bash for Windows, this delegates
to validate_comsol_skill.ps1. On Linux, this validates structure, Python runtime,
the COMSOL Bash probe, and optionally model loading when --model-path is passed.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir|-SkillDir) skill_dir="$2"; shift 2 ;;
    --python|-Python) python_bin="$2"; shift 2 ;;
    --model-path|-ModelPath) model_path="$2"; shift 2 ;;
    --comsol-bin|-ComsolBin) comsol_bin="$2"; shift 2 ;;
    --out-dir|-OutDir) out_dir="$2"; shift 2 ;;
    --deep|-Deep) deep=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

to_windows_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" 2>/dev/null || printf '%s\n' "$1"
  else
    printf '%s\n' "$1"
  fi
}

os_name="$(detect_os)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ "$os_name" == "windows-bash" ]]; then
  if ! command -v powershell >/dev/null 2>&1; then
    echo "PowerShell was not found. Install PowerShell or run on Linux." >&2
    exit 1
  fi
  ps_args=(-ExecutionPolicy Bypass -File "$(to_windows_path "$script_dir/validate_comsol_skill.ps1")" -SkillDir "$(to_windows_path "$skill_dir")" -OutDir "$(to_windows_path "$out_dir")")
  [[ -n "$python_bin" ]] && ps_args+=(-Python "$(to_windows_path "$python_bin")")
  [[ -n "$model_path" ]] && ps_args+=(-ModelPath "$(to_windows_path "$model_path")")
  [[ -n "$comsol_bin" ]] && ps_args+=(-ComsolBin "$(to_windows_path "$comsol_bin")")
  [[ "$deep" -eq 1 ]] && ps_args+=(-Deep)
  exec powershell "${ps_args[@]}"
fi

if [[ "$os_name" != "linux" ]]; then
  echo "Unsupported OS from uname: $(uname -s 2>/dev/null || echo unknown). Supported: Git Bash on Windows, Linux." >&2
  exit 2
fi

if [[ -z "$python_bin" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python_bin="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    python_bin="$(command -v python)"
  else
    echo "No Python interpreter found. Pass --python." >&2
    exit 1
  fi
fi

mkdir -p "$out_dir"
test -f "$skill_dir/SKILL.md"
test -f "$skill_dir/references/comsol-automation.md"
test -f "$skill_dir/scripts/probe_comsol.sh"
test -f "$skill_dir/scripts/comsol_mph_tool.py"
test -d "$skill_dir/scripts/comsol_mcp_runtime"

"$python_bin" -c 'import sys; import pathlib; print("python_runtime_ok")'

probe_args=("--dry-run" "--out-dir" "$out_dir/probe")
[[ -n "$comsol_bin" ]] && probe_args+=("--comsol-bin" "$comsol_bin")
"$skill_dir/scripts/probe_comsol.sh" "${probe_args[@]}"

if [[ "$deep" -eq 1 ]]; then
  deep_args=("--deep" "--out-dir" "$out_dir/probe_deep")
  [[ -n "$comsol_bin" ]] && deep_args+=("--comsol-bin" "$comsol_bin")
  "$skill_dir/scripts/probe_comsol.sh" "${deep_args[@]}"
fi

"$python_bin" "$skill_dir/scripts/comsol_mph_tool.py" list-tools >"$out_dir/adapter_list_tools.json"

if [[ -n "$model_path" ]]; then
  "$python_bin" "$skill_dir/scripts/comsol_mph_tool.py" batch --json '[{"tool":"comsol_start","args":{}},{"tool":"model_load","args":{"file_path":"'"$model_path"'","set_current":true}},{"tool":"model_inspect","args":{}},{"tool":"param_list","args":{}},{"resource":"comsol://session/info"},{"tool":"comsol_disconnect","args":{}}]' >"$out_dir/mph_model_validation.json"
fi

cat >"$out_dir/validation_summary.json" <<EOF
{
  "success": true,
  "host_os": "linux",
  "skill_dir": "$skill_dir",
  "python": "$python_bin",
  "model_path": "$model_path",
  "out_dir": "$out_dir"
}
EOF
cat "$out_dir/validation_summary.json"
