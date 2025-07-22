#!/bin/bash

# Monte Carlo Batch Job Dispatcher
# Dispatch separate Nomad jobs for multiple tickers

set -e

# Configuration
JOB_NAME="monte-carlo-batch"
DEFAULT_DAYS=252
DEFAULT_SIMULATIONS=10000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Cleanup function to stop all child jobs
cleanup_child_jobs() {
    local job_name="$1"
    log "Cleaning up child jobs for: $job_name"
    
    # Get all jobs with this parent job name
    local child_jobs=()
    while IFS= read -r job_line; do
        # Skip header line and empty lines
        [[ "$job_line" =~ ^ID || -z "$job_line" ]] && continue
        
        # Extract job ID (first field)
        local job_id=$(echo "$job_line" | awk '{print $1}')
        
        # Check if it's a dispatch job (contains the parent job name and dispatch pattern)
        if [[ "$job_id" == "$job_name/dispatch-"* ]]; then
            child_jobs+=("$job_id")
        fi
    done < <(nomad job status 2>/dev/null)
    
    if [[ ${#child_jobs[@]} -eq 0 ]]; then
        warning "No child jobs found for job: $job_name"
        return 0
    fi
    
    log "Found ${#child_jobs[@]} child jobs to stop"
    
    # Stop each child job
    local stopped_count=0
    for job_id in "${child_jobs[@]}"; do
        log "Stopping job: $job_id"
        if nomad job stop "$job_id" >/dev/null 2>&1; then
            success "Stopped: $job_id"
            ((stopped_count++))
        else
            error "Failed to stop: $job_id"
        fi
    done
    
    success "Stopped $stopped_count out of ${#child_jobs[@]} child jobs"
    return 0
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] TICKER1 [TICKER2 TICKER3 ...]

Dispatch separate Monte Carlo batch jobs for multiple tickers.

OPTIONS:
    -d, --days DAYS              Number of trading days to simulate (default: $DEFAULT_DAYS)
    -s, --simulations SIMS       Number of Monte Carlo paths (default: $DEFAULT_SIMULATIONS)
    -j, --job-name NAME          Nomad job name (default: $JOB_NAME)
    -w, --wait                   Wait for all jobs to complete
    -m, --monitor                Monitor job progress after dispatch
    -c, --cleanup                Stop all running child jobs for this job
    -h, --help                   Show this help message

EXAMPLES:
    # Dispatch jobs for multiple tickers with defaults
    $0 AAPL MSFT GOOG

    # Custom simulation parameters
    $0 -d 126 -s 5000 TSLA NVDA AMD

    # Dispatch and monitor progress
    $0 -m AAPL MSFT GOOG TSLA

    # Dispatch and wait for completion
    $0 -w AAPL MSFT

    # Clean up all running child jobs
    $0 -c
EOF
}

# Parse command line arguments
DAYS=$DEFAULT_DAYS
SIMULATIONS=$DEFAULT_SIMULATIONS
WAIT_FOR_COMPLETION=false
MONITOR_JOBS=false
CLEANUP_JOBS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--days)
            DAYS="$2"
            shift 2
            ;;
        -s|--simulations)
            SIMULATIONS="$2"
            shift 2
            ;;
        -j|--job-name)
            JOB_NAME="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_FOR_COMPLETION=true
            shift
            ;;
        -m|--monitor)
            MONITOR_JOBS=true
            shift
            ;;
        -c|--cleanup)
            CLEANUP_JOBS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            error "Unknown option $1"
            usage
            exit 1
            ;;
        *)
            # Remaining arguments are tickers
            break
            ;;
    esac
done

# Handle cleanup mode
if [[ "$CLEANUP_JOBS" == true ]]; then
    # Validate Nomad is available
    if ! command -v nomad &> /dev/null; then
        error "Nomad CLI not found. Please install Nomad client."
        exit 1
    fi
    
    # Check if job exists
    if ! nomad job inspect "$JOB_NAME" &> /dev/null; then
        error "Job '$JOB_NAME' not found."
        exit 1
    fi
    
    cleanup_child_jobs "$JOB_NAME"
    exit 0
