# ESP32-S3-EYE 联网与首次 AI 对话排障记录

## 结论

- 中文 SSID“梦”可以被扫描、关联并通过 DHCP 获取地址，无需改成英文。
- macOS 直连 MiMo 网关的 443 端口和 TLS 正常，开发板也能解析或使用其 IPv4 地址；电脑代理不是当前故障根因。
- 旧固件会把 Wi-Fi 断开后残留的 IPv4 地址误判为“已联网”，继而启动 LLM 请求；现场同时出现 RSSI `-128`、`ping` 返回 `errno=101`，证明当时实际 carrier 已掉线。
- 静态 ARP 判别实验第一次在 Agent 自有 CLI 中执行，命令并不存在；进入 NSH 后虽成功写入静态网关 ARP，但此时 carrier 已掉线，因此该次实验不能用于证明或否定 ARP 队列假设。
- 当前已按 NuttX 网络模型修复 carrier 判定、ARP 首包队列和非阻塞 TCP 建连等待方式，并完成 clean build、烧录和启动验证。

## 现场证据

真实 DHCP 参数：

```text
IP: 192.168.123.212
Mask: 255.255.255.0
Gateway: 192.168.123.1
BSSID: 8c:de:f9:3c:fc:9c
```

断链后的矛盾状态：

```text
ifconfig wlan0: 192.168.123.212/24
wapi show wlan0: Sense -128
ping 192.168.123.1: sendto failed, errno 101
```

这说明仅检查 IP 地址不足以判断 Wi-Fi 可用性。

MiMo 请求在旧固件中的失败点：

```text
[vela_tls] DNS fallback for MiMo gateway: 124.251.34.38
[vela_tls] IPv4 connect timed out for token-plan-cn.xiaomimimo.com
```

失败发生在 TCP 建连阶段，尚未进入 TLS 握手，因此不能归因于证书、API Key 或模型请求格式。

## 已实施修复

### 1. 真实联网判定

`network_is_connected()` 对 ESP32-S3 的 `wlan0` 同时要求：

- IPv4 地址不是 `0.0.0.0`；
- 不是板级默认地址 `10.0.0.2`；
- 接口同时具备 `IFF_UP` 与 `IFF_RUNNING`。

未满足条件时同步把缓存 IP 重置为 `0.0.0.0`，避免继续展示旧地址。

### 2. Wi-Fi 凭据恢复

关联成功即可证明 SSID/PSK 有效，因此凭据在 carrier 建立后、DHCP 前保存。即使本轮 DHCP 暂时失败，下次启动仍能自动重连。

### 3. ARP 首包队列

最终配置为：

```text
# CONFIG_NET_ARP_SEND is not set
CONFIG_NET_ARP_SEND_QUEUE=y
```

该模式让 ARP 未命中时保留待发送的 TCP SYN，收到 ARP 回复后再发送，避免首包被 ARP 请求覆盖后丢失。

### 4. TCP 建连完成判定

ESP32-S3 的非阻塞 `connect()` 现在使用：

```text
poll(POLLOUT | POLLERR)
-> getsockopt(SO_ERROR)
```

不再通过循环 `getpeername()` 猜测连接状态，因此可以获得 `ETIMEDOUT`、`ENETUNREACH` 等真实错误。

## 新固件证据

```text
构建版本：2026-07-17 07:38:45
nuttx.bin：1,039,048 bytes
SHA-256：69e4a57734be0778f837f5fa735231912c403233ae41e533b32c78d27b1619ce
烧录结果：Hash of data verified
```

重启后未配置 Wi-Fi 时，Agent 只报告“没有保存的 Wi-Fi 凭据”，不再因残留 IP 启动网络服务，证明假联网修复已生效。

## 下一验证闸门

烧录会重建 `/data` tmpfs，Wi-Fi、MiMo 与 Tavily 配置不会保留。重新输入配置后依次验证：

1. `set_wifi` 成功，并显示真实 DHCP 地址；
2. `net_status` 必须为 connected；
3. `net_test` 完成 DNS、TCP 与 TLS；
4. `ask 只回复OK` 返回模型答案；
5. 硬复位后确认凭据持久化方案，或明确记录 tmpfs 限制并迁移到持久存储。

所有证据日志必须脱敏，不记录 Wi-Fi 密码和 API Key。
