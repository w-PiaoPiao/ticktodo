import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/habit.dart' show PomodoroSession;
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

/// 番茄专注：25 分钟专注 + 5 分钟短休，每 4 轮一次 15 分钟长休。
///
/// 剩余时间基于 startedAt 真实时间差计算，App 切后台回来时间依然准确。
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  static const int focusMinutes = 25;
  static const int shortBreakMinutes = 5;
  static const int longBreakMinutes = 15;

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

enum _Phase { idle, focus, breakTime }

class _FocusScreenState extends ConsumerState<FocusScreen> {
  DateTime? _segmentStart;
  _Phase _phase = _Phase.idle;
  bool _running = false;
  // 倒计时以"结束时刻"表达：圆环组件内部按真实时间差刷新，切后台依然准确
  DateTime? _endsAt;
  // 暂停/未开始时圆环显示的剩余秒数
  int _frozenRemaining = FocusScreen.focusMinutes * 60;
  int _totalSeconds = FocusScreen.focusMinutes * 60;
  int _segment = 0; // 段编号：每开始新的一段 +1，防止同一段重复触发完成回调
  int _finishedFocusCount = 0; // 本轮次内完成番茄数（决定长短休）
  Task? _selectedTask;
  // 缓存查询结果：避免计时期间每秒 build 重建 DB 查询
  late final Future<List<Task>> _taskFuture =
      ref.read(taskRepoProvider).queryAll(includeCompleted: false);
  Future<(int, int)>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<(int, int)> _loadStats() =>
      ref.read(pomodoroRepoProvider).todayStats();

  /// 完成一个会话后刷新今日统计。
  void _refreshStats() {
    setState(() => _statsFuture = _loadStats());
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _endTitle(AppLocalizations l10n) =>
      _phase == _Phase.breakTime ? l10n.focusEndBreak : l10n.focusEndFocus;

  String _endBody(AppLocalizations l10n) => _phase == _Phase.breakTime
      ? l10n.focusEndBreakBody
      : l10n.focusEndFocusBody;

  void _startFocus() {
    setState(() {
      _phase = _Phase.focus;
      _totalSeconds = FocusScreen.focusMinutes * 60;
      _frozenRemaining = _totalSeconds;
      _segmentStart = DateTime.now();
      _endsAt = _segmentStart!.add(Duration(seconds: _totalSeconds));
      _segment++;
      _running = true;
    });
    _scheduleEndNotification();
  }

  void _startBreak() {
    final long = _finishedFocusCount > 0 && _finishedFocusCount % 4 == 0;
    final minutes = long
        ? FocusScreen.longBreakMinutes
        : FocusScreen.shortBreakMinutes;
    setState(() {
      _phase = _Phase.breakTime;
      _totalSeconds = minutes * 60;
      _frozenRemaining = _totalSeconds;
      _segmentStart = DateTime.now();
      _endsAt = _segmentStart!.add(Duration(seconds: _totalSeconds));
      _segment++;
      _running = true;
    });
    _scheduleEndNotification();
  }

  /// 按当前剩余时间调度系统级结束通知（绝对时间，由 OS 触发）。
  ///
  /// 用系统调度而非 Future.delayed：后者在移动端挂起后不执行导致
  /// 后台到点不通知，且暂停后 stale 回调会在错误时刻弹通知。
  void _scheduleEndNotification() {
    final remain =
        _endsAt!.difference(DateTime.now()).inSeconds.clamp(0, _totalSeconds);
    final l10n = AppLocalizations.of(context);
    ref.read(notificationServiceProvider).schedulePomodoroEnd(
          title: _endTitle(l10n),
          body: _endBody(l10n),
          at: DateTime.now().add(Duration(seconds: remain)),
        );
  }

  Future<void> _onSegmentEnd() async {
    if (_phase == _Phase.focus) {
      // 记录完成的番茄
      await ref.read(pomodoroRepoProvider).saveSession(PomodoroSession(
            taskId: _selectedTask?.id,
            taskTitle: _selectedTask?.title ?? '',
            startedAt: _segmentStart!.millisecondsSinceEpoch,
            durationMinutes: FocusScreen.focusMinutes,
            completed: true,
          ));
      bumpMutation(ref);
      setState(() {
        _finishedFocusCount++;
        _running = false;
      });
      _refreshStats();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.focusCompleted(_finishedFocusCount)),
          duration: const Duration(seconds: 3),
        ));
      }
      _startBreak();
    } else {
      // 休息结束自动进入下一轮专注
      setState(() => _running = false);
      _startFocus();
    }
  }

  Future<void> _giveUp() async {
    await ref.read(notificationServiceProvider).cancelPomodoroNotification();
    if (_phase == _Phase.focus && _segmentStart != null) {
      final elapsedMin =
          DateTime.now().difference(_segmentStart!).inMinutes;
      if (elapsedMin >= 1) {
        // 超过 1 分钟记录为放弃会话（数据留痕）
        await ref.read(pomodoroRepoProvider).saveSession(PomodoroSession(
              taskId: _selectedTask?.id,
              taskTitle: _selectedTask?.title ?? '',
              startedAt: _segmentStart!.millisecondsSinceEpoch,
              durationMinutes: elapsedMin,
              completed: false,
            ));
        bumpMutation(ref);
        _refreshStats();
      }
    }
    setState(() {
      _phase = _Phase.idle;
      _running = false;
      _frozenRemaining = FocusScreen.focusMinutes * 60;
      _totalSeconds = _frozenRemaining;
      _endsAt = null;
      _segmentStart = null;
      _segment++;
    });
  }

  Future<void> _pauseResume() async {
    if (_running) {
      // 暂停：冻结剩余时间，保留原总时长（进度环位置不变）
      final remain = _endsAt!
          .difference(DateTime.now())
          .inSeconds
          .clamp(0, _totalSeconds);
      setState(() {
        _frozenRemaining = remain;
        _endsAt = null;
        _running = false;
      });
      // 取消已调度的结束通知，恢复时按剩余时间重新调度
      ref.read(notificationServiceProvider).cancelPomodoroNotification();
    } else {
      setState(() {
        _running = true;
        _endsAt = DateTime.now().add(Duration(seconds: _frozenRemaining));
      });
      _scheduleEndNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.focusTitle)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _phaseLabel(theme),
            const SizedBox(height: 20),
            _CountdownRing(
              totalSeconds: _totalSeconds,
              running: _running,
              endsAt: _endsAt,
              frozenRemaining: _frozenRemaining,
              isBreak: _phase == _Phase.breakTime,
              segment: _segment,
              taskTitle:
                  _phase == _Phase.focus ? _selectedTask?.title : null,
              onCompleted: _onSegmentEnd,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_phase == _Phase.idle)
                  FilledButton.icon(
                    onPressed: _startFocus,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.focusStart),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _running ? _pauseResume : _pauseResume,
                    icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                    label: Text(_running ? l10n.focusPause : l10n.focusResume),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _giveUp,
                    icon: const Icon(Icons.stop),
                    label: Text(l10n.focusGiveUp),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (_phase == _Phase.idle) _taskPicker(theme),
            const SizedBox(height: 8),
            Text(l10n.focusSummary(_finishedFocusCount),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            _todayStats(theme),
          ],
        ),
      ),
    );
  }

  Widget _phaseLabel(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final text = switch (_phase) {
      _Phase.idle => l10n.focusIdle,
      _Phase.focus => l10n.focusRunning,
      _Phase.breakTime => l10n.focusBreak,
    };
    return Chip(
      label: Text(text),
      backgroundColor: _phase == _Phase.breakTime
          ? const Color(0x152F9D45)
          : _phase == _Phase.focus
              ? const Color(0x15E04C4C)
              : null,
    );
  }

  Widget _taskPicker(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: FutureBuilder<List<Task>>(
        future: _taskFuture,
        builder: (_, snap) {
          final tasks = snap.data ?? const <Task>[];
          return DropdownButtonFormField<Task?>(
            initialValue: _selectedTask,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.focusTaskLabel,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _selectedTask == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _selectedTask = null),
                    ),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.focusNoTask)),
              for (final t in tasks.take(50))
                DropdownMenuItem(
                    value: t,
                    child: Text(t.title.isEmpty ? l10n.untitledTask : t.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _selectedTask = v),
          );
        },
      ),
    );
  }

  Widget _todayStats(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: FutureBuilder<(int, int)>(
        future: _statsFuture,
        builder: (_, snap) {
          final data = snap.data ?? (0, 0);
          return Text(l10n.focusTodayStats(data.$1, data.$2),
              style: theme.textTheme.labelLarge);
        },
      ),
    );
  }
}

