#!/bin/bash
# Script para ejecutar Love2D y ver la consola

cd "$(dirname "$0")"
love . 2>&1 | tee game_console.log
