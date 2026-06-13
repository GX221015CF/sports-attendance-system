# Sports Attendance System

运动队签到考勤系统。

本项目用于校运动队日常训练签到和考勤管理，包含 Web 管理后台、Flutter 安卓 App、Supabase 数据库和 Figma/Stitch UI 设计资源。

## 功能概览

### Web 管理后台

- 成员管理
- Excel 导入成员
- 创建签到
- 签到任务列表
- 签到详情
- 结束签到
- 导出 Excel

### Flutter App

- 普通签到端
- 当前签到
- 成员签到列表
- 正常 / 迟到 / 缺勤判断
- 管理员登录
- App 内成员管理
- App 内创建签到
- App 内签到详情
- App 内结束签到
- 管理员数据看板

## 技术栈

- Flutter
- React + Vite + TypeScript
- Ant Design
- Supabase
- PostgreSQL
- xlsx
- Figma / Stitch

## 目录结构

```text
sports-attendance-system/
  admin_web/      Web 管理后台
  mobile_app/     Flutter 安卓 App
  database/       Supabase PostgreSQL schema
  docs/           产品和开发文档
  design/         Figma / Stitch UI 设计资源
  scripts/        脚本目录
```

## Supabase 配置

1. 在 Supabase 控制台创建项目。
2. 在 SQL Editor 中执行 `database/schema.sql`，用于创建表结构。
3. 在 SQL Editor 中执行 `database/dev_rls_policies.sql`，用于配置开发阶段 RLS 策略。
4. 在 Supabase Auth 中创建管理员用户。
5. 不要提交 `service_role` key。
6. 不要将数据库密码写入 Web 或 App。

### RLS 开发策略说明

- Web 后台未登录 Supabase Auth 时，通常以 `anon` 角色访问数据。
- Flutter App 管理员使用 Supabase Auth 登录后，请求角色会变成 `authenticated`。
- 如果 App 管理员登录后读不到数据，常见原因是 `authenticated` 角色缺少 RLS 策略。
- 开发阶段需要同时给 `anon` 和 `authenticated` 配置表访问策略。
- `database/dev_rls_policies.sql` 已覆盖 `groups`、`members`、`attendance_sessions`、`session_members` 四张表的开发阶段读写策略。
- 这些策略比较宽松，只用于本地开发和 MVP 验证，生产环境上线前必须收紧。

## Web 后台运行

```bash
cd admin_web
npm install
```

复制 `.env.example` 为 `.env`，并填写：

```env
VITE_SUPABASE_URL=你的 Supabase Project URL
VITE_SUPABASE_ANON_KEY=你的 Supabase anon/public key
```

运行开发服务器：

```bash
npm run dev
```

构建：

```bash
npm run build
```

## Flutter App 运行

```bash
cd mobile_app
flutter pub get
```

运行到安卓真机示例：

```bash
flutter run -d 5fcc3360 --dart-define=SUPABASE_URL=你的URL --dart-define=SUPABASE_ANON_KEY=你的KEY
```

不要把真实 URL 和 key 写死进代码。也可以使用 `.env` 配合：

```bash
flutter run -d 5fcc3360 --dart-define-from-file=.env
```

## Android APK 打包

```bash
cd mobile_app
flutter build apk --release --dart-define=SUPABASE_URL=你的URL --dart-define=SUPABASE_ANON_KEY=你的KEY
```

如果使用 `.env` 文件：

```bash
flutter build apk --release --dart-define-from-file=.env
```

输出路径：

```text
mobile_app/build/app/outputs/flutter-apk/app-release.apk
```

## 测试清单

- 管理员登录
- 创建签到
- 普通签到
- 迟到判断
- 结束签到
- 缺勤标记
- 成员管理
- Excel 导入
- 导出 Excel
- 横屏检查

## 安全提醒

- `.env` 不提交。
- `service_role` key 不进前端。
- App 不使用数据库密码。
- 当前开发 RLS 策略上线前需要收紧。
