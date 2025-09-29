#!/bin/bash
# step_clip_audio.sh

# --- Configuration ---
INPUT_CSV="disfluency_detections.csv"
INPUT_AUDIO_DIR="data/raw_audio"
OUTPUT_DIR="clips"
FFMPEG_LOG="data/ffmpeg_errors.log"

# Create necessary directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "data" # Ensure data dir exists for log

echo "Starting audio clipping from $INPUT_CSV..."

# Check for required utilities
if ! command -v ffmpeg &> /dev/null; then
    echo "[FATAL] ffmpeg is not installed. Please install it to proceed."
    exit 1
fi

# Read the CSV header and data
# We skip the header (first line) and set IFS to comma (CSV delimiter)
tail -n +2 "$INPUT_CSV" | while IFS=, read -r row_id recording_id segment_id disfluency_type detected_token start_time end_time duration clip_path confidence notes audio_url
do
    # 1. Prepare variables and cleanup
    REC_ID=$(echo "$recording_id" | xargs)
    CLIP_SEGMENT_ID=$(echo "$segment_id" | xargs)
    START=$(echo "$start_time" | xargs)
    END=$(echo "$end_time" | xargs)
    
    # Construct input and output paths
    INPUT_FULL_AUDIO="$INPUT_AUDIO_DIR/${REC_ID}.wav"
    OUTPUT_CLIP="$OUTPUT_DIR/${CLIP_SEGMENT_ID}.wav"
    
    # Basic validation
    if [ ! -f "$INPUT_FULL_AUDIO" ]; then
        echo "[WARN] Skipping $CLIP_SEGMENT_ID: Full audio file not found at $INPUT_FULL_AUDIO. Check downloads." >> "$FFMPEG_LOG"
        continue
    fi

    if [ -z "$START" ] || [ -z "$END" ] || [ "$START" == "None" ] || [ "$END" == "None" ]; then
        echo "[WARN] Skipping $CLIP_SEGMENT_ID: Missing or invalid timestamps ($start_time, $end_time)." >> "$FFMPEG_LOG"
        continue
    fi
    
    # 2. Clip the audio segment using ffmpeg
    echo "Clipping $CLIP_SEGMENT_ID: $START to $END..."
    
    # FFMPEG Command: -ss (seek input) -to (duration/end time) -i (input) -ar (sample rate) -ac (channels)
    ffmpeg -y \
        -ss "$START" \
        -to "$END" \
        -i "$INPUT_FULL_AUDIO" \
        -ar 16000 \
        -ac 1 \
        "$OUTPUT_CLIP" \
        -hide_banner \
        -loglevel error >> "$FFMPEG_LOG" 2>&1

    if [ $? -ne 0 ]; then
        echo "[ERROR] FFMPEG failed for $CLIP_SEGMENT_ID. Check $FFMPEG_LOG."
    fi

done

echo "Clipping process finished. Clips are in $OUTPUT_DIR. Errors/warnings logged to $FFMPEG_LOG."