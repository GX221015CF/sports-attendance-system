# 鲨鱼记账交互音效研究

调查日期：2026-10-25。目标是为「队齐」设计交互声音提供参考。本轮提取参考 App 的音效和触发证据，不修改队齐业务代码、数据库或发布版本。

后续采纳说明（2026-10-25）：用户已明确选定研究试听页 `complete-preview.wav`（deep + select）作为队齐 v2 的签到成功音，并确认平板验收通过。该组合声以 `ui_checkin_success.wav` 单独纳入 App 运行时资源，与试听文件字节一致；其他原始提取音频、参考 APK、录音和日志仍不纳入源码。下文保留研究发生时的观察和建议，不把研究阶段的“尚未接入”当作 v2 当前状态。接入与验收见 [音效说明](INTERACTION_AUDIO.md) 和 [v2 版本记录](versions/duiqi-ux-audio-v2-20261025.md)。

## 调查对象与方法

- 从当前连接的 Redmi 核验并拉取 `com.shark.jizhang`，版本 **4.42.0 / code 349**。
- APK：43,170,716 字节，SHA-256 `206ab54bd9cf970eabc5dea180a5abdd7cc9f68e11a41211d8e770b6ee12f2ca`。
- 使用本机 REA 6.4.0 CLI 完成安装信息、完整 APK 拉取与包内资源图分析。当前聊天没有连接 REA MCP；未改 MCP 配置。
- REA Android 反编译接口返回 `capability_unavailable`：缺少调用者提供的 JADX MCP JAR。代码证据由隔离安装在忽略目录中的 Androguard 与 Android SDK `aapt2` 补查，不冒充 REA 反编译结果。
- 扫描 5 个 DEX，保存 279 个包含核心声音管理器引用或特定音频引用的方法记录；另查辅助包装器、计算键盘、振动管理器和资源数字 ID。279 是匹配方法数，不是独立交互或播放次数。
- 提取的 8 个音频共 **190,106 字节**；逐个完成 FFprobe 解码参数检查和 SHA-256 校验。APK、原始声音、工具与详细字节码均留在 Git 忽略目录。

## 音频资源与用途

时长为完整文件时长，包含文件本身可能存在的静音尾部；不能等同于实际可闻长度。

| 文件 | 时长 | 资源 ID / 核心声音编号 | 已核对的代码用途 |
|---|---:|---|---|
| `click.mp3` | 0.243 秒 | `0x7f100000` / 0 | 数字输入回调；普通点击；经常与其他音效连续调用 |
| `deep.mp3` | 0.998 秒 | `0x7f100003` / 1 | 完成记账处理的第一层 |
| `delete.mp3` | 1.051 秒 | `0x7f100004` / 2 | 删除账目路径；不是数字键盘退格的专用声 |
| `music.wav` | 0.160 秒 | `0x7f100006` / 不在核心六音色中 | 图片选择库的拍摄反馈音，由 `com.luck.picture.lib.i.h.c` 加载 |
| `push.mp3` | 1.650 秒 | `0x7f100007` / 不在核心六音色中 | 记账提醒通知的 `NotificationCompat.Builder.setSound` 资源；实际通知声受系统通知渠道设置影响 |
| `select.mp3` | 0.634 秒 | `0x7f10000a` / 3 | 非零金额进入完成处理的第二层；取消记账的部分路径也会使用 |
| `swoosh1.mp3` | 0.529 秒 | `0x7f10000d` / 4 | 页面、日期弹层的进入或退出；没有据此认定下拉刷新有声音 |
| `tap2.mp3` | 0.344 秒 | `0x7f10000e` / 5 | 类别选择的第二层 |

除 `music.wav` 为 48 kHz 单声道 PCM 外，其余为双声道 MP3；`tap2` 为 48 kHz，其余 MP3 为 44.1 kHz。

## 用户关心的触发关系

