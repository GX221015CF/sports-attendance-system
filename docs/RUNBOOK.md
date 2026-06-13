# 运行手册

本文档记录运动队签到考勤系统的本地运行、Supabase 配置和常见问题处理步骤。

## 本地运行顺序

1. 启动 Supabase 项目并确认数据库表存在。
2. 启动 Web 管理后台。
3. 启动 Flutter App。
4. 使用管理员账号创建签到任务。
5. 在普通签到端完成签到测试。

## Supabase 配置

1. 在 Supabase 控制台创建项目。
2. 打开 SQL Editor。
3. 执行 `database/schema.sql`。
4. 确认表已创建：
   - `groups`
   - `members`
   - `attendance_sessions`
   - `session_members`
5. 配置开发阶段 RLS 策略。
6. 在 Authentication 中创建管理员邮箱密码账号。

注意：

- 不要把数据库密码发送到聊天或写入代码。
- 不要把 `service_role` key 放到 Web 或 App。
- `anon/public key` 可以用于前端，但权限由 RLS 策略控制。

## Web 管理后台

```bash
cd admin_web
npm install
```

复制 `.env.example` 为 `.env`，填写：

```env
VITE_SUPABASE_URL=你的 Supabase Project URL
VITE_SUPABASE_ANON_KEY=你的 Supabase anon/public key
```

开发运行：

```bash
npm run dev
```

构建检查：

```bash
npm run build
```

## Flutter App

安装依赖：

```bash
cd mobile_app
flutter pub get
```

运行到真机：

```bash
flutter run -d 5fcc3360 --dart-define=SUPABASE_URL=你的URL --dart-define=SUPABASE_ANON_KEY=你的KEY
```

也可以使用 `.env`：

```bash
flutter run -d 5fcc3360 --dart-define-from-file=.env
```

`.env` 示例：

```env
SUPABASE_URL=你的 Supabase Project URL
SUPABASE_ANON_KEY=你的 Supabase anon/public key
```

## Android APK 打包

推荐使用 `.env`，避免真实 key 出现在命令历史中：

```bash
cd mobile_app
flutter build apk --release --dart-define-from-file=.env
```

输出文件：

```text
mobile_app/build/app/outputs/flutter-apk/app-release.apk
```

## Gradle / Maven 网络问题

如果 Android 构建卡在 Gradle 或 Maven 依赖下载：

1. 确认本地代理可用。
2. 确认 Gradle 代理配置。
3. 必要时为 Flutter 项目 Android Gradle 配置国内 Maven 镜像。
4. 不要删除全局 Gradle 缓存，除非明确知道原因。

## Supabase RLS 常见问题

### 现象

- Web 后台可以看到数据。
- Flutter App 管理员登录后看不到数据。
- 管理员首页提示数据看板加载失败。
- 普通签到页也提示数据加载失败。
- App 页面能打开，登录状态也存在，但成员、分组、签到任务都读不到。

### 原因

Supabase 的 `anon` 和 `authenticated` 是不同角色。

Web 后台在未使用 Supabase Auth 登录时，通常以 `anon` 角色访问数据库。Flutter App 管理员登录后，请求会变成 `authenticated` 角色。如果只给 `anon` 配了 RLS 策略，而没有给 `authenticated` 配策略，App 登录后就会被 RLS 拒绝访问。

### 解决

在 Supabase SQL Editor 中执行：

```text
database/dev_rls_policies.sql
```

该文件会给以下四张表同时配置 `anon` 和 `authenticated` 的开发阶段读写策略：

- `groups`
- `members`
- `attendance_sessions`
- `session_members`

### 验证

1. App 完全退出后重新打开，或重新 debug 运行。
2. 进入管理员首页，点击刷新。
3. 进入成员管理，点击刷新。
4. 进入分组管理，点击刷新。
5. 回到普通签到首页，点击刷新。
6. 确认 Web 新增的数据可以在 App 看到，App 新增的数据也可以在 Web 看到。

### 安全提醒

`database/dev_rls_policies.sql` 是开发阶段宽松策略，只用于本地开发和 MVP 验证。正式上线前必须改成更严格的权限规则，例如区分管理员和普通签到端的访问范围。

## NDK 说明

如果构建提示缺少 NDK：

1. 打开 Android Studio。
2. 进入 SDK Manager。
3. 打开 SDK Tools。
4. 勾选 Show Package Details。
5. 安装需要的 NDK 版本。

本项目开发环境曾使用：

```text
NDK 28.2.13676358
```

## 常见检查命令

```bash
flutter doctor
flutter analyze
flutter devices
npm run build
git status
```

## 上线前待处理

- 收紧 Supabase RLS 策略。
- 区分管理员和普通签到端权限。
- 评估是否需要正式签名 APK。
- 配置更安全的生产环境变量管理。
