// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '滴答清单Pro';

  @override
  String get kvSyncOk => '坚果云已同步';

  @override
  String get kvSyncDown => '坚果云未连接';

  @override
  String get kvSyncNone => '未配置同步';

  @override
  String get navToday => '今天';

  @override
  String get navWeek => '最近7天';

  @override
  String get navCalendar => '日历';

  @override
  String get navAll => '全部';

  @override
  String get navAllTasks => '全部任务';

  @override
  String get navMatrix => '四象限';

  @override
  String get navLists => '清单';

  @override
  String get navTags => '标签管理';

  @override
  String get navFilters => '智能清单';

  @override
  String get navHabits => '习惯打卡';

  @override
  String get navFocus => '番茄专注';

  @override
  String get navSearch => '搜索任务';

  @override
  String get navTrash => '回收站';

  @override
  String get navSettings => '设置';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDelete => '删除';

  @override
  String get commonSave => '保存';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonOk => '好';

  @override
  String get commonToday => '今天';

  @override
  String get commonTomorrow => '明天';

  @override
  String get commonAll => '全部';

  @override
  String get commonNone => '无';

  @override
  String get commonCustom => '自定义';

  @override
  String get untitledTask => '无标题任务';

  @override
  String get todayEmptyTitle => '今天没有任务';

  @override
  String get todayEmptySubtitle => '点击右下角 + 快速添加';

  @override
  String get weekAllDone => '全部完成';

  @override
  String weekRemaining(int count) {
    return '还有 $count 项待完成';
  }

  @override
  String get weekEmptyTitle => '未来7天没有任务';

  @override
  String get weekEmptySubtitle => '点右下角 + 添加带日期的任务';

  @override
  String get allEmptyTitle => '还没有任务';

  @override
  String get allEmptySubtitle => '点击右下角 + 添加任务';

  @override
  String get allListEmpty => '该清单暂无任务';

  @override
  String get allFilterAllLists => '全部清单';

  @override
  String calendarMonthTitle(int year, int month) {
    return '$year年$month月';
  }

  @override
  String get calendarAddTask => '添加任务';

  @override
  String get calendarNoSelection => '点击日期查看当天任务';

  @override
  String get calendarDayEmpty => '当天没有任务';

  @override
  String get calendarToday => '今天';

  @override
  String get matrixQ1Title => '重要且紧急';

  @override
  String get matrixQ1Subtitle => '立即做';

  @override
  String get matrixQ2Title => '重要不紧急';

  @override
  String get matrixQ2Subtitle => '安排做';

  @override
  String get matrixQ3Title => '紧急不重要';

  @override
  String get matrixQ3Subtitle => '委托做';

  @override
  String get matrixQ4Title => '不重要不紧急';

  @override
  String get matrixQ4Subtitle => '少做';

  @override
  String get matrixEmpty => '空';

  @override
  String get searchHint => '搜索任务标题或备注';

  @override
  String get searchEmpty => '没有找到相关任务';

  @override
  String get searchInitialHint => '输入关键词开始搜索';

  @override
  String get searchClear => '清空搜索';

  @override
  String get taskTitleHint => '任务标题';

  @override
  String get taskNoteHint => '备注';

  @override
  String get taskDetailTitle => '任务详情';

  @override
  String get taskDeleteTitle => '删除任务';

  @override
  String taskDeleteConfirm(String title) {
    return '确定要删除「$title」吗？';
  }

  @override
  String get taskDeleteTooltip => '删除';

  @override
  String get taskSubtaskTitle => '子任务';

  @override
  String get taskSubtaskHint => '添加子任务…';

  @override
  String get taskPriority => '优先级';

  @override
  String taskRepeatPrefix(String label) {
    return '重复 · $label';
  }

  @override
  String get taskRepeatClear => '清除重复';

  @override
  String get listSection => '清单';

  @override
  String get listChoose => '选择清单';

  @override
  String get listManage => '清单';

  @override
  String get listDefaultNotDeletable => '默认清单「收集箱」不可删除';

  @override
  String get listDeleteTitle => '删除清单';

  @override
  String listDeleteConfirm(String name) {
    return '删除「$name」？其中的任务将保留（回到默认清单）。';
  }

  @override
  String get listCreateHint => '新清单名称';

  @override
  String get listMoveTo => '移动到清单';

  @override
  String get listCreate => '创建清单';

  @override
  String get listPin => '置顶';

  @override
  String get listUnpin => '取消置顶';

  @override
  String get inboxName => '收集箱';

  @override
  String get tagManageTitle => '标签管理';

  @override
  String get tagRenameTitle => '重命名标签';

  @override
  String get tagEmpty => '还没有标签，在下方创建一个吧';

  @override
  String get tagNameHint => '标签名称';

  @override
  String get tagManageAction => '管理标签';

  @override
  String get filterTitle => '智能清单';

  @override
  String get filterEmpty => '还没有智能清单';

  @override
  String get filterEmptyHint => '按清单/标签/优先级/日期组合创建';

  @override
  String get filterNew => '新建智能清单';

  @override
  String get filterEdit => '编辑智能清单';

  @override
  String get filterResultEmpty => '没有符合条件的任务';

  @override
  String get filterDeleteTitle => '删除智能清单';

  @override
  String filterDeleteConfirm(String name) {
    return '确定删除「$name」吗？';
  }

  @override
  String get filterNameLabel => '名称';

  @override
  String get filterListsLabel => '清单（不选=全部）';

  @override
  String get filterTagsLabel => '标签（不选=不限）';

  @override
  String get filterMinPriority => '最低优先级';

  @override
  String get filterDateRange => '日期范围';

  @override
  String get filterSaveTooltip => '保存';

  @override
  String get filterDeleteTooltip => '删除';

  @override
  String get filterAllOpen => '全部未完成任务';

  @override
  String filterCountLists(int count) {
    return '$count 个清单';
  }

  @override
  String filterCountTags(int count) {
    return '$count 个标签';
  }

  @override
  String get filterPriorityHigh => '高';

  @override
  String get filterPriorityAboveMedium => '中以上';

  @override
  String get filterPriorityAboveLow => '低以上';

  @override
  String get filterPrioritySuffix => '优先级';

  @override
  String get filterDateAny => '不限';

  @override
  String get filterDateToday => '今天';

  @override
  String get filterDateWeek => '最近7天';

  @override
  String get filterDateOverdue => '已过期';

  @override
  String get filterDateNoDate => '无日期';

  @override
  String get trashTitle => '回收站';

  @override
  String get trashEmpty => '回收站为空';

  @override
  String get trashClearTooltip => '清空回收站';

  @override
  String get trashRestoreTooltip => '恢复';

  @override
  String get trashPurgeTooltip => '彻底删除';

  @override
  String get trashPurgeTitle => '彻底删除';

  @override
  String get trashPurgeConfirm => '彻底删除后无法恢复，确定吗？';

  @override
  String get trashClearTitle => '清空回收站';

  @override
  String trashClearConfirm(int count) {
    return '将彻底删除全部 $count 个任务，无法恢复。';
  }

  @override
  String trashDeletedAt(String date) {
    return '删除于 $date';
  }

  @override
  String trashCountTasks(int count) {
    return '$count 个任务';
  }

  @override
  String get dateNoReminder => '不提醒';

  @override
  String get dateAtDue => '到期时间';

  @override
  String get dateAhead5m => '提前 5 分钟';

  @override
  String get dateAhead15m => '提前 15 分钟';

  @override
  String get dateAhead30m => '提前 30 分钟';

  @override
  String get dateAhead1h => '提前 1 小时';

  @override
  String get dateAhead1d => '提前 1 天';

  @override
  String get dateCustomTime => '自定义时间';

  @override
  String get dateAddDate => '添加日期';

  @override
  String get dateAddTime => '添加时间';

  @override
  String get dateRemindMe => '提醒我';

  @override
  String get dateBadgeToday => '今天';

  @override
  String get dateBadgeTomorrow => '明天';

  @override
  String get dateBadgeYesterday => '昨天';

  @override
  String dateBadgeMd(int month, int day) {
    return '$month月$day日';
  }

  @override
  String dateBadgeYmd(int year, int month, int day) {
    return '$year年$month月$day日';
  }

  @override
  String get repeatTitle => '重复';

  @override
  String get repeatNone => '不重复';

  @override
  String get repeatCustomWeekly => '自定义每周…';

  @override
  String get repeatEveryDay => '每天';

  @override
  String repeatEveryNDays(int count) {
    return '每 $count 天';
  }

  @override
  String get repeatWorkdays => '工作日';

  @override
  String get repeatEveryWeek => '每周';

  @override
  String repeatEveryNWeeks(int count) {
    return '每 $count 周';
  }

  @override
  String get repeatEveryMonth => '每月';

  @override
  String repeatEveryNMonths(int count) {
    return '每 $count 月';
  }

  @override
  String get repeatEveryYear => '每年';

  @override
  String repeatEveryNYears(int count) {
    return '每 $count 年';
  }

  @override
  String repeatPerWeekday(String day) {
    return '周$day';
  }

  @override
  String repeatWeekdaysJoin(String days) {
    return '$days';
  }

  @override
  String repeatWeeklyDays(String days) {
    return '每$days';
  }

  @override
  String repeatWeeklyDaysInterval(String days, int count) {
    return '每$days · 每 $count 周';
  }

  @override
  String get priorityHigh => '高';

  @override
  String get priorityMedium => '中';

  @override
  String get priorityLow => '低';

  @override
  String get quickAddHint => '输入任务，如“明天下午3点开会 #工作 !高”';

  @override
  String quickAddAdded(String title) {
    return '已添加「$title」';
  }

  @override
  String get quickAddListLabel => '清单';

  @override
  String quickAddTagPrefix(String name) {
    return '#$name';
  }

  @override
  String get quickAddConfirm => '添加';

  @override
  String get remindersTitle => '提醒时间';

  @override
  String get remindersAddTooltip => '添加提醒';

  @override
  String get remindersEmpty => '暂无，点 + 添加指定日期时间的提醒';

  @override
  String get remindersPickDateHelp => '选择提醒日期';

  @override
  String get remindersPickTimeHelp => '选择提醒时间';

  @override
  String get remindersFormatMd => 'MM月dd日 HH:mm';

  @override
  String multiDeleteTitle(int count) {
    return '删除 $count 个任务';
  }

  @override
  String get multiDeleteRestorable => '删除后可在回收站恢复。';

  @override
  String get multiMoveTo => '移动到清单';

  @override
  String get multiPickDate => '选择日期…';

  @override
  String multiCompletedCount(int count) {
    return '已完成 $count';
  }

  @override
  String get multiSelectAll => '全选';

  @override
  String get multiCancel => '取消多选';

  @override
  String get multiSetDate => '设置日期';

  @override
  String get emptyDefaultTitle => '没有任务';

  @override
  String get habitsTitle => '习惯';

  @override
  String get habitArchivedTitle => '已归档习惯';

  @override
  String get habitBackToList => '返回习惯列表';

  @override
  String get habitViewArchived => '查看已归档';

  @override
  String get habitArchivedEmpty => '没有已归档的习惯';

  @override
  String get habitEmpty => '还没有习惯';

  @override
  String get habitArchivedHint => '长按习惯卡片即可归档';

  @override
  String get habitCreateFirst => '点击右下角 + 创建第一个习惯';

  @override
  String get habitArchivedTip => '通过卡片右侧菜单可恢复或删除习惯';

  @override
  String get habitCardTip => '长按卡片或使用卡片右侧菜单：归档 / 删除';

  @override
  String get habitNew => '新建习惯';

  @override
  String get habitEdit => '编辑习惯';

  @override
  String get habitNameLabel => '习惯名称';

  @override
  String get habitColor => '颜色';

  @override
  String get habitWeeklyTarget => '每周目标';

  @override
  String get habitEveryDay => '每天';

  @override
  String habitDaysPerWeek(int count) {
    return '$count 天/周';
  }

  @override
  String habitStreakDays(int count) {
    return '$count 天';
  }

  @override
  String habitWeekProgress(int count, int target) {
    return '本周 $count/$target';
  }

  @override
  String get habitMoreTooltip => '更多操作';

  @override
  String habitDeleteConfirm(String name) {
    return '确定删除「$name」吗？其打卡记录将一并隐藏，无法在界面恢复。';
  }

  @override
  String get habitDeleteTitle => '删除习惯';

  @override
  String get habitArchive => '归档';

  @override
  String get habitRestore => '恢复';

  @override
  String get habitDeleted => '（已删除）';

  @override
  String get focusTitle => '番茄专注';

  @override
  String get focusStart => '开始专注';

  @override
  String get focusGiveUp => '放弃';

  @override
  String get focusPause => '暂停';

  @override
  String get focusResume => '继续';

  @override
  String get focusIdle => '准备就绪';

  @override
  String get focusRunning => '专注中';

  @override
  String get focusBreak => '休息中';

  @override
  String get focusEndBreak => '休息结束';

  @override
  String get focusEndFocus => '专注完成';

  @override
  String get focusEndBreakBody => '休息结束，继续加油！';

  @override
  String get focusEndFocusBody => '番茄结束，休息一下吧 🎉';

  @override
  String focusCompleted(int count) {
    return '🍅 第 $count 个番茄完成！';
  }

  @override
  String focusSummary(int count) {
    return '已完成 $count 个番茄 · 今日统计见下方';
  }

  @override
  String get focusTaskLabel => '关联任务（可选）';

  @override
  String get focusNoTask => '不关联';

  @override
  String focusTodayStats(int pomodoros, int minutes) {
    return '今日 $pomodoros 个番茄 · 累计专注 $minutes 分钟';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSyncSection => '坚果云同步';

  @override
  String get settingsWebdavUrl => 'WebDAV 地址';

  @override
  String get settingsWebdavHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get settingsAccount => '账号（坚果云邮箱）';

  @override
  String get settingsAppPassword => '应用密码';

  @override
  String get settingsTestConnection => '测试连接';

  @override
  String get settingsSyncNow => '立即同步';

  @override
  String get settingsIncomplete => '请填写完整的账号信息';

  @override
  String get settingsSaved => '已保存';

  @override
  String get settingsTesting => '测试中…';

  @override
  String get settingsConnected => '连接成功';

  @override
  String settingsConnectFailed(String error) {
    return '连接失败：$error';
  }

  @override
  String get settingsSyncing => '同步中…';

  @override
  String get settingsUploaded => '已上传';

  @override
  String get settingsDownloaded => '已下载';

  @override
  String get settingsMerged => '已合并';

  @override
  String get settingsNothingToSync => '无需同步';

  @override
  String settingsSyncFailed(String error) {
    return '同步失败：$error';
  }

  @override
  String get settingsNeverSynced => '尚未同步';

  @override
  String settingsLastSync(String time) {
    return '上次同步：$time';
  }

  @override
  String get settingsPasswordTip =>
      '提示：坚果云「应用密码」在坚果云网页版 → 账户信息 → 安全选项 中生成，不要直接使用登录密码。';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsAbout => '关于';

  @override
  String settingsAboutSubtitle(String version) {
    return '版本 $version · 本地优先 · 坚果云备份同步';
  }

  @override
  String get settingsBackupSection => '本地备份';

  @override
  String settingsBackupLast(String time) {
    return '上次备份：$time（保留最近 7 份，每日自动）';
  }

  @override
  String get settingsBackupNever => '尚未备份';

  @override
  String get settingsBackupNow => '立即备份';

  @override
  String get settingsBackupBusy => '备份中…';

  @override
  String get settingsBackupSuccess => '备份成功';

  @override
  String get settingsBackupFailed => '备份失败，请查看日志';

  @override
  String get desktopMenuApp => '滴答清单Pro';

  @override
  String get desktopMenuAbout => '关于滴答清单Pro';

  @override
  String get desktopMenuSettings => '设置…';

  @override
  String get desktopMenuQuit => '退出滴答清单Pro';

  @override
  String get desktopMenuFile => '文件';

  @override
  String get desktopMenuNewTask => '新建任务…';

  @override
  String get desktopMenuSearch => '搜索…';

  @override
  String get desktopMenuView => '视图';

  @override
  String get desktopMenuHelp => '帮助';

  @override
  String get desktopMenuShortcuts => '键盘快捷键';

  @override
  String get desktopNewTask => '新建任务';

  @override
  String get desktopSearch => '搜索';

  @override
  String get desktopSettingsCmd => '设置 ⌘,';

  @override
  String get desktopShortcutsTitle => '键盘快捷键';

  @override
  String get desktopShortcutQuit => '退出';

  @override
  String get desktopSidebarFilters => '智能清单';

  @override
  String get notifOpenTask => '点击查看任务详情';

  @override
  String get notifTaskChannel => '任务提醒';

  @override
  String get notifTaskChannelDesc => '任务到期/提醒通知';

  @override
  String get notifPomodoroChannel => '番茄专注';

  @override
  String get notifPomodoroChannelDesc => '专注/休息阶段切换提醒';

  @override
  String get emptyStateDefaultTitle => '没有任务';
}
