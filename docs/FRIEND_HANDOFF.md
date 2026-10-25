# 给好友与接手 GPT 的最新交接

交接日期：2026-10-21；2026-10-22 补充独立导出。当前为 v0.9.1，包含 v0.9 五谱基础、本机账号、流畅谱面工坊与三秒过场。已导出 Windows EXE/PCK 与 Android ARM64 APK，说明见 RELEASE.md；原交接 ZIP 是当日源工程快照。

## 先读与先跑

1. 阅读根目录 AGENTS.md、README.md、docs/PROJECT.md、docs/TASKS.md、docs/DEVELOPMENT.md，再读本文件与 docs/CREATOR.md。
2. 交接压缩包的“交流记录”包含当前可见对话摘录与需求演进，不是平台完整聊天导出。早期助手回复有缺失，不应据此推断未记录的承诺。
3. 安装 Godot 4.5.1，导入 `game/project.godot`，等待资源扫描，按 F5。此包是源工程，不是 EXE 或 APK，不包含 Godot 程序。
4. 本交接包附带用户提供的四首 MP3；GitHub 仓库的历史源码不包含这些音频。保留 .gitignore，不要因本包带素材就自动将音乐或聊天提交远程。
5. 默认 J 地面 / F 空中；菜单箭头切歌，Enter 开始，先经历三秒准备过场。自定义按键和空击忽略规则保持。
6. “设置 / 创作”创建昵称并登录，进入我的作品、新建谱面、导入音乐后编辑保存，点击试玩。

## 用户目标与明确决定

- 做安卓手机上的上下双轨跑酷式音游，参考喵斯快跑的操作与编排体验；当前使用 Godot 4.5.1 GDScript，已完成 APK 导出，待真机验收。
- 用户多次指出自动生成的谱面“怪”“不好”，要求学习真实游玩与参考录像，加入短组、换轨、连续击打、长按和留白。自动全完美模拟仅能说明技术可完成，不能视为音乐质量验收。
- “人是猫”最初用户提供 146 BPM，随后明确选择按录音鼓点对齐约 148 BPM。不要擅自改回 146。
- “之前五首”在项目中落实为四首歌曲、五套谱面；人是猫包含普通+和挑战，不存在已确认的第五首歌。
- 保留自定义键、默认 J 地面/F 空中、双指触控；空击不计分、不惩罚、不打断连击，真正漏击仍计 MISS。
- 账号功能已经确认先做本机账号与本地创作，不是联网认证。昵称用于本机作品归属，无密码、无加密、无云同步。
- 工坊：空格原位暂停/继续，R 回当前八拍段起点，段循环，标尺定位，拖动音符/换轨/拉尾，类型转换、撤销重做、复制粘贴、实际波形、节拍器、一拍预备与 J/F 实时点按录谱。
- 点击开始、按 Enter、重玩、自制谱面试玩均先显示约三秒准备过场，再同时从零启动音乐与谱面。准备时提前攻击和重复开始无效，失焦或返回取消。

## 四曲五谱

| 歌曲/难度 | BPM（约） | 谱面对象数 | 主音乐 |
| --- | ---: | ---: | --- |
| 人是猫 · 普通+ | 148 | 339 | game/assets/ren_shi_mao.mp3 |
| 人是猫 · 挑战 | 148 | 475 | 与上一项共用 |
| 海馬成長痛 × Mass Destruction · 挑战 | 140.008 | 683 | game/assets/kaiba_mass.mp3 |
| ロストワンの号哭 · 挑战 | 161.999 | 1019 | game/assets/lost_one.mp3 |
| Never More · 进阶 | 92.9985 | 430 | game/assets/never_more.mp3 |

哈希、精确时长、BPM 与起拍偏移以各 song JSON 为准；不要用不同剪辑版本直接替换音乐。参考分析与优先试听片段见 docs/VIDEO_CHART_REVIEW.md、game/CHART_NOTES.md。

## 代码与状态接口

