# 队齐交互音效接入

日期：2026-10-25。依据用户要求，结合对话「签到-鲨鱼交互音效逆向」与 [研究报告](SHARK_AUDIO_RESEARCH.md)，为现有交互优化体验包加入声音。本轮保留直接签到、粒子庆祝、骨架与人数滚动。

**当前交付为音效 v2，用户已明确确认平板验收通过。** 最后调整仅替换签到成功专用声（`checkinSuccess`），其他表单的通用成功声不变。验收 APK、源码指纹、六音频清单与版本标签见 [v2 验收存档](versions/duiqi-ux-audio-v2-20261025.md)。下文的平台行为描述是实现与测试范围，不推断所有设备和系统模式均已实测。

## 研究成果的采用方式

参考 App 共用少量音色描述点击、选择、完成与转场；数字和类别没有各自独立的音频。研究中的完成处理音发生于后续保存之前，不能据此判断写入成功。队齐为保证状态可信，将完成提示接在真实保存回调之后；滚动、加载与数字动画保持安静。

最初五个通用音色由 `mobile_app/tool/generate_ui_sounds.py` 确定性合成，使用 Python 标准库生成单声道、44.1 kHz、16 bit PCM，共 63,724 字节。v2 另采用下述用户明确选定的签到专用参考素材；生成工具不会覆盖这个独立文件。

随后用户明确要求将“完成签到”提示音换成“完成记账”。v2 增加独立的 `checkinSuccess` 事件与 `ui_checkin_success.wav`，直接采用研究试听页的 `previews/complete-preview.wav`（deep + select 同起点组合），48 kHz、单声道、16 bit PCM、约 0.993 秒、95,340 字节，SHA256 `376bc9813692e70547f152f1d7ff43b4af2a855ca754736d8a5dd4b48e1665c6`。应用资源与参考文件字节一致，没有截断或变速；其余五种自制音色保留，总计六个 WAV。该运行时素材是用户此次明确选定的资源，研究目录其他原始提取文件仍不属于应用素材。

| 声音 | 时长 | 触发位置 |
|---|---:|---|
| `ui_tap.wav` | 45 ms | 有效的签到点击、表单主操作 |
| `ui_select.wav` | 85 ms | 签到状态筛选切换、创建任务名单选择/全选/清空；开启音效时试听 |
| `ui_checkin_success.wav` | 993 ms | 在线/离线真实签到保存完成，与成功勾及粒子庆祝同一事件触发，使用用户指定“完成记账”组合声 |
| `ui_success.wav` | 280 ms | 成员/分组/备注保存、登录和任务发布成功，保留原自制音色 |
| `ui_failure.wav` | 190 ms | 上述保存或登录失败，配合现有失败提示与重试 |
| `ui_transition.wav` | 120 ms | 用户打开/返回页面、底部表单或确认弹窗；初始页面不播放 |

不额外给系统键盘逐字配音，不给持续加载、刷新绘制或人数滚动发声。系统键盘、触控声音仍由系统设置管理。声音与减少动态效果设置独立。

## 开关与播放机制

- 在线首页模式栏、离线首页右上角提供扬声器开关。设置保存在 Android 应用自身的 SharedPreferences，与账号、离线数据库和应用数据升级路径无关。
- 首次默认开启，之后恢复用户选择；开启时播放一次选中声便于试听，关闭时立即停止当前声音。
- Android SoundPool 预加载短音频，单流、无循环、无延迟队列。成功/失败提示优先，快速完成时停止前一个点击声，避免叠加过响。
- v2 对签到完成音预留约 1.1 秒保护窗口，普通点击或转场不抢断它；新的保存结果仍可立即反馈，不延迟实际操作。
- 遵守系统静音、振动模式与勿扰；应用退到后台停止当前播放，后台完成的操作不补播。声音输出不可用不会改变保存结果，也不阻止页面操作。
- Flutter 与 Android 通过 `duiqi/interaction_audio` 平台通道连接，未增加第三方 App 音频依赖或权限。非 Android 环境无原生播放器时，保持完整视觉反馈。

主要代码：`lib/services/interaction_audio.dart`、`lib/widgets/interaction_audio_controls.dart`、Android `InteractionAudio.kt` / `MainActivity.kt`；六个音频位于 `android/app/src/main/res/raw/`。

## 验证与交付

- v2 完整 133 项 Flutter 测试通过，包含 10 项音效检查：静音偏好恢复、初始化合并、缺少播放器、在线/离线保存成功时机、签到专用音色与通用成功声独立、失败/重试、音频故障不影响保存、加载与人数动画静默、页面转场和开关。
- 静态分析无问题；WAV 参数、峰值、哈希及包内资源由交付检查核验，最终 APK 与签名信息见体验包目录的元数据。
- 用户已明确确认最新 v2 平板体验验收通过；未单独提供所有设备或静音/勿扰模式的逐项记录，不把平台通道模拟测试当作实录。接收归档阶段没有安装或操作连接设备，没有写入真实签到数据。

体验包产物与音频清单位于忽略目录 `mobile_app/build/selected-motion-20261025/`。用户已授权接收、提交并同步本次 v2，Git 验收标签为 `duiqi-ux-audio-v2-20261025`；六个运行时 WAV 随源码保存，研究原始资源、APK 和日志保留在本地忽略目录。

技术依据：[Android SoundPool](https://developer.android.com/reference/android/media/SoundPool)、[AudioAttributes](https://developer.android.com/reference/android/media/AudioAttributes)、[Flutter 平台通道](https://docs.flutter.dev/platform-integration/platform-channels)。
