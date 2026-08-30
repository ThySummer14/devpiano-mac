#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="build_macos"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET='\033[0m'
  C_INFO='\033[1;34m'
  C_WARN='\033[1;33m'
  C_ERROR='\033[1;31m'
  C_SUCCESS='\033[1;32m'
else
  C_RESET=''
  C_INFO=''
  C_WARN=''
  C_ERROR=''
  C_SUCCESS=''
fi

log()     { printf '%b[%s]%b %s\n' "${C_INFO}" "${SCRIPT_NAME}" "${C_RESET}" "$*"; }
warn()    { printf '%b[%s WARN]%b %s\n' "${C_WARN}" "${SCRIPT_NAME}" "${C_RESET}" "$*"; }
success() { printf '%b[%s]%b %s\n' "${C_SUCCESS}" "${SCRIPT_NAME}" "${C_RESET}" "$*"; }
fail()    { printf '%b[%s ERROR]%b %s\n' "${C_ERROR}" "${SCRIPT_NAME}" "${C_RESET}" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: ./scripts/build_macos.sh [options]

Configure and build DevPiano.app on macOS (Apple Silicon or Intel).

Options:
  -r, --release          Build Release (default)
  -d, --debug            Build Debug
  --preset <name>        Override CMake preset (default: macos-clang-release / macos-clang-debug)
  --clean                Remove the build directory before configuring
  --no-config            Skip configure step (incremental build only)
  --open                 Launch DevPiano.app after a successful build
  --arch <arch>          Target architecture: arm64 | x86_64 (default: arm64)
  -h, --help             Show this help

Examples:
  ./scripts/build_macos.sh                    # Release build
  ./scripts/build_macos.sh --debug --open     # Debug build then launch
  ./scripts/build_macos.sh --clean            # Full rebuild
EOF
}

BUILD_TYPE="Release"
PRESET=""
CLEAN=0
NO_CONFIG=0
OPEN=0
ARCH="arm64"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--release) BUILD_TYPE="Release"; shift ;;
    -d|--debug)   BUILD_TYPE="Debug"; shift ;;
    --preset)     PRESET="$2"; shift 2 ;;
    --clean)      CLEAN=1; shift ;;
    --no-config)  NO_CONFIG=1; shift ;;
    --open)       OPEN=1; shift ;;
    --arch)       ARCH="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *)            fail "Unknown option: $1 (see --help)" ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "This script must run on macOS."
fi

if [[ -z "${PRESET}" ]]; then
  if [[ "${BUILD_TYPE}" == "Release" ]]; then
    PRESET="macos-clang-release"
  else
    PRESET="macos-clang-debug"
  fi
fi

command -v cmake >/dev/null 2>&1 || fail "cmake not found. Install via: brew install cmake ninja"
command -v ninja >/dev/null 2>&1 || warn "ninja not found (CMake will fall back to another generator). Recommended: brew install ninja"

if ! xcode-select -p >/dev/null 2>&1; then
  fail "Xcode Command Line Tools not found. Install via: xcode-select --install"
fi

# 子模块完整性检查（JUCE / JIVE / melatonin_inspector 任一缺失即失败并给出恢复命令）
for sub in JUCE JIVE melatonin_inspector; do
  if [[ ! -f "submodules/${sub}/CMakeLists.txt" ]]; then
    fail "submodule submodules/${sub} is missing. Restore with:
  git -c http.proxy= -c https.proxy= clone --depth 1 --branch 8.0.15 https://github.com/juce-framework/JUCE.git submodules/JUCE   # JUCE 8.x (JIVE 尚未适配 JUCE 9)
  git -c http.proxy= -c https.proxy= clone --depth 1 https://github.com/ImJimmi/JIVE.git submodules/JIVE
  git -c http.proxy= -c https.proxy= clone --depth 1 https://github.com/sudara/melatonin_inspector.git submodules/melatonin_inspector"
  fi
done

BINARY_DIR="$(cmake --preset "${PRESET}" 2>/dev/null | grep -o 'build-[^ ]*' | head -1 || true)"
if [[ -z "${BINARY_DIR}" ]]; then
  BINARY_DIR="build-mac-release"
  [[ "${BUILD_TYPE}" == "Debug" ]] && BINARY_DIR="build-mac"
fi

if [[ ${CLEAN} -eq 1 ]]; then
  log "Removing ${BINARY_DIR}"
  rm -rf "${BINARY_DIR}"
fi

if [[ ${NO_CONFIG} -eq 0 ]]; then
  log "Configuring (preset: ${PRESET})"
  cmake --preset "${PRESET}" -D CMAKE_OSX_ARCHITECTURES="${ARCH}"
fi

JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
log "Building (${BUILD_TYPE}, -j${JOBS})"
cmake --build "${BINARY_DIR}" -j "${JOBS}"

APP_PATH="${BINARY_DIR}/devpiano_artefacts/${BUILD_TYPE}/DevPiano.app"
[[ -d "${APP_PATH}" ]] || APP_PATH="$(find "${BINARY_DIR}/devpiano_artefacts" -maxdepth 2 -name 'DevPiano.app' -type d 2>/dev/null | head -1)"
[[ -n "${APP_PATH}" && -d "${APP_PATH}" ]] || fail "DevPiano.app not found after build."

success "Built: ${APP_PATH}"

if [[ ${OPEN} -eq 1 ]]; then
  log "Launching DevPiano.app"
  open "${APP_PATH}"
fi
