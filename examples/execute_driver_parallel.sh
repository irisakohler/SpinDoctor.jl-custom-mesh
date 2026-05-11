#!/bin/bash

# -------------------------------------------
# CONFIGURATION
# -------------------------------------------

JULIA="/home/ikohler/.julia/juliaup/julia-1.7.3+0.x64.linux.gnu/bin/julia"
JULIA_THREADS_PER_JOB=1      # Each patch uses 1 Julia thread
MAX_PARALLEL_JOBS=64         # Number of patch jobs run at the same time

SCRIPT_ENVIRONMENT="/home/ikohler/SpinDoctor.jl/examples"

LOG_ROOT="/home/ikohler/SpinDoctor.jl/examples/data/logs/2D_mesh_label_mask_big_volume_918x918_tiled_b800_fixed_gradient_direction_x"
PARENT_DIR="/home/ikohler/mesh_from_image/cgal/2D_mesh_label_mask_big_volume_918x918_tiled"
OUTPUT_ROOT="/home/ikohler/SpinDoctor.jl/examples/data/2D_mesh_label_mask_big_volume_918x918_tiled_b800_fixed_gradient_direction_x"
PARAM_ROOT="/home/ikohler/SpinDoctor.jl/examples/data/parameters"

B_VALUE=800
GRADIENT_DIRECTION="x"

# -------------------------------------------
# Validate parent dir
# -------------------------------------------
if [[ ! -d "$PARENT_DIR" ]]; then
    echo "Error: '$PARENT_DIR' is not a valid directory."
    exit 1
fi

mkdir -p $OUTPUT_ROOT

# -------------------------------------------
# Function to run a single patch job
# -------------------------------------------
run_patch() {
    local MESH_PATH="$1"
    local DATASET="$2"

    LOG_DIR="$LOG_ROOT/$DATASET"
    mkdir -p "$LOG_DIR"

    LOGFILE="$LOG_DIR/log_$(date +%Y%m%d_%H%M%S).log"
    # PERF_LOG="$LOG_DIR/perf_$(date +%Y%m%d_%H%M%S).log"

    echo "[*] Starting patch $DATASET"
    echo "    Log: $LOGFILE"
    # echo "    Perf log: $PERF_LOG"

    # To profile: wrap Julia command with perf
    # perf stat -o "$PERF_LOG" -e ls_any_fills_from_sys.mem_io_local,ls_any_fills_from_sys.mem_io_remote,ls_dmnd_fills_from_sys.mem_io_local,ls_dmnd_fills_from_sys.mem_io_remote,ls_hw_pf_dc_fills.mem_io_local,ls_hw_pf_dc_fills.mem_io_remote,stalled-cycles-backend,cpu-cycles,L1-dcache-loads,L1-dcache-load-misses,L1-dcache-stores,L1-dcache-store-misses,LLC-loads,LLC-load-misses,LLC-stores,LLC-store-misses \
    #     "$JULIA" -t "$JULIA_THREADS_PER_JOB" custom_driver.jl \
    #     "$MESH_PATH" "$DATASET" "$B_VALUE" "$GRADIENT_DIRECTION" "$OUTPUT_ROOT"
    /usr/bin/time -v "$JULIA" --project="$SCRIPT_ENVIRONMENT" -t "$JULIA_THREADS_PER_JOB" custom_driver.jl \
    "$MESH_PATH" "$DATASET" "$B_VALUE" "$GRADIENT_DIRECTION" "$OUTPUT_ROOT" "$PARAM_ROOT" \
    > >(tee "$LOGFILE") \
    2> >(tee -a "$LOGFILE" >&2)
}

export -f run_patch
export JULIA JULIA_THREADS_PER_JOB LOG_ROOT B_VALUE GRADIENT_DIRECTION OUTPUT_ROOT PARAM_ROOT SCRIPT_ENVIRONMENT

cd "$SCRIPT_ENVIRONMENT"
"$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

# -------------------------------------------
# Find all patches and distribute across CPU
# -------------------------------------------
find "$PARENT_DIR" -maxdepth 1 -mindepth 1 -type d | \
    xargs -I {} -P "$MAX_PARALLEL_JOBS" bash -c '
        DATASET=$(basename "{}")
        run_patch "{}" "$DATASET"
    '

echo "All patch simulations completed."
