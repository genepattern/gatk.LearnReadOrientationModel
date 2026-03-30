#!/bin/bash
# runLocal.sh -- Run gatk.LearnReadOrientationModel locally in Docker using gpunit test data.
# Uses the same pre-existing broadinstitute/gatk image as the GenePattern module,
# mounting the wrapper script from this directory rather than baking it into the image.
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${MODULE_DIR}/gpunit/data"
RUN_DIR="${MODULE_DIR}/gpunit/local_runs/$(date +%Y%m%d_%H%M%S)"
mkdir -p "${RUN_DIR}"

IMAGE="broadinstitute/gatk:4.1.4.1"
WRAPPER="${MODULE_DIR}/gatk_learnreadorientationmodel_wrapper.sh"

echo "=== gatk.LearnReadOrientationModel local Docker test run ==="
echo "=== Image:   ${IMAGE}"
echo "=== Data:    ${DATA_DIR}"
echo "=== Output:  ${RUN_DIR}"
echo ""

# GenePattern passes multi-value FILE parameters as a list file (one absolute
# path per line).  Simulate that here by writing a list file into the run dir.
LIST_FILE="${RUN_DIR}/input.tar.gz.list"
echo "/data/f1r2_test.tar.gz" > "${LIST_FILE}"

CMD=(docker run --rm
  -v "${DATA_DIR}:/data"
  -v "${RUN_DIR}:/work"
  -v "${WRAPPER}:/usr/local/bin/gatk_learnreadorientationmodel_wrapper.sh"
  -w /work
  "${IMAGE}"
  bash /usr/local/bin/gatk_learnreadorientationmodel_wrapper.sh
    --input.tar.gz /work/input.tar.gz.list
    --output.file.name artifact-prior.tar.gz
)

echo "=== Running command ==="
echo "${CMD[*]}"
echo ""

"${CMD[@]}"

echo ""
echo "=== Run complete. Output files in: ${RUN_DIR} ==="
ls -lh "${RUN_DIR}/"
