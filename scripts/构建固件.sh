#!/opt/homebrew/bin/bash

# 按官方 build.sh 流程构建 ESP32-S3-EYE 板级基线或 ai_agent 固件。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/macos环境.sh"

usage() {
  cat <<'EOF'
用法：
  ./scripts/构建固件.sh openvela [--clean] [--dry-run]
  ./scripts/构建固件.sh ai_agent [--clean] [--dry-run]

说明：
  openvela  构建开发板全功能基线。
  ai_agent  构建比赛所需的 openvela + ai_agent 固件。
  --clean   先执行官方 distclean 流程。
  --dry-run 仅打印命令和准备动作，不修改编译树。
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

build_target="${1:-}"
[[ -n "${build_target}" ]] || { usage; exit 2; }
shift

clean_build=0
dry_run=0
while (($# > 0)); do
  case "$1" in
    --clean) clean_build=1 ;;
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "错误：未知参数 $1" >&2; usage; exit 2 ;;
  esac
  shift
done

run_command() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  if ((dry_run == 0)); then
    "$@"
  fi
}

cd "${OPENVELA_ROOT}"

case "${build_target}" in
  openvela)
    config_path="${OPENVELA_ROOT}/vendor/espressif/boards/esp32s3/esp32s3-eye/configs/openvela"
    if ((clean_build == 1)); then
      run_command "${OPENVELA_ROOT}/build.sh" "${config_path}" distclean
    fi
    run_command "${OPENVELA_ROOT}/build.sh" "${config_path}" "-j${OPENVELA_JOBS}"
    ;;
  ai_agent)
    defconfig_source="${OPENVELA_ROOT}/packages/ai_agent/defconfigs/esp32s3-eye/esp32s3-eye_defconfig"
    defconfig_dir="${OPENVELA_ROOT}/nuttx/boards/xtensa/esp32s3/esp32s3-eye/configs/ai_agent"
    defconfig_target="${defconfig_dir}/defconfig"

    if ((dry_run == 1)); then
      echo "+ mkdir -p ${defconfig_dir}"
      echo "+ install -m 0644 ${defconfig_source} ${defconfig_target}"
    else
      mkdir -p "${defconfig_dir}"
      install -m 0644 "${defconfig_source}" "${defconfig_target}"
    fi

    if ((clean_build == 1)); then
      run_command "${OPENVELA_ROOT}/build.sh" esp32s3-eye:ai_agent distclean
      if ((dry_run == 1)); then
        echo "+ bash ${OPENVELA_ROOT}/packages/ai_agent/fix_esp32s3.sh &"
      else
        bash "${OPENVELA_ROOT}/packages/ai_agent/fix_esp32s3.sh" &
        fix_pid=$!
        trap 'kill "${fix_pid}" 2>/dev/null || true' EXIT
      fi
    fi

    run_command "${OPENVELA_ROOT}/build.sh" esp32s3-eye:ai_agent "-j${OPENVELA_JOBS}"

    if [[ -n "${fix_pid:-}" ]]; then
      wait "${fix_pid}"
      trap - EXIT
    fi
    ;;
  *)
    echo "错误：目标必须是 openvela 或 ai_agent。" >&2
    用法
    exit 2
    ;;
esac
