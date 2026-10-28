# Codex Dressed Launcher · 启动动画与随机换肤

一个独立的社区整合入口：**先选皮肤 → 启动一次客户端 → 按客户端窗口大小播放动画**。

**当前状态：0.1.0 源码预览。macOS 源码已编译并通过启动编排测试；Windows 已实现源码，尚未完成 Windows 桌面实测。不是 OpenAI 官方产品。**

## 为什么做这个

动画启动器和换肤启动器分别运行，会造成重复启动。客户端先正常打开、再由换肤监听退出重开，也会让人感觉“闪退”。本项目只让一个入口发起启动；动画仅观察窗口，不能打开或重启客户端。

- 完全退出后点击统一入口：从配置的已安装主题中随机选择，多主题时避免连续重复。
- 客户端已运行：只激活现有窗口，不自动重启、不切皮肤、不重播动画。
- 重复点击：进程锁防止同时执行两次启动流程。
- 动画：使用客户端可见窗口的边界，视频保持比例；可按 Esc 跳过，超时或媒体错误不阻止客户端使用。
- 皮肤失败：保留错误日志，不自动退出客户端再试；仅在实际渲染验证通过后记录成功主题。
- 不修改官方客户端、原始快捷方式、系统安全设置，不添加登录自启动。

“只启动一次”指一次客户端启动请求；客户端自身的渲染、GPU 等辅助进程不属于重复启动。用户同时点击官方入口或其他启动器的跨应用竞争无法完全消除，请统一使用本入口。

## 平台与安装

| 平台 | 入口 | 当前验证范围 |
| --- | --- | --- |
| macOS 13+ | `~/Applications/Codex 皮肤与动画.app` | Swift 编译、自检、六项 shell 编排测试；这一可移植版本仍待端到端视觉验收 |
| Windows 10/11 | 开始菜单 → Codex 皮肤与动画 | 源码与非图形测试；Store 客户端、播放、焦点和多屏缩放待 Windows 实测 |

先安装官方 Codex / ChatGPT 和 **Dream Skin**，通过 Dream Skin 导入适配当前平台的主题，再配置本项目。Windows 目前仅对接上游可验证的 `OpenAI.Codex` Store 安装；不冒充支持所有发行渠道。

- [macOS 安装与卸载](docs/MACOS.md)
- [Windows 安装与卸载](docs/WINDOWS.md)
- [配置与行为边界](docs/CONFIGURATION.md)
- [验证记录与验收步骤](docs/TESTING.md)

当前是开发者源码安装版：macOS 需要 Xcode Command Line Tools，Windows 需要允许执行本地脚本的 PowerShell 环境。没有预编译 DMG、EXE 或一键安装包。

## 参考项目与皮肤下载网站

感谢以下上游项目：

- **[dragon-codex-boot](https://github.com/yushua0808-cpu/dragon-codex-boot)**，作者/维护者 `yushua0808-cpu` 与贡献者：提供龙娘启动动画项目，以及启动视频、窗口覆盖和焦点交接的设计参考。本项目的动画播放器是轻量整合实现，不包含上游 Windows DWM 实时窗口过渡效果。
- **[Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)**，作者/维护者 `Fei-Away` 与贡献者：提供主题库、校验、客户端身份识别、CDP 验证和换肤注入器。本项目依赖用户独立安装的 Dream Skin，不重新实现其换肤内核。

皮肤网站：**[DreamSkin 官网](https://dreamskin.cc)** · **[社区主题库 / 下载](https://dreamskin.cc/gallery)** · **[在线主题制作 Studio](https://dreamskin.cc/studio)**。

我们原来使用的五款主题及下载记录见 [皮肤来源](docs/THEME-SOURCES.md)。这些是来源记录，不是随包提供的皮肤，也不代表所有主题都兼容两种系统。

## 让你的 Codex 帮忙安装

把本仓库链接发给能操作你电脑的 Codex，并发送：

> 请先阅读这个仓库的 README、AGENTS.md 和对应平台安装说明，检查我的环境，再帮助我安装启动动画和随机换肤。请完成配置及可执行的验证，不要只给教程。缺少视频、主题、登录或权限时明确告诉我需要做什么；不要自动退出当前客户端或用反复重启解决失败。仓库：https://github.com/yuki1230kk/codex-dressed-launcher

当前不是零配置自动安装包：需要独立安装 Dream Skin、导入兼容皮肤并提供视频。Codex 可以协助这些步骤，但无法保证每种系统和客户端版本都能自动完成。Windows 原生桌面流程尚待实测，不能把源码检查通过当作安装成功。

## 素材与许可证

本项目整合代码使用 MIT，见 [LICENSE](LICENSE)。上游声明保存在 [licenses](licenses)，详细说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

仓库不包含启动视频、主题背景图、官方客户端或官方图标。请自行取得允许使用的素材并填入配置。上游代码的 MIT 许可证不等于其中的视频、角色、音乐和社区皮肤均可自由再分发。

## 本地检查

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
bash -n macos/install.sh macos/uninstall.sh macos/launch-once.sh
swiftc -framework AppKit -framework AVFoundation macos/main.swift -o /tmp/DressedLauncher
/tmp/DressedLauncher --self-test
```

Windows：

```powershell
.\tests\windows-tests.ps1
```

`.github/workflows/check.yml` 只执行源码检查，不创建 Release、不上传安装包。仓库公开提供源码；不代表已发布签名安装包或完成桌面兼容性验收。
