#!/bin/bash

# test_paths.sh - Simple script to test if specific paths exist

echo "Testing existence of known paths..."

# List of paths to check
paths=(
    "/etc/ssh/ssh_config"
    "/etc/bash.bashrc"
    "${HOME}/.config/kate"
)

# Check each path
for path in "${paths[@]}"; do
    if [[ -e "${path}" ]]; then
        echo "[FOUND] ${path} exists"
    else
        echo "[MISSING] ${path} does not exist"
    fi
done

echo "Path testing complete."
