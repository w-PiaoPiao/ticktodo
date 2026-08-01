# 桌面小部件 · 月视图 · 设计文档

日期：2026-08-01
前置授权：用户指示"不要问我，有疑惑时自己审查，都选建议的选项"

## 1. 目标

在 Android 桌面添加一个**月视图小部件**：7 列日历网格，有任务的日期显示圆点，今天高亮，点击日期打开 App 日历视图并选中该日期；支持左右切换月份、手动刷新。

## 2. 技术约束与选型

- Android App Widget 只能用 **RemoteViews** 渲染（有限 View 集合：TextView/ImageView/LinearLayout/GridLayout 等），**无法用 Flutter 渲染**。
- 方案对比：
  - **A: 纯原生 RemoteViews（推荐）**：Kotlin AppWidgetProvider + GridLayout（7×6=42 格 + 表头）。零额外依赖、完全可控。
  - B: Jetpack Glance：多一个框架依赖，LazyVerticalGrid 对 7 列支持不稳，收益低。
  - → 选 A。
- **数据读取**：原生侧用 `SQLiteDatabase.openDatabase` 只读打开 Flutter sqflite 的数据库文件 `databases/ticktodo.db`，查询当月 `dueDate`（`deletedAt IS NULL AND completed=0`）。SQLite 多连接只读安全。
- **刷新链路**：
  1. Flutter 任务变更（`bumpMutation`）→ MethodChannel `ticktodo/widget` 调 `refresh` → 原生 `updateAppWidget`
  2. 小部件手动刷新按钮 → PendingIntent → `onReceive(ACTION_REFRESH)` 重建
  3. 系统 `APPWIDGET_UPDATE`（含添加小部件时）→ `onUpdate` 重建
- **月份状态**：SharedPreferences 存 `widget_month_offset`（相对当月的偏移），左右箭头 PendingIntent 修改后重建；点"今天"归零。
- **点击日期**：PendingIntent 打开 MainActivity，Intent extra `date=yyyy-MM-dd`；MainActivity 存 static 字段（或通过 MethodChannel）供 Flutter 读取，Flutter 跳转日历 tab 并选中日期。
- **深色适配**：提供 `layout/month_widget.xml` + `layout-night/month_widget.xml`，跟随系统主题。

## 3. 布局（RemoteViews）

```
LinearLayout (垂直, 背景圆角卡片)
├─ 头部 Row: 月份文本 | Spacer | 刷新按钮 | 右箭头(仅非本月) | "今天"按钮(仅非本月)
│   （左箭头恒显示，点击即前一个月）
├─ 星期表头 Row: 一二三四五六日（7 个 TextView）
└─ GridLayout: 7 列 × 6 行 = 42 个 TextView 单元格
     - 非本月日期：灰色小字（前后补位）
     - 今天：绿色圆形背景 + 白字加粗
     - 有任务日期：数字下方 4dp 绿色圆点
     - 点击：带 date extra 的 PendingIntent（非本月格子不可点）
```

## 4. 文件清单

| 文件 | 内容 |
|---|---|
| `android/.../MonthWidgetProvider.kt` | AppWidgetProvider：onUpdate/onReceive，构建 RemoteViews |
| `android/.../MonthWidgetRenderer.kt` | 纯函数：读库→月份数据→RemoteViews（可读性好） |
| `android/app/src/main/res/layout/month_widget.xml` | 浅色布局 |
| `android/app/src/main/res/layout-night/month_widget.xml` | 深色布局 |
| `android/app/src/main/res/xml/month_widget_info.xml` | appwidget-provider 元数据（最小 4x3，updatePeriodMillis=0 由应用主动刷新） |
| `android/.../MainActivity.kt` | MethodChannel（refresh + 启动日期读取） |
| `lib/core/widget_bridge.dart` | Flutter 侧 channel 封装（bumpMutation 中调用 refresh） |
| `lib/app.dart` | HomeShell 支持初始 tab=日历 + 初始选中日期 |
| `lib/features/calendar/calendar_screen.dart` | 支持外部传入选中日期（initialSelectedDate） |
| `AndroidManifest.xml` | 注册 receiver + meta-data |

## 5. 交互细节

- 点击"今天/左/右"外的空白区不响应；点日期打开 App。
- 小部件内月份为偏移（非绝对），始终以"当前月+偏移"渲染，避免跨月后显示过期月份。
- 数据库打开失败（首次未建库/文件不存在）→ 显示空网格 + 头行"暂无数据"，不崩溃。
- Flutter 启动参数：MainActivity 通过 `MethodChannel.getStartupDate()` 返回 `date` extra；HomeShell 在 initState 里异步查询后 setState 切换 tab 并传给 CalendarScreen。

## 6. 错误处理

- SQLite 打开失败 → try-catch，空网格。
- RemoteViews 构建异常 → 不 crash provider，logcat 输出。
- Flutter 侧 channel 未注册（测试环境）→ invokeMethod 用 `catchError` 静默。

## 7. 测试

- 构建 APK 通过；模拟器安装。
- `adb shell am broadcast -a android.appwidget.action.APPWIDGET_UPDATE` 触发渲染，logcat 无异常。
- `adb shell am start` 带 extra date 验证跳转（集成测试扩展或手动）。
- Flutter 单测：widget_bridge 静默失败；HomeShell 初始 tab 逻辑。

## 8. 范围外（YAGNI）

- 小部件内完成任务、拖拽调整大小适配（用 minWidth 固定）、多实例不同月份、翻页动画。