| 交互 | 静态代码中的播放关系 | 证据定位与解释 |
|---|---|---|
| 点击餐饮、购物、交通等支出类别 | 代码请求 `click`，随后 `tap2`；实机确认 `tap2` | `AddAccountActivity$p.a` 与 `LedgerAddAccountFragment$c.a` 先调用编号 0，再调用 5；使用通用类别对象，没有为每个支出类别选择不同声音。11 次录音均匹配 `tap2`，未单独确认其中的 `click` 分量 |
| 填写数字 | `click` | `CalcView.onClick → f / j → CalcView$a.b` 回调；`AddAccountActivity$l.b` 与 `LedgerAddAccountFragment$o.b` 在非空输入时调用编号 0；另一个 `SkNumericKeyboardView.onClick` 也直接调用 0 |
| 数字键盘退格 | 取决于输入变化回调 | `CalcView.c` 删除字符后调用 `j`，再通知输入回调；非空更新走 `click`。没有将编号 2 的删除账目声绑定为退格声；不能保证每次无效按键都发声 |
| 点“完成”进入记账处理 | `deep`；金额非零时再调用 `select` | `AddAccountActivity.P3` 与 `LedgerAddAccountFragment.e8` 先播编号 1，再读取并判断金额，非零后播编号 3。播放发生在后续数据处理前，**不是已保存成功的证明** |
| 页面 / 日期弹层打开、关闭 | 常见 `click + swoosh1`，部分退出只播 `swoosh1` | `AddAccountActivity$m.f` 及其日期确认/取消回调、`AddAccountActivity.M3`、`ExpensesIncomeSelectorLayout.onClick` 等 |
| 删除已有账目 | `click + delete` | `DetailFragment.z1` 中调用编号 0 和 2；本轮不在真实账本执行删除 |
| 记账提醒 | `push` | `module.alarmsetting.d.c` 将 `2131755015`（`0x7f100007`）构造为 `android.resource://…` URI 并传给 `setSound`；没有实际发送通知 |
| 明细主页面下拉和上滑 | 本次实机录音为静音 | 两次手势期间录音 PCM RMS 均为 0；只证明当前页面、当前设置和这两次动作没有输出声音。没有证明触发了网络刷新，也不能扩展为所有页面均静音 |

六种核心声音在 `com.shark.sound.a.a(Context)` 中一次加载到 SoundPool。`getType(String)` 明确对应 `CLICK / DEEP / DELETE / SELECT / SWOOSH / TAP`；`f(int, Context)` 检查 App 自身声音开关后调用播放函数。默认配置值为开，但这不能证明当前手机的用户配置为开。

播放函数的静态参数为左右声道增益 1、循环 0、速率 1，SoundPool 上限 10 个流，使用媒体流。两个连续调用之间没有显式等待，因此可能重叠播放；实际间隔不能由静态代码精确测量。

`com.shark.jizhang.module.sound.a` 是另一套振动管理器；`d()` 在振动开关开启且 Vibrator 存在时请求 **40 ms 振动**。计算键盘入口先调用它。声音与触觉应分别理解，40 ms 也不是实测振动长度。

## 实机覆盖与限制

已核验设备连接、安装版本、启动入口及记账页；完成餐饮、购物、日用、交通的未保存类别点选。第一轮手机前台发生变化后停止点击；该轮音频捕获未形成可解码文件，不能当作已验证的手机音效录音。

用户随后同意在两分钟内保持鲨鱼记账前台。第二轮采用 42 秒定时录音，正常结束，形成可解码的 **41.557 秒 FLAC，187,083 字节**。全过程只捕获设备输出，不使用麦克风，不录视频。

实际动作：进入记账页，依次点击餐饮、购物、日用、交通、运动、学习、医疗、服饰、水果、书籍、礼金 11 个可见类别；依次点数字 1–9、0；取消草稿；在明细主页面下拉和上滑。每次快速点击前重新检查前台包名；没有按“完成”保存，也没有删除原账目。

将录音和提取音频统一解码为 12 kHz 单声道，进行归一化互相关比对：

- 11 次类别点击均匹配 `tap2`，相关系数约 **0.962**。静态代码另外请求 `click`，但本次波形未能单独证实该分量；不把两者都称为已实录确认。
- 10 次数字点击均匹配 `click`，相关系数约 **0.997**。没有发现各数字使用不同文件。
- 进入记账与取消草稿分别匹配一次 `select`，相关系数约 **0.983**；说明 `select` 并非成功保存专用音。
- `deep`、`swoosh1`、`delete` 在本次录音中没有达到 0.45 的匹配阈值；这只是当前操作序列的检测结果，不否定其他路径的静态调用。
- 下拉与上滑覆盖的录音区间约 31–36 秒及 36–41.557 秒，PCM RMS 均为 **0**。当前主页面拉动未发声；未证明进行了真正的网络刷新。

