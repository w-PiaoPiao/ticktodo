# 滴答清单Pro (TickTodo)

对标滴答清单核心体验的待办应用。Flutter 构建，支持 **Android + macOS**，本地优先存储 + 坚果云 WebDAV 备份同步。

## 功能

### 任务管理
- **任务**：标题、备注、优先级（无/低/中/高）、日期、时间、子任务（增删勾选排序）、标签多选
- **重复任务**：每天 / 每周 / 工作日 / 每月 / 每年 / 自定义周几；完成自动生成下一期，子任务与标签关联同步克隆，提醒保持偏移
- **提醒通知**：主提醒（提前 N 分钟）+ 多个额外提醒时间点；点击通知直达任务详情；任务删除/完成自动取消
- **全局搜索**：标题/备注关键词，300ms 防抖实时结果

### 习惯与专注
- **习惯打卡**：自定义颜色与每周目标天数；今日一键打卡；连续天数 🔥 统计；近 5 周 GitHub 风格热力图；支持归档
- **番茄专注**：25 分钟专注 + 短休/长休轮次（每 4 轮长休）；圆环倒计时（基于真实时间差，切后台计时依然准确）；可关联任务；阶段切换本地通知；今日番茄数/专注分钟统计

### 视图与组织
- **五视图**：今天 / 最近7天 / 日历（月视图）/ 全部（清单筛选）/ 四象限（重要×紧急矩阵）
- **智能清单（自定义过滤器）**：按 清单+标签+最低优先级+日期模式 组合保存查询条件
- **清单**：置顶、拖拽排序、颜色管理、默认"收集箱"
- **多选批量操作**：长按进入多选，批量删除/移动清单/设置日期
- **回收站**：软删除可恢复/彻底删除/清空；启动时自动清理 30 天前的记录
- **快速添加**：中文自然语言解析——`明天下午3点开会 #工作 !高` 自动识别日期/时间/标签/优先级

### 平台
| 平台 | 状态 | 说明 |
|---|---|---|
| Android | ✅ 完整 | 含桌面小部件（月视图）、本地通知 |
| macOS | ✅ 完整 | 侧边栏导航、平台菜单栏、⌘N/⌘F/⌘1-5 快捷键 |

### 同步与主题
- **坚果云 WebDAV 快照备份**：打开自动同步 + 变更 30s 防抖上传 + 手动同步；冲突按记录级合并
- **主题**：跟随系统 / 浅色 / 深色（Material 3）

## 构建

环境要求：Flutter 3.x。

```bash
cd ticktodo
flutter pub get
flutter build apk --debug        # Android
flutter build macos --debug      # macOS
```

运行：

```bash
flutter run -d <device-id>       # flutter devices 查看
```

## 测试

```bash
flutter test                          # 全量单元 + widget 测试
flutter test integration_test -d <device>   # 端到端冒烟
```

## 坚果云同步配置

1. 打开应用 → 抽屉/侧边栏 → **设置**
2. 填写：
   - WebDAV 地址：`https://dav.jianguoyun.com/dav/`
   - 账号：坚果云注册邮箱
   - 应用密码：坚果云网页版 → 账户信息 → **安全选项** → 添加应用生成（**不要用登录密码**）
3. 点"保存" → "测试连接" → "立即同步"

数据备份到坚果云目录 `TickTodo/todo_backup.json.gz`。

同步策略：本地 SQLite 为主数据源；打开 App 自动同步；本地变更 30 秒防抖后自动上传；冲突**永远按记录逐条 LWW 合并**（各表按 `updatedAt` 取较新者，不做整库覆盖——本地 revision 在重启后会失真，按它判定新旧会静默覆盖另一端数据）；标签关联按 (任务, 标签) 对逐条合并，**取消标签可同步**（软删墓碑，schema v5）。快照包含任务/子任务/清单/标签/关联/额外提醒/过滤器/**习惯与打卡/番茄会话**（含软删墓碑记录，保证取消打卡/删除标签等负向操作可同步）。同步落库后自动重排本机通知：其他设备新建的提醒在本机同样响铃，另一端完成/删除的任务取消本机遗留调度。

墓碑（软删记录）保留 90 天（`kTombstoneRetention`），超过后启动时物理清理；其他设备离线超过该时长可能出现"已删数据复活"（已知限制，彻底方案需永久墓碑表）。

> 版本兼容：v5 快照中标签关联带 `updatedAt/deletedAt` 列，**两端 App 需一起升级**（旧版本写入新快照会因未知列失败）。

### 本地备份

除坚果云备份外，App 会在本地自动保留快照副本（`buildSnapshot` + gzip，与云端同格式）：

- 首次启动后每 24 小时自动备份一次（变更时 30s 防抖顺带触发），也可在设置页手动「立即备份」
- 存储于应用文档目录 `backups/`，**保留最近 7 份**，启动时自动清理更旧的
- 恢复能力复用 `applySnapshot`（当前未提供恢复 UI，避免误覆盖）

## 目录结构

```
lib/
  core/          # 主题、常量、RepeatRule 引擎、快速添加解析器、providers、Logger
  data/
    db/          # SQLite 建表与迁移（v4）
    models/      # Task / ListModel / Tag / Subtask / Reminder / Filter / Habit
    repositories # 任务 / 元数据 / 过滤器 / 习惯 / 番茄 数据访问层
  backup/        # 本地快照备份（自动 + 手动）
  sync/          # WebDAV 客户端、快照序列化/合并、同步编排
  notifications/ # 本地提醒调度（Android + Darwin）
  features/
    today/ week/ calendar/ all/ matrix/   # 五视图
    habits/ focus/    # 习惯打卡、番茄专注
    detail/      # 任务详情（重复/提醒/子任务/标签编辑）
    desktop/     # macOS 侧边栏外壳
    filters/     # 智能清单管理与结果视图
    trash/       # 回收站
    search/ lists/ tags/ settings/ drawer/
  widgets/       # 通用组件（任务行、重复选择器、快速添加、优先级选择等）
```

> 说明：快速添加的中文自然语言解析（`quick_add_parser.dart`）为中文专用语法，不属于 UI 文案国际化范围。

## 国际化

UI 文案通过 `gen-l10n` 管理（`lib/l10n/app_zh.arb` 中文模板 + `app_en.arb` 英文）：

- 新增文案：在 ARB 中添加 key（zh 为模板），运行 `flutter gen-l10n` 生成 `AppLocalizations`，代码中用 `AppLocalizations.of(context).xxx`
- 语言跟随系统；`TickTodoApp(locale: ...)` 可强制（测试用）
- 通知频道文案在 `main.dart` 中按系统语言注入 `NotificationService`；未注入时回退中文
- 模型层数据语义（`TaskPriority.label`、`FilterDateMode.label`、快速添加解析语法）保持中文，UI 显示层通过 l10n 映射
