#!/usr/bin/env bash
set -euo pipefail

deep=0
cli=0
dry_run=0
out_dir="solver_probe_out/lumerical"
api_path=""
executable=""
license="${ANSYSLMD_LICENSE_FILE:-1055@localhost}"
python_bin="${PYTHON:-}"

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
Usage: probe_lumerical.sh [--dry-run] [--deep] [--cli] [--out-dir DIR] [--api-path PATH] [--executable PATH] [--license VALUE] [--python PYTHON]

Bash wrapper for the FDTD Python probe. It detects Git Bash on Windows versus
Linux first, then chooses an appropriate Python command.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deep) deep=1; shift ;;
    --cli) cli=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --out-dir) out_dir="$2"; shift 2 ;;
    --api-path) api_path="$2"; shift 2 ;;
    --executable) executable="$2"; shift 2 ;;
    --license) license="$2"; shift 2 ;;
    --python) python_bin="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

os_name="$(detect_os)"
if [[ "$os_name" == "unsupported" ]]; then
  echo "Unsupported OS from uname: $(uname -s 2>/dev/null || echo unknown). Supported: Git Bash on Windows, Linux." >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -z "$python_bin" ]]; then
  if [[ "$os_name" == "windows-bash" ]] && command -v py >/dev/null 2>&1; then
    python_bin="py -3"
  elif command -v python3 >/dev/null 2>&1; then
    python_bin="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    python_bin="$(command -v python)"
  else
    echo "No Python interpreter found. Pass --python." >&2
    exit 1
  fi
fi

args=("$script_dir/probe_lumerical.py" "--out-dir" "$out_dir" "--license" "$license")
[[ "$deep" -eq 1 ]] && args+=("--deep")
[[ "$cli" -eq 1 ]] && args+=("--cli")
[[ "$dry_run" -eq 1 ]] && args+=("--dry-run")
[[ -n "$api_path" ]] && args+=("--api-path" "$api_path")
[[ -n "$executable" ]] && args+=("--executable" "$executable")

if [[ "$python_bin" == *" "* ]]; then
  read -r -a python_parts <<<"$python_bin"
  exec "${python_parts[@]}" "${args[@]}"
else
  exec "$python_bin" "${args[@]}"
fi