互相关系数为波形相似度，不是统计置信度。录音时间轴与电脑动作时间存在约 1 秒偏移，不能用这套记录测量输入延迟。完成记账与删除现有账目仅做静态定位；未作成功保存、失败保存或云同步的端到端验收。

## 试听与证据文件

本机产物目录：`mobile_app/build/shark-audio-research-20261025/`。

- `index.html`：8 个原始声音与 3 组代码组合的试听页。
- `audio/`：原始 MP3 / WAV，字节与 APK 成员一致。
- `previews/`：`category-preview.wav`、`complete-preview.wav`、`page-preview.wav`。采用同起点叠加，每轨降低约 6 dB；是组合示意，不是手机录音。
- `previews/runtime-categories.wav` 与 `previews/runtime-digits.wav`：从实机录音截取，分别为 7.8 秒、6.8 秒，仅提高约 18 dB 便于试听，不改变触发间隔。
- `runtime-v2.flac`、`runtime-v2-timeline.json`、`runtime-matches.json`：原始实机声音、动作记录与比对结果；完整录音留在本机忽略目录，试听包只包含已选定片段。
- `shark-audio-reference.zip`：试听页、原始声音、组合预览、参数清单及本报告；不包含 APK、工具或个人账本。
- `audio-manifest.json`：8 个文件的完整 SHA-256、大小、时长、编码、采样率和声道数。
- `key-static-evidence.json`：53 个关键方法的 DEX 位置、类名、方法签名和指令；`sound-callers.json`、`sound-secondary.json` 保存较广的匹配记录。
- `resources.txt`：aapt2 资源 ID 对照。

REA 原始证据定位：

| 证据 | Evidence ID |
|---|---|
| 安装信息 | `ev_623464003eb865da66eadb3bdbbb9804d0a2e15ac9b942c177faf629dc487c3f` |
| APK 拉取与哈希 | `ev_a69cdea65326d90ebf955a49c2dd917ba1c96e8c7933b7420d2a5838a7f76848` |
| APK 资源图分析 | `ev_6ba24cc1e47b2c21d98e05af5d5e7fb58e7d817f70fb72a567712d5bb8fa3aaa` |
| 包内库存子证据 | `ev_5d465395248c1607f6ae037ae015858c1e83beb220ed2c7cd71c29ddb4cbef23` |

上述 JSON 保存在产物目录中；Androguard、aapt2 和 scrcpy 产物属于辅助工具证据，没有虚构 REA Evidence ID。

音频捕获使用官方 scrcpy 3.3.4 便携包，ZIP SHA-256 与官方 `SHA256SUMS.txt` 相符：`d8a155b7c180b7ca4cdadd40712b8750b63f3aab48cb5b8a2a39ac2d0d4c5d38`。捕获源为设备音频输出，不使用麦克风，也不录制账本画面。[官方发行页](https://github.com/Genymobile/scrcpy/releases/tag/v3.3.4)、[录音说明](https://github.com/Genymobile/scrcpy/blob/master/doc/recording.md)。

## 对队齐的设计启发

以下是基于本次调查的设计建议，尚未接入代码：

1. 建立少量共用声音：轻点击、选中、完成、页面转场。无需按每位成员、每个分组设计不同声音。
2. 签到的连续高频操作使用短促轻声；完成任务或同步完成使用更明确的一组提示，并等待真实成功回调后播放。
3. 声音和振动分别可关闭；持续加载与滚动不宜持续发声。同一次操作避免普通点击与成功提示重复、堆叠过响。
4. 参考这些声音的长度与触发层次，为队齐制作自己的音色；当前参考文件仍留在研究目录，不作为已选定的正式 App 素材。

## 覆盖清单

- [x] 当前目标身份与 APK 哈希。
- [x] 8 个音频提取、参数、哈希及试听交付。
- [x] 支出类别是否各有不同声音：共用类别处理器，`click + tap2`。
- [x] 数字输入、完成处理、页面转场、删除、通知、拍摄辅助音的静态定位。
- [x] 声音开关、振动开关及 40 ms 请求定位。
- [x] 11 个类别、数字 0–9、进入与取消的实机波形比对。
- [x] 当前明细页下拉与上滑：本次两段录音为静音。
- [ ] 所有页面的真实网络刷新、回弹和滚动声音：本轮不作全覆盖结论。
- [ ] 实际保存成功 / 失败后的声音：本轮未写真实账本。
