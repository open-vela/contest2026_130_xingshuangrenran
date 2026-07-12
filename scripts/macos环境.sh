#!/opt/homebrew/bin/bash

# 统一配置 ESP32-S3-EYE 在 macOS 上的 openvela 开发环境。
# 本文件既可直接执行，也可由其他脚本 source。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CONTEST_REPO="$(cd "${SCRIPT_DIR}/.." && pwd)"
export OPENVELA_ROOT="$(cd "${CONTEST_REPO}/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "错误：本适配器仅用于 macOS。" >&2
  return 1 2>/dev/null || exit 1
fi

if [[ ! -x "${OPENVELA_ROOT}/build.sh" ]]; then
  echo "错误：未找到 ${OPENVELA_ROOT}/build.sh，请从 repo-managed 参赛仓运行。" >&2
  return 1 2>/dev/null || exit 1
fi

HOMEBREW_ROOT="${HOMEBREW_PREFIX:-/opt/homebrew}"
GNU_SED_BIN="${HOMEBREW_ROOT}/opt/gnu-sed/libexec/gnubin"
PYTHON_VENV="${OPENVELA_ROOT}/.venv-esp32"
XTENSA_GCC_BIN="${OPENVELA_ROOT}/prebuilts/gcc/darwin-arm64/xtensa-esp32s3-elf/bin"
XTENSA_GDB_BIN="${OPENVELA_ROOT}/prebuilts/gcc/darwin-arm64/xtensa-esp-elf-gdb/bin"

export PATH="${PYTHON_VENV}/bin:${XTENSA_GCC_BIN}:${XTENSA_GDB_BIN}:${GNU_SED_BIN}:${HOMEBREW_ROOT}/bin:${PATH}"
export CCACHE_DISABLE=1
export OPENVELA_JOBS="${OPENVELA_JOBS:-$(sysctl -n hw.logicalcpu)}"

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "OPENVELA_ROOT=${OPENVELA_ROOT}"
  echo "OPENVELA_JOBS=${OPENVELA_JOBS}"
  echo "Python=$(command -v python3 || true)"
  echo "GCC=$(command -v xtensa-esp32s3-elf-gcc || true)"
  echo "GDB=$(command -v xtensa-esp32s3-elf-gdb || true)"
  echo "sed=$(command -v sed || true)"
fi
