# 队齐交互优化体验包 v2 · 平板验收存档

日期：2026-10-25，北京时间。本版以音效 v2 为唯一交付依据。

## 验收与版本标识

- 用户在本轮明确确认：最新「队齐交互优化体验包 v2」已在平板验收通过，包含动效、音效及最后一次签到成功音调整。
- 新 Git 附注标签：`duiqi-ux-audio-v2-20261025`，指向包含本验收记录的成果提交；同步到原私有仓库的 `codex/attendance-ux` 分支。
- 旧 `duiqi-ux-20261025` 标签保留原对象与目标，不移动、不覆盖；`master` 不合并、不推送更新。
- 应用包版本仍为 **1.1.0+2**，包名 `com.example.mobile_app`，显示名称「队齐」。Git 标签中的 v2 表示本次体验包迭代，不是应用包版本号。
- 用户未单独提供所有设备、系统模式的逐项记录。本版记录平板体验验收通过，不扩展成全平台、所有静音/勿扰模式均实测通过。

## 相对上一验收版的成果

1. 在线、离线签到改为单击直接提交；保存中防重复、失败可重试。持久化服务与签到状态、备注和离线手动同步规则保持原契约。
2. 接入实验室 07 的按压回弹、保存中、卡片状态过渡和成功勾；真实保存成功才触发一次实验室 12「粒子庆祝」，庆祝层不拦截触控。加载、失败、刷新与重复绘制不触发成功庆祝。
3. 接入实验室 10「骨架落位」，对齐现有横屏摘要、搜索筛选和名单区域；数据就绪即展示，不添加最短等待。签到总览、在线/离线工作区和管理看板采用人数滚动。
4. 减少动态效果或辅助导航下提供静态视觉反馈；声音开关独立，在线首页模式栏和离线首页右上角可保存开关选择。
5. 六个运行时 WAV：五个自制通用音色，加用户明确选定的签到成功参考组合声。仅 `checkinSuccess` 使用 `ui_checkin_success.wav`；成员、分组、备注、登录和发布等表单继续使用原 `ui_success.wav`。
6. Android SoundPool 预加载、单流、无循环、不排队补播；播放失败不影响保存。真实签到成功后才发声，成功勾和粒子共享该保存结果事件；加载、滚动、数字动画保持静默。实现了静音/振动/勿扰检查及后台停止，平台模式的测试覆盖限实际记录。

## 最终 APK 与接收核验

| 项目 | 本版唯一交付值 |
|---|---|
| APK | `mobile_app/build/selected-motion-20261025/duiqi-selected-motion-audio-v2-arm64.apk` |
| 大小 | **20,997,181 字节** |
| SHA256 | `a065a2ac0677144204691c08c67ebe6eea4e0194afdf36b500998ddf04bb712f` |
| 模式 / 目标 | release / android-arm64 |
| 包名 / 名称 / 版本 | `com.example.mobile_app` / 队齐 / `1.1.0+2` |
| 证书 SHA256 | `143a46a8a25e12ef3cacee46cff129c3c5fa05100145dc81933d1bc3ef2eb1e4`，与前版一致 |

接收时独立核对 `build.json` 的 **81 项源码指纹**，全部匹配；APK 字节、大小、哈希匹配；`apksigner verify` 通过，`aapt` 回读包名、名称和版本正确。六个 WAV 与 APK 成员逐字节一致，压缩方式均为 stored。没有重新生成已验收 APK，也没有安装设备、操作线上数据或修改数据库。

接收时复跑：26 个 Dart 文件格式检查零变化；`flutter analyze --no-pub` 无问题；完整 **133 项 Flutter 测试通过**，包含动效 12 项与音效 10 项回归，不能用旧版测试数替代本次证据。`git diff --check` 通过。侧边对话的四张合成 widget 预览和构建记录为补充证据，不冒充实机录制。

## 六个音频的可追溯清单

所有文件为单声道、16 bit PCM WAV；五种自制声音为 44.1 kHz，签到成功专用声为 48 kHz。时长为完整文件时长。

| 文件 | 时长（秒） | 字节 | SHA256 |
|---|---:|---:|---|
| `ui_tap.wav` | 0.044989 | 4012 | `c3c2c27d2eb85dd876fb4d4207c450ad7d0e5fe36082f2a117174925a34881aa` |
| `ui_select.wav` | 0.085011 | 7542 | `35b4b72f6b065fb9301332d22946abec79f7c8f428b74ac556daec46d061a191` |
| `ui_success.wav` | 0.280000 | 24740 | `3fabcd42b9dbdabb022ed1a8c12e293bdd575dd4dccda2a6199cfbb545bd2d55` |
| `ui_failure.wav` | 0.190000 | 16802 | `659a51c91a0da27ff757da4dffd3bd1eef25ebd28d0cb5939f14bf7bb4de6bce` |
| `ui_transition.wav` | 0.120000 | 10628 | `e98af023d5155da9bd93af8cd0a6118127d22125b42897a516bac742c2f39c03` |
| `ui_checkin_success.wav` | 0.992667 | 95340 | `376bc9813692e70547f152f1d7ff43b4af2a855ca754736d8a5dd4b48e1665c6` |

`ui_checkin_success.wav` 与本地研究目录 `previews/complete-preview.wav`（deep + select）字节一致，没有截断、变速或一起替换通用成功声。该文件是用户明确指定并验收的运行时素材，随源码保存；其余研究原始音频、参考 APK、录音及日志不纳入提交。

`mobile_app/tool/generate_ui_sounds.py` 使用 Python 标准库确定性生成五个通用音色；若签到专用资源存在则读取其参数加入清单，不生成或覆盖它。完整六个运行时资源位于 `mobile_app/android/app/src/main/res/raw/`，Git 检出后即可使用，不依赖本地研究目录。

## 接收范围与证据定位

- 代码、素材、测试和工具范围以本地 `DELIVERY.md` 的 35 个文件为起点，加音效接入说明、研究报告、项目上下文、进展和本验收记录；精确选择，不全量暂存。
- 本地交付资料：`mobile_app/build/selected-motion-20261025/` 内的 `DELIVERY.md`、`build.json`、`package-verification.json`、`audio-manifest.json`、`checkin-sound-reference.json`。
- 本轮接收结果：同目录 `receiving-integrity.json`、`receiving-format.log`、`receiving-analyze.log`、`receiving-tests.log`；这些元数据与原始日志继续位于本地忽略目录。
- 验收存档不上传真实配置、凭据、APK、设备数据、研究原始日志；其他对话的未跟踪资料保留。未写入永久记忆。

实现说明见 [交互音效](../INTERACTION_AUDIO.md)，研究出处见 [鲨鱼交互音效研究](../SHARK_AUDIO_RESEARCH.md)。本标签只读查看可用 `git show duiqi-ux-audio-v2-20261025`；后续修改以该标签作比较基准。
