#!/bin/bash
# Quick test script to run the game with Love2D
# Usage: ./run_game.sh

cd "$(dirname "$0")"

# Check if love.app exists in the project
if [ -d "love.app" ]; then
    echo "Running with local love.app..."
    ./love.app/Contents/MacOS/love source/
elif command -v love &> /dev/null; then
    echo "Running with system Love2D..."
    love source/
else
    echo "Error: Love2D not found!"
    echo "Please install Love2D or place love.app in the project directory"
    exit 1
fi
