# 运动队签到考勤系统：项目上下文摘要

## 项目路径

C:\Users\GX\Documents\New project 2\sports-attendance-system

## 项目组成

- admin_web：React + Vite + TypeScript + Ant Design Web 管理后台
- mobile_app：Flutter 安卓 App
- database：Supabase SQL 文件
- docs：项目文档
- design：Stitch/Figma UI 资源

## 技术栈

- Web：React、Vite、TypeScript、Ant Design、Supabase、xlsx
- App：Flutter、Dart、supabase_flutter、intl、lpinyin
- 数据库：Supabase PostgreSQL
- UI：Stitch + Figma

## 数据库表

主要表：

- groups
- members
- attendance_sessions
- session_members

session_members 包含 remark 字段：

- remark text
- 用于自由文本备注，例如请假、迟到原因、伤病、特殊情况
- 备注不是下拉列表，不是固定选项
- 已结束签到也允许编辑备注

重要 SQL：

- database/schema.sql：建表
- database/dev_rls_policies.sql：开发阶段 RLS 策略，包含 anon 和 authenticated
- database/add_session_member_remark.sql：给 session_members 增加 remark 字段

## Web 后台功能

admin_web 已实现：

- 数据看板
- 成员管理
- 分组管理
- Excel 导入成员
- 创建签到
- 签到任务列表
- 编辑签到任务
- 删除签到任务
- 签到详情
- 结束签到
- 成员签到备注
- 单个签到导出 Excel
- 多个签到批量汇总导出 Excel

Web 启动方式：

cd "C:\Users\GX\Documents\New project 2\sports-attendance-system\admin_web"
npm run dev

也有一键启动脚本：

启动电脑后台.bat

## Flutter App 功能

mobile_app 已实现：

普通签到端：
- 当前签到
- 成员签到列表
- 正常 / 迟到 / 缺勤判断
- 过期签到处理
- 拼音排序
- 横屏适配
- 普通签到界面编辑备注

管理员端：
- Supabase Auth 登录
- 管理员首页数据看板
- 成员管理
- 分组管理
- 签到任务列表
- 创建签到
- 签到详情
- 结束签到
- 管理员端编辑备注
- 退出登录

App 运行 debug 示例：

cd "C:\Users\GX\Documents\New project 2\sports-attendance-system\mobile_app"
flutter run -d 5fcc3360 --dart-define=SUPABASE_URL=真实URL --dart-define=SUPABASE_ANON_KEY=真实KEY

也可使用：

flutter run -d 5fcc3360 --dart-define-from-file=.env

注意不要提交 .env。

## 重要业务规则

签到状态：

- pending：未签到
- normal：正常
- late：迟到
- absent：缺勤

判断规则：

- 当前时间 <= required_time：正常
- required_time < 当前时间 <= end_time：迟到
- 当前时间 > end_time：未签到人员变缺勤，签到任务关闭

备注规则：

- 备注字段为 session_members.remark
- 备注是自由文本
- 任何状态都可备注
- active / closed 签到都可备注
- 保存备注只更新 remark，不修改 status、checkin_time、late_minutes

## Excel 导出

Web 支持：

- 单个签到导出，包含备注
- 多个签到批量汇总导出

批量导出包含：

- 人员汇总 Sheet
- 签到总览 Sheet

人员汇总按成员合并多次签到，每次签到动态列包括：

- 任务标题-状态
- 任务标题-签到时间
- 任务标题-迟到分钟
- 任务标题-备注

## 重要经验

1. Supabase RLS：
   - Web 未登录通常是 anon
   - App 管理员登录后是 authenticated
   - 开发阶段需要给 anon 和 authenticated 都配置策略
   - 正式上线前必须收紧 RLS

2. release APK：
   - 必须带 dart-define 或 dart-define-from-file
   - 否则会数据加载失败

3. 鸿蒙平板安装 APK：
   - 微信可能把文件改成 .apk.1.1
   - 需要在文件管理中重命名为 .apk 后安装

4. Flutter 红屏：
   - 备注编辑曾出现 context 生命周期问题
   - 已通过安全的弹窗/BottomSheet 和 mounted 检查修复

## 当前状态

项目 MVP 基本完成：

- Web 后台可用
- Flutter App 可用
- 手机端和电脑端数据同步
- 备注功能完成
- Excel 导出增强完成
- 横屏适配完成
- APK 可打包安装

后续优先事项：

1. 收紧 Supabase RLS
2. 设置正式 App 名称和图标
3. 做真实训练测试
4. 备份代码或上传私有 Git 仓库
