# 运动队签到考勤系统：项目上下文

> 用途：供后续功能升级、故障排查和新会话快速恢复。本文只记录当前源码可验证的事实；设备连接、线上数据、部署结果和仓库状态等易变信息，执行相关任务时必须重新核验。
>
> 原功能源码核验：2026-09-15；离线增量核验：2026-10-10。参考资料：桌面旧版 `PROJECT_CONTEXT.md`；事实以当前源码、数据库脚本和现场检查为准。

## 1. 项目定位与路径

- 项目：面向校队、社团和训练小组的签到考勤系统。
- 源码根目录为本仓库根目录，运行命令从该目录进入对应子目录。
- `admin_web/`：React + Vite + TypeScript + Ant Design Web 管理后台。
- `mobile_app/`：Flutter App，当前主要使用场景为 Android。
- 移动端品牌：2026-10-25 用户选定「队齐」，功能说明「运动队签到」；图形母版为 `design/branding/20261025/duiqi.svg`，品牌常量与标记组件为 `mobile_app/lib/branding/app_brand.dart`。对用户名称与包名分开管理，保留既有 Android/Dart 标识。
- `database/`：Supabase PostgreSQL 建表、迁移和开发 RLS 脚本。
- `docs/`：产品、运行、测试和项目上下文文档。
- `design/stitch-ui/`：现有 Flutter 界面的设计参考图。

项目仓库为 <https://github.com/GX221015CF/sports-attendance-system>，默认分支使用 `master`。应用源码整合基线为已验收的 `duiqi-ux-audio-v2-20261025`，应用包版本 `1.1.0+2`。2026-11-15 按用户授权完成 master 正常快进整合、作品展示资料推送和原仓库公开，匿名首页、图片、视频文件及关键文档访问已核对。GitHub 文件页的 MP4 内嵌预览受平台限制，用户另行授权通过 GitHub Pages 提供[视频播放页](https://gx221015cf.github.io/sports-attendance-system/showcase/)，发布源为 `master` 的 `docs/` 目录。仓库可见性、分支与远程提交在后续操作中继续重新核验。

### 项目介绍与实际使用（2026-11-15）

- 项目已用于校队日常考勤，支持训练名单、签到、统计与报表。
- 展示媒体采用用户明确选定的 full-v1 第一版完整初剪，见 [展示说明](showcase/README.md)。视频约 62 秒，封面与代表截图均从同版成片提取。
- 视频覆盖在线业务；结束段切换另一任务，Web 展示历史任务，Excel 为单任务工作表。离线和多任务汇总按实际源码能力另行说明。

## 2. 权威来源与判断顺序

发生冲突时按以下顺序判断：

1. 用户当前明确指令和现场运行/数据库证据；
2. 当前源码与数据库脚本；
3. `README.md`、`docs/PRD.md`、`docs/RUNBOOK.md`、`docs/QA_CHECKLIST.md`；
4. 本文和 `work/ACTIVE_TASK.md`；
5. 旧聊天摘要、旧设备记录和经验性推测。

不得把旧文档中的“已修复”“已测试”“MVP 可用”直接视为当前运行结论。涉及手机、Supabase 线上项目、代理、APK 或端到端同步时，应现场复测。

## 3. 技术栈与配置边界

| 部分 | 当前技术 | 关键入口 |
|---|---|---|
| Web | React 19、Vite 8、TypeScript、Ant Design 6、Supabase JS、xlsx | `admin_web/src/App.tsx` |
| App | Flutter/Dart、supabase_flutter、intl、lpinyin | `mobile_app/lib/app.dart` |
| 数据 | Supabase PostgreSQL、RLS | `database/schema.sql` |

- Web 读取 `VITE_SUPABASE_URL`、`VITE_SUPABASE_ANON_KEY`。
- Flutter 读取编译时变量 `SUPABASE_URL`、`SUPABASE_ANON_KEY`。
- 真实凭据只能放在被忽略的本地 `.env` 或安全的部署配置中；不得写入源码、文档、提交记录或截图。
- 前端只能使用 publishable/anon key，不得使用数据库密码、JWT、`service_role` 或 secret key。
- 根 `.gitignore` 已排除 `.env`、构建目录、APK/AAB 和常见依赖目录，但提交前仍需做敏感信息扫描。

## 4. 数据模型与数据库基线

核心表：

- `groups`：分组；删除分组时，`members.group_id` 由外键设置为 `null`。
- `members`：成员资料与启用状态。
- `attendance_sessions`：签到任务，状态仅允许 `active`、`closed`。
- `session_members`：任务与成员的签到记录，同一任务与成员组合唯一。

