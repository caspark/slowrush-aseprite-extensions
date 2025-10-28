#!/usr/bin/env bash

set -eu

function devlink() {
    local extension_name="$1"
    local target_dir="$HOME/.config/aseprite/extensions/$extension_name"

    # Skip if target directory doesn't exist (extension not installed)
    if [ ! -d "$target_dir" ]; then
        echo "Skipping $extension_name: $target_dir does not exist (extension not installed)"
        return
    fi

    # Remove existing symlinks/files in target directory, preserving __info.json
    find "$target_dir" -mindepth 1 -not -name "__info.json" -delete

    # Create symlinks for all files in the extension directory
    echo "Creating symlinks for $extension_name:"
    for file in "$extension_name"/*; do
        if [ -f "$file" ] || [ -d "$file" ]; then
            ln -s "$(realpath "$file")" "$target_dir/$(basename "$file")"
            echo " ✓ $target_dir/$(basename "$file") -> $(realpath "$file")"
        fi
    done
}

devlink hotspots-palette
devlink named-palette