/// 倒计时圆环：内部持有 1s ticker，每秒只重建自身，
/// 不再拖动整屏（含按钮/统计）每秒 setState 重建。
class _CountdownRing extends StatefulWidget {
  const _CountdownRing({
    required this.totalSeconds,
    required this.running,
    required this.endsAt,
    required this.frozenRemaining,
    required this.isBreak,
    required this.segment,
    required this.taskTitle,
    required this.onCompleted,
  });

  final int totalSeconds;
  final bool running;
  final DateTime? endsAt;
  final int frozenRemaining;
  final bool isBreak;

  /// 段编号：同一秒内若剩余已到 0，只触发一次完成回调。
  final int segment;
  final String? taskTitle;
  final VoidCallback onCompleted;

  @override
  State<_CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<_CountdownRing> {
  Timer? _timer;
  int _firedSegment = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || !widget.running) return;
    setState(() {}); // 只重建圆环与时间文本
    if (_remaining <= 0 && _firedSegment != widget.segment) {
      _firedSegment = widget.segment;
      widget.onCompleted();
    }
  }

  /// 剩余秒数：运行中按真实时间差计算（切后台回来依然准确），暂停显示冻结值。
  int get _remaining {
    if (!widget.running || widget.endsAt == null) return widget.frozenRemaining;
    final r = widget.endsAt!.difference(DateTime.now()).inSeconds;
    return r.clamp(0, widget.totalSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _remaining;
    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: widget.totalSeconds == 0
                  ? 0
                  : 1 - remaining / widget.totalSeconds,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: widget.isBreak
                  ? const Color(0xFF2F9D45)
                  : const Color(0xFFE04C4C),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$m:$s',
                  style: theme.textTheme.displayMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (!widget.isBreak && widget.taskTitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    widget.taskTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
