#!/usr/bin/env bash
# Local (Linux/macOS) equivalent of lib/scripts/patch.ps1 for the Android target.
#
#   FLUTTER_ROOT=/opt/flutter ./tool/apply_patches_android.sh
#
# It applies the Flutter SDK patches, the material_ui patches (inside the pub
# cache) and the getx patch, exactly like the CI powershell script does.
set -euo pipefail

FLUTTER_ROOT="${FLUTTER_ROOT:-$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "workspace: $ROOT"
echo "flutter:   $FLUTTER_ROOT"

# Normalise CRLF -> LF for every patch we are going to apply, and report the
# resulting end-of-line style so a corrupted checkout is easy to spot.
normalise() {
    local file="$1"
    sed -i 's/\r$//' "$file"
}

apply() {
    local dir="$1" file="$2"
    ( cd "$dir" && git apply "$file" ) && echo "applied $(basename "$file")" \
        || { echo "FAILED $(basename "$file")" >&2; exit 1; }
}

# ---------------------------------------------------------------------------
# 1. Flutter SDK patches
# ---------------------------------------------------------------------------
SDK_PATCHES=(
    modal_barrier.patch
    text_selection.patch
    mouse_cursor.patch
    image_anim.patch
    layout_builder.patch
    navigation_drawer.patch
    popup_menu.patch
    fab.patch
    null_safety_for_selectable_region.patch
    selectable_region.patch
    editable_text.patch
    text_field.patch
    scroll_position.patch
    scrollable.patch
    scrollable_gesture.patch
    draggable_scrollable_sheet.patch
    scaffold.patch
    text.patch
    text_painter.patch
    sliver.patch
    refresh_indicator.patch
    double_tap_gesture.patch
    bottom_sheet_android.patch
    scroll_view.patch
    navigator.patch
)

for p in "${SDK_PATCHES[@]}"; do
    normalise "$ROOT/lib/scripts/$p"
done

( cd "$FLUTTER_ROOT" && git reset --hard HEAD -q )
for p in "${SDK_PATCHES[@]}"; do
    apply "$FLUTTER_ROOT" "$ROOT/lib/scripts/$p"
done

# ---------------------------------------------------------------------------
# 2. material_ui patches (pub cache)
# ---------------------------------------------------------------------------
PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
MATERIAL_DIR="$(find "$PUB_CACHE/hosted/pub.dev" -maxdepth 1 -type d -name 'material_ui-*' | sort | tail -1)"
[ -n "$MATERIAL_DIR" ] || { echo "material_ui not found in pub cache" >&2; exit 1; }
echo "material_ui: $MATERIAL_DIR"

MATERIAL_PATCHES=(
    modal_barrier_material.patch
    navigation_drawer.patch
    popup_menu.patch
    fab.patch
    text_field.patch
    scaffold.patch
    refresh_indicator.patch
    tabs.patch
    motion.patch
    glass.patch
    bottom_sheet_android.patch
)

for p in "${MATERIAL_PATCHES[@]}"; do
    normalise "$ROOT/lib/scripts/material/$p"
done

( cd "$MATERIAL_DIR" && git checkout -- . 2>/dev/null || true )
for p in "${MATERIAL_PATCHES[@]}"; do
    apply "$MATERIAL_DIR" "$ROOT/lib/scripts/material/$p"
done

# ---------------------------------------------------------------------------
# 3. getx patch
# ---------------------------------------------------------------------------
GETX_DIR="$(find "$PUB_CACHE/git" -maxdepth 1 -type d -name 'getx-*' | sort | tail -1)"
[ -n "$GETX_DIR" ] || { echo "getx not found in pub cache" >&2; exit 1; }
echo "getx: $GETX_DIR"

normalise "$ROOT/lib/scripts/getx/get_transition.patch"
( cd "$GETX_DIR" && git reset --hard HEAD -q )
apply "$GETX_DIR" "$ROOT/lib/scripts/getx/get_transition.patch"

echo "all patches applied"
