#!/bin/bash

# File containing Spotify credentials
CREDENTIALS_FILE="spotify_credentials.txt"

# Directories
DOWNLOAD_DIR="./downloads"
mkdir -p "$DOWNLOAD_DIR"

# Read Spotify API credentials from file
get_spotify_credentials() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "Credentials file not found!"
        exit 1
    fi

    SPOTIFY_CLIENT_ID=$(grep -oP '^client_id=\K.*' "$CREDENTIALS_FILE")
    SPOTIFY_CLIENT_SECRET=$(grep -oP '^client_secret=\K.*' "$CREDENTIALS_FILE")

    if [[ -z "$SPOTIFY_CLIENT_ID" || -z "$SPOTIFY_CLIENT_SECRET" ]]; then
        echo "Spotify client ID or secret missing in the credentials file."
        exit 1
    fi
}

# Get Spotify Access Token
get_spotify_token() {
    curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -u "$SPOTIFY_CLIENT_ID:$SPOTIFY_CLIENT_SECRET" \
        https://accounts.spotify.com/api/token | jq -r '.access_token'
}

# Fetch song details from Spotify
fetch_spotify_song() {
    local track_url="$1"
    local token="$2"
    local track_id=$(echo "$track_url" | grep -oP "track/\K[^?]+")

    if [ -z "$track_id" ]; then
        echo "Invalid track URL."
        exit 1
    fi

    local response=$(curl -s -X GET "https://api.spotify.com/v1/tracks/$track_id" \
        -H "Authorization: Bearer $token")
    
    if echo "$response" | jq -e .error > /dev/null; then
        echo "Error fetching track details: $(echo "$response" | jq -r .error.message)"
        exit 1
    fi

    local song_name=$(echo "$response" | jq -r '.name')
    local artist_name=$(echo "$response" | jq -r '.artists[0].name')

    echo "$artist_name" "$song_name"
}

# Download song using yt-dlp
download_song() {
    local artist="$1"
    local song="$2"

    # Refined search query: artist's name + song name + lyrics
    local search_query="${artist} - ${song} lyrics"
    echo "Downloading: $search_query (priority: lyrics version)"

    yt-dlp -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 \
        --output "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
        "ytsearch1:${search_query}"
}

# Main function
main() {
    echo "Enter Spotify track URL:"
    read -r track_url

    echo "Reading Spotify credentials..."
    get_spotify_credentials

    echo "Fetching Spotify token..."
    SPOTIFY_TOKEN=$(get_spotify_token)

    echo "Fetching song details..."
    read -r ARTIST SONG < <(fetch_spotify_song "$track_url" "$SPOTIFY_TOKEN")
    if [[ -z "$ARTIST" || -z "$SONG" ]]; then
        echo "No song found or invalid track URL."
        exit 1
    fi

    echo "Song: $SONG by $ARTIST. Starting download..."
    download_song "$ARTIST" "$SONG"

    echo "Download completed!"
}

main
