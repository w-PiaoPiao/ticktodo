import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/data/models/task.dart';

/// 快速添加解析结果。
class ParsedDraft {
  const ParsedDraft({
    required this.title,
    this.dueDate,
    this.dueTime,
    this.priority = TaskPriority.none,
    this.tagNames = const [],
  });

  final String title;
  final String? dueDate; // yyyy-MM-dd
  final String? dueTime; // HH:mm
  final TaskPriority priority;
  final List<String> tagNames;
}

/// 中文自然语言快速解析：日期、时间、优先级、标签。
///
/// 规则：
/// - 标签：`#标签名`（含全角＃）
/// - 优先级：`!高 / ！中 / ！低`
/// - 日期：今天/明天/后天/大后天/周X/下周X/X月X日/yyyy-MM-dd
/// - 时间：下午3点/晚上11点半/9:00 等
class QuickAddParser {
  QuickAddParser._();

  static final _tagRe = RegExp(r'[#＃]([\u4e00-\u9fa5A-Za-z0-9_-]+)');
  static final _prioRe = RegExp(r'[!！]\s*([高中低])');
  static final _relTimeRe =
      RegExp(r'(凌晨|早上|上午|中午|下午|傍晚|晚上)\s*(\d{1,2})[点时:：]\s*(半|\d{1,2}分?)?');
  static final _absTimeRe = RegExp(r'\b(\d{1,2}):([0-5]\d)\b');
  static final _isoDateRe = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
  static final _mdDateRe = RegExp(r'(\d{1,2})月(\d{1,2})[日号]');
  static final _weekRe = RegExp(r'[下本]?周([一二三四五六日天])(?!期)');
  static const _wordDayRe = r'大后天|后天|明早|明天|今晚|今天';
  static final _wsRe = RegExp(r'\s+');

  static const _wdMap = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7};

  static ParsedDraft parse(String input, {DateTime? now}) {
    final n = now ?? DateTime.now();
    var text = input.trim();
    if (text.isEmpty) return ParsedDraft(title: '');

    // 1) 标签
    final tagNames = _tagRe.allMatches(text).map((m) => m.group(1)!).toList();
    text = text.replaceAll(_tagRe, ' ');

    // 2) 优先级
    var priority = TaskPriority.none;
    final pm = _prioRe.firstMatch(text);
    if (pm != null) {
      priority = switch (pm.group(1)) {
        '高' => TaskPriority.high,
        '中' => TaskPriority.medium,
        _ => TaskPriority.low,
      };
      text = text.replaceRange(pm.start, pm.end, ' ');
    }

    // 3) 日期（ISO → X月X日 → 周X → 相对词，取第一个命中的类型）
    String? dueDate;
    final iso = _isoDateRe.firstMatch(text);
    final md = _mdDateRe.firstMatch(text);
    final wk = _weekRe.firstMatch(text);
    final wd = RegExp(_wordDayRe).firstMatch(text);
    if (iso != null) {
      dueDate =
          '${iso.group(1)}-${iso.group(2)!.padLeft(2, '0')}-${iso.group(3)!.padLeft(2, '0')}';
      text = text.replaceRange(iso.start, iso.end, ' ');
    } else if (md != null) {
      dueDate = _mdToIso(n, int.parse(md.group(1)!), int.parse(md.group(2)!));
      text = text.replaceRange(md.start, md.end, ' ');
    } else if (wk != null) {
      dueDate = _nextWeekday(n, _wdMap[wk.group(1)!]!);
      text = text.replaceRange(wk.start, wk.end, ' ');
    } else if (wd != null) {
      dueDate = _wordToIso(wd.group(0)!, n);
      text = text.replaceRange(wd.start, wd.end, ' ');
    }

    // 4) 时间（相对时段词 > HH:mm）
    String? dueTime;
    final rt = _relTimeRe.firstMatch(text);
    final at = _absTimeRe.firstMatch(text);
    if (rt != null) {
      final rawHour = int.parse(rt.group(2)!);
      if (rawHour <= 23) {
        final hour = _to24h(rt.group(1)!, rawHour);
        final minute = _parseMinute(rt.group(3));
        dueTime =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        text = text.replaceRange(rt.start, rt.end, ' ');
      }
    } else if (at != null) {
      final hour = int.tryParse(at.group(1)!) ?? -1;
      if (hour >= 0 && hour <= 23) {
        dueTime =
            '${hour.toString().padLeft(2, '0')}:${at.group(2)!.padLeft(2, '0')}';
        text = text.replaceRange(at.start, at.end, ' ');
      }
    }

    final title = text.replaceAll(_wsRe, ' ').trim();
    return ParsedDraft(
      title: title,
      dueDate: dueDate,
      dueTime: dueTime,
      priority: priority,
      tagNames: tagNames,
    );
  }

  static int _to24h(String period, int hour) {
    const evening = {'下午', '傍晚', '晚上'};
    const morning = {'凌晨', '早上', '上午'};
    if (evening.contains(period) && hour < 12) return hour + 12;
    if (morning.contains(period) && hour == 12) return 0;
    if (period == '中午' && hour < 6) return hour + 12;
    return hour;
  }

  static int _parseMinute(String? g) {
    if (g == null || g.isEmpty) return 0;
    if (g == '半') return 30;
    return int.tryParse(g.replaceAll('分', '')) ?? 0;
  }

  /// X月X日：今年的该日期，若已过则取明年。
  static String _mdToIso(DateTime n, int month, int day) {
    var y = n.year;
    if (DateTime(y, month, day).isBefore(DateTime(n.year, n.month, n.day))) {
      y++;
    }
    return DateUtilsEx.formatDate(DateTime(y, month, day));
  }

  /// 下一个星期 target（不含今天）。
  static String _nextWeekday(DateTime n, int target) {
    final today = DateTime(n.year, n.month, n.day);
    var diff = target - today.weekday;
    if (diff <= 0) diff += 7;
    return DateUtilsEx.formatDate(today.add(Duration(days: diff)));
  }

  static String _wordToIso(String word, DateTime n) {
    const offsets = {'今天': 0, '今晚': 0, '明早': 1, '明天': 1, '后天': 2, '大后天': 3};
    final today = DateTime(n.year, n.month, n.day);
    return DateUtilsEx.formatDate(today.add(Duration(days: offsets[word] ?? 0)));
  }
}
