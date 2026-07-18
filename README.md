# 你好 openvela — ESP32-S3-EYE 主动执行 AI 硬件助手

> 2026 首届 openvela AI 硬件开发者大赛参赛作品 · 队伍 `contest2026_130_xingshuangrenran` · **AI 硬件产品创新**赛道

## 一、作品简介

本作品在乐鑫 **ESP32-S3-EYE** 开发板上，基于 openvela（NuttX）与官方 `ai_agent` 框架，交付一个**多模态、可主动执行**的桌面 AI 硬件助手：

- **语音唤醒**：以固定唤醒词「**你好，openvela**」触发，经火山引擎 ASR 识别、大模型应答、TTS 合成语音回复。
- **视觉问答**：调用板载摄像头（`/dev/video0`）实时取帧并 JPEG 编码，交由 **MiMo v2.5** 视觉模型完成图文问答。
- **中文屏显**：240×240 LCD（`/dev/fb0`，LVGL）以中文字体渲染对话与回复，含轻量 Markdown 清理。
- **稳定联网**：针对 ESP32 Wi-Fi 首次握手失败、关联漂移、DNS/TLS 链路问题做了系统性修复与掉线自愈。
- **移动伴侣**：附带 Android 控制端，通过 WebSocket 与设备联调并以 Markdown 渲染回复。

## 二、选题方向

**AI 硬件产品创新**。ESP32-S3-EYE 同时具备摄像头、麦克风、LCD 与 Wi-Fi，是「视觉 + 语音 + 屏显」多模态 AI 硬件的理想载体。本作品围绕「一句唤醒词即可发起多模态问答」的桌面助手场景展开，尽量复用 openvela 官方 `ai_agent` 能力，把定制集中在唤醒词、多模态取数与联网稳定性上。

## 三、目录结构

```text
contest2026_130_xingshuangrenran/
├── app/hello_app/          # 应用骨架，manifest 软链至 packages/demos/contest2026_130_hello_app
├── quickapp/hello_quickapp/# 快应用骨架，软链至 packages/apps/contest2026_130_hello_quickapp
├── board/contest_board/    # 板级适配骨架，软链至 vendor/openvela/boards/contest2026_130_board
├── scripts/                # macOS 环境检查 / 构建 / 烧录 / 串口监视脚本
├── docs/                   # 规格、进度与证据
│   ├── 比赛开发规格.md      # 作品规格事实源
│   ├── progress/           # 分阶段开发进度
│   └── 证据/               # 真机基线、构建日志、代码改动 patch 等可复现证据
│       └── 代码改动/        # 对 packages/ai_agent、nuttx 的补丁与说明
├── logs/                   # AI Coding 日志（Claude Code 会话，凭据已脱敏）
├── artifacts/              # 构建产物留存
└── contest2026_130_xingshuangrenran.xml  # repo manifest（含 openvela.xml）
```

作品核心逻辑位于 openvela 公共仓 `packages/ai_agent`（语音、视觉、网络），按大赛规则不写入本仓本体，改动以补丁形式留存于 `docs/证据/代码改动/`，可一键复现。

## 四、运行方式

### 1. 拉取完整工程

```bash
repo init -u https://github.com/open-vela/contest2026_130_xingshuangrenran \
  -b dev-ai-contest-2026 -m contest2026_130_xingshuangrenran.xml
repo sync -c -j8
```

### 2. 准备工具链（macOS / Apple Silicon）

```bash
cd contest2026_130_xingshuangrenran
bash scripts/检查开发环境.sh     # 检查 Xtensa GCC/Ninja/esptool 等
bash scripts/macos环境.sh        # 冻结 macOS 构建/烧录适配
```

### 3. 应用作品补丁并构建

```bash
# 应用对公共仓的改动（唤醒词、联网自愈、TLS 诊断、板级网络配置）
git -C ../packages/ai_agent apply docs/证据/代码改动/packages_ai_agent.patch
git -C ../nuttx apply docs/证据/代码改动/nuttx_net.patch

# 构建固件，产物为 ../nuttx/nuttx.bin
bash scripts/构建固件.sh
```

### 4. 烧录与运行

```bash
bash scripts/烧录固件.sh          # 通过 esptool 烧录 ESP32-S3
bash scripts/串口监视.sh          # 观察启动日志与设备节点
```

设备启动到 NSH 后，通过串口注入运行期凭据（**不入库**）：

```bash
set_wifi <SSID> <PASSWORD>                 # Wi-Fi 联网
set_llm  <host> <model> <key>              # MiMo 大模型
set_volc_asr <AppID> <Token> <Cluster>     # 火山语音识别
```

配置完成后，对麦克风说「**你好，openvela，……**」即可发起语音问答；摄像头视觉与中文屏显随对话自动工作。

> `/data` 为临时文件系统，重新烧录后需再次注入上述凭据。

## 五、AI Coding 使用说明

本作品全程借助 **Claude Code** 协作开发，`logs/xingranya/` 保留了完整会话日志（已按安全要求对 Wi-Fi 密码、MiMo Key 等凭据脱敏，事件级 `redacted_count` 可审计）。AI 在以下环节发挥了实际作用：

- **需求拆解与规划**：将「多模态 AI 硬件助手」拆分为工作区基线、真机烟测、多模态、可靠性等阶段（见 `docs/progress/`）。
- **深度调试**：定位 ESP32 Wi-Fi 首次 4 次握手失败、残留 IP 假联网、DNS/TLS 真实错误码（`-0x52`/`-0x4c`）等疑难问题，并给出网络栈与应用层的联合修复。
- **多模态集成**：完成 V4L2 取帧 + JPEG 编码 + MiMo 视觉 Tool、240×240 LVGL 中文界面、火山 ASR/TTS 与唤醒词闸门的代码集成。
- **跨平台适配**：冻结 macOS/Apple Silicon 的 Xtensa 工具链、构建与烧录脚本。
- **文档与证据**：生成规格、进度与可复现的代码改动补丁。

---

*本仓所有文档与证据均不含任何 Wi-Fi SSID/密码、MiMo Key、火山 AppID/Token 或 Tavily Key；运行期凭据一律经串口注入 `/data`。*
