#!/opt/homebrew/bin/bash

# 只检查依赖和目录，不启动编译、烧录或串口会话。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/macos环境.sh"

failure_count=0

check_command() {
  local label="$1"
  local command_name="$2"

  if command -v "${command_name}" >/dev/null 2>&1; then
    printf '通过  %-12s %s\n' "${label}" "$(command -v "${command_name}")"
  else
    printf '缺失  %-12s %s\n' "${label}" "${command_name}" >&2
    failure_count=$((failure_count + 1))
  fi
}

check_file() {
  local label="$1"
  local path="$2"

  if [[ -e "${path}" ]]; then
    printf '通过  %-12s %s\n' "${label}" "${path}"
  else
    printf '缺失  %-12s %s\n' "${label}" "${path}" >&2
    failure_count=$((failure_count + 1))
  fi
}

check_command "Homebrew Bash" bash
check_command "GNU sed" sed
check_command "Python" python3
check_command "esptool" esptool.py
check_command "Ninja" ninja
check_command "Xtensa GCC" xtensa-esp32s3-elf-gcc
check_command "Xtensa GDB" xtensa-esp32s3-elf-gdb

check_file "统一构建入口" "${OPENVELA_ROOT}/build.sh"
check_file "板级配置" "${OPENVELA_ROOT}/vendor/espressif/boards/esp32s3/esp32s3-eye/configs/openvela/defconfig"
check_file "Agent 配置源" "${OPENVELA_ROOT}/packages/ai_agent/defconfigs/esp32s3-eye/esp32s3-eye_defconfig"
check_file "官方修复脚本" "${OPENVELA_ROOT}/packages/ai_agent/fix_esp32s3.sh"
check_file "多媒体框架" "${OPENVELA_ROOT}/frameworks/multimedia/Kconfig"
check_file "媒体播放器" "${OPENVELA_ROOT}/frameworks/multimedia/media/include/media_player.h"
check_file "媒体参数框架" "${OPENVELA_ROOT}/frameworks/multimedia/media/pfw/Kconfig"

if [[ "$(sed --version 2>/dev/null | head -1 || true)" != *"GNU sed"* ]]; then
  echo "错误：当前 sed 不是 GNU sed，官方修复脚本将无法使用 sed -i。" >&2
  failure_count=$((failure_count + 1))
fi

if ((failure_count > 0)); then
  echo "环境检查失败：共 ${failure_count} 项异常。" >&2
  exit 1
fi

echo "环境检查通过；并发数为 ${OPENVELA_JOBS}。"
