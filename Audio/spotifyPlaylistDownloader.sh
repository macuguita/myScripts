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

# Fetch songs from Spotify playlist
fetch_spotify_playlist() {
    local playlist_url="$1"
    local token="$2"
    local playlist_id=$(echo "$playlist_url" | grep -oP "playlist/\K[^?]+")

    if [[ -z "$playlist_id" ]]; then
        echo "Invalid playlist URL."
        exit 1
    fi

    local response=$(curl -s -X GET "https://api.spotify.com/v1/playlists/$playlist_id/tracks" \
        -H "Authorization: Bearer $token")

    if echo "$response" | jq -e .error > /dev/null; then
        echo "Error fetching playlist: $(echo "$response" | jq -r .error.message)"
        exit 1
    fi

    echo "$response" | jq -r '.items[].track | "\(.artists[0].name) - \(.name)"'
}

# Download song using yt-dlp with artist and lyrics preference
download_song() {
    local song="$1"
    local artist=$(echo "$song" | cut -d '-' -f 1 | xargs)
    local title=$(echo "$song" | cut -d '-' -f 2- | xargs)

    # Refined search query: artist's name + song title + lyrics
    local search_query="${artist} - ${title} lyrics"
    echo "Downloading: $search_query (priority: official channel and lyrics version)"

    yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 \
        --output "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
        "ytsearch1:${search_query}"
}

# Main function
main() {
    echo "Reading Spotify credentials..."
    get_spotify_credentials

    echo "Enter Spotify playlist URL:"
    read -r playlist_url

    echo "Fetching Spotify token..."
    SPOTIFY_TOKEN=$(get_spotify_token)

    echo "Fetching playlist songs..."
    SONGS=$(fetch_spotify_playlist "$playlist_url" "$SPOTIFY_TOKEN")
    if [ -z "$SONGS" ]; then
        echo "No songs found or invalid playlist."
        exit 1
    fi

    echo "Found $(echo "$SONGS" | wc -l) songs. Starting download..."
    echo "$SONGS" | while read -r song; do
        download_song "$song"
    done

    echo "All downloads completed!"
}

main
