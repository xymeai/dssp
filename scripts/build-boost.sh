#!/bin/bash
# Build Boost with Boost.Python for the current Python interpreter.
# Usage: ./scripts/build-boost.sh [boost-version]
# Installs to /usr/local by default.
set -euo pipefail

BOOST_VERSION="${1:-1.86.0}"
BOOST_UNDERSCORE="${BOOST_VERSION//./_}"
BOOST_URL="https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_UNDERSCORE}.tar.gz"
INSTALL_PREFIX="${BOOST_PREFIX:-/usr/local}"
JOBS="${BUILD_JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

PYTHON_BIN="$(command -v python3 || command -v python)"
PYTHON_VERSION="$("$PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
PYTHON_INCLUDE="$("$PYTHON_BIN" -c 'import sysconfig; print(sysconfig.get_path("include"))')"
PYTHON_LIB_DIR="$("$PYTHON_BIN" -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')"

echo "=== Building Boost ${BOOST_VERSION} with Python ${PYTHON_VERSION} ==="
echo "Python: ${PYTHON_BIN}"
echo "Include: ${PYTHON_INCLUDE}"
echo "Lib dir: ${PYTHON_LIB_DIR}"
echo "Install: ${INSTALL_PREFIX}"
echo "Jobs: ${JOBS}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$WORK_DIR"
echo "Downloading Boost..."
curl -sSL "$BOOST_URL" | tar xz
cd "boost_${BOOST_UNDERSCORE}"

# Configure boost.python to use the target Python
cat > user-config.jam <<EOF
using python : ${PYTHON_VERSION} : ${PYTHON_BIN} : ${PYTHON_INCLUDE} : ${PYTHON_LIB_DIR} ;
EOF

echo "Bootstrapping..."
./bootstrap.sh --prefix="$INSTALL_PREFIX" --with-python="$PYTHON_BIN" --with-libraries=python

echo "Building Boost.Python..."
./b2 install \
    --prefix="$INSTALL_PREFIX" \
    --with-python \
    --user-config=user-config.jam \
    variant=release \
    link=shared \
    threading=multi \
    python="${PYTHON_VERSION}" \
    -j"$JOBS" \
    -q

echo "=== Boost ${BOOST_VERSION} installed to ${INSTALL_PREFIX} ==="
ls -la "${INSTALL_PREFIX}/lib"/libboost_python* 2>/dev/null || true
