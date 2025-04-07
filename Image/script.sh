#!/bin/bash

# Directory containing the images (current directory)
input_dir="."

# Loop through all PNG files in the input directory
for input_image in "$input_dir"/*.png; do
  # Create a temporary file for the optimized image
  temp_image=$(mktemp)

  # Process the image: strip metadata, preserve transparency, and compress
  echo "Optimizing image: $input_image"
  convert "$input_image" -strip -alpha on -define png:compression-level=9 "$temp_image"

  # Replace the original image with the optimized one
  mv "$temp_image" "$input_image"

  echo "Replaced original image with optimized version: $input_image"
done

echo "All images have been optimized and replaced in place."