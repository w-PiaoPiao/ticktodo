# 滴答清单Pro (TickTodo)

对标滴答清单核心体验的待办应用。Flutter 构建，支持 **Android + macOS**，本地优先存储 + 坚果云 WebDAV 备份同步。

## 功能

### 任务管理
- **任务**：标题、备注、优先级（无/低/中/高）、日期、时间、子任务（增删勾选排序）、标签多选
- **重复任务**：每天 / 每周 / 工作日 / 每月 / 每年 / 自定义周几；完成自动生成下一期，子任务与标签关联同步克隆，提醒保持偏移
- **提醒通知**：主提醒（提前 N 分钟）+ 多个额外提醒时间点；点击通知直达任务详情；任务删除/完成自动取消
- **全局搜索**：标题/备注关键词，300ms 防抖实时结果

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

同步策略：本地 SQLite 为主数据源；打开 App 自动下载比较版本；本地变更 30 秒防抖后自动上传；冲突时按记录 `updatedAt` 合并（5 分钟窗口内逐条合并，超出则整体取新）。快照包含任务/子任务/清单/标签/关联/**额外提醒**/**过滤器**。

## 目录结构

```
lib/
  core/          # 主题、常量、RepeatRule 引擎、快速添加解析器、providers
  data/
    db/          # SQLite 建表与迁移（v3）
    models/      # Task / ListModel / Tag / Subtask / Reminder / Filter
    repositories # 任务 / 元数据 / 过滤器 数据访问层
  sync/          # WebDAV 客户端、快照序列化/合并、同步编排
  notifications/ # 本地提醒调度（Android + Darwin）
  features/
    today/ week/ calendar/ all/ matrix/   # 五视图
    detail/      # 任务详情（重复/提醒/子任务/标签编辑）
    desktop/     # macOS 侧边栏外壳
    filters/     # 智能清单管理与结果视图
    trash/       # 回收站
    search/ lists/ tags/ settings/ drawer/
  widgets/       # 通用组件（任务行、重复选择器、快速添加、优先级选择等）
```
