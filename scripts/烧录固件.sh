#!/opt/homebrew/bin/bash

# 将 simple-boot 平面镜像烧录到 ESP32-S3-EYE 的 flash 偏移 0x0。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/macos环境.sh"

erase_first=0
selected_port="${OPENVELA_PORT:-}"

while (($# > 0)); do
  case "$1" in
    --erase) erase_first=1 ;;
    --port)
      shift
      [[ $# -gt 0 ]] || { echo "错误：--port 缺少端口。" >&2; exit 2; }
      selected_port="$1"
      ;;
    -h|--help)
      echo "用法：./scripts/烧录固件.sh [--erase] [--port /dev/cu.usbmodemXXXX]"
      exit 0
      ;;
    *) echo "错误：未知参数 $1" >&2; exit 2 ;;
  esac
  shift
done

discover_port() {
  local -a candidates=()
  local port

  shopt -s nullglob
  candidates=(/dev/cu.usbmodem* /dev/cu.usbserial* /dev/cu.wchusbserial*)
  shopt -u nullglob

  if ((${#candidates[@]} == 0)); then
    echo "错误：未发现 ESP32-S3-EYE 串口。请连接开发板后重试。" >&2
    return 1
  fi
  if ((${#candidates[@]} > 1)); then
    echo "错误：发现多个串口，请通过 --port 或 OPENVELA_PORT 指定：" >&2
    for port in "${candidates[@]}"; do echo "  ${port}" >&2; done
    return 1
  fi
  echo "${candidates[0]}"
}

port="${selected_port:-$(discover_port)}"
firmware="${OPENVELA_ROOT}/nuttx/nuttx.bin"

[[ -c "${port}" ]] || { echo "错误：串口不存在：${port}" >&2; exit 1; }
[[ -f "${firmware}" ]] || { echo "错误：未找到固件：${firmware}" >&2; exit 1; }

cd "${OPENVELA_ROOT}"
if ((erase_first == 1)); then
  python3 -m esptool --chip esp32s3 --port "${port}" erase_flash
fi

python3 -m esptool --chip esp32s3 --port "${port}" --baud 460800 \
  --before default_reset --after hard_reset \
  write_flash 0x0 "${firmware}"
