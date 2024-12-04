#!/bin/bash

# Variables
M3U8_URL=$1 # Replace with your .m3u8 URL or file path
OUTPUT_FILE="output.mp4"
TEMP_DIR="downloads"
FILE_LIST="filelist.txt"
MAX_RETRIES=3       # Maximum number of retries for each segment
LIMIT_RATE="10M"   # Limit download speed (e.g., 100K for 100KB/s)
DELAY_BETWEEN=2     # Delay in seconds between downloads

# Create a temporary directory for segments
mkdir -p "$TEMP_DIR"

# Download the .m3u8 file (if it's a remote URL)
if [[ "$M3U8_URL" == http* ]]; then
    echo "Downloading M3U8 file..."
    curl -o "$TEMP_DIR/playlist.m3u8" "$M3U8_URL"
else
    cp "$M3U8_URL" "$TEMP_DIR/playlist.m3u8"
fi

# Parse and download each segment
echo "Parsing and downloading segments..."
COUNT=0
> "$FILE_LIST" # Clear any previous file list
while read -r LINE; do
    # Skip comments
    if [[ "$LINE" == \#* ]]; then
        continue
    fi

    FILENAME=$(printf "%05d.ts" $COUNT) # Use a zero-padded filename
    SUCCESS=0
    ATTEMPT=1

    while [[ $SUCCESS -eq 0 && $ATTEMPT -le $MAX_RETRIES ]]; do
        echo "Downloading $LINE (Attempt $ATTEMPT)..."
        curl --limit-rate "$LIMIT_RATE" -s -o "$TEMP_DIR/$FILENAME" "$LINE"

        # Check if the file was downloaded successfully
        if [[ $? -eq 0 && -s "$TEMP_DIR/$FILENAME" ]]; then
            echo "Download succeeded: $LINE"
            SUCCESS=1
        else
            echo "Download failed: $LINE"
            ATTEMPT=$((ATTEMPT + 1))
        fi
    done

    if [[ $SUCCESS -eq 1 ]]; then
        echo "file '$TEMP_DIR/$FILENAME'" >> "$FILE_LIST"
    else
        echo "Skipping $LINE after $MAX_RETRIES attempts."
    fi

    COUNT=$((COUNT + 1))
    sleep "$DELAY_BETWEEN" # Add delay between downloads
done < "$TEMP_DIR/playlist.m3u8"

# Concatenate all segments into a single MP4 file
echo "Concatenating segments into $OUTPUT_FILE..."
ffmpeg -f concat -safe 0 -i "$FILE_LIST" -c copy "$OUTPUT_FILE"

# Cleanup temporary files
echo "Cleaning up..."
rm -rf "$TEMP_DIR" "$FILE_LIST"

echo "Done! Output saved as $OUTPUT_FILE"
