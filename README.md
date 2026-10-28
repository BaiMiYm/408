# 音游

两人协作的音游项目。Neon Paws v0.9.1：Godot 4.5.1、上下双轨跑酷式音游，已导出 Windows 独立运行版与安卓 ARM64 安装包。

## 从这里开始

- [协作指南](docs/COLLABORATION.md)：加入项目、同步文件与分工方式。
- [项目说明](docs/PROJECT.md)：共同认可的目标与待定事项。
- [任务列表](docs/TASKS.md)：认领任务和跟踪进度。
- [开发记录](docs/DEVELOPMENT.md)：记录成果、决定和交接事项。

每次让 GPT/Codex 开始工作时，请先让它读取上述文档和根目录的 AGENTS.md。

## 当前状态

共同仓库：https://github.com/BaiMiYm/408 （2026-10-25 核对为公开）。

代码位于 [game](game/README.md)，用 Godot 打开 `game/project.godot` 后按 F5 运行。包含四曲歌单、五套谱面、长按与连打、自定义按键、双指触控、暂停和重玩。

默认 J 地面 / F 空中，菜单左右方向键或 ‹ / › 切歌。缺少本地音乐时仍可查看菜单和改键，对应曲目暂不能开始。音频不随仓库发布，导入说明见 [game/assets/README.md](game/assets/README.md)。

原型技术测试已通过，Windows EXE 已独立启动验证，APK 已构建并通过签名校验；谱面听感与安卓真机体验仍待验收。安装、构建和具体限制见 [独立运行版说明](docs/RELEASE.md)，协作成果见 [交接说明](docs/HANDOFF.md)。本次未变更成员权限。

## 验证

```powershell
# 不需要歌曲的核心检查（Godot 已加入 PATH）
./tools/test.ps1 -CoreOnly

# 导入自己有权使用、且版本匹配的本地录音后运行全部检查
./tools/import_audio.ps1 -SourceDirectory '你的音频目录'
./tools/test.ps1
```

Godot 未加入 PATH 时，用 `-Godot 'Godot控制台程序的完整路径'` 指定。测试日志与临时数据写入忽略的 `.local/`，不进入仓库。

本次视频参考分析与优先试听片段见 [视频修订记录](docs/VIDEO_CHART_REVIEW.md)。

新增本机账号与谱面工坊：菜单点击“设置 / 创作”，创建本机账号后可导入音乐，编辑点按、长按与连打，保存并试玩。具体见 [创作指南](docs/CREATOR.md)。账号与作品仅保存在当前设备。

Godot 本地角色测试已接入用户提供的白发兽耳动画：F5 后点击“角色动作测试”，或打开 `game/character_lab.tscn` 按 F6。地面/空中攻击、升降、长按、连打与衔接见 [动作测试说明](docs/CHARACTER_TEST.md)。本轮不更新安装包。

2026-10-26 本地游玩界面已按用户PSD切换为公园美术、持棒角色、头像、血条及歌曲进度；零血立即失败。操作与当前测试数值见 [PSD游玩界面](docs/PSD_GAME_UI.md)。此前独立安装包尚未包含这次修改。



2026-10-25 协作同步：[同步范围](docs/SYNC_2026-10-25.md)、[四个项目聊天摘录](docs/conversations/README.md)。摘录已获用户明确公开授权；合作人请先阅读最新交接文档。


2026-10-28 合作交接：公园游玩界面与血量规则已纳入共享工程。接手请先阅读 [最新交接](docs/SYNC_2026-10-28.md) 和 [项目聊天摘录](docs/conversations/README.md)。
