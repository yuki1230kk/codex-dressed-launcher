# 发布说明草稿（未发布）

Codex Dressed Launcher 把随机皮肤和窗口大小启动动画整合为一个入口。客户端只由换肤启动适配器打开一次；动画播放器只观察窗口，遇到换肤失败也不退出重开客户端。

支持代码包含 macOS 和 Windows。当前是源码预览：macOS 编译及编排测试通过；Windows 桌面和新 macOS 构建的完整使用流程仍待验收。不包含视频、皮肤图片或官方客户端，需要独立安装 Dream Skin 并导入素材。

参考：
- https://github.com/yushua0808-cpu/dragon-codex-boot
- https://github.com/Fei-Away/Codex-Dream-Skin
- 皮肤下载：https://dreamskin.cc/gallery

发布前待办：完成 docs/TESTING.md 验收、复查素材许可、确定签名分发方式和支持版本。本文件是未来安装包发布的检查草稿；当前仅公开源码预览。
