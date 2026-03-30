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
# GenePattern passes multi-value FILE parameters (numValues=1+) as a single
# path to a list file containing one absolute file path per line.  The
# variable below holds that list-file path; expand_inputs() reads it and
# populates INPUT_TAR_GZ_FILES with the actual tar.gz paths.
INPUT_TAR_GZ_LIST_FILE=""
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
    echo "  --input.tar.gz FILE            Path to a GenePattern list file whose lines are"
    echo "                                 absolute paths to F1R2 tar.gz files (one per line)."
    echo "                                 GenePattern generates this list file automatically"
    echo "                                 when multiple files are submitted for a 1+ parameter."
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
                # GenePattern passes a single list-file path for multi-value FILE params.
                # expand_inputs() will read the actual tar.gz paths from this file.
                INPUT_TAR_GZ_LIST_FILE="$2"
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
# Expand multi-value FILE input
#
# GenePattern passes multi-value FILE parameters (numValues=1+ or 0+) as a
# single path to a server-generated list file.  Each line of that list file
# is an absolute path to one of the actual input files.  This function reads
# the list file and populates INPUT_TAR_GZ_FILES with the real paths.
# ---------------------------------------------------------------------------
expand_inputs() {
    if [[ -z "$INPUT_TAR_GZ_LIST_FILE" ]]; then
        echo "[ERROR] --input.tar.gz is required."
        exit 1
    fi
    if [[ ! -f "$INPUT_TAR_GZ_LIST_FILE" ]]; then
        echo "[ERROR] Input list file not found: $INPUT_TAR_GZ_LIST_FILE"
        exit 1
    fi

    echo "[INFO] Reading F1R2 input paths from list file: $INPUT_TAR_GZ_LIST_FILE"
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip blank lines
        [[ -z "$line" ]] && continue
        INPUT_TAR_GZ_FILES+=("$line")
    done < "$INPUT_TAR_GZ_LIST_FILE"

    if [[ ${#INPUT_TAR_GZ_FILES[@]} -eq 0 ]]; then
        echo "[ERROR] No F1R2 file paths found in list file: $INPUT_TAR_GZ_LIST_FILE"
        exit 1
    fi

    echo "[INFO] Found ${#INPUT_TAR_GZ_FILES[@]} F1R2 input file(s):"
    for f in "${INPUT_TAR_GZ_FILES[@]}"; do
        echo "[INFO]   $f"
    done
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------
validate_inputs() {
    local errors=0

    if [[ -z "$OUTPUT_FILE_NAME" ]]; then
        echo "[ERROR] --output.file.name is required."
        errors=$((errors+1))
    fi

    # File existence checks for each expanded F1R2 path
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
    expand_inputs
    validate_inputs
    run_tool

    echo "[INFO] === ${TOOL_NAME} wrapper finished successfully ==="
}

main "$@"
