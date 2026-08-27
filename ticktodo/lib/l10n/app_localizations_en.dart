// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TickTodo Pro';

  @override
  String get kvSyncOk => 'Nutstore synced';

  @override
  String get kvSyncDown => 'Nutstore not connected';

  @override
  String get kvSyncNone => 'Sync not configured';

  @override
  String get navToday => 'Today';

  @override
  String get navWeek => 'Next 7 Days';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navAll => 'All';

  @override
  String get navAllTasks => 'All Tasks';

  @override
  String get navMatrix => 'Matrix';

  @override
  String get navLists => 'Lists';

  @override
  String get navTags => 'Tags';

  @override
  String get navFilters => 'Smart Lists';

  @override
  String get navHabits => 'Habits';

  @override
  String get navFocus => 'Focus';

  @override
  String get navSearch => 'Search Tasks';

  @override
  String get navTrash => 'Trash';

  @override
  String get navSettings => 'Settings';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonOk => 'OK';

  @override
  String get commonToday => 'Today';

  @override
  String get commonTomorrow => 'Tomorrow';

  @override
  String get commonAll => 'All';

  @override
  String get commonNone => 'None';

  @override
  String get commonCustom => 'Custom';

  @override
  String get untitledTask => 'Untitled task';

  @override
  String get todayEmptyTitle => 'No tasks for today';

  @override
  String get todayEmptySubtitle => 'Tap + to add quickly';

  @override
  String get weekAllDone => 'All done';

  @override
  String weekRemaining(int count) {
    return '$count left to do';
  }

  @override
  String get weekEmptyTitle => 'No tasks in the next 7 days';

  @override
  String get weekEmptySubtitle => 'Tap + to add a task with a date';

  @override
  String get allEmptyTitle => 'No tasks yet';

  @override
  String get allEmptySubtitle => 'Tap + to add a task';

  @override
  String get allListEmpty => 'No tasks in this list';

  @override
  String get allFilterAllLists => 'All lists';

  @override
  String calendarMonthTitle(int year, int month) {
    return '$month/$year';
  }

  @override
  String get calendarAddTask => 'Add Task';

  @override
  String get calendarNoSelection => 'Tap a date to see its tasks';

  @override
  String get calendarDayEmpty => 'No tasks on this day';

  @override
  String get calendarToday => 'Today';

  @override
  String get matrixQ1Title => 'Important & Urgent';

  @override
  String get matrixQ1Subtitle => 'Do now';

  @override
  String get matrixQ2Title => 'Important, Not Urgent';

  @override
  String get matrixQ2Subtitle => 'Schedule';

  @override
  String get matrixQ3Title => 'Urgent, Not Important';

  @override
  String get matrixQ3Subtitle => 'Delegate';

  @override
  String get matrixQ4Title => 'Neither';

  @override
  String get matrixQ4Subtitle => 'Skip';

  @override
  String get matrixEmpty => 'Empty';

  @override
  String get searchHint => 'Search task titles or notes';

  @override
  String get searchEmpty => 'No matching tasks';

  @override
  String get searchInitialHint => 'Type keywords to search';

  @override
  String get searchClear => 'Clear search';

  @override
  String get taskTitleHint => 'Task title';

  @override
  String get taskNoteHint => 'Notes';

  @override
  String get taskDetailTitle => 'Task Details';

  @override
  String get taskDeleteTitle => 'Delete Task';

  @override
  String taskDeleteConfirm(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get taskDeleteTooltip => 'Delete';

  @override
  String get taskSubtaskTitle => 'Subtasks';

  @override
  String get taskSubtaskHint => 'Add subtask…';

  @override
  String get taskPriority => 'Priority';

  @override
  String taskRepeatPrefix(String label) {
    return 'Repeats · $label';
  }

  @override
  String get taskRepeatClear => 'Clear repeat';

  @override
  String get listSection => 'Lists';

  @override
  String get listChoose => 'Choose List';

  @override
  String get listManage => 'Lists';

  @override
  String get listDefaultNotDeletable => 'The default Inbox cannot be deleted';

  @override
  String get listDeleteTitle => 'Delete List';

  @override
  String listDeleteConfirm(String name) {
    return 'Delete \"$name\"? Its tasks will be kept (moved to Inbox).';
  }

  @override
  String get listCreateHint => 'New list name';

  @override
  String get listMoveTo => 'Move to List';

  @override
  String get listCreate => 'Create List';

  @override
  String get listPin => 'Pin';

  @override
  String get listUnpin => 'Unpin';

  @override
  String get inboxName => 'Inbox';

  @override
  String get tagManageTitle => 'Manage Tags';

  @override
  String get tagRenameTitle => 'Rename Tag';

  @override
  String get tagEmpty => 'No tags yet. Create one below.';

  @override
  String get tagNameHint => 'Tag name';

  @override
  String get tagManageAction => 'Manage Tags';

  @override
  String get filterTitle => 'Smart Lists';

  @override
  String get filterEmpty => 'No smart lists yet';

  @override
  String get filterEmptyHint =>
      'Create one by combining lists/tags/priority/date';

  @override
  String get filterNew => 'New Smart List';

  @override
  String get filterEdit => 'Edit Smart List';

  @override
  String get filterResultEmpty => 'No matching tasks';

  @override
  String get filterDeleteTitle => 'Delete Smart List';

  @override
  String filterDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get filterNameLabel => 'Name';

  @override
  String get filterListsLabel => 'Lists (none = all)';

  @override
  String get filterTagsLabel => 'Tags (none = any)';

  @override
  String get filterMinPriority => 'Minimum priority';

  @override
  String get filterDateRange => 'Date range';

  @override
  String get filterSaveTooltip => 'Save';

  @override
  String get filterDeleteTooltip => 'Delete';

  @override
  String get filterAllOpen => 'All open tasks';

  @override
  String filterCountLists(int count) {
    return '$count lists';
  }

  @override
  String filterCountTags(int count) {
    return '$count tags';
  }

  @override
  String get filterPriorityHigh => 'High';

  @override
  String get filterPriorityAboveMedium => 'Medium+';

  @override
  String get filterPriorityAboveLow => 'Low+';

  @override
  String get filterPrioritySuffix => 'priority';

  @override
  String get filterDateAny => 'Any time';

  @override
  String get filterDateToday => 'Today';

  @override
  String get filterDateWeek => 'Next 7 days';

  @override
  String get filterDateOverdue => 'Overdue';

  @override
  String get filterDateNoDate => 'No date';

  @override
  String get trashTitle => 'Trash';

  @override
  String get trashEmpty => 'Trash is empty';

  @override
  String get trashClearTooltip => 'Empty Trash';

  @override
  String get trashRestoreTooltip => 'Restore';

  @override
  String get trashPurgeTooltip => 'Delete Forever';

  @override
  String get trashPurgeTitle => 'Delete Forever';

  @override
  String get trashPurgeConfirm => 'Deleted forever, this cannot be undone.';

  @override
  String get trashClearTitle => 'Empty Trash';

  @override
  String trashClearConfirm(int count) {
    return 'Permanently delete all $count tasks. This cannot be undone.';
  }

  @override
  String trashDeletedAt(String date) {
    return 'Deleted $date';
  }

  @override
  String trashCountTasks(int count) {
    return '$count tasks';
  }

  @override
  String get dateNoReminder => 'No reminder';

  @override
  String get dateAtDue => 'Due time';

  @override
  String get dateAhead5m => '5 minutes early';

  @override
  String get dateAhead15m => '15 minutes early';

  @override
  String get dateAhead30m => '30 minutes early';

  @override
  String get dateAhead1h => '1 hour early';

  @override
  String get dateAhead1d => '1 day early';

  @override
  String get dateCustomTime => 'Custom time…';

  @override
  String get dateAddDate => 'Add date';

  @override
  String get dateAddTime => 'Add time';

  @override
  String get dateRemindMe => 'Remind me';

  @override
  String get dateBadgeToday => 'Today';

  @override
  String get dateBadgeTomorrow => 'Tomorrow';

  @override
  String get dateBadgeYesterday => 'Yesterday';

  @override
  String dateBadgeMd(int month, int day) {
    return '$month/$day';
  }

  @override
  String dateBadgeYmd(int year, int month, int day) {
    return '$year/$month/$day';
  }

  @override
  String get repeatTitle => 'Repeat';

  @override
  String get repeatNone => 'Never';

  @override
  String get repeatCustomWeekly => 'Custom weekly…';

  @override
  String get repeatEveryDay => 'Daily';

  @override
  String repeatEveryNDays(int count) {
    return 'Every $count days';
  }

  @override
  String get repeatWorkdays => 'Weekdays';

  @override
  String get repeatEveryWeek => 'Weekly';

  @override
  String repeatEveryNWeeks(int count) {
    return 'Every $count weeks';
  }

  @override
  String get repeatEveryMonth => 'Monthly';

  @override
  String repeatEveryNMonths(int count) {
    return 'Every $count months';
  }

  @override
  String get repeatEveryYear => 'Yearly';

  @override
  String repeatEveryNYears(int count) {
    return 'Every $count years';
  }

  @override
  String repeatPerWeekday(String day) {
    return '$day';
  }

  @override
  String repeatWeekdaysJoin(String days) {
    return '$days';
  }

  @override
  String repeatWeeklyDays(String days) {
    return 'Every $days';
  }

  @override
  String repeatWeeklyDaysInterval(String days, int count) {
    return 'Every $days · every $count weeks';
  }

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityLow => 'Low';

  @override
  String get quickAddHint =>
      'Type a task, e.g. \"meeting 3pm tomorrow #work !high\"';

  @override
  String quickAddAdded(String title) {
    return 'Added \"$title\"';
  }

  @override
  String get quickAddListLabel => 'List';

  @override
  String quickAddTagPrefix(String name) {
    return '#$name';
  }

  @override
  String get quickAddConfirm => 'Add';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersAddTooltip => 'Add reminder';

  @override
  String get remindersEmpty =>
      'None yet. Tap + to add a reminder at a specific time.';

  @override
  String get remindersPickDateHelp => 'Pick reminder date';

  @override
  String get remindersPickTimeHelp => 'Pick reminder time';

  @override
  String get remindersFormatMd => 'MMM d HH:mm';

  @override
  String multiDeleteTitle(int count) {
    return 'Delete $count tasks';
  }

  @override
  String get multiDeleteRestorable =>
      'Deleted tasks can be restored from Trash.';

  @override
  String get multiMoveTo => 'Move to List';

  @override
  String get multiPickDate => 'Pick a date…';

  @override
  String multiCompletedCount(int count) {
    return '$count completed';
  }

  @override
  String get multiSelectAll => 'Select All';

  @override
  String get multiCancel => 'Cancel selection';

  @override
  String get multiSetDate => 'Set Date';

  @override
  String get emptyDefaultTitle => 'No tasks';

  @override
  String get habitsTitle => 'Habits';

  @override
  String get habitArchivedTitle => 'Archived Habits';

  @override
  String get habitBackToList => 'Back to habits';

  @override
  String get habitViewArchived => 'View archived';

  @override
  String get habitArchivedEmpty => 'No archived habits';

  @override
  String get habitEmpty => 'No habits yet';

  @override
  String get habitArchivedHint => 'Long-press a card to archive';

  @override
  String get habitCreateFirst => 'Tap + to create your first habit';

  @override
  String get habitArchivedTip =>
      'Use the card menu to restore or delete habits';

  @override
  String get habitCardTip =>
      'Long-press a card or use its menu: archive / delete';

  @override
  String get habitNew => 'New Habit';

  @override
  String get habitEdit => 'Edit Habit';

  @override
  String get habitNameLabel => 'Habit name';

  @override
  String get habitColor => 'Color';

  @override
  String get habitWeeklyTarget => 'Weekly target';

  @override
  String get habitEveryDay => 'Every day';

  @override
  String habitDaysPerWeek(int count) {
    return '$count days/week';
  }

  @override
  String habitStreakDays(int count) {
    return '$count days';
  }

  @override
  String habitWeekProgress(int count, int target) {
    return 'This week $count/$target';
  }

  @override
  String get habitMoreTooltip => 'More actions';

  @override
  String habitDeleteConfirm(String name) {
    return 'Delete \"$name\"? Its check-in history will be hidden and cannot be restored.';
  }

  @override
  String get habitDeleteTitle => 'Delete Habit';

  @override
  String get habitArchive => 'Archive';

  @override
  String get habitRestore => 'Restore';

  @override
  String get habitDeleted => '(deleted)';

  @override
  String get focusTitle => 'Focus';

  @override
  String get focusStart => 'Start Focus';

  @override
  String get focusGiveUp => 'Give Up';

  @override
  String get focusPause => 'Pause';

  @override
  String get focusResume => 'Resume';

  @override
  String get focusIdle => 'Ready';

  @override
  String get focusRunning => 'Focusing';

  @override
  String get focusBreak => 'On break';

  @override
  String get focusEndBreak => 'Break over';

  @override
  String get focusEndFocus => 'Focus complete';

  @override
  String get focusEndBreakBody => 'Break over, keep going!';

  @override
  String get focusEndFocusBody => 'Pomodoro done, take a break 🎉';

  @override
  String focusCompleted(int count) {
    return '🍅 Pomodoro #$count done!';
  }

  @override
  String focusSummary(int count) {
    return '$count pomodoros completed · statistics below';
  }

  @override
  String get focusTaskLabel => 'Link task (optional)';

  @override
  String get focusNoTask => 'None';

  @override
  String focusTodayStats(int pomodoros, int minutes) {
    return '$pomodoros pomodoros today · $minutes minutes focused';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSyncSection => 'Nutstore Sync';

  @override
  String get settingsWebdavUrl => 'WebDAV URL';

  @override
  String get settingsWebdavHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get settingsAccount => 'Account (Nutstore email)';

  @override
  String get settingsAppPassword => 'App password';

  @override
  String get settingsTestConnection => 'Test Connection';

  @override
  String get settingsSyncNow => 'Sync Now';

  @override
  String get settingsIncomplete => 'Please fill in all account fields';

  @override
  String get settingsSaved => 'Saved';

  @override
  String get settingsTesting => 'Testing…';

  @override
  String get settingsConnected => 'Connected';

  @override
  String settingsConnectFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get settingsSyncing => 'Syncing…';

  @override
  String get settingsUploaded => 'Uploaded';

  @override
  String get settingsDownloaded => 'Downloaded';

  @override
  String get settingsMerged => 'Merged';

  @override
  String get settingsNothingToSync => 'Nothing to sync';

  @override
  String settingsSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get settingsNeverSynced => 'Never synced';

  @override
  String settingsLastSync(String time) {
    return 'Last sync: $time';
  }

  @override
  String get settingsPasswordTip =>
      'Tip: generate the Nutstore app password at Nutstore web → Account → Security, and never use your login password.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsAboutSubtitle(String version) {
    return 'Version $version · Local-first · Nutstore backup sync';
  }

  @override
  String get settingsBackupSection => 'Local Backup';

  @override
  String settingsBackupLast(String time) {
    return 'Last backup: $time (keeps 7 copies, automatic daily)';
  }

  @override
  String get settingsBackupNever => 'Never backed up';

  @override
  String get settingsBackupNow => 'Back Up Now';

  @override
  String get settingsBackupBusy => 'Backing up…';

  @override
  String get settingsBackupSuccess => 'Backup complete';

  @override
  String get settingsBackupFailed => 'Backup failed, check the log';

  @override
  String get desktopMenuApp => 'TickTodo Pro';

  @override
  String get desktopMenuAbout => 'About TickTodo Pro';

  @override
  String get desktopMenuSettings => 'Settings…';

  @override
  String get desktopMenuQuit => 'Quit TickTodo Pro';

  @override
  String get desktopMenuFile => 'File';

  @override
  String get desktopMenuNewTask => 'New Task…';

  @override
  String get desktopMenuSearch => 'Search…';

  @override
  String get desktopMenuView => 'View';

  @override
  String get desktopMenuHelp => 'Help';

  @override
  String get desktopMenuShortcuts => 'Keyboard Shortcuts';

  @override
  String get desktopNewTask => 'New Task';

  @override
  String get desktopSearch => 'Search';

  @override
  String get desktopSettingsCmd => 'Settings ⌘,';

  @override
  String get desktopShortcutsTitle => 'Keyboard Shortcuts';

  @override
  String get desktopShortcutQuit => 'Quit';

  @override
  String get desktopSidebarFilters => 'Smart Lists';

  @override
  String get notifOpenTask => 'Tap to view task';

  @override
  String get notifTaskChannel => 'Task reminders';

  @override
  String get notifTaskChannelDesc => 'Task due/reminder notifications';

  @override
  String get notifPomodoroChannel => 'Focus';

  @override
  String get notifPomodoroChannelDesc => 'Focus/break phase notifications';

  @override
  String get emptyStateDefaultTitle => 'No tasks';
}
