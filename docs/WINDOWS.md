# Windows（待桌面实测）

本目录包含可安装的 PowerShell 源码，不是已验证的 Windows 安装包。请先在测试电脑验收，再用于正式分发。

## 前提

- Windows 10/11 和 Windows PowerShell 5.1（安装入口用系统 PowerShell）。
- 已安装官方 `OpenAI.Codex` Store 包；上游身份验证函数必须能识别它。其他发行渠道暂不支持。
- 已安装 [Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin/releases)，通过其客户端导入并保存 Windows 兼容主题。
- 本地可播放的 MP4；推荐 H.264/AAC。无视频也可仅启动换肤。

以 Dream Skin 1.5.21 的脚本接口为基线。默认安装目录参考上游安装器；若你自定义了安装目录，请改 `engineRoot`，它应是含 `scripts` 子目录的路径。

## 配置

复制 `config/windows.example.json`，编辑：

```json
{
  "engineRoot": "%LOCALAPPDATA%\\Programs\\CodexDreamSkin\\payload",
  "video": "%USERPROFILE%\\Videos\\startup.mp4",
  "themeIDs": ["your-first-theme-id", "your-second-theme-id"]
}
```

已保存主题通常位于 `%LOCALAPPDATA%\CodexDreamSkin\themes`。ID 取自各目录的 `theme.json`，不是文件夹显示名。不要直接把下载 ZIP 解压后冒充“已导入主题”；请使用上游导入器完成校验。

## 安装

在本项目目录用 PowerShell 执行：

```powershell
.\windows\Install.ps1 -ConfigPath "$env:USERPROFILE\Downloads\my-launcher-config.json"
```

若当前执行策略禁止本地脚本，先按组织/电脑管理要求处理；本项目不绕过执行策略，也不关闭安全防护。

脚本安装到 `%LOCALAPPDATA%\CodexDressedLauncher\app`，在开始菜单创建“Codex 皮肤与动画”。不需要管理员权限，不修改官方快捷方式，不加入登录启动项。可自行把新入口固定到任务栏。

首次使用前保存工作并完全退出客户端，然后点击新入口。已运行时点击只尝试激活已有窗口，不为换肤退出重开。

## 单次启动与限制

- 直接调用上游验证过的 Store 可执行文件启动一次；不先走可能丢失参数的包激活，也不做“失败后重启”的降级流程。
- 若 Store 策略禁止直接启动，或客户端版本禁止 CDP，会明确失败。不得用更改 WindowsApps 权限、替换签名或反复重启来掩盖这个限制。
- 使用单独的 `%LOCALAPPDATA%\CodexDressedLauncher\cdp-profile`。首次可能需要登录；不复制账号令牌，不覆盖官方默认 profile。
- Windows 整合版向所选已保存主题目录注入，不修改 Dream Skin 的活动主题状态文件；以本项目的验证日志为准。会话中不要删除该主题或同时用其他换肤器更换它。
- 注入监督进程绑定本次客户端进程的生命周期，客户端退出后结束自己创建的注入器。它不会再次启动客户端。
- 动画是 WPF 窗口覆盖，按客户端窗口坐标定位并保持视频比例；没有 DWM 实时融合效果。混合 DPI、多屏和焦点交接必须实机验收。

## 日志与卸载

日志在 `%LOCALAPPDATA%\CodexDressedLauncher`：`latest-launch.log`、`latest-error.log`、`injector.log`、`injector-error.log`。

保存工作并退出客户端后执行：

```powershell
.\windows\Uninstall.ps1
```

只删除本项目程序目录和仍指向本项目的开始菜单快捷方式。保留配置、日志、登录 profile、主题和原客户端；需要彻底清理本项目数据时，在确认无须保留登录状态后自行删除该数据目录。
