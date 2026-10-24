# 交互升级：测量与阶段验证

## 基线与范围

- 功能基线：1.1.0/code 2，提交 `44fd3f85e6c6c8ad5998fe54cd53f2b70fc04bad`；原仓库已切回私有，离线升级已同步。
- 工作分支：`codex/attendance-ux`。本轮先改创建签到页的响应式布局与名单渲染，不改数据结构、在线/离线发布规则或真实考勤。
- 用户明确：所有需要键盘输入的场景都有唤起卡顿；勾选人员正常。因此下面的布局问题不能直接认定为全局键盘卡顿的根因。
- 运行环境：原真机安装为 debug 包，现已按用户选择保数据更新为原版 profile 包；电脑模拟器继续用于观察布局。不以 widget 测试耗时或模拟器观感替代真实帧率。

## 已运行的复现

命令（在 mobile_app 下）：

```powershell
flutter test --no-pub test/interaction_layout_test.dart --reporter expanded
```

全部使用合成成员与可注入回调，不初始化线上服务、不读写真实成员或考勤。

| 场景 | 自动检查 | 1.1.0 基线结果 | 当前工作分支 |
|---|---|---|---|
| 1180×820 横屏平板、500 人名单 | 发布主操作在不滚动时可点击 | 失败：底部“发布签到”不可见 | 通过；固定底栏可操作 |
| 相同名单与窗口 | 实际挂载控件随视口受限，不能全部创建 | 失败：挂载 500 个 Checkbox，目标少于 40 | 通过；惰性渲染，挂载数少于 40 |
| 420×900 手机、分步增加键盘 inset 至 520 | 窗口宽度未变化时行宽与输入保持稳定 | 失败：成员卡片从 380 变成 177，发生列表/双列切换 | 通过；行宽、输入内容和发布入口保持稳定 |

测试中的控件数量用于判断是否进行无效的全量视图工作；不把它换算成真实 FPS 或加载网络耗时。1180×820 是首轮合成横屏尺寸，后续仍需覆盖更窄横屏、字体缩放和实际平板。

## 本轮修正策略

1. 布局只根据可用宽度决定分栏；键盘压缩高度不切换名单列数。
2. 宽屏把任务设置与名单分到两侧，分开滚动；名单用惰性 sliver，保留搜索/分组/已选人数。
3. 主要发布操作留在固定底栏；成员数量变化可以反馈，但不改变发布数据与规则。

这三项分别有上述失败测试对应，修改后全部通过；另增加滚动/搜索后保持选择、名单加载时禁止发布、800×360 窄横屏主操作可达、1180×820 平板弹出 520 高度键盘后仍可搜索与发布四项检查。当前新增 7 项交互回归，全部 34 项 Flutter 测试通过，静态分析无问题。

1180×820 的合成数据预览位于 `mobile_app/build/interaction-previews/create-tablet.png`。预览来自真实页面 widget 的测试渲染，不含真实成员；不等同于实际平板截图。

## 全局键盘卡顿：独立排查

已从未修改的 1.1.0 代码构建 arm64 profile APK：`mobile_app/build/interaction-baseline-20261024/baseline-profile-arm64.apk`，32555950 字节，SHA256 `8c6ef9861eff1a6057925d01c9298b095353a1b415ea9f8478e9b6e35ea45c1c`。构建时库源码与基线提交一致；之后才修改创建页。

用户选择“现在测，保数据更新后由我操作输入框”。已核验原 APK 备份、包名、1.1.0/code 2 和新旧签名一致，采用 `adb install -r` 成功安装。回读手机实际 APK 哈希与 profile 产物完全一致；确认存在编译后的 `libapp.so`、没有 debug kernel blob。Android 的 DEBUGGABLE 标志不能单独判断 Flutter 构建模式。

用户在实际输入场景反馈“明显更顺滑，卡顿基本消失”，并进一步确认“加载也明显改善了”。这是同一业务代码、同一设备下切换构建模式后的用户体验对比，支持 debug 运行开销是主要影响因素之一；尚无帧耗时或请求耗时追踪结果，不能写成量化 FPS/网络加速，其他平板和输入法仍待验收。后续交付使用 release 构建，profile 留作诊断。

Redmi 已确认提供 `android.surfaceflinger.frametimeline` 数据源，尚未进行帧捕获；如果 profile/release 仍有可复现卡顿再进行有针对性的追踪。校园网可达性是独立问题，本轮未诊断。

