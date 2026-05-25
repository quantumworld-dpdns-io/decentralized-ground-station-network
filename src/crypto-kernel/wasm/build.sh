#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WASM_DIR="$SCRIPT_DIR/pkg"

echo "=== DGSN Crypto Kernel WASM Build ==="
echo "Script dir: $SCRIPT_DIR"
echo "Project dir: $PROJECT_DIR"
echo "WASM output: $WASM_DIR"

if ! command -v wasm-pack &>/dev/null; then
    echo "Error: wasm-pack is not installed."
    echo "Install it with: cargo install wasm-pack"
    exit 1
fi

if ! command -v wasm-opt &>/dev/null; then
    echo "Warning: wasm-opt (binaryen) not found. Skipping optimization."
    WASM_OPT=false
else
    WASM_OPT=true
fi

WASM_TARGET="${WASM_TARGET:-web}"
PROFILE="${PROFILE:-release}"

echo ""
echo "Building with:"
echo "  target: ${WASM_TARGET}"
echo "  profile: ${PROFILE}"
echo "  optimization: ${WASM_OPT}"
echo ""

CARGO_ARGS=()
if [ "$PROFILE" = "release" ]; then
    CARGO_ARGS+=("--release")
fi

cd "$PROJECT_DIR"

wasm-pack build \
    --target "$WASM_TARGET" \
    --out-dir "$WASM_DIR" \
    --out-name "dgsn_crypto_kernel" \
    --features wasm \
    "${CARGO_ARGS[@]}"

echo ""
echo "=== WASM build complete ==="

if [ "$WASM_OPT" = true ]; then
    WASM_FILE="$WASM_DIR/dgsn_crypto_kernel_bg.wasm"
    if [ -f "$WASM_FILE" ]; then
        ORIG_SIZE=$(stat -f%z "$WASM_FILE" 2>/dev/null || stat -c%s "$WASM_FILE" 2>/dev/null || echo 0)
        echo "Optimizing WASM binary (size before: ${ORIG_SIZE} bytes)..."
        wasm-opt -Oz -o "$WASM_FILE" "$WASM_FILE"
        OPT_SIZE=$(stat -f%z "$WASM_FILE" 2>/dev/null || stat -c%s "$WASM_FILE" 2>/dev/null || echo 0)
        echo "Optimization complete (size after: ${OPT_SIZE} bytes, savings: $((ORIG_SIZE - OPT_SIZE)) bytes)"
    fi
fi

echo ""
echo "=== Build output ==="
ls -lh "$WASM_DIR/"
echo ""
echo "To publish:"
echo "  cd $WASM_DIR && npm publish --access public"
