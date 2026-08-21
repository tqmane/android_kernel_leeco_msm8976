#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-out/.config}"
FRAGMENT_FILE="${2:-arch/arm64/configs/lineage_s2_docker.config}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "error: kernel config not found: $CONFIG_FILE" >&2
  exit 1
fi

if [[ ! -f "$FRAGMENT_FILE" ]]; then
  echo "error: Docker config fragment not found: $FRAGMENT_FILE" >&2
  exit 1
fi

missing=0

echo "Verifying Docker/container kernel options..."
while IFS= read -r wanted; do
  symbol=""
  case "$wanted" in
    CONFIG_*=y|CONFIG_*=m|CONFIG_*='""')
      symbol="${wanted%%=*}"

      if grep -Fqx "$wanted" "$CONFIG_FILE"; then
        printf '  [OK] %s\n' "$wanted"
      else
        printf '  [MISMATCH] %s\n' "$wanted" >&2
        actual="$(grep -E "^${symbol}=|^# ${symbol} is not set$" "$CONFIG_FILE" || true)"
        if [[ -n "$actual" ]]; then
          printf '             actual: %s\n' "$actual" >&2
        else
          printf '             actual: symbol absent from generated .config\n' >&2
        fi
        missing=1
      fi
      ;;

    '# CONFIG_'*' is not set')
      symbol="${wanted#\# }"
      symbol="${symbol% is not set}"

      # Kconfig may omit a symbol entirely when one of its dependencies is
      # disabled. For a requested disabled option, both an explicit
      # "# CONFIG_FOO is not set" line and complete absence mean that the
      # resulting kernel cannot enable that feature. Only an active assignment
      # is a mismatch.
      if grep -Eq "^${symbol}=" "$CONFIG_FILE"; then
        printf '  [MISMATCH] %s\n' "$wanted" >&2
        actual="$(grep -E "^${symbol}=" "$CONFIG_FILE" | head -n1)"
        printf '             actual: %s\n' "$actual" >&2
        missing=1
      else
        if grep -Fqx "$wanted" "$CONFIG_FILE"; then
          printf '  [OK] %s\n' "$wanted"
        else
          printf '  [OK] %s (hidden by unmet dependency)\n' "$wanted"
        fi
      fi
      ;;

    *)
      continue
      ;;
  esac
done < "$FRAGMENT_FILE"

if (( missing != 0 )); then
  echo "error: one or more requested Docker options did not survive Kconfig dependency resolution" >&2
  exit 1
fi

echo "Docker/container config verification passed."