fi

# Check if tickers were provided (only required for dispatch mode)
if [[ $# -eq 0 ]]; then
    error "No tickers specified"
    usage
    exit 1
fi

TICKERS=("$@")

# Validate Nomad is available
if ! command -v nomad &> /dev/null; then
    error "Nomad CLI not found. Please install Nomad client."
    exit 1
fi

# Check if job exists
if ! nomad job inspect "$JOB_NAME" &> /dev/null; then
    error "Job '$JOB_NAME' not found. Please run the job first:"
    echo "  nomad job run monte-carlo-batch.nomad"
    exit 1
fi

# Array to store dispatched job IDs
DISPATCHED_JOBS=()

log "Dispatching Monte Carlo batch jobs for ${#TICKERS[@]} tickers..."
log "Parameters: Days=$DAYS, Simulations=$SIMULATIONS"

# Dispatch jobs for each ticker
for ticker in "${TICKERS[@]}"; do
    log "Dispatching job for ticker: $ticker"
    
    # Dispatch the job and capture the job ID
    if JOB_OUTPUT=$(nomad job dispatch \
        -meta TICKER="$ticker" \
        -meta DAYS="$DAYS" \
        -meta SIMULATIONS="$SIMULATIONS" \
        "$JOB_NAME" 2>&1); then
        
        # Extract job ID from output (format: "Dispatched Job ID: <id>")
        if JOB_ID=$(echo "$JOB_OUTPUT" | grep -o "Dispatched Job ID: [a-z0-9-]*" | cut -d' ' -f4); then
            DISPATCHED_JOBS+=("$JOB_ID")
            success "Dispatched job for $ticker (Job ID: $JOB_ID)"
        else
            warning "Job dispatched for $ticker but couldn't extract Job ID"
            echo "$JOB_OUTPUT"
        fi
    else
        error "Failed to dispatch job for $ticker: $JOB_OUTPUT"
    fi
    
    # Small delay to avoid overwhelming the scheduler
    sleep 1
done

success "Dispatched ${#DISPATCHED_JOBS[@]} jobs successfully"

# Print job IDs
if [[ ${#DISPATCHED_JOBS[@]} -gt 0 ]]; then
    log "Dispatched Job IDs:"
    for job_id in "${DISPATCHED_JOBS[@]}"; do
        echo "  - $job_id"
    done
fi

# Monitor jobs if requested
if [[ "$MONITOR_JOBS" == true || "$WAIT_FOR_COMPLETION" == true ]]; then
    log "Monitoring job progress..."
    
    while true; do
        running_count=0
        completed_count=0
        failed_count=0
        
        for job_id in "${DISPATCHED_JOBS[@]}"; do
            if status=$(nomad job status -short "$job_id" 2>/dev/null); then
                if echo "$status" | grep -q "running"; then
                    ((running_count++))
                elif echo "$status" | grep -q "complete"; then
                    ((completed_count++))
                elif echo "$status" | grep -q "failed\|dead"; then
                    ((failed_count++))
                fi
            fi
        done
        
        log "Job Status: Running=$running_count, Completed=$completed_count, Failed=$failed_count"
        
        # Break if all jobs are done
        if [[ $((completed_count + failed_count)) -eq ${#DISPATCHED_JOBS[@]} ]]; then
            break
        fi
        
        # Break if only monitoring (not waiting)
        if [[ "$MONITOR_JOBS" == true && "$WAIT_FOR_COMPLETION" == false ]]; then
            log "Monitoring stopped. Jobs are still running in the background."
            break
        fi
        
        sleep 10
    done
    
    if [[ "$WAIT_FOR_COMPLETION" == true ]]; then
        if [[ $failed_count -eq 0 ]]; then
            success "All jobs completed successfully!"
        else
            warning "$failed_count job(s) failed"
        fi
    fi
fi
