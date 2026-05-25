#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PYTHON_SRC="${PROJECT_ROOT}/src/quantum-engine"
RESULTS_DIR="${PROJECT_ROOT}/benchmark-results"

PYTHON="${PYTHON:-python3}"
REPORT_FORMAT="${REPORT_FORMAT:-json}"

BENCHMARK_CATEGORIES=(
    "circuits/scheduling"
    "circuits/optimization"
    "circuits/signal_processing"
    "qiskit_wrapper"
)

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --all           Run all benchmarks (default)"
    echo "  --category      Run specific category"
    echo "  --output        Results directory"
    echo "  --format        Report format (json, html, csv)"
    echo "  --quick         Run with fewer iterations"
    echo "  --full          Run comprehensive benchmarks"
    echo "  --compare       Compare with previous results"
    echo "  --help          Show this help"
    exit 0
}

setup_environment() {
    echo "Setting up benchmark environment..."
    cd "${PYTHON_SRC}"

    if ! ${PYTHON} -c "import pytest_benchmark" 2>/dev/null; then
        pip install pytest-benchmark
    fi

    mkdir -p "${RESULTS_DIR}"
}

run_benchmark_category() {
    local category="$1"
    local output_dir="$2"
    local benchmark_args="$3"
    local category_name
    category_name=$(basename "${category}")
    local output_file="${output_dir}/${category_name}-benchmark.${REPORT_FORMAT}"

    echo ""
    echo "========================================"
    echo "  Benchmark: ${category}"
    echo "========================================"

    local tests_path="${PYTHON_SRC}/${category}/tests"
    if [ -d "${tests_path}" ]; then
        cd "${PYTHON_SRC}"
        ${PYTHON} -m pytest "${tests_path}" \
            --benchmark-only \
            --benchmark-json="${output_file}" \
            ${benchmark_args} \
            2>&1 || true
        echo "  Results: ${output_file}"
    else
        echo "  No tests found in ${tests_path}"
    fi
}

run_all_benchmarks() {
    local output_dir="$1"
    local benchmark_args="$2"

    echo "Running all quantum benchmarks..."
    echo ""

    for category in "${BENCHMARK_CATEGORIES[@]}"; do
        run_benchmark_category "${category}" "${output_dir}" "${benchmark_args}"
    done

    echo ""
    echo "Generating summary report..."
    generate_summary "${output_dir}"
}

generate_summary() {
    local output_dir="$1"
    local summary_file="${output_dir}/summary.${REPORT_FORMAT}"

    if [ "${REPORT_FORMAT}" = "json" ]; then
        ${PYTHON} -c "
import json, glob, os

results_dir = '${output_dir}'
all_results = {'benchmarks': [], 'categories': {}}

for bench_file in glob.glob(os.path.join(results_dir, '*-benchmark.json')):
    with open(bench_file) as f:
        data = json.load(f)
        category = os.path.basename(bench_file).replace('-benchmark.json', '')
        all_results['categories'][category] = {
            'total': len(data.get('benchmarks', [])),
            'mean_time': sum(b.get('stats', {}).get('mean', 0) for b in data.get('benchmarks', [])),
        }
        all_results['benchmarks'].extend(data.get('benchmarks', []))

with open('${summary_file}', 'w') as f:
    json.dump(all_results, f, indent=2)
print(f'Summary: {\"${summary_file}\"}')
"
    fi
}

compare_results() {
    local base_dir="${RESULTS_DIR}/previous"
    local current_dir="${RESULTS_DIR}"

    if [ ! -d "${base_dir}" ]; then
        echo "No previous results to compare against."
        echo "Run benchmarks first, then copy results to ${base_dir}"
        return
    fi

    echo ""
    echo "Comparing with previous results..."
    ${PYTHON} -c "
import json, glob, os

current = '${current_dir}'
previous = '${base_dir}'

for bench_file in glob.glob(os.path.join(current, '*-benchmark.json')):
    name = os.path.basename(bench_file)
    prev_file = os.path.join(previous, name)
    if os.path.exists(prev_file):
        with open(bench_file) as f:
            cur_data = json.load(f)
        with open(prev_file) as f:
            prev_data = json.load(f)
        print(f'\n{name}:')
        for cb, pb in zip(cur_data.get('benchmarks', []), prev_data.get('benchmarks', [])):
            cur_mean = cb.get('stats', {}).get('mean', 0)
            prev_mean = pb.get('stats', {}).get('mean', 0)
            if prev_mean > 0:
                change = ((cur_mean - prev_mean) / prev_mean) * 100
                marker = '✓' if change <= 0 else '✗'
                print(f'  {marker} {cb.get(\"name\", \"\")}: {change:+.1f}%')
"
}

main() {
    local mode="all"
    local category=""
    local output_dir="${RESULTS_DIR}"
    local benchmark_args=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all) mode="all" ;;
            --category) category="$2"; shift; mode="category" ;;
            --output) output_dir="$2"; shift ;;
            --format) REPORT_FORMAT="$2"; shift ;;
            --quick) benchmark_args="--benchmark-min-rounds=5 --benchmark-max-time=10" ;;
            --full) benchmark_args="--benchmark-min-rounds=50 --benchmark-max-time=120" ;;
            --compare) mode="compare" ;;
            --help) usage ;;
            *) echo "Unknown option: $1"; usage ;;
        esac
        shift
    done

    setup_environment

    case "${mode}" in
        all)
            if [ -z "${benchmark_args}" ]; then
                benchmark_args=""
            fi
            run_all_benchmarks "${output_dir}" "${benchmark_args}"
            ;;
        category)
            run_benchmark_category "${category}" "${output_dir}" "${benchmark_args}"
            ;;
        compare)
            compare_results
            ;;
    esac

    echo ""
    echo "Benchmark run complete!"
}

main "$@"