`session_members.status` 是 App、Web 和数据库共同依赖的业务契约：

- `pending`：未签到；
- `normal`：正常；
- `late`：迟到；
- `absent`：缺勤。

数据库关系：

- 删除 `attendance_sessions` 会通过 `on delete cascade` 删除对应 `session_members`；Web 删除任务依赖这一行为。
- 删除 `members` 也会级联删除其历史 `session_members`，升级成员删除逻辑时必须评估历史数据影响。
- `late_minutes >= 0`，并由数据库约束校验。

### 备注字段迁移

`database/schema.sql` 当前没有定义 `session_members.remark`；该列由 `database/add_session_member_remark.sql` 单独添加。新建或重建数据库时需依次确认：

1. 执行 `database/schema.sql`；
2. 执行 `database/add_session_member_remark.sql`；
3. 按环境配置 RLS；
4. 验证 App 与 Web 均可读取、写入和清空备注。

### RLS 安全边界

`database/dev_rls_policies.sql` 同时给 `anon` 和 `authenticated` 开放四张表的增删改查，只适合本地开发或受控 MVP 验证，不能作为生产授权方案。当前 Web 直接使用前端 Supabase 客户端，未实现独立 Web 登录和严格管理员授权；正式部署前必须设计角色、操作范围和生产 RLS。

## 5. 核心业务规则

签到判断：

- `now <= required_time`：允许签到，记为 `normal`，迟到分钟为 0；
- `required_time < now <= end_time`：允许签到，记为 `late`；
- `now > end_time`：不允许签到；剩余 `pending` 转为 `absent`，任务由 `active` 转为 `closed`。

并发保护：普通签到更新时附带 `status = pending` 条件；如果记录已被其他端更新，则本次更新不覆盖现有结果并提示刷新。

备注规则：

- 备注存储在 `session_members.remark`，为可清空的自由文本；
- 普通签到页和 App 管理员详情页均可编辑；Web 详情页也可编辑；
- 保存备注只更新 `remark`，不得联动修改 `status`、`checkin_time` 或 `late_minutes`；
- 当前代码没有按任务状态禁止备注，因此已结束任务仍可编辑备注。

## 6. Web 后台现有能力

- 数据看板；
- 成员新增、编辑、删除、搜索、分组/状态筛选；
- 分组新增、编辑、删除；
- 从 Excel 导入成员；
- 创建签到并选择参与成员；
- 签到任务列表、详情、结束任务；
- 编辑任务标题、规定签到时间和结束时间；
- 删除任务及其成员签到记录；
- 编辑或清空成员备注；
- 单任务 Excel 导出和多任务汇总导出。

重要边界：

- Web 编辑签到任务只更新 `title`、`required_time`、`end_time`，不修改参与成员。
- 删除签到任务不可恢复，界面会明确提示其成员签到记录也将删除。
- App 管理端当前未实现签到任务编辑和删除；这两项目前是 Web 能力。

## 7. Excel 导出契约

单任务导出包含成员资料、签到状态、实际签到时间、迟到分钟和备注。

多任务批量导出固定生成：

1. `人员汇总`：每名成员一行，每个签到任务动态生成“状态、签到时间、迟到分钟、备注”列，并统计正常、迟到、缺勤、未签到、已签到、应签到次数和出勤率；
2. `签到总览`：每次任务一行，包含人数和各状态统计；
3. 每个签到任务的详情 Sheet，重名标题会自动去重。

出勤率口径为 `(normal + late) / 应签到次数`。修改统计或导出时必须同步核对 Web 页面、Flutter 页面和 Excel 口径。

## 8. Flutter App 页面与入口

### 普通签到端

- `SportsAttendanceApp` 首页为 `ModeHomePage`，由用户显式切换在线/离线；在线内容仍是 `CurrentSessionPage`。没有底部四项导航，不在无明确需求时重新引入。
- 当前签到页支持下拉刷新、空状态、错误状态、管理员入口和签到总览。
- 签到总览展示参与、已签、未签、正常、迟到、缺勤及出勤率。
- 成员签到列表按姓名拼音排序，支持点击签到、正常/迟到判断和备注编辑。
- 2026-10-25 音效 v2：在线/离线签到单击直接提交，保存期间防重复；真实成功回调触发一次成功勾、非阻塞粒子与签到专用音，失败允许重试。初次加载使用对应横屏分区骨架，统计数字滚动；减少动态效果/辅助导航采用静态视觉反馈。
- 在线模式栏、离线首页提供持久化声音开关，与减少动态效果独立。六个 WAV 中仅签到使用用户选定的 `ui_checkin_success.wav`，其他表单保留 `ui_success.wav`；SoundPool 失败不影响业务保存，加载/滚动不反复发声。v2 用户已在平板验收通过，证据与限制见 `docs/versions/duiqi-ux-audio-v2-20261025.md`。
- 页面按宽高和 720px 阈值采用横屏/宽屏紧凑布局。

