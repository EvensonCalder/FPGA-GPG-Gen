#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_IN_DIR="$ROOT_DIR/build/gpg_vanity_real_hits_gpg"
DEFAULT_OUT_DIR="$ROOT_DIR/build/gpg_vanity_transferable_gpg"
CERT_TOOL="$ROOT_DIR/tools/gpg_vanity_certify.py"

in_dir="${GPG_VANITY_GPG_DIR:-$DEFAULT_IN_DIR}"
out_dir="${GPG_VANITY_TRANSFERABLE_DIR:-$DEFAULT_OUT_DIR}"
uid="${GPG_VANITY_UID:-GPGgen Vanity Key <gpggen@example.invalid>}"

require_tools() {
  command -v python3 >/dev/null || { echo "missing python3" >&2; exit 1; }
  command -v gpg >/dev/null || { echo "missing gpg" >&2; exit 1; }
}

read_path() {
  local prompt="$1" default="$2" value
  read -r -p "$prompt [$default]: " value
  printf '%s' "${value:-$default}"
}

collect_gpg_files() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "directory does not exist: $dir" >&2
    return 1
  fi
  mapfile -d '' GPG_FILES < <(find "$dir" -maxdepth 1 -type f -name '*.gpg' -print0 | sort -z)
  if [[ ${#GPG_FILES[@]} -eq 0 ]]; then
    echo "no .gpg files found in: $dir" >&2
    return 1
  fi
}

show_config() {
  printf 'Input directory:  %s\n' "$in_dir"
  printf 'Output directory: %s\n' "$out_dir"
  printf 'User ID:          %s\n' "$uid"
}

choose_input_dir() {
  in_dir="$(read_path "Input .gpg directory" "$in_dir")"
}

choose_output_dir() {
  out_dir="$(read_path "Transferable output directory" "$out_dir")"
}

choose_uid() {
  uid="$(read_path "Certificate user ID" "$uid")"
}

list_fingerprints() {
  collect_gpg_files "$in_dir"
  python3 "$CERT_TOOL" info "${GPG_FILES[@]}"
}

convert_all() {
  collect_gpg_files "$in_dir"
  mkdir -p "$out_dir"
  chmod 700 "$out_dir"
  python3 "$CERT_TOOL" convert --uid "$uid" --out-dir "$out_dir" "${GPG_FILES[@]}"
}

verify_transferable_dir() {
  collect_gpg_files "$out_dir"
  local tmp
  tmp="$(mktemp -d)"
  chmod 700 "$tmp"
  trap 'rm -rf "$tmp"' RETURN
  GNUPGHOME="$tmp" gpg --batch --import "${GPG_FILES[@]}"
  GNUPGHOME="$tmp" gpg --batch --list-secret-keys --fingerprint --keyid-format long
}

inspect_packets() {
  collect_gpg_files "$in_dir"
  for f in "${GPG_FILES[@]}"; do
    printf '\n== %s ==\n' "$f"
    gpg --list-packets "$f"
  done
}

main_menu() {
  require_tools
  while true; do
    printf '\nGPGgen Key Tool\n'
    printf '1. Show current config\n'
    printf '2. Choose input .gpg directory\n'
    printf '3. Choose output directory\n'
    printf '4. Set certificate user ID\n'
    printf '5. List fingerprints\n'
    printf '6. Inspect raw packets\n'
    printf '7. Convert all to GnuPG transferable secret certificates and verify\n'
    printf '8. Import-check/list transferable output directory\n'
    printf '9. Quit\n'
    read -r -p '> ' choice
    case "$choice" in
      1) show_config ;;
      2) choose_input_dir ;;
      3) choose_output_dir ;;
      4) choose_uid ;;
      5) list_fingerprints ;;
      6) inspect_packets ;;
      7) convert_all ;;
      8) verify_transferable_dir ;;
      9|q|Q) exit 0 ;;
      *) echo "unknown choice" >&2 ;;
    esac
  done
}

main_menu "$@"
