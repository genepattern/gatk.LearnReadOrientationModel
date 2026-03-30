#!/bin/bash
set -euo pipefail

# gatk.LearnReadOrientationModel GenePattern wrapper
# Learns read orientation artifact priors from F1R2 counts produced by
# Mutect2 or CollectF1R2Counts. Output is a tar.gz artifact prior file
# used by FilterMutectCalls to filter orientation bias artifacts.
#
# Required GATK arguments: -I (one or more F1R2 tar.gz inputs), -O (output)
# Optional GATK arguments: --num-em-iterations, --convergence-threshold,
#   --max-depth, --arguments_file, --gatk-config-file

TOOL_NAME="gatk.LearnReadOrientationModel"

# ---------------------------------------------------------------------------
# Parameter variables (populated by parse_arguments)
# ---------------------------------------------------------------------------
INPUT_TAR_GZ_FILES=()
OUTPUT_FILE_NAME=""
NUM_EM_ITERATIONS=""
CONVERGENCE_THRESHOLD=""
MAX_DEPTH=""
ARGUMENTS_FILE=""
GATK_CONFIG_FILE=""

# ---------------------------------------------------------------------------
# Cleanup trap -- always runs on EXIT (success or failure)
# ---------------------------------------------------------------------------
cleanup() {
    echo "[INFO] Cleanup complete (no staged files for this tool)."
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "GenePattern wrapper for GATK LearnReadOrientationModel"
    echo ""
    echo "Required options:"
    echo "  --input.tar.gz FILE            F1R2 counts tar.gz from Mutect2 or CollectF1R2Counts"
    echo "                                 (may be repeated for multiple scatters)"
    echo "  --output.file.name TEXT        Name for the output artifact prior tar.gz"
    echo ""
    echo "Optional options:"
    echo "  --num.em.iterations INT        Max EM iterations (default: 20)"
    echo "  --convergence.threshold FLOAT  EM convergence threshold (default: 1e-4)"
    echo "  --max.depth INT                Max depth for histogram grouping"
    echo "  --arguments.file FILE          GATK arguments file"
    echo "  --gatk.config.file FILE        GATK configuration file"
    echo "  -h, --help                     Show this help and exit"
    exit 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_arguments() {
    if [[ $# -eq 0 ]]; then
        echo "[ERROR] No arguments provided."
        usage
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --input.tar.gz)
                INPUT_TAR_GZ_FILES+=("$2")
                shift 2
                ;;
            --output.file.name)
                OUTPUT_FILE_NAME="$2"
                shift 2
                ;;
            --num.em.iterations)
                NUM_EM_ITERATIONS="$2"
                shift 2
                ;;
            --convergence.threshold)
                CONVERGENCE_THRESHOLD="$2"
                shift 2
                ;;
            --max.depth)
                MAX_DEPTH="$2"
                shift 2
                ;;
            --arguments.file)
                ARGUMENTS_FILE="$2"
                shift 2
                ;;
            --gatk.config.file)
                GATK_CONFIG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "[ERROR] Unknown option: $1"
                usage
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------
validate_inputs() {
    local errors=0

    # Required parameter presence checks
    if [[ ${#INPUT_TAR_GZ_FILES[@]} -eq 0 ]]; then
        echo "[ERROR] At least one --input.tar.gz is required."
        errors=$((errors+1))
    fi
    if [[ -z "$OUTPUT_FILE_NAME" ]]; then
        echo "[ERROR] --output.file.name is required."
        errors=$((errors+1))
    fi

    # File existence checks
    for f in "${INPUT_TAR_GZ_FILES[@]}"; do
        if [[ ! -f "$f" ]]; then
            echo "[ERROR] Input F1R2 file not found: $f"
            errors=$((errors+1))
        fi
    done
    if [[ -n "$ARGUMENTS_FILE" && ! -f "$ARGUMENTS_FILE" ]]; then
        echo "[ERROR] Arguments file not found: $ARGUMENTS_FILE"
        errors=$((errors+1))
    fi
    if [[ -n "$GATK_CONFIG_FILE" && ! -f "$GATK_CONFIG_FILE" ]]; then
        echo "[ERROR] GATK config file not found: $GATK_CONFIG_FILE"
        errors=$((errors+1))
    fi

    if [[ "$errors" -gt 0 ]]; then
        echo "[ERROR] $errors validation error(s) found. Exiting."
        exit 1
    fi

    echo "[INFO] Input validation passed."
    echo "[INFO] Number of F1R2 input files: ${#INPUT_TAR_GZ_FILES[@]}"
    for f in "${INPUT_TAR_GZ_FILES[@]}"; do
        echo "[INFO]   $f"
    done
}

# ---------------------------------------------------------------------------
# Execute GATK LearnReadOrientationModel
# ---------------------------------------------------------------------------
run_tool() {
    local -a cmd=(gatk LearnReadOrientationModel)

    # Add each input F1R2 file with -I flag
    for f in "${INPUT_TAR_GZ_FILES[@]}"; do
        cmd+=(-I "$f")
    done

    # Required output
    cmd+=(-O "${OUTPUT_FILE_NAME}")

    # Append optional arguments when provided
    if [[ -n "$NUM_EM_ITERATIONS" ]]; then
        cmd+=(--num-em-iterations "${NUM_EM_ITERATIONS}")
    fi

    if [[ -n "$CONVERGENCE_THRESHOLD" ]]; then
        cmd+=(--convergence-threshold "${CONVERGENCE_THRESHOLD}")
    fi

    if [[ -n "$MAX_DEPTH" ]]; then
        cmd+=(--max-depth "${MAX_DEPTH}")
    fi

    if [[ -n "$ARGUMENTS_FILE" ]]; then
        cmd+=(--arguments_file "${ARGUMENTS_FILE}")
    fi

    if [[ -n "$GATK_CONFIG_FILE" ]]; then
        cmd+=(--gatk-config-file "${GATK_CONFIG_FILE}")
    fi

    echo "[INFO] Executing: ${cmd[*]}"
    echo "-------------------------------------------------------------------"

    "${cmd[@]}"
    local exit_code=$?

    echo "-------------------------------------------------------------------"
    if [[ "$exit_code" -ne 0 ]]; then
        echo "[ERROR] gatk LearnReadOrientationModel failed with exit code ${exit_code}."
        exit "${exit_code}"
    fi

    echo "[INFO] gatk LearnReadOrientationModel completed successfully."
    echo "[INFO] Output written to: ${OUTPUT_FILE_NAME}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo "[INFO] === ${TOOL_NAME} wrapper starting ==="
    echo "[INFO] Working directory: $(pwd)"

    parse_arguments "$@"
    validate_inputs
    run_tool

    echo "[INFO] === ${TOOL_NAME} wrapper finished successfully ==="
}

main "$@"
