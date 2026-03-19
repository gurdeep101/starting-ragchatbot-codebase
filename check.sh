#!/bin/bash
# Run code quality checks

set -e

echo "=== Black (format check) ==="
uv run black --check backend/ main.py

echo ""
echo "All checks passed."
