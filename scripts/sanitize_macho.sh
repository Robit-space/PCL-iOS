#!/bin/bash
set -euo pipefail

ROOT="$1"

echo "[PCL-iOS] Sanitizing Mach-O files..."

find "$ROOT" -type f -print0 |
while IFS= read -r -d '' file; do

    if ! file -b "$file" | grep -q "Mach-O"; then
        continue
    fi

    echo "[Mach-O] $file"
    info="$(lipo -info "$file" 2>&1 || true)"

    if echo "$info" | grep -q "Architectures in the fat file"; then

        if ! echo "$info" | grep -qw arm64; then
            echo "ERROR: fat binary has no arm64: $file"
            exit 1
        fi

        tmp="${file}.arm64"
        lipo "$file" -thin arm64 -output "$tmp"
        mv "$tmp" "$file"

        echo "  -> thinned to arm64"
    fi

    codesign --remove-signature "$file" \
        >/dev/null 2>&1 || true

    if ! ldid -S -M "$file"; then
        echo "ERROR: ldid failed on:"
        echo "$file"
        exit 1
    fi

done

echo "[PCL-iOS] Mach-O sanitize complete"
