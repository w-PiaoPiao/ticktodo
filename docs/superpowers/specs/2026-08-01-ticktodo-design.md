# TickTodo — 对标滴答清单的安卓待办应用 · 设计文档

日期：2026-08-01
状态：已批准（用户授权按推荐选项自主推进）

## 1. 目标与范围

做一个对标滴答清单核心体验的 Android 待办应用。

**第一版范围（核心任务管理）：**
- 任务 + 子任务
- 清单（列表）、标签
- 优先级（无/低/中/高）
- 日期、时间、提醒（本地通知）
- 四个视图：今天 / 最近7天 / 日历 / 全部
- 浅深双主题（跟随系统）
- 坚果云 WebDAV 快照同步（自动 + 手动）

**非目标（后续迭代）：** 习惯打卡、番茄钟、笔记、统计图表、桌面小部件、多端账号体系。

## 2. 技术栈

| 项 | 选择 | 理由 |
|---|---|---|
| 框架 | Flutter | 用户环境已就绪 |
| 本地存储 | sqflite（手写 SQL + Repository 层） | 轻量、无代码生成依赖、可控 |
| 状态管理 | Riverpod | 社区标准，可测试 |
| 通知 | flutter_local_notifications + timezone | 标准方案 |
| WebDAV | http 包手写简版（PUT/GET） | 只需读写一个文件，避免第三方依赖风险 |
| 主题 | Material 3，跟随系统 + 手动覆盖 | 浅深双主题 |

## 3. 数据模型

```
清单 List     → id(INTEGER PK), name, color(INT), icon(INT), sortOrder, isDefault
标签 Tag      → id, name, color
任务 Task     → id, title, note, completed(0/1), priority(0-3),
                dueDate(ISO yyyy-MM-dd, 可空), dueTime(ISO HH:mm, 可空),
                remindTime(epoch ms, 可空), listId, sortOrder,
                createdAt, updatedAt, deletedAt(epoch ms, 可空=软删除)
子任务 Subtask → id, taskId, title, completed, sortOrder
任务-标签关联  → taskId, tagId
```

**视图定义：**
- 今天：`dueDate == 今天` 或（`dueDate < 今天` 且未完成且未删除）
- 最近7天：`dueDate` 在 [今天, 今天+6] 内且未完成
- 日历：月视图，每天显示到期任务圆点；点选日期查看当日任务
- 全部：所有未删除任务，按清单分组显示，可筛选清单/标签/优先级

## 4. UI / 导航

- 底部导航 4 tab：今天、最近7天、日历、全部
- 左侧抽屉：清单列表（含计数）、标签入口、设置入口、坚果云同步状态
- 主列表：卡片式任务行（圆形勾选框、标题、优先级色条/图标、到期日期徽章、清单色点），滑动删除，长按多选？——不做多选，保持简单
- FAB：快速添加任务；点击任务行 → 详情/编辑页（含子任务编辑、提醒时间选择）
- 完成任务：勾选后动画进入"已完成"折叠区，当日完成的任务显示"已完成"区
- 空状态：无任务时的引导插图文案

## 5. 数据层与同步

**架构：** 本地 SQLite 为主数据源；Repository 层封装所有读写；Riverpod Provider 暴露给 UI。

**同步（快照方案 A）：**
- 坚果云目录 `TickTodo/todo_backup.json.gz`（gzip 压缩 JSON）
- 快照内容：`{ revision(epoch ms), tasks, subtasks, lists, tags, taskTags }`（含软删除记录）
- 触发：
  - 打开 App 时自动同步一次（下载比较）
  - 本地变更后防抖 30 秒自动上传
  - 设置页手动同步按钮 + 显示上次同步时间
- 冲突策略（按 revision 比较）：
  - 本地 revision > 服务器 → 上传本地
  - 服务器 revision > 本地 → 下载服务器并替换
  - 两者接近（时间差 < 5 分钟或相等）→ 按 id 合并，每条取 updatedAt 较新者
- WebDAV 凭据：坚果云账号邮箱 + 应用密码，存 SharedPreferences
- 所有网络/压缩操作放 isolate（compute），不阻塞 UI

## 6. 设置页

- 坚果云：WebDAV URL、账号、应用密码；测试连接按钮；手动同步按钮；上次同步时间
- 外观：跟随系统 / 浅色 / 深色
- 其他：关于页

## 7. 错误处理

- 网络失败：同步失败提示 + 静默重试（下次打开/变更时自然重试），不丢本地数据
- 提醒：申请通知权限（Android 13+ POST_NOTIFICATIONS），Android 12+ 精确闹钟权限；提醒使用 zonedSchedule，任务删除/完成时取消通知
- 坚果云凭据错误：设置页明确报错文案

## 8. 测试

- 单元测试：同步合并/冲突逻辑、快照序列化、Repository 增删改查
- Widget 测试：主列表渲染、完成任务流、视图切换
- 手动验证：模拟器跑通全流程

## 9. 环境准备

- 安装 JDK 17（brew install --cask temurin@17）
- `flutter create` 生成项目骨架
- Android SDK 已就绪（`~/Library/Android/sdk`）

## 10. 目录结构

```
lib/
  main.dart
  core/          # 主题、常量、路由
  data/
    db/          # database helper, DAO
    repositories/  # task/list/tag/sync repository
    models/      # Task, List, Tag, Subtask 实体
  sync/          # webdav client, snapshot serialize/merge
  notifications/ # 提醒调度
  features/
    today/  week/  calendar/  all/      # 四个视图
    detail/        # 任务详情/编辑
    drawer/        # 侧边抽屉
    settings/      # 设置页
  widgets/         # 通用组件（任务行、优先级选择等）
```
