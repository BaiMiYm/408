# 本地角色动画素材

来源：用户提供的 NeonPaws-whitecat-animation-v1.zip。接入五张原始 atlases PNG 与 animation.json，未修改像素或透明通道；生成来源和局部帧间变化已记录在任务028。

游戏直接按4×2图集切换八帧，不使用配置中 frames 列出的独立文件，因此本目录不重复存放40张单帧、GIF或生成源图。统一单帧448×544，脚底锚点(224,496)，角色面朝右。时长与持续段索引来自 animation.json。

入口：whitecat_runner.gd；操作和局限见 docs/CHARACTER_TEST.md。本次仅本地接入，不上传远程或重新打包。
