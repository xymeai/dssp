#!/bin/bash
# Build dssp wheels for macOS Apple Silicon (arm64).
# Run on an Apple Silicon Mac with Python 3.12, 3.13, and 3.14 installed via uv.
#
# Usage:
#   ./scripts/build-macos-wheels.sh
#   ./scripts/build-macos-wheels.sh 3.12        # single version
#   ./scripts/build-macos-wheels.sh --publish    # build and publish
#
# Prerequisites:
#   - uv (for Python version management)
#   - Xcode command line tools (provides C++ compiler)
#   - cmake (brew install cmake)
#
# The script builds Boost.Python from source for each Python version,
# then uses cibuildwheel to produce arm64 wheels.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WHEELHOUSE="${PROJECT_ROOT}/wheelhouse"
PUBLISH=false
PYTHON_VERSIONS=("3.12" "3.13" "3.14")

# Parse args
for arg in "$@"; do
    case "$arg" in
        --publish) PUBLISH=true ;;
        3.*) PYTHON_VERSIONS=("$arg") ;;
    esac
done

echo "=== macOS ARM64 dssp wheel builder ==="
echo "Python versions: ${PYTHON_VERSIONS[*]}"
echo "Project root: ${PROJECT_ROOT}"
echo

# Check prerequisites
for cmd in uv cmake; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found. Install it first."
        exit 1
    fi
done

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "WARNING: Not running on arm64. Wheels will be for $(uname -m)."
fi

rm -rf "$WHEELHOUSE"
mkdir -p "$WHEELHOUSE"

for PYVER in "${PYTHON_VERSIONS[@]}"; do
    echo
    echo "=== Building wheel for Python ${PYVER} ==="

    # Create a temporary venv with the target Python
    VENV_DIR="$(mktemp -d)"
    trap "rm -rf '$VENV_DIR'" EXIT

    uv venv --python "$PYVER" "$VENV_DIR/venv"
    PYTHON_BIN="$VENV_DIR/venv/bin/python"

    # Install build deps in the venv
    uv pip install --python "$PYTHON_BIN" "scikit-build-core>=0.10" "pip"

    # Build Boost.Python for this Python version
    echo "Building Boost.Python for Python ${PYVER}..."
    BOOST_PREFIX="$VENV_DIR/boost"
    BOOST_PREFIX="$BOOST_PREFIX" PATH="$VENV_DIR/venv/bin:$PATH" \
        bash "$SCRIPT_DIR/build-boost.sh" 1.86.0

    # Build the wheel
    echo "Building wheel..."
    BOOST_ROOT="$BOOST_PREFIX" \
    CMAKE_PREFIX_PATH="$BOOST_PREFIX" \
    MACOSX_DEPLOYMENT_TARGET="11.0" \
        "$PYTHON_BIN" -m pip wheel "$PROJECT_ROOT" \
        --no-build-isolation \
        --wheel-dir "$WHEELHOUSE" \
        -v

    # Clean up venv
    rm -rf "$VENV_DIR"
    trap - EXIT

    echo "=== Done: Python ${PYVER} ==="
done

echo
echo "=== All wheels built ==="
ls -la "$WHEELHOUSE"/*.whl

if $PUBLISH; then
    echo
    echo "=== Publishing to https://pypi.prd.xyme.cloud/ ==="
    uv publish "$WHEELHOUSE"/*.whl --index xyme-pypi --username "test"
    echo "=== Published ==="
fi