官方依据：[Flutter 性能分析](https://docs.flutter.dev/perf/ui-performance)、[构建模式](https://docs.flutter.dev/testing/build-modes)。两者要求区分 debug 与真机 profile 的性能结果。

## 阶段产物与版本保存

- 当前创建页改版已完成 release 构建：`mobile_app/build/interaction-previews/create-layout-release-arm64.apk`，20624872 字节，SHA256 `832abe8474af0c431470254cd935baa8626b0f7c1b3b8c1ebb53e512614a6ac5`。
- 包名仍为 `com.example.mobile_app`、版本仍为 1.1.0/code 2；签名校验通过，并与真机原包证书一致。尚未将这一改版包安装到手机或目标平板，端到端体验待用户确认。
- 首次 release 构建等待发生在 Gradle 引擎依赖下载；用本次命令的代理参数切换已有通道后成功，随后 Flutter 标准 release 命令也成功。没有修改全局代理配置，也不把构建下载等待作为 App 加载性能证据。
- 阶段提交仅包含创建页源码、新增回归测试和本文档，保存在本地 `codex/attendance-ux` 分支；GitHub 默认分支继续保留已上传的离线升级基线。安装包和预览留在被忽略的 build 目录。

## 现场签到页：在线与离线横屏

用户继续要求“推进横屏友好”后，本轮将在线 `SessionMemberListPage` 与离线 `OfflineSessionPage` 接入共用的展示组件 `AttendanceWorkspace`。保留两者各自的服务、签到确认、备注保存及离线结束后手动同步规则，没有修改数据库、网络服务或真实考勤。

- 窗口宽度达到 760 逻辑像素时，左侧显示任务、时间和完整统计并独立滚动，右侧保留搜索与状态筛选、独立滚动名单。窄屏改为单栏，布局不根据键盘压缩后的高度决定列数。
- 名单改为惰性 sliver 行；右侧空间足够时每行两人，较窄或字体放大时使用单列。卡片采用自然高度，较长备注与字体缩放不再受固定网格高度限制。
- 签到与备注按钮的高度均为 48 逻辑像素。离线搜索继续支持姓名或学号，筛选统一为可横向滚动的状态选项；离线备注弹层的状态改为中文。
- 新增 16 项回归，在线/离线分别验证：1180×820 与 800×360 首位成员可直接签到、500 人名单挂载少于 30 张卡片；520 键盘 inset 下宽度与搜索稳定；旋转后保留搜索/筛选并可恢复空结果；1.6 倍字体与长备注；滚动后搜索和任务摘要可见；键盘打开时备注保存；取消签到不发生写入。全部使用合成回调，未初始化线上客户端或操作真实数据。
- 完整 Flutter 测试共 50 项通过，`flutter analyze --no-pub` 无问题。实际 widget 的中文预览已目检：`mobile_app/build/interaction-previews/signing-tablet-online.png` 与 `signing-tablet-local.png`。
- 本轮 release 包为 `mobile_app/build/interaction-previews/attendance-landscape-release-arm64.apk`，20624644 字节，SHA256 `1a639c31f441619cd97b3dc9943e23e87fe77e1608621973c78054dd8d2d42c4`；Flutter release 构建成功，签名与原真机包一致。未更新手机，目标平板的实际触感与完整业务验收仍待进行。
- AttendanceLab 已用 `adb -s emulator-5582 install -r` 保数据更新为本轮 x64 debug 布局预览包；先核验 AVD、原安装包哈希、新旧签名及包名，安装成功后回读 APK 哈希一致。产物为 `mobile_app/build/interaction-previews/attendance-landscape-emulator-debug.apk`，161636319 字节，SHA256 `a586bc5df3cfa2531d6108374565fa3bdaa2ebcee2837d6bb1baf0da69135821`。没有卸载、清数据或自动启动/点击；用户手动打开与走查，模拟器 debug 包不作为真实性能评估依据。

## 首页与管理页：横屏衔接和看板精简

用户明确要求继续首页、管理页横屏优化，并删除数据看板“待签到人数”与“迟到人数”。本轮只修改 Flutter 的七个页面、共用布局、新增回归与本报告；Web、数据库和各服务的查询/写入规则保持现有实现。

- 数据看板已移除上述两张卡片，保留成员总数、分组数量、进行中签到和已结束签到，重新排为四项统计。签到列表、详情与真实记录中的 pending/late 状态保留；本轮没有删除数据或修改状态契约。
- 在线首页将任务摘要与统计分栏，固定底部“进入签到”；管理员首页固定“创建签到”，常用功能在统计读取失败时也可访问。看板不再展示底层服务的项目连接标识。
- 离线首页将名单准备区和本机任务列表分栏；成员、分组、任务列表与签到详情统一为摘要区、筛选区、惰性列表，保留现有新增/编辑/删除/结束/同步确认。卡片采用自然高度，根据宽度与字体大小分列，键盘高度不改变列数。
- 新增 27 项回归：七页各覆盖 1180×820、800×360、1.6 倍字体；四个管理工作页覆盖键盘 inset 520 与旋转后搜索保留；另验证长名单滚动后筛选可见及搜索恢复、统计失败时管理入口可达。500 条合成成员/分组/任务/详情仅挂载视口附近卡片；离线进行中任务不出现同步入口。
- 完整 77 项 Flutter 测试通过，静态分析无问题，格式与补丁检查通过。七张实际 widget 中文预览 `mobile_app/build/interaction-previews/home-admin-{online,offline,dashboard,members,groups,sessions,detail}.png` 已逐张目检；合成数据与服务替身没有初始化线上客户端、读取真实账户或写入真实考勤。
- release 构建成功：`mobile_app/build/interaction-previews/home-admin-release-arm64.apk`，20624056 字节，SHA256 `eb97c47e98bdec2626976a814c18d1cf5087a95c330626f52cce018d6c460ff1`。模拟器 debug 构建成功：`home-admin-emulator-debug.apk`，161636319 字节，SHA256 `e14c14cd28883379f4af2c76a10271ddbbed2e3c19d1d7fa7aa4fe12cc0678d2`。包内 kernel 已核验包含新布局类，且不再包含被移除的看板标签；目标平板端到端仍待用户验收。
- AttendanceLab 已完成本轮 `install -r` 就地更新：核验设备、更新前版本哈希、两包签名与应用标识，安装成功后实际 APK 哈希一致。验证记录为 `mobile_app/build/interaction-previews/home-admin-emulator-verification.json`。未自动启动或点击 App，真机未更新，由用户手动确认界面及登录状态。

## 尚未完成

- 目标平板与 release 包的键盘、加载体验确认；如仍有可复现卡顿或等待，再做针对性的帧时间/请求分段测量。
- 创建、现场签到、首页、离线任务列表及上述管理工作页已完成横屏布局及合成验证；登录和编辑表单细节、完整真机端到端体验仍待进一步验收。
- 名称、图标和统一动效；候选参考 docs/MOBILE_INTERACTION_RESEARCH.md，尚未把研究清单整体作为实现范围。