### 管理员端

- 普通签到首页进入管理员入口；已登录时直达管理员首页，否则进入 Supabase Auth 邮箱密码登录页。
- 管理员首页提供数据看板、成员管理、分组管理、签到任务、创建签到和退出登录。
- 签到任务支持列表、创建、详情、结束任务和详情内备注编辑。
- 成员和分组管理支持新增、编辑、删除及搜索。

### 已固化的交互决定

- 管理端多个搜索框使用 180ms 防抖，避免每次输入都重建列表。
- 可并行的数据读取使用 `Future.wait`，页面保持非阻塞加载状态。
- 创建签到默认标题由当前日期生成；规定时间使用日期选择器加滚轮时间选择器。
- 选择规定时间后，若结束时间无效则自动设为 30 分钟后；结束时间必须晚于规定时间。
- 创建签到至少选择 1 名成员，可按分组筛选、选择当前筛选结果或清空选择。

## 9. 本地运行与验证

详细步骤以 `docs/RUNBOOK.md` 为准。常用命令：

```powershell
# Web
cd admin_web
npm run dev
npm run lint
npm run build

# Flutter
cd mobile_app
flutter run -d DEVICE_ID --dart-define-from-file=.env
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=.env
```

不要在共享日志、文档或聊天中粘贴真实 `.env` 内容。设备 ID、代理地址、安装状态和 Supabase 在线状态都属于易变信息，不写死在项目上下文中。

## 10. 当前验证边界与已知风险

- Flutter 包含时间判断、本地 SQLite、同步重试与离线页面测试；Web 未发现自动化测试目录，主要依赖 lint、构建和人工 QA。
- 2026-09-15 上下文核验只做静态检查；2026-10-10 离线增量通过 27 项测试、静态分析、APK 构建、云端合成数据回滚验证和保数据安装。同日用户明确确认整体验收通过；逐项真实场景过程未记录，不宣称 Agent 独立验证了所有真实训练数据。
- “红屏、布局溢出、中文乱码、APK 安装问题已修复”等历史结论不能替代当前版本复测。
- 生产前最高风险仍是开发 RLS 过宽和 Web 缺少严格管理员授权。
- 删除成员会级联删除其历史签到记录；若产品需要保留历史，应优先使用 `is_active` 停用并重新设计删除策略。
- 队齐名称与图标已接入；正式发布配置仍需完善 Android 签名、隐私说明、更多设备适配和数据备份方案。

## 11. 后续升级工作约定

开始新功能前：

1. 明确用户场景、改动端（App/Web/数据库）和验收标准；
2. 只读取涉及模块，核对数据库契约、RLS、历史数据和多端统计口径；
3. 先实施最小改动，再运行对应的 lint/build/test 和人工 QA；
4. 涉及数据库变更时新增可重复执行的迁移，不直接假设线上结构等于 `schema.sql`；
5. 涉及安装更新时采用保留数据的就地安装，不卸载 App、不清除手机数据；
6. 提交或推送前检查 Git diff、敏感信息、构建产物和截图脱敏情况。

后续优先事项建议：生产权限模型与 RLS、数据库迁移基线整合、真实训练场景回归、正式发布配置。二维码、GPS、人脸识别、消息推送等属于新范围，需单独确认产品目标和隐私边界。

## 12. 显式离线模式（2026-10-10 增量）

- 适用一部公共手机：显式进入离线，使用预先保存名单，发布新的本机任务；不下载或续签云端任务，不离线维护成员/分组。
- 本机签到、备注、统计、结束使用 SQLite 事务。只允许结束后手动整单同步，网络恢复、重启、刷新和模式切换均不上传。
- 上传保留原始签到时间，第一次上传前锁定快照；失败保留记录，只能手动重试。稳定 ID、内容校验与私有回执防重复，不覆盖线上原任务。
- 新接口使用调用者权限、帐号隔离，不使用服务端密钥。旧核心表/策略不变；离线时钟、手机保管和旧生产权限风险仍存在，不宣称防篡改或完整管理员授权。
- 使用、限制、迁移、验证详见 [OFFLINE_MODE.md](OFFLINE_MODE.md)。当前交付与实际验收状态以 `work/ACTIVE_TASK.md` 为准，版本/设备/部署仍需使用时复核。
