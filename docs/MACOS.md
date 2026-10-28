# macOS

## 准备

1. 安装并正常使用一次官方 Codex / ChatGPT。
2. 按 [Dream Skin macOS 文档](https://github.com/Fei-Away/Codex-Dream-Skin/blob/main/macos/README.md) 安装换肤工具，并通过其导入器保存主题。对接版本基线为 1.5.21。
3. 准备本地 H.264/AAC MP4。可从 [dragon-codex-boot](https://github.com/yushua0808-cpu/dragon-codex-boot) 了解其示例动画，使用时遵守原项目媒体声明。
4. 确保已安装 Xcode Command Line Tools（`xcode-select --install`）。

复制 `config/macos.example.json` 到自己的位置，填写 `themeIDs` 和视频路径。主题 ID 是已导入主题的 `theme.json` 中的 `id`，不是显示名称。已保存主题通常位于：

```text
~/Library/Application Support/CodexDreamSkinStudio/themes/
```

示例：

```json
{
  "engineRoot": "~/.codex/codex-dream-skin-studio",
  "video": "~/Movies/startup.mp4",
  "themeIDs": ["your-first-theme-id", "your-second-theme-id"]
}
```

## 安装

在本项目根目录执行，替换成你自己的配置文件路径：

```sh
bash macos/install.sh "$HOME/Downloads/my-launcher-config.json"
```

安装到用户的应用程序目录 `~/Applications/Codex 皮肤与动画.app`，无需管理员权限。可用 Finder 的“前往文件夹”打开 `~/Applications`，以后从该入口启动。默认通用图标，避免把官方图标作为项目素材分发。

安装不会启动、退出或重启当前客户端。首次使用前自行保存工作并 ⌘Q 退出客户端，再打开新入口。若仍点官方 ChatGPT.app，其启动不会自动经过本项目。

## 与现有动画监听器的关系

本项目自己播放动画。若之前装过 dragon-codex-boot 的 `--watch` 服务，或随机换肤启动监听器，请先按各自卸载/停用说明停用，避免两个播放器同时出现。本安装器不会擅自修改其他项目的后台服务。

你原来已经使用的个人方案并不会因为整理这份源码而被替换；只有手动安装并切换入口后，才会使用这里的新版本。

## 配置与日志

```text
~/Library/Application Support/CodexDressedLauncher/config.json
~/Library/Application Support/CodexDressedLauncher/latest-launch.log
~/Library/Application Support/CodexDressedLauncher/last-theme.txt
```

安装器保留已有配置。视频为空或找不到时，跳过动画，仍可换肤。播放器最多等待窗口 45 秒，播放阶段最多 30 秒。保持比例可能有黑边，不拉伸；本版没有复刻原视频中的实时窗口融合效果。

采用本机 ad hoc 签名；不是已公证的公开下载应用。源码安装和 Developer ID 签名分发是两回事。

## 卸载与恢复

```sh
bash macos/uninstall.sh
```

只移除身份匹配的整合入口。原客户端、Dream Skin、主题、视频以及配置日志保留。以后可直接打开官方客户端；若要卸载换肤引擎，请使用 Dream Skin 自己的恢复/卸载入口。
