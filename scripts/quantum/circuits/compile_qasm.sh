#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CIRCUITS_DIR="${PROJECT_ROOT}/src/quantum-circuits"
BUILD_DIR="${PROJECT_ROOT}/dist/quantum-circuits"

PYTHON="${PYTHON:-python3}"

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --all           Compile all circuits (default)"
    echo "  --circuit       Compile specific circuit file"
    echo "  --validate-only Only validate syntax, skip transpilation"
    echo "  --output        Output directory"
    echo "  --help          Show this help"
    exit 0
}

validate_qasm() {
    local qasm_file="$1"
    echo "  Validating: ${qasm_file}"

    if [ ! -f "${qasm_file}" ]; then
        echo "    ERROR: File not found"
        return 1
    fi

    if ! head -1 "${qasm_file}" | grep -q "OPENQASM 3.0"; then
        echo "    WARNING: File may not be OpenQASM 3.0"
    fi

    if grep -q "include \"stdgates.inc\";" "${qasm_file}"; then
        echo "    Standard gates included"
    fi

    local qubit_count
    qubit_count=$(grep -c "^[[:space:]]*qubit" "${qasm_file}" || true)
    echo "    Qubit declarations: ${qubit_count}"

    local gate_count
    gate_count=$(grep -cP "^\s+(h|cx|cz|swap|rx|ry|rz|cp|ccx|mcx|reset|measure)\s" "${qasm_file}" || true)
    echo "    Gate operations: ${gate_count}"

    local lines
    lines=$(wc -l < "${qasm_file}")
    echo "    Lines: ${lines}"

    return 0
}

transpile_qasm() {
    local qasm_file="$1"
    local output_dir="$2"
    local name
    name=$(basename "${qasm_file}" .qasm)

    echo "  Transpiling: ${name}"

    local output_file="${output_dir}/${name}_transpiled.qasm"
    cp "${qasm_file}" "${output_file}"
    echo "    -> ${output_file}"
}

compile_circuit() {
    local circuit_path="$1"
    local output_dir="$2"
    local validate_only="$3"

    local name
    name=$(basename "${circuit_path}" .qasm)
    local category
    category=$(basename "$(dirname "${circuit_path}")")

    echo ""
    echo "[${category}/${name}]"

    mkdir -p "${output_dir}/${category}"

    if ! validate_qasm "${circuit_path}"; then
        return 1
    fi

    if [ "${validate_only}" != "true" ]; then
        transpile_qasm "${circuit_path}" "${output_dir}/${category}"
    fi

    echo "  OK"
}

compile_all() {
    local output_dir="$1"
    local validate_only="$2"

    echo "Compiling all OpenQASM circuits..."
    echo ""

    local count=0
    local success=0
    local failed=0

    while IFS= read -r -d '' qasm_file; do
        count=$((count + 1))
        if compile_circuit "${qasm_file}" "${output_dir}" "${validate_only}"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
    done < <(find "${CIRCUITS_DIR}" -name "*.qasm" -print0)

    echo ""
    echo "========================================"
    echo "  Compiled: ${success}, Failed: ${failed}, Total: ${count}"
    echo "  Output: ${output_dir}"
    echo "========================================"
}

main() {
    local mode="all"
    local circuit_file=""
    local validate_only="false"
    local output_dir="${BUILD_DIR}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all) mode="all" ;;
            --circuit) circuit_file="$2"; shift ;;
            --validate-only) validate_only="true" ;;
            --output) output_dir="$2"; shift ;;
            --help) usage ;;
            *) echo "Unknown option: $1"; usage ;;
        esac
        shift
    done

    mkdir -p "${output_dir}"

    if [ -n "${circuit_file}" ]; then
        compile_circuit "${circuit_file}" "${output_dir}" "${validate_only}"
    elif [ "${mode}" = "all" ]; then
        compile_all "${output_dir}" "${validate_only}"
    fi
}

main "$@"
