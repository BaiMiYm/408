# 音游

两人协作的音游项目。已导入 Neon Paws v0.8 原型：Godot 4.5.1、上下双轨跑酷式音游，目标平台为安卓手机。

## 从这里开始

- [协作指南](docs/COLLABORATION.md)：加入项目、同步文件与分工方式。
- [项目说明](docs/PROJECT.md)：共同认可的目标与待定事项。
- [任务列表](docs/TASKS.md)：认领任务和跟踪进度。
- [开发记录](docs/DEVELOPMENT.md)：记录成果、决定和交接事项。

每次让 GPT/Codex 开始工作时，请先让它读取上述文档和根目录的 AGENTS.md。

## 当前状态

共同仓库：https://github.com/BaiMiYm/408 （私有）。

代码位于 [game](game/README.md)，用 Godot 打开 `game/project.godot` 后按 F5 运行。包含四曲歌单、五套谱面、长按与连打、自定义按键、双指触控、暂停和重玩。

默认 J 地面 / F 空中，菜单左右方向键或 ‹ / › 切歌。缺少本地音乐时仍可查看菜单和改键，对应曲目暂不能开始。音频不随仓库发布，导入说明见 [game/assets/README.md](game/assets/README.md)。

原型技术测试已通过，但谱面选音和手感仍待双方实听试玩，尚未交付 APK。已有成果与待办见 [交接说明](docs/HANDOFF.md)。JiangYI16 的邀请此前为等待接受，本次未变更成员权限。

## 验证

```powershell
# 不需要歌曲的核心检查（Godot 已加入 PATH）
./tools/test.ps1 -CoreOnly

# 导入自己有权使用、且版本匹配的本地录音后运行全部八组检查
./tools/import_audio.ps1 -SourceDirectory '你的音频目录'
./tools/test.ps1
```

Godot 未加入 PATH 时，用 `-Godot 'Godot控制台程序的完整路径'` 指定。测试日志与临时数据写入忽略的 `.local/`，不进入仓库。
