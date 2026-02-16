#!/usr/bin/env bash
set -euo pipefail

SOURCE_PNG="${1:-Assets/IconCandidates/vitalbar-icon-pulse-grid.png}"
OUTPUT_ICNS="${2:-Assets/AppIcon.icns}"

if [[ ! -f "${SOURCE_PNG}" ]]; then
    echo "icon source not found: ${SOURCE_PNG}" >&2
    exit 1
fi

if ! command -v iconutil >/dev/null 2>&1; then
    echo "iconutil is required but not found" >&2
    exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
    echo "sips is required but not found" >&2
    exit 1
fi

OUTPUT_DIR="$(dirname "${OUTPUT_ICNS}")"
mkdir -p "${OUTPUT_DIR}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vitalbar-icon.XXXXXX")"
ICONSET_DIR="${TMP_DIR}/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

create_icon() {
    local size="$1"
    local name="$2"
    sips -z "${size}" "${size}" "${SOURCE_PNG}" --out "${ICONSET_DIR}/${name}" >/dev/null
}

create_icon 16 "icon_16x16.png"
create_icon 32 "icon_16x16@2x.png"
create_icon 32 "icon_32x32.png"
create_icon 64 "icon_32x32@2x.png"
create_icon 128 "icon_128x128.png"
create_icon 256 "icon_128x128@2x.png"
create_icon 256 "icon_256x256.png"
create_icon 512 "icon_256x256@2x.png"
create_icon 512 "icon_512x512.png"
create_icon 1024 "icon_512x512@2x.png"

iconutil -c icns "${ICONSET_DIR}" -o "${OUTPUT_ICNS}"
echo "${OUTPUT_ICNS}"
