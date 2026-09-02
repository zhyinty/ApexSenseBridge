ApexSenseBridge - APEX 4 Mini 便携版
====================================

本包专用于飞智八爪鱼 4（APEX 4），包含桥接主程序、集成式虚拟 DS5
后端、离线驱动安装包和启动/停止脚本。不包含 Playnite、托盘程序、控制
面板或 VIIPER sidecar。

一、系统要求
------------

1. Windows 10/11 64 位系统。
2. 安装并运行“飞智空间站”。
3. APEX 4 使用 2.4G 接收器连接，并切换到 XInput 模式。
4. 游戏需要支持 DualSense/PS5 手柄的原生自适应扳机反馈。
5. 游戏内应选择 DualSense 手柄；如使用 Steam，通常需要关闭该游戏的
   Steam 输入，否则游戏可能只输出 Xbox 反馈。

二、新电脑首次安装
------------------

1. 将 ZIP 完整解压到普通文件夹，不要直接在压缩包中运行。
2. 安装并启动飞智空间站，确认空间站能识别 APEX 4，并能手动修改扳机
   阻尼。
3. 双击 Install-Drivers.cmd，接受 Windows 管理员权限提示。
4. 安装助手会检查现有环境：
   - 缺少 usbip-win2 时，离线安装 0.9.7.7。它负责把虚拟 DS5 挂载为
     Windows USB 设备。
   - 缺少 HidHide 时，离线安装 1.5.230。它用于需要隐藏实体手柄的场景；
     当前 APEX 4 空间站模式默认不会启用隐藏。
   - 已存在兼容版本时会保留，不会重复覆盖。
5. 安装完成后重启 Windows。驱动首次安装后不重启可能无法创建虚拟 DS5。

三、每次使用
------------

1. 打开飞智空间站，并保持它在后台运行。
2. 确认 APEX 4 处于 XInput 模式。
3. 双击 Start-APEX4-Mini.cmd，看到以下信息即表示桥接准备完成：
   - `APEX verified: Apex 4 via Flydigi Space Station`
   - `Virtual DualSense firmware 0x0630 verified`
   - `Bridge running`
4. 保持桥接窗口运行，然后启动游戏。

工作链路：

APEX 4 XInput -> ApexSenseBridge -> 虚拟 DS5 -> 游戏
游戏原生 DS5 扳机反馈 -> ApexSenseBridge -> 飞智空间站 -> APEX 4

四、停止与复位
--------------

优先在桥接窗口按 Ctrl+C。也可以双击 Stop-APEX4-Mini.cmd 请求安全停止。
程序退出时会将左右扳机恢复为普通模式。若程序被强制结束后阻尼未恢复，
请在飞智空间站中把左右扳机手感设回“普通”。

五、常见问题
------------

1. 提示无法创建虚拟 DualSense：重新运行 Install-Drivers.cmd，重启电脑。
2. 游戏识别不到 DS5：关闭该游戏的 Steam 输入，重启游戏，并确认桥接窗口
   在启动游戏之前已经显示 `Bridge running`。
3. 有虚拟 DS5 但扳机无变化：确认飞智空间站正在运行，且本机 UDP 端口
   127.0.0.1:7878 未被安全软件拦截。
4. 输入重复：游戏同时读取了实体 XInput 和虚拟 DS5。优先在游戏中只选择
   DualSense 输入；当前空间站通道需要保留实体 XInput 给飞智空间站访问。
5. 驱动安装日志位于本目录的 driver-install.log；USBip 安装器详细日志为
   usbip-upstream.log。

说明：APEX 4 空间站模式目前只转发自适应扳机，不转发握把震动或音频触觉。
