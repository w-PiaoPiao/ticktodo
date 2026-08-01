# 滴答清单Pro (TickTodo)

对标滴答清单核心体验的 Android 待办应用。Flutter 构建，本地优先存储 + 坚果云 WebDAV 备份同步。

## 功能

- **四视图**：今天 / 最近7天 / 日历（月视图点选日期）/ 全部（按清单筛选）
- **任务管理**：标题、备注、优先级（无/低/中/高）、日期、时间、提醒通知
- **子任务**：添加、勾选、删除、上下移动排序
- **清单**：多清单管理（颜色、排序）、默认"收集箱"、清单内任务筛选
- **标签**：标签多选、颜色管理、重命名
- **本地通知**：任务提醒（到期时间 / 提前 N 分钟 / 自定义），任务删除自动取消
- **坚果云同步**：WebDAV 快照备份（gzip 压缩），打开自动同步 + 变更防抖自动上传 + 手动同步，冲突按记录级合并
- **主题**：跟随系统 / 浅色 / 深色（Material 3，滴答绿种子色）

## 构建

环境要求：Flutter 3.x、JDK 17（Android SDK）。

```bash
cd ticktodo
flutter pub get
flutter build apk --debug     # 或 --release
```

产物：`build/app/outputs/flutter-apk/app-debug.apk`

## 测试

```bash
flutter test                          # 单元 + widget 测试（56 项）
flutter test integration_test -d <device>   # 端到端冒烟（真机/模拟器）
```

## 坚果云同步配置

1. 打开应用 → 抽屉 → **设置**
2. 填写：
   - WebDAV 地址：`https://dav.jianguoyun.com/dav/`
   - 账号：坚果云注册邮箱
   - 应用密码：坚果云网页版 → 账户信息 → **安全选项** → 添加应用生成（**不要用登录密码**）
3. 点"保存" → "测试连接" → "立即同步"

数据备份到坚果云目录 `TickTodo/todo_backup.json.gz`。

同步策略：本地 SQLite 为主数据源；打开 App 自动下载比较版本；本地变更 30 秒防抖后自动上传；冲突时按记录 `updatedAt` 合并（5 分钟窗口内逐条合并，超出则整体取新）。

## 目录结构

```
lib/
  core/          # 主题、常量、Riverpod providers
  data/
    db/          # SQLite 建表与连接
    models/      # Task / ListModel / Tag / Subtask 实体
    repositories # 数据访问层
  sync/          # WebDAV 客户端、快照序列化/合并、同步编排
  notifications/ # 本地提醒调度
  features/      # 今天 / 周 / 日历 / 全部 / 详情 / 清单 / 标签 / 设置 / 抽屉
  widgets/       # 通用组件（任务行、优先级选择、日期时间选择、空状态）
```
