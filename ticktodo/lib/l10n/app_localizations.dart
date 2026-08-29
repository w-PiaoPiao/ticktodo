import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'滴答清单Pro'**
  String get appTitle;

  /// No description provided for @kvSyncOk.
  ///
  /// In zh, this message translates to:
  /// **'坚果云已同步'**
  String get kvSyncOk;

  /// No description provided for @kvSyncDown.
  ///
  /// In zh, this message translates to:
  /// **'坚果云未连接'**
  String get kvSyncDown;

  /// No description provided for @kvSyncNone.
  ///
  /// In zh, this message translates to:
  /// **'未配置同步'**
  String get kvSyncNone;

  /// No description provided for @navToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get navToday;

  /// No description provided for @navWeek.
  ///
  /// In zh, this message translates to:
  /// **'最近7天'**
  String get navWeek;

  /// No description provided for @navCalendar.
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get navCalendar;

  /// No description provided for @navAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get navAll;

  /// No description provided for @navAllTasks.
  ///
  /// In zh, this message translates to:
  /// **'全部任务'**
  String get navAllTasks;

  /// No description provided for @navMatrix.
  ///
  /// In zh, this message translates to:
  /// **'四象限'**
  String get navMatrix;

  /// No description provided for @navLists.
  ///
  /// In zh, this message translates to:
  /// **'清单'**
  String get navLists;

  /// No description provided for @navTags.
  ///
  /// In zh, this message translates to:
  /// **'标签管理'**
  String get navTags;

  /// No description provided for @navFilters.
  ///
  /// In zh, this message translates to:
  /// **'智能清单'**
  String get navFilters;

  /// No description provided for @navHabits.
  ///
  /// In zh, this message translates to:
  /// **'习惯打卡'**
  String get navHabits;

  /// No description provided for @navFocus.
  ///
  /// In zh, this message translates to:
  /// **'番茄专注'**
  String get navFocus;

  /// No description provided for @navSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索任务'**
  String get navSearch;

  /// No description provided for @navTrash.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get navTrash;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonConfirm;

  /// No description provided for @commonOk.
  ///
  /// In zh, this message translates to:
  /// **'好'**
  String get commonOk;

  /// No description provided for @commonToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get commonToday;

  /// No description provided for @commonTomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天'**
  String get commonTomorrow;

  /// No description provided for @commonAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get commonAll;

  /// No description provided for @commonNone.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get commonNone;

  /// No description provided for @commonCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get commonCustom;

  /// No description provided for @untitledTask.
  ///
  /// In zh, this message translates to:
  /// **'无标题任务'**
  String get untitledTask;

  /// No description provided for @taskNotFound.
  ///
  /// In zh, this message translates to:
  /// **'任务不存在或已删除'**
  String get taskNotFound;

  /// No description provided for @todayEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'今天没有任务'**
  String get todayEmptyTitle;

  /// No description provided for @todayEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角 + 快速添加'**
  String get todayEmptySubtitle;

  /// No description provided for @weekAllDone.
  ///
  /// In zh, this message translates to:
  /// **'全部完成'**
  String get weekAllDone;

  /// No description provided for @weekRemaining.
  ///
  /// In zh, this message translates to:
  /// **'还有 {count} 项待完成'**
  String weekRemaining(int count);

  /// No description provided for @weekEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'未来7天没有任务'**
  String get weekEmptyTitle;

  /// No description provided for @weekEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点右下角 + 添加带日期的任务'**
  String get weekEmptySubtitle;

  /// No description provided for @allEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有任务'**
  String get allEmptyTitle;

  /// No description provided for @allEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角 + 添加任务'**
  String get allEmptySubtitle;

  /// No description provided for @allListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该清单暂无任务'**
  String get allListEmpty;

  /// No description provided for @allFilterAllLists.
  ///
  /// In zh, this message translates to:
  /// **'全部清单'**
  String get allFilterAllLists;

  /// No description provided for @calendarMonthTitle.
  ///
  /// In zh, this message translates to:
  /// **'{year}年{month}月'**
  String calendarMonthTitle(int year, int month);

  /// No description provided for @calendarAddTask.
  ///
  /// In zh, this message translates to:
  /// **'添加任务'**
  String get calendarAddTask;

  /// No description provided for @calendarNoSelection.
  ///
  /// In zh, this message translates to:
  /// **'点击日期查看当天任务'**
  String get calendarNoSelection;

  /// No description provided for @calendarDayEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当天没有任务'**
  String get calendarDayEmpty;

  /// No description provided for @calendarToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get calendarToday;

  /// No description provided for @matrixQ1Title.
  ///
  /// In zh, this message translates to:
  /// **'重要且紧急'**
  String get matrixQ1Title;

  /// No description provided for @matrixQ1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'立即做'**
  String get matrixQ1Subtitle;

  /// No description provided for @matrixQ2Title.
  ///
  /// In zh, this message translates to:
  /// **'重要不紧急'**
  String get matrixQ2Title;

  /// No description provided for @matrixQ2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'安排做'**
  String get matrixQ2Subtitle;

  /// No description provided for @matrixQ3Title.
  ///
  /// In zh, this message translates to:
  /// **'紧急不重要'**
  String get matrixQ3Title;

  /// No description provided for @matrixQ3Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'委托做'**
  String get matrixQ3Subtitle;

  /// No description provided for @matrixQ4Title.
  ///
  /// In zh, this message translates to:
  /// **'不重要不紧急'**
  String get matrixQ4Title;

  /// No description provided for @matrixQ4Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'少做'**
  String get matrixQ4Subtitle;

  /// No description provided for @matrixEmpty.
  ///
  /// In zh, this message translates to:
  /// **'空'**
  String get matrixEmpty;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索任务标题或备注'**
  String get searchHint;

  /// No description provided for @searchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关任务'**
  String get searchEmpty;

  /// No description provided for @searchInitialHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词开始搜索'**
  String get searchInitialHint;

  /// No description provided for @searchClear.
  ///
  /// In zh, this message translates to:
  /// **'清空搜索'**
  String get searchClear;

  /// No description provided for @taskTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'任务标题'**
  String get taskTitleHint;

  /// No description provided for @taskNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get taskNoteHint;

  /// No description provided for @taskDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务详情'**
  String get taskDetailTitle;

  /// No description provided for @taskDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除任务'**
  String get taskDeleteTitle;

  /// No description provided for @taskDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除「{title}」吗？'**
  String taskDeleteConfirm(String title);

  /// No description provided for @taskDeleteTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get taskDeleteTooltip;

  /// No description provided for @taskSubtaskTitle.
  ///
  /// In zh, this message translates to:
  /// **'子任务'**
  String get taskSubtaskTitle;

  /// No description provided for @taskSubtaskHint.
  ///
  /// In zh, this message translates to:
  /// **'添加子任务…'**
  String get taskSubtaskHint;

  /// No description provided for @taskPriority.
  ///
  /// In zh, this message translates to:
  /// **'优先级'**
  String get taskPriority;

  /// No description provided for @taskRepeatPrefix.
  ///
  /// In zh, this message translates to:
  /// **'重复 · {label}'**
  String taskRepeatPrefix(String label);

  /// No description provided for @taskRepeatClear.
  ///
  /// In zh, this message translates to:
  /// **'清除重复'**
  String get taskRepeatClear;

  /// No description provided for @listSection.
  ///
  /// In zh, this message translates to:
  /// **'清单'**
  String get listSection;

  /// No description provided for @listChoose.
  ///
  /// In zh, this message translates to:
  /// **'选择清单'**
  String get listChoose;

  /// No description provided for @listManage.
  ///
  /// In zh, this message translates to:
  /// **'清单'**
  String get listManage;

  /// No description provided for @listDefaultNotDeletable.
  ///
  /// In zh, this message translates to:
  /// **'默认清单「收集箱」不可删除'**
  String get listDefaultNotDeletable;

  /// No description provided for @listDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除清单'**
  String get listDeleteTitle;

  /// No description provided for @listDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」？其中的任务将保留（回到默认清单）。'**
  String listDeleteConfirm(String name);

  /// No description provided for @listCreateHint.
  ///
  /// In zh, this message translates to:
  /// **'新清单名称'**
  String get listCreateHint;

  /// No description provided for @listMoveTo.
  ///
  /// In zh, this message translates to:
  /// **'移动到清单'**
  String get listMoveTo;

  /// No description provided for @listCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建清单'**
  String get listCreate;

  /// No description provided for @listPin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get listPin;

  /// No description provided for @listUnpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get listUnpin;

  /// No description provided for @inboxName.
  ///
  /// In zh, this message translates to:
  /// **'收集箱'**
  String get inboxName;

  /// No description provided for @tagManageTitle.
  ///
  /// In zh, this message translates to:
  /// **'标签管理'**
  String get tagManageTitle;

  /// No description provided for @tagRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名标签'**
  String get tagRenameTitle;

  /// No description provided for @tagEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有标签，在下方创建一个吧'**
  String get tagEmpty;

  /// No description provided for @tagNameHint.
  ///
  /// In zh, this message translates to:
  /// **'标签名称'**
  String get tagNameHint;

  /// No description provided for @tagManageAction.
  ///
  /// In zh, this message translates to:
  /// **'管理标签'**
  String get tagManageAction;

  /// No description provided for @filterTitle.
  ///
  /// In zh, this message translates to:
  /// **'智能清单'**
  String get filterTitle;

  /// No description provided for @filterEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有智能清单'**
  String get filterEmpty;

  /// No description provided for @filterEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'按清单/标签/优先级/日期组合创建'**
  String get filterEmptyHint;

  /// No description provided for @filterNew.
  ///
  /// In zh, this message translates to:
  /// **'新建智能清单'**
  String get filterNew;

  /// No description provided for @filterEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑智能清单'**
  String get filterEdit;

  /// No description provided for @filterResultEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的任务'**
  String get filterResultEmpty;

  /// No description provided for @filterDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除智能清单'**
  String get filterDeleteTitle;

  /// No description provided for @filterDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」吗？'**
  String filterDeleteConfirm(String name);

  /// No description provided for @filterNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get filterNameLabel;

  /// No description provided for @filterListsLabel.
  ///
  /// In zh, this message translates to:
  /// **'清单（不选=全部）'**
  String get filterListsLabel;

  /// No description provided for @filterTagsLabel.
  ///
  /// In zh, this message translates to:
  /// **'标签（不选=不限）'**
  String get filterTagsLabel;

  /// No description provided for @filterMinPriority.
  ///
  /// In zh, this message translates to:
  /// **'最低优先级'**
  String get filterMinPriority;

  /// No description provided for @filterDateRange.
  ///
  /// In zh, this message translates to:
  /// **'日期范围'**
  String get filterDateRange;

  /// No description provided for @filterSaveTooltip.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get filterSaveTooltip;

  /// No description provided for @filterDeleteTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get filterDeleteTooltip;

  /// No description provided for @filterAllOpen.
  ///
  /// In zh, this message translates to:
  /// **'全部未完成任务'**
  String get filterAllOpen;

  /// No description provided for @filterCountLists.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个清单'**
  String filterCountLists(int count);

  /// No description provided for @filterCountTags.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个标签'**
  String filterCountTags(int count);

  /// No description provided for @filterPriorityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get filterPriorityHigh;

  /// No description provided for @filterPriorityAboveMedium.
  ///
  /// In zh, this message translates to:
  /// **'中以上'**
  String get filterPriorityAboveMedium;

  /// No description provided for @filterPriorityAboveLow.
  ///
  /// In zh, this message translates to:
  /// **'低以上'**
  String get filterPriorityAboveLow;

  /// No description provided for @filterPrioritySuffix.
  ///
  /// In zh, this message translates to:
  /// **'优先级'**
  String get filterPrioritySuffix;

  /// No description provided for @filterDateAny.
  ///
  /// In zh, this message translates to:
  /// **'不限'**
  String get filterDateAny;

  /// No description provided for @filterDateToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get filterDateToday;

  /// No description provided for @filterDateWeek.
  ///
  /// In zh, this message translates to:
  /// **'最近7天'**
  String get filterDateWeek;

  /// No description provided for @filterDateOverdue.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get filterDateOverdue;

  /// No description provided for @filterDateNoDate.
  ///
  /// In zh, this message translates to:
  /// **'无日期'**
  String get filterDateNoDate;

  /// No description provided for @trashTitle.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get trashTitle;

  /// No description provided for @trashEmpty.
  ///
  /// In zh, this message translates to:
  /// **'回收站为空'**
  String get trashEmpty;

  /// No description provided for @trashClearTooltip.
  ///
  /// In zh, this message translates to:
  /// **'清空回收站'**
  String get trashClearTooltip;

  /// No description provided for @trashRestoreTooltip.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get trashRestoreTooltip;

  /// No description provided for @trashPurgeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除'**
  String get trashPurgeTooltip;

  /// No description provided for @trashPurgeTitle.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除'**
  String get trashPurgeTitle;

  /// No description provided for @trashPurgeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除后无法恢复，确定吗？'**
  String get trashPurgeConfirm;

  /// No description provided for @trashClearTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空回收站'**
  String get trashClearTitle;

  /// No description provided for @trashClearConfirm.
  ///
  /// In zh, this message translates to:
  /// **'将彻底删除全部 {count} 个任务，无法恢复。'**
  String trashClearConfirm(int count);

  /// No description provided for @trashDeletedAt.
  ///
  /// In zh, this message translates to:
  /// **'删除于 {date}'**
  String trashDeletedAt(String date);

  /// No description provided for @trashCountTasks.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个任务'**
  String trashCountTasks(int count);

  /// No description provided for @dateNoReminder.
  ///
  /// In zh, this message translates to:
  /// **'不提醒'**
  String get dateNoReminder;

  /// No description provided for @dateAtDue.
  ///
  /// In zh, this message translates to:
  /// **'到期时间'**
  String get dateAtDue;

  /// No description provided for @dateAhead5m.
  ///
  /// In zh, this message translates to:
  /// **'提前 5 分钟'**
  String get dateAhead5m;

  /// No description provided for @dateAhead15m.
  ///
  /// In zh, this message translates to:
  /// **'提前 15 分钟'**
  String get dateAhead15m;

  /// No description provided for @dateAhead30m.
  ///
  /// In zh, this message translates to:
  /// **'提前 30 分钟'**
  String get dateAhead30m;

  /// No description provided for @dateAhead1h.
  ///
  /// In zh, this message translates to:
  /// **'提前 1 小时'**
  String get dateAhead1h;

  /// No description provided for @dateAhead1d.
  ///
  /// In zh, this message translates to:
  /// **'提前 1 天'**
  String get dateAhead1d;

  /// No description provided for @dateCustomTime.
  ///
  /// In zh, this message translates to:
  /// **'自定义时间'**
  String get dateCustomTime;

  /// No description provided for @dateAddDate.
  ///
  /// In zh, this message translates to:
  /// **'添加日期'**
  String get dateAddDate;

  /// No description provided for @dateAddTime.
  ///
  /// In zh, this message translates to:
  /// **'添加时间'**
  String get dateAddTime;

  /// No description provided for @dateRemindMe.
  ///
  /// In zh, this message translates to:
  /// **'提醒我'**
  String get dateRemindMe;

  /// No description provided for @dateBadgeToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get dateBadgeToday;

  /// No description provided for @dateBadgeTomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天'**
  String get dateBadgeTomorrow;

  /// No description provided for @dateBadgeYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get dateBadgeYesterday;

  /// No description provided for @dateBadgeMd.
  ///
  /// In zh, this message translates to:
  /// **'{month}月{day}日'**
  String dateBadgeMd(int month, int day);

  /// No description provided for @dateBadgeYmd.
  ///
  /// In zh, this message translates to:
  /// **'{year}年{month}月{day}日'**
  String dateBadgeYmd(int year, int month, int day);

  /// No description provided for @repeatTitle.
  ///
  /// In zh, this message translates to:
  /// **'重复'**
  String get repeatTitle;

  /// No description provided for @repeatNone.
  ///
  /// In zh, this message translates to:
  /// **'不重复'**
  String get repeatNone;

  /// No description provided for @repeatCustomWeekly.
  ///
  /// In zh, this message translates to:
  /// **'自定义每周…'**
  String get repeatCustomWeekly;

  /// No description provided for @repeatEveryDay.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get repeatEveryDay;

  /// No description provided for @repeatEveryNDays.
  ///
  /// In zh, this message translates to:
  /// **'每 {count} 天'**
  String repeatEveryNDays(int count);

  /// No description provided for @repeatWorkdays.
  ///
  /// In zh, this message translates to:
  /// **'工作日'**
  String get repeatWorkdays;

  /// No description provided for @repeatEveryWeek.
  ///
  /// In zh, this message translates to:
  /// **'每周'**
  String get repeatEveryWeek;

  /// No description provided for @repeatEveryNWeeks.
  ///
  /// In zh, this message translates to:
  /// **'每 {count} 周'**
  String repeatEveryNWeeks(int count);

  /// No description provided for @repeatEveryMonth.
  ///
  /// In zh, this message translates to:
  /// **'每月'**
  String get repeatEveryMonth;

  /// No description provided for @repeatEveryNMonths.
  ///
  /// In zh, this message translates to:
  /// **'每 {count} 月'**
  String repeatEveryNMonths(int count);

  /// No description provided for @repeatEveryYear.
  ///
  /// In zh, this message translates to:
  /// **'每年'**
  String get repeatEveryYear;

  /// No description provided for @repeatEveryNYears.
  ///
  /// In zh, this message translates to:
  /// **'每 {count} 年'**
  String repeatEveryNYears(int count);

  /// No description provided for @repeatPerWeekday.
  ///
  /// In zh, this message translates to:
  /// **'周{day}'**
  String repeatPerWeekday(String day);

  /// No description provided for @repeatWeekdaysJoin.
  ///
  /// In zh, this message translates to:
  /// **'{days}'**
  String repeatWeekdaysJoin(String days);

  /// No description provided for @repeatWeeklyDays.
  ///
  /// In zh, this message translates to:
  /// **'每{days}'**
  String repeatWeeklyDays(String days);

  /// No description provided for @repeatWeeklyDaysInterval.
  ///
  /// In zh, this message translates to:
  /// **'每{days} · 每 {count} 周'**
  String repeatWeeklyDaysInterval(String days, int count);

  /// No description provided for @priorityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get priorityHigh;

  /// No description provided for @priorityMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get priorityMedium;

  /// No description provided for @priorityLow.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get priorityLow;

  /// No description provided for @quickAddHint.
  ///
  /// In zh, this message translates to:
  /// **'输入任务，如“明天下午3点开会 #工作 !高”'**
  String get quickAddHint;

  /// No description provided for @quickAddAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加「{title}」'**
  String quickAddAdded(String title);

  /// No description provided for @quickAddListLabel.
  ///
  /// In zh, this message translates to:
  /// **'清单'**
  String get quickAddListLabel;

  /// No description provided for @quickAddTagPrefix.
  ///
  /// In zh, this message translates to:
  /// **'#{name}'**
  String quickAddTagPrefix(String name);

  /// No description provided for @quickAddConfirm.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get quickAddConfirm;

  /// No description provided for @remindersTitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒时间'**
  String get remindersTitle;

  /// No description provided for @remindersAddTooltip.
  ///
  /// In zh, this message translates to:
  /// **'添加提醒'**
  String get remindersAddTooltip;

  /// No description provided for @remindersEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无，点 + 添加指定日期时间的提醒'**
  String get remindersEmpty;

  /// No description provided for @remindersPickDateHelp.
  ///
  /// In zh, this message translates to:
  /// **'选择提醒日期'**
  String get remindersPickDateHelp;

  /// No description provided for @remindersPickTimeHelp.
  ///
  /// In zh, this message translates to:
  /// **'选择提醒时间'**
  String get remindersPickTimeHelp;

  /// No description provided for @remindersFormatMd.
  ///
  /// In zh, this message translates to:
  /// **'MM月dd日 HH:mm'**
  String get remindersFormatMd;

  /// No description provided for @multiDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除 {count} 个任务'**
  String multiDeleteTitle(int count);

  /// No description provided for @multiDeleteRestorable.
  ///
  /// In zh, this message translates to:
  /// **'删除后可在回收站恢复。'**
  String get multiDeleteRestorable;

  /// No description provided for @multiMoveTo.
  ///
  /// In zh, this message translates to:
  /// **'移动到清单'**
  String get multiMoveTo;

  /// No description provided for @multiPickDate.
  ///
  /// In zh, this message translates to:
  /// **'选择日期…'**
  String get multiPickDate;

  /// No description provided for @multiCompletedCount.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {count}'**
  String multiCompletedCount(int count);

  /// No description provided for @multiSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get multiSelectAll;

  /// No description provided for @multiCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消多选'**
  String get multiCancel;

  /// No description provided for @multiSetDate.
  ///
  /// In zh, this message translates to:
  /// **'设置日期'**
  String get multiSetDate;

  /// No description provided for @emptyDefaultTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有任务'**
  String get emptyDefaultTitle;

  /// No description provided for @habitsTitle.
  ///
  /// In zh, this message translates to:
  /// **'习惯'**
  String get habitsTitle;

  /// No description provided for @habitArchivedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已归档习惯'**
  String get habitArchivedTitle;

  /// No description provided for @habitBackToList.
  ///
  /// In zh, this message translates to:
  /// **'返回习惯列表'**
  String get habitBackToList;

  /// No description provided for @habitViewArchived.
  ///
  /// In zh, this message translates to:
  /// **'查看已归档'**
  String get habitViewArchived;

  /// No description provided for @habitArchivedEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有已归档的习惯'**
  String get habitArchivedEmpty;

  /// No description provided for @habitEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有习惯'**
  String get habitEmpty;

  /// No description provided for @habitArchivedHint.
  ///
  /// In zh, this message translates to:
  /// **'长按习惯卡片即可归档'**
  String get habitArchivedHint;

  /// No description provided for @habitCreateFirst.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角 + 创建第一个习惯'**
  String get habitCreateFirst;

  /// No description provided for @habitArchivedTip.
  ///
  /// In zh, this message translates to:
  /// **'通过卡片右侧菜单可恢复或删除习惯'**
  String get habitArchivedTip;

  /// No description provided for @habitCardTip.
  ///
  /// In zh, this message translates to:
  /// **'长按卡片或使用卡片右侧菜单：归档 / 删除'**
  String get habitCardTip;

  /// No description provided for @habitNew.
  ///
  /// In zh, this message translates to:
  /// **'新建习惯'**
  String get habitNew;

  /// No description provided for @habitEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑习惯'**
  String get habitEdit;

  /// No description provided for @habitNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'习惯名称'**
  String get habitNameLabel;

  /// No description provided for @habitColor.
  ///
  /// In zh, this message translates to:
  /// **'颜色'**
  String get habitColor;

  /// No description provided for @habitWeeklyTarget.
  ///
  /// In zh, this message translates to:
  /// **'每周目标'**
  String get habitWeeklyTarget;

  /// No description provided for @habitEveryDay.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get habitEveryDay;

  /// No description provided for @habitDaysPerWeek.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天/周'**
  String habitDaysPerWeek(int count);

  /// No description provided for @habitStreakDays.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天'**
  String habitStreakDays(int count);

  /// No description provided for @habitWeekProgress.
  ///
  /// In zh, this message translates to:
  /// **'本周 {count}/{target}'**
  String habitWeekProgress(int count, int target);

  /// No description provided for @habitMoreTooltip.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get habitMoreTooltip;

  /// No description provided for @habitDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」吗？其打卡记录将一并隐藏，无法在界面恢复。'**
  String habitDeleteConfirm(String name);

  /// No description provided for @habitDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除习惯'**
  String get habitDeleteTitle;

  /// No description provided for @habitArchive.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get habitArchive;

  /// No description provided for @habitRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get habitRestore;

  /// No description provided for @habitDeleted.
  ///
  /// In zh, this message translates to:
  /// **'（已删除）'**
  String get habitDeleted;

  /// No description provided for @focusTitle.
  ///
  /// In zh, this message translates to:
  /// **'番茄专注'**
  String get focusTitle;

  /// No description provided for @focusStart.
  ///
  /// In zh, this message translates to:
  /// **'开始专注'**
  String get focusStart;

  /// No description provided for @focusGiveUp.
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get focusGiveUp;

  /// No description provided for @focusPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get focusPause;

  /// No description provided for @focusResume.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get focusResume;

  /// No description provided for @focusIdle.
  ///
  /// In zh, this message translates to:
  /// **'准备就绪'**
  String get focusIdle;

  /// No description provided for @focusRunning.
  ///
  /// In zh, this message translates to:
  /// **'专注中'**
  String get focusRunning;

  /// No description provided for @focusBreak.
  ///
  /// In zh, this message translates to:
  /// **'休息中'**
  String get focusBreak;

  /// No description provided for @focusEndBreak.
  ///
  /// In zh, this message translates to:
  /// **'休息结束'**
  String get focusEndBreak;

  /// No description provided for @focusEndFocus.
  ///
  /// In zh, this message translates to:
  /// **'专注完成'**
  String get focusEndFocus;

  /// No description provided for @focusEndBreakBody.
  ///
  /// In zh, this message translates to:
  /// **'休息结束，继续加油！'**
  String get focusEndBreakBody;

  /// No description provided for @focusEndFocusBody.
  ///
  /// In zh, this message translates to:
  /// **'番茄结束，休息一下吧 🎉'**
  String get focusEndFocusBody;

  /// No description provided for @focusCompleted.
  ///
  /// In zh, this message translates to:
  /// **'🍅 第 {count} 个番茄完成！'**
  String focusCompleted(int count);

  /// No description provided for @focusSummary.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {count} 个番茄 · 今日统计见下方'**
  String focusSummary(int count);

  /// No description provided for @focusTaskLabel.
  ///
  /// In zh, this message translates to:
  /// **'关联任务（可选）'**
  String get focusTaskLabel;

  /// No description provided for @focusNoTask.
  ///
  /// In zh, this message translates to:
  /// **'不关联'**
  String get focusNoTask;

  /// No description provided for @focusTodayStats.
  ///
  /// In zh, this message translates to:
  /// **'今日 {pomodoros} 个番茄 · 累计专注 {minutes} 分钟'**
  String focusTodayStats(int pomodoros, int minutes);

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsSyncSection.
  ///
  /// In zh, this message translates to:
  /// **'坚果云同步'**
  String get settingsSyncSection;

  /// No description provided for @settingsWebdavUrl.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 地址'**
  String get settingsWebdavUrl;

  /// No description provided for @settingsWebdavHint.
  ///
  /// In zh, this message translates to:
  /// **'https://dav.jianguoyun.com/dav/'**
  String get settingsWebdavHint;

  /// No description provided for @settingsAccount.
  ///
  /// In zh, this message translates to:
  /// **'账号（坚果云邮箱）'**
  String get settingsAccount;

  /// No description provided for @settingsAppPassword.
  ///
  /// In zh, this message translates to:
  /// **'应用密码'**
  String get settingsAppPassword;

  /// No description provided for @settingsTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get settingsTestConnection;

  /// No description provided for @settingsSyncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get settingsSyncNow;

  /// No description provided for @settingsIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'请填写完整的账号信息'**
  String get settingsIncomplete;

  /// No description provided for @settingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get settingsSaved;

  /// No description provided for @settingsTesting.
  ///
  /// In zh, this message translates to:
  /// **'测试中…'**
  String get settingsTesting;

  /// No description provided for @settingsConnected.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get settingsConnected;

  /// No description provided for @settingsConnectFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{error}'**
  String settingsConnectFailed(String error);

  /// No description provided for @settingsSyncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中…'**
  String get settingsSyncing;

  /// No description provided for @settingsUploaded.
  ///
  /// In zh, this message translates to:
  /// **'已上传'**
  String get settingsUploaded;

  /// No description provided for @settingsDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'已下载'**
  String get settingsDownloaded;

  /// No description provided for @settingsMerged.
  ///
  /// In zh, this message translates to:
  /// **'已合并'**
  String get settingsMerged;

  /// No description provided for @settingsNothingToSync.
  ///
  /// In zh, this message translates to:
  /// **'无需同步'**
  String get settingsNothingToSync;

  /// No description provided for @settingsSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败：{error}'**
  String settingsSyncFailed(String error);

  /// No description provided for @settingsNeverSynced.
  ///
  /// In zh, this message translates to:
  /// **'尚未同步'**
  String get settingsNeverSynced;

  /// No description provided for @settingsLastSync.
  ///
  /// In zh, this message translates to:
  /// **'上次同步：{time}'**
  String settingsLastSync(String time);

  /// No description provided for @settingsPasswordTip.
  ///
  /// In zh, this message translates to:
  /// **'提示：坚果云「应用密码」在坚果云网页版 → 账户信息 → 安全选项 中生成，不要直接使用登录密码。'**
  String get settingsPasswordTip;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsThemeDark;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version} · 本地优先 · 坚果云备份同步'**
  String settingsAboutSubtitle(String version);

  /// No description provided for @settingsBackupSection.
  ///
  /// In zh, this message translates to:
  /// **'本地备份'**
  String get settingsBackupSection;

  /// No description provided for @settingsBackupLast.
  ///
  /// In zh, this message translates to:
  /// **'上次备份：{time}（保留最近 7 份，每日自动）'**
  String settingsBackupLast(String time);

  /// No description provided for @settingsBackupNever.
  ///
  /// In zh, this message translates to:
  /// **'尚未备份'**
  String get settingsBackupNever;

  /// No description provided for @settingsBackupNow.
  ///
  /// In zh, this message translates to:
  /// **'立即备份'**
  String get settingsBackupNow;

  /// No description provided for @settingsBackupBusy.
  ///
  /// In zh, this message translates to:
  /// **'备份中…'**
  String get settingsBackupBusy;

  /// No description provided for @settingsBackupSuccess.
  ///
  /// In zh, this message translates to:
  /// **'备份成功'**
  String get settingsBackupSuccess;

  /// No description provided for @settingsBackupFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份失败，请查看日志'**
  String get settingsBackupFailed;

  /// No description provided for @desktopMenuApp.
  ///
  /// In zh, this message translates to:
  /// **'滴答清单Pro'**
  String get desktopMenuApp;

  /// No description provided for @desktopMenuAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于滴答清单Pro'**
  String get desktopMenuAbout;

  /// No description provided for @desktopMenuSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置…'**
  String get desktopMenuSettings;

  /// No description provided for @desktopMenuQuit.
  ///
  /// In zh, this message translates to:
  /// **'退出滴答清单Pro'**
  String get desktopMenuQuit;

  /// No description provided for @desktopMenuFile.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get desktopMenuFile;

  /// No description provided for @desktopMenuNewTask.
  ///
  /// In zh, this message translates to:
  /// **'新建任务…'**
  String get desktopMenuNewTask;

  /// No description provided for @desktopMenuSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索…'**
  String get desktopMenuSearch;

  /// No description provided for @desktopMenuView.
  ///
  /// In zh, this message translates to:
  /// **'视图'**
  String get desktopMenuView;

  /// No description provided for @desktopMenuHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助'**
  String get desktopMenuHelp;

  /// No description provided for @desktopMenuShortcuts.
  ///
  /// In zh, this message translates to:
  /// **'键盘快捷键'**
  String get desktopMenuShortcuts;

  /// No description provided for @desktopNewTask.
  ///
  /// In zh, this message translates to:
  /// **'新建任务'**
  String get desktopNewTask;

  /// No description provided for @desktopSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get desktopSearch;

  /// No description provided for @desktopSettingsCmd.
  ///
  /// In zh, this message translates to:
  /// **'设置 ⌘,'**
  String get desktopSettingsCmd;

  /// No description provided for @desktopShortcutsTitle.
  ///
  /// In zh, this message translates to:
  /// **'键盘快捷键'**
  String get desktopShortcutsTitle;

  /// No description provided for @desktopShortcutQuit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get desktopShortcutQuit;

  /// No description provided for @desktopSidebarFilters.
  ///
  /// In zh, this message translates to:
  /// **'智能清单'**
  String get desktopSidebarFilters;

  /// No description provided for @notifOpenTask.
  ///
  /// In zh, this message translates to:
  /// **'点击查看任务详情'**
  String get notifOpenTask;

  /// No description provided for @notifTaskChannel.
  ///
  /// In zh, this message translates to:
  /// **'任务提醒'**
  String get notifTaskChannel;

  /// No description provided for @notifTaskChannelDesc.
  ///
  /// In zh, this message translates to:
  /// **'任务到期/提醒通知'**
  String get notifTaskChannelDesc;

  /// No description provided for @notifPomodoroChannel.
  ///
  /// In zh, this message translates to:
  /// **'番茄专注'**
  String get notifPomodoroChannel;

  /// No description provided for @notifPomodoroChannelDesc.
  ///
  /// In zh, this message translates to:
  /// **'专注/休息阶段切换提醒'**
  String get notifPomodoroChannelDesc;

  /// No description provided for @emptyStateDefaultTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有任务'**
  String get emptyStateDefaultTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
