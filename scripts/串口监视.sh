#!/opt/homebrew/bin/bash

# 使用 macOS 自带 screen 打开 USB-CDC 串口；退出按 Ctrl-A，再按反斜杠。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/macos环境.sh"

selected_port="${OPENVELA_PORT:-}"
baud_rate="${OPENVELA_BAUD:-115200}"

while (($# > 0)); do
  case "$1" in
    --port)
      shift
      [[ $# -gt 0 ]] || { echo "错误：--port 缺少端口。" >&2; exit 2; }
      selected_port="$1"
      ;;
    --baud)
      shift
      [[ $# -gt 0 ]] || { echo "错误：--baud 缺少波特率。" >&2; exit 2; }
      baud_rate="$1"
      ;;
    -h|--help)
      echo "用法：./scripts/串口监视.sh [--port /dev/cu.usbmodemXXXX] [--baud 115200]"
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
    echo "错误：未发现 USB 串口。" >&2
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
[[ -c "${port}" ]] || { echo "错误：串口不存在：${port}" >&2; exit 1; }

echo "正在打开 ${port}，波特率 ${baud_rate}。退出按 Ctrl-A，再按反斜杠。"
exec screen "${port}" "${baud_rate}"
