# 独立运行版 v0.9.1

构建日期：2026-10-22。沿用最后一版游戏：四曲五谱、本机账号、流畅谱面工坊、三秒演奏准备过场。本次主要补齐独立导出配置、可再分发中文字体、应用图标与许可证。

## 使用

- Windows：下载 `NeonPaws-Windows-x64.zip`，完整解压后双击 `NeonPaws.exe`。`NeonPaws.pck` 是游戏数据，必须与 EXE 放在一起；不需要安装 Godot。目标为 Windows 10/11 x64，使用 OpenGL 兼容渲染。
- 安卓：将 `NeonPaws-Android-arm64.apk` 传到手机，点开并按系统安装提示操作。支持 Android 7.0 / API 24 及以上的 ARM64 手机，横屏。当前为测试签名安装包，不是应用商店正式发布版。
- 两个版本都内置四首录音，不必再次导入。自制曲仍从“设置 / 创作”导入自己的音乐。
- 电脑 J 地面 / F 空中，可改键；手机左半屏地面、右半屏空中。空格、R 等工坊快捷键用于电脑键盘；手机提供相应播放、段首、循环等按钮。

账号与自制作品保存在设备的 Godot 用户目录，不在 EXE 或 APK 内。本机身份没有云同步；压缩包不含作者的本机账号、改键配置或私人作品。

## 构建与复现

源工程仍为 Godot 4.5.1，导出包版本为 0.9.1 / Android versionCode 10。四曲五谱的 chart_revision 仍是 0.9.0，本次不重编谱面。

构建用官方 Windows release x86_64 与 Android debug 导出模板，OpenJDK 17、Android build-tools 35.0.0 和 platform-tools；使用预编译 APK 模板，无需本地重新编译 Godot。项目开启安卓要求的 ETC2/ASTC 导入设置，仍用 GL Compatibility。

工具放在忽略的 `.local/export-tools/`。`tools/export.ps1` 支持参数指定模板目录、JDK、SDK，自动使用工程内隔离的构建目录、缓存和临时目录，导出后检查退出码与错误日志。不会改动系统级 Java 或 Android 配置。

```powershell
./tools/export.ps1 -Godot 'Godot控制台程序的完整路径' `
  -TemplateDirectory '含windows_release_x86_64.exe及android_debug.apk的目录' `
  -JavaSdk 'JDK17目录' -AndroidSdk 'Android SDK目录'

# 只导出 Windows
./tools/export.ps1 -Godot 'Godot控制台程序的完整路径' -WindowsOnly
```

测试签名位于忽略的 `.local/signing/`，不打进交付包或仓库；应保留本机签名文件，以便后续对同一安装继续升级。这里的测试签名不能冒充正式商店签名。

字体使用 Noto Sans SC，可变字重设为 500；许可位于 `game/assets/fonts/OFL.txt`。Godot 与依赖许可位于 `game/assets/licenses/`，也随安装包分发。官方下载与说明：

- [Godot 4.5.1 导出模板](https://github.com/godotengine/godot/releases/tag/4.5.1-stable)
- [Godot 安卓导出说明](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html)
- [Godot Windows 导出说明](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_windows.html)
- [Noto Sans SC 与开放字体许可](https://github.com/google/fonts/tree/main/ofl/notosanssc)

## 验证及限制

- 最新源工程十二组检查通过。
- Windows 使用实际导出的 release EXE 与 PCK，在独立目录加载打包后的项目和中文字体，播放四首音乐、进入准备过场与创作页，退出码 0；实际 OpenGL 画面核对通过。
- APK 构建、签名验证通过，v2/v3 签名有效；zipalign 16KB 对齐检查通过。aapt 验证包名、版本、启动 Activity、API 24/35 与 ARM64 架构。
- 最终交付检查 ZIP 完整性、文件 SHA256、四曲五谱与许可证内容；不含账号、密钥、构建工具或日志。
- 当前没有连接安卓设备，未进行真机安装与触控/音画时差验收。谱面听感仍需真人带声音验收，不能把程序测试等同于音乐质量达标。
