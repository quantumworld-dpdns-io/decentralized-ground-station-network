#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GO_SRC="${PROJECT_ROOT}/src/backend"
RUST_SRC="${PROJECT_ROOT}/src/crypto-kernel"
PYTHON_SRC="${PROJECT_ROOT}/src/quantum-engine"
JULIA_SRC="${PROJECT_ROOT}/src/signal-processing"
FRONTEND_SRC="${PROJECT_ROOT}/src/frontend"

COVERAGE_DIR="${PROJECT_ROOT}/coverage"
mkdir -p "${COVERAGE_DIR}"

PASS=0
FAIL=0
SKIP=0

results=()

print_banner() {
    echo ""
    echo "=========================================="
    echo "  DGSN Unit Tests - $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "=========================================="
    echo ""
}

print_result() {
    local status="$1"
    local name="$2"
    local duration="$3"
    local msg="${4:-}"

    if [ "${status}" = "PASS" ]; then
        echo -e "  ${GREEN}✓${NC} ${name} (${duration}s)"
        PASS=$((PASS + 1))
    elif [ "${status}" = "FAIL" ]; then
        echo -e "  ${RED}✗${NC} ${name} (${duration}s)"
        [ -n "${msg}" ] && echo "    ${msg}"
        FAIL=$((FAIL + 1))
    else
        echo -e "  ${YELLOW}⊘${NC} ${name}"
        SKIP=$((SKIP + 1))
    fi
}

run_go_tests() {
    echo ""
    echo -e "${BLUE}[Go Backend]${NC}"
    if [ -d "${GO_SRC}" ]; then
        local start=$(date +%s)
        cd "${GO_SRC}"
        if go test -v -race -count=1 -coverprofile="${COVERAGE_DIR}/go.out" ./... 2>&1; then
            local end=$(date +%s)
            local duration=$((end - start))
            print_result "PASS" "go test -race ./..." "${duration}"
            go tool cover -func="${COVERAGE_DIR}/go.out" | tail -1
        else
            local end=$(date +%s)
            local duration=$((end - start))
            print_result "FAIL" "go test -race ./..." "${duration}"
        fi
    else
        print_result "SKIP" "go test" "0"
    fi
}

run_rust_tests() {
    echo ""
    echo -e "${BLUE}[Rust Crypto Kernel]${NC}"
    if [ -d "${RUST_SRC}" ]; then
        local start=$(date +%s)
        cd "${RUST_SRC}"
        if cargo test --features pqc 2>&1; then
            local end=$(date +%s)
            local duration=$((end - start))
            print_result "PASS" "cargo test --features pqc" "${duration}"
        else
            local end=$(date +%s)
            local duration=$((end - start))
            print_result "FAIL" "cargo test --features pqc" "${duration}"
        fi
    else
        print_result "SKIP" "cargo test" "0"
    fi
}

run_python_tests() {
    echo ""
    echo -e "${BLUE}[Python Quantum Engine]${NC}"
    if [ -d "${PYTHON_SRC}" ]; then
        local start=$(date +%s)
        cd "${PYTHON_SRC}"
        if python -m pytest --verbose --cov=. --cov-report=term --cov-report=html:"${COVERAGE_DIR}/python" 2>&1; then
            local end=$(date +%s)
            local duration=$((end - start))
            print_result "PASS" "pytest with coverage" "${duration}"
        else
            local end=$(date +%s)
            local duration=$((end - start))
            print_result "FAIL" "pytest with coverage" "${duration}"
        fi
    else
        print_result "SKIP" "pytest" "0"
    fi
}

run_julia_tests() {
    echo ""
    echo -e "${BLUE}[Julia Signal Processing]${NC}"
    if [ -d "${JULIA_SRC}" ]; then
        local start=$(date +%s)
        cd "${JULIA_SRC}"
        if julia --project=. -e "using Pkg; Pkg.test()" 2>&1; then
            local end=$(date +%s)
            local duration=$((end - start))
            print_result "PASS" "Pkg.test()" "${duration}"
        else
            local end=$(date +%s)
            local duration=$((end - start))
            print_result "FAIL" "Pkg.test()" "${duration}"
        fi
    else
        print_result "SKIP" "Pkg.test()" "0"
    fi
}

run_frontend_tests() {
    echo ""
    echo -e "${BLUE}[Frontend]${NC}"
    if [ -d "${FRONTEND_SRC}" ]; then
        local start=$(date +%s)
        cd "${FRONTEND_SRC}"
        if npm test -- --coverage 2>&1; then
            local end=$(date +%s)
            local duration=$((end - start))
            print_result "PASS" "npm test -- --coverage" "${duration}"
        else
            local end=$(date +%s)
            local duration=$((end - start))
            print_result "FAIL" "npm test -- --coverage" "${duration}"
        fi
    else
        print_result "SKIP" "npm test" "0"
    fi
}

print_summary() {
    local total=$((PASS + FAIL + SKIP))
    echo ""
    echo "------------------------------------------"
    echo "  Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped (${total} total)"
    echo "------------------------------------------"
    echo ""

    if [ "${PASS}" -gt 0 ]; then
        echo -e "  ${GREEN}${PASS} tests passed${NC}"
    fi
    if [ "${FAIL}" -gt 0 ]; then
        echo -e "  ${RED}${FAIL} tests failed${NC}"
    fi
    if [ "${SKIP}" -gt 0 ]; then
        echo -e "  ${YELLOW}${SKIP} tests skipped${NC}"
    fi

    return ${FAIL}
}

print_banner

run_go_tests
run_rust_tests
run_python_tests
run_julia_tests
run_frontend_tests

print_summary
