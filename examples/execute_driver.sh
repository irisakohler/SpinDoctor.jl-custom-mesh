#!/bin/bash

JULIA="/home/ikohler/.julia/juliaup/julia-1.7.3+0.x64.linux.gnu/bin/julia"
THREADS=32

MESH_ROOT="/home/ikohler/mesh_from_image/cgal"
LOG_ROOT="/home/ikohler/SpinDoctor.jl/examples/data/logs"
OUTPUT_ROOT="/home/ikohler/SpinDoctor.jl/examples/data"
PARAM_ROOT="/home/ikohler/SpinDoctor.jl/examples/data/parameters"

# list of datasets you want to process
DATASET_NAMES=(
  "2D_mesh_label_mask_big_volume_192x192"
  "2D_mesh_label_mask_big_volume_288x288"
  "2D_mesh_label_mask_big_volume_448x448"
  "2D_mesh_label_mask_big_volume_608x608"
  "2D_mesh_label_mask_big_volume_768x768"
  "2D_mesh_label_mask_big_volume_928x928"
)

B_VALUE=800
GRADIENT_DIRECTION="x"

for DATASET in "${DATASET_NAMES[@]}"; do

    MESH_PATH=$(find "$MESH_ROOT/$DATASET" -mindepth 1 -maxdepth 1 -type d | head -n 1)

    if [[ -z "$MESH_PATH" ]]; then
      echo "Error: no subfolder found inside $MESH_ROOT/$DATASET"
      exit 1
    fi

    LOG_DIR="$LOG_ROOT/$DATASET"

    mkdir -p "$LOG_DIR"

    # log filename with timestamp
    LOGFILE="$LOG_DIR/log_$(date +%Y%m%d_%H%M%S).log"

    echo "Running dataset: $DATASET"
    echo "Logging to: $LOGFILE"

    # Run simulation with /usr/bin/time -v and log everything
    /usr/bin/time -v $JULIA -t $THREADS custom_driver.jl "$MESH_PATH" "$DATASET" "$B_VALUE" "$GRADIENT_DIRECTION" "$OUTPUT_ROOT" "$PARAM_ROOT" \
        > >(tee "$LOGFILE") \
        2> >(tee -a "$LOGFILE" >&2)

done
