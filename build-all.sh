#!/usr/bin/env bash

set -eu

function build() {
    local extension_name="$1"

    cd "$extension_name"
    zip -r "../target/$extension_name.aseprite-extension" ./*
    cd ..
    echo "Built $extension_name as target/$extension_name.aseprite-extension"
}

[ -d target/ ] && rm -r target/
mkdir target/

build hotspots-palette
build named-palette