| 文件 | 负责内容与入口 |
| --- | --- |
| game/main.gd | 游戏状态、菜单、输入与绘制。`_request_start` 进入 intro，`_advance_intro` 结束后调用 `_start` 真正播放；`_cancel_intro` 取消 |
| game/rhythm_session.gd | 判定与持续音符状态；`reset`、`press`、`release`、`update`；支持键盘/鼠标/多触控输入源 |
| game/judge.gd | 判定窗口与最近音符 |
| game/key_bindings.gd | 按键配置与冲突处理 |
| game/creator_store.gd | 本机身份、素材复制、项目校验和 JSON 保存；`profiles.json` 与按账号/项目 ID 分目录的 `project.json` |
| game/creator_panel.gd | 设置、账号、作品列表、编辑器；`locate`、`return_to_bar`、`set_loop`、`_play`、`_pause_audio` 与快捷键 |
| game/creator_timeline.gd | 网格、实际波形、音符绘制与编辑；`bar_start/end`、`begin_pointer/update_drag/end_drag`、`copy_notes/paste_notes`、`record_tap` |
| game/playlist.json | 四曲清单；自制作品在运行时加入当前账号歌单，不改原清单 |
| game/tests/ | 十二组验证与共享自动输入工具 |
| tools/test.ps1 | 测试统一入口，`-Godot` 指定控制台程序，`-CoreOnly` 无音频核心检查 |
| tools/audio_features.py、refine_charts_from_references.py | 五谱分析/修订辅助工具；重建依赖此前忽略目录中的基线与特征，本包没有这些缓存，不能声称开箱可一键复现旧生成过程 |

游戏模式为 menu / intro / play / pause / result / bindings / creator。工坊页在 creator 模式下接管 UI 输入，演奏时仍使用原双指输入；不要全局一直打开触控鼠标模拟，否则可能重复击打。

## 本机保存与验证

- 作品保存在 `user://creator`，不在 `res://`。本机身份并非安全隔离；拥有设备文件访问权限的人可以查看文件。
- 本会话启动器将 Godot 用户目录定向到项目 `.local/play-runtime/Godot/app_userdata/Neon Paws/`，直接 F5 使用系统标准目录，两者不会自动同步。交接包不带本人账号、设置或私人作品。
- 素材导入复制为独立文件；项目 JSON 临时写入后替换；同轨重叠、过短间距、负时间、越界等会拒绝保存或编辑。
- 八拍为用户要求的编辑段，并非断言歌曲乐理上每小节都是八拍；边界按 BPM 与起拍偏移计算，片头/片尾可截断。
- J/F 录谱当前记录点按并吸附，长按/连打随后转换；不是录制人声或麦克风。音乐播放来自导入音轨。
- 最近十二组检查全部通过，详细见 game/VALIDATION.md。local_audio_test 退出仍存在已记录的 ObjectDB 引用释放警告，未作为已修复问题。

运行测试：

```powershell
./tools/test.ps1 -Godot '你的Godot控制台程序完整路径'
```

## 待验收与协作注意

- 第一优先：真人带声音验收短谱面片段与工坊操作。现有谱面不应描述为已经逐拍人工听写、真人全连或达到正式曲质量。
- 安卓：SDK/JDK/模板配置与签名 APK 已完成；安装、双指、原生文件选择、软键盘、音画时差与字体仍待真机验证。
- 参考图中的背景视频、封面裁剪、自动节奏分析、独立试听文件导出与联网账号尚未实现。
- 交接时原三段参考 MP4 已不在最早提供的路径，本包仅带分析记录。附件清单会明确列出缺失原件，不假装已附视频。
- 远程 https://github.com/BaiMiYm/408 最后确认导入的是 v0.8；本地后续功能尚未同步。本次未重新检查成员邀请或远程最新变动。
- 本地 Git 未建立正常远程提交历史，不能 reset/force push；与合作人的文件比较后再选择正常同步流程，保留双方改动。
- 新任务先在 TASKS.md 标注负责人、范围和状态；聊天及本包不会自动进入好友 GPT 的上下文。由好友主动上传或让其 GPT 阅读文件，不能声称它已经收到或学会。

## 2026-10-25 最新接手补充

本次同步包含白发兽耳角色、独立动作测试场景与十三组检查；测试全部通过。当前源码比此前 EXE/APK 更新。运行时从菜单进入“角色动作测试”，或打开 game/character_lab.tscn 按 F6。

此前关于本地无历史、后续功能未同步及仓库私有的说明属于历史状态。本次已关联远程历史并同步最新成果；仓库现为公开，歌曲与含歌曲交付包仍不上传。详见 SYNC_2026-10-25.md，公开授权的项目聊天摘录见 conversations/README.md。

