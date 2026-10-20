# Neon Paws · 四曲全谱重编（v0.8.0）

四首歌曲、五套谱面全部替换为本次重新编排的数据。用现有工程打开即可玩；选歌控件、自定义按键仍可用；商业歌曲 MP3 不随仓库分发，需按 assets/README.md 在本地导入。交付为 Godot 源工程。

主菜单 ‹ / › 或键盘左右方向键切歌，Enter 开始。《人是猫》可切换普通+ / 挑战；其他三首各有一套谱面。默认 J 地面、F 空中，手机左右半屏分别操作地面与空中。

## 本次重编

- 移除旧的反复八拍音符模板，先选择录音起音候选，再按低频、上中频与和声变化组织短组和换轨。
- 按歌曲分别安排推进、应答、缓冲和收尾，削减无区分的整段底流；高难使用有起音支持的短十六分，普通+保留较宽间隔。
- 长按重新选择起止，长度随持续和声变化；同路占用期间没有单点。强起音双押附近清出操作间隔，连打只替换少量密集起音簇。
- Never More 偏向疏点与持续和声，不强制添加连打。连打段数不代表同轨连续单点组数，普通+也有需要逐次敲击的短连组。

| 曲目 | 难度 | 单点 | 长按 | 连打段 | 总对象 |
|---|---|---:|---:|---:|---:|
| 人是猫 | 普通+ | 260 | 14 | 0 | 274 |
| 人是猫 | 挑战 | 557 | 14 | 2 | 573 |
| 海馬成長痛 × Mass Destruction | 挑战 | 597 | 18 | 3 | 618 |
| ロストワンの号哭 | 挑战 | 966 | 22 | 3 | 991 |
| Never More | 进阶 | 330 | 50 | 0 | 380 |

音频原文件、原速及已拟合的 BPM / 相位均保留；空击仍不扣分、不断连。现场演示只提供截图，当前没有逐拍人工听写或手机手感验收，技术检查不能替代听感评价。详见 CHART_NOTES.md。

## 运行

1. 用 Godot 4.5.1 或兼容的 Godot 4.x 打开 project.godot。
2. 按 F5，使用菜单上方箭头选歌，再点击“开始演奏”。
3. 左半屏击打青色地面目标，右半屏击打粉色空中目标。目标中心到达左侧圆环时操作；双路组合用两根手指。
4. 电脑默认：**J 打地面，F 打空中**；备用键为左 / 右方向键。右上角暂停；安卓返回键切换暂停。

## 连打与长按

- 菱形：到达圆环时点按一次；密集的小组需要逐个敲击。
- 带“按”字的长条：头部到达圆环时按下，持续按住，直到白色尾线到达圆环后松手。过程中可操作另一条路线。两枚同路按键可接力维持长按，但中间不能同时松开。
- 金色“连”目标：进入判定区域后，在条带持续时间内反复点按，计数达到目标要求即满足要求（每段显示 6 / 6 或 8 / 8，按具体目标要求完成）。长按键盘产生的系统自动重复不会增加次数。

长按头部按普通窗口判定，尾部结束后结算；提前不超过 80 ms 松手时，最高为良好，提前更多则漏击。连打只检查时段内的有效敲击次数，完成后判完美，次数不足为漏击。每条长按和每段连打各按一个判定对象计分、计连击，不按内部次数重复计分。

暂停会冻结音乐和判定，并清除旧的按住状态。恢复时，进行中的长按有 500 ms 重新按住的宽限；超过宽限未续按则漏击。切后台自动暂停。

## 自定义按键

主菜单左侧点击“按键设置”，或暂停后点击“按键设置”。每条路线可设置主按键和备用按键。

点击需要修改的按键框，再按一次新按键即可，修改后自动保存，重启后继续生效。支持字母、数字、常用标点、空格和方向键。按 Esc 取消当前改键；再次按 Esc 返回。失去窗口焦点也会取消当前改键。

重复使用其他按键框中的按键会显示冲突提示，不会覆盖原有绑定。Esc、Enter 和组合键不作为攻击键。点击“恢复默认”会恢复地面 J / 左方向键、空中 F / 右方向键。游戏内提示随设置同步更新。手机仍为左半屏地面、右半屏空中。

界面使用系统中文字体，不额外捆绑商业字体。Windows 显示已检查；安卓字体仍待真机确认。

## 判定与时差

完美 ±55 ms，1000 分；良好 ±115 ms，700 分；命中 ±180 ms，300 分。超时漏击断连。空击完全忽略：不扣分、不断连、不计入准确率，也不显示空击提示或结算项。

菜单提供 ±250 ms 手动补偿，每步 10 ms，自动保存。经常点晚则增加，点早则减少。设备补偿与每首歌各自的网格相位分别处理。

## 安卓导出

附带 export_presets.cfg：横屏、Compatibility 渲染、arm64-v8a，包名 com.neonpaws.prototype。JSON 歌曲信息和谱面显式包含在导出中，MP3 作为引擎资源导出。

当前机器未配置 Android SDK、JDK 和对应导出模板，未生成 APK。按对应 Godot 版本文档配置后，在“项目 → 导出”选择 Android，导出调试 APK：
https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

真机待验收：双指触控、音频延迟、中文字体、刘海安全区、不同屏幕比例、切后台恢复、返回键暂停和完整一曲的性能与结算。

## 文件

- project.godot / main.tscn：入口工程与主场景。
- main.gd：音频时钟、触控、计分、流程与中文界面。
- judge.gd：判定与最近音符选择。
- rhythm_session.gd：长按、连打、多指输入、暂停恢复和计分状态。
- key_bindings.gd：按键映射、冲突检测、存储与恢复。
- chart.json：音符时间（秒）和路线；0 为地面、1 为空中。kind 为 tap / hold / roll；后两者有 end_time，roll 另有 required_hits。
- song.json：普通+曲目信息、BPM、时长、网格相位、分段和音频校验值。
- chart-hard.json / song-hard.json：《人是猫》独立挑战谱面与统计。
- playlist.json：四曲歌单与各首可用的谱面入口。
- songs/：三首新歌各自的谱面和歌曲信息。
- CHART_NOTES.md：新歌音频分析、编排与统计说明。
- assets/*.mp3：四首用户提供的原文件副本。
- preview.png / preview-game.png：实际引擎截图。
- preview-song-0.png 至 preview-song-3.png：当前四曲选歌界面；preview-song-1-game.png 至 preview-song-3-game.png：新增歌曲游戏画面。
- preview-keys.png：自定义按键页面截图。
- preview-hold.png / preview-roll.png：实际引擎的长按与连打画面。为便于检查，截图通过调试入口定位到对应段落。
- tests/：判定、全谱与流程测试。
- RESEARCH.md：检索的视频、制谱资料、实际访问范围及本版调整依据。

测试命令：

    godot --headless --path . --script tests/judge_test.gd
    godot --headless --path . --script tests/flow_test.gd
    godot --headless --path . --script tests/key_bindings_test.gd
    godot --headless --path . --script tests/sustain_test.gd
    godot --headless --path . --script tests/sustain_input_test.gd
    godot --headless --path . --script tests/empty_input_test.gd
    godot --headless --path . --script tests/challenge_test.gd
    godot --headless --path . --script tests/playlist_test.gd

音频时钟参考：
https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html

