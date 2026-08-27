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
  Timer? _timer;
  DateTime? _segmentStart;
  _Phase _phase = _Phase.idle;
  bool _running = false;
  int _remaining = FocusScreen.focusMinutes * 60;
  int _totalSeconds = FocusScreen.focusMinutes * 60;
  int _finishedFocusCount = 0; // 本轮次内完成番茄数（决定长短休）
  Task? _selectedTask;
  // 缓存查询结果：避免计时期间每秒 build 重建 DB 查询
  late final Future<List<Task>> _taskFuture =
      ref.read(taskRepoProvider).queryAll(includeCompleted: false);
  Future<List<int>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<List<int>> _loadStats() => Future.wait([
        ref.read(pomodoroRepoProvider).todayCount(),
        ref.read(pomodoroRepoProvider).todayMinutes(),
      ]);

  /// 完成一个会话后刷新今日统计。
  void _refreshStats() {
    setState(() => _statsFuture = _loadStats());
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      _remaining = _totalSeconds;
      _segmentStart = DateTime.now();
      _running = true;
    });
    _scheduleTick();
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
      _remaining = _totalSeconds;
      _segmentStart = DateTime.now();
      _running = true;
    });
    _scheduleTick();
    _scheduleEndNotification();
  }

  /// 按当前剩余时间调度系统级结束通知（绝对时间，由 OS 触发）。
  ///
  /// 用系统调度而非 Future.delayed：后者在移动端挂起后不执行导致
  /// 后台到点不通知，且暂停后 stale 回调会在错误时刻弹通知。
  void _scheduleEndNotification() {
    final l10n = AppLocalizations.of(context);
    ref.read(notificationServiceProvider).schedulePomodoroEnd(
          title: _endTitle(l10n),
          body: _endBody(l10n),
          at: DateTime.now().add(Duration(seconds: _remaining)),
        );
  }

  void _scheduleTick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!_running || _segmentStart == null) return;
    final elapsed =
        DateTime.now().difference(_segmentStart!).inSeconds;
    final remain = _totalSeconds - elapsed;
    if (remain <= 0) {
      _onSegmentEnd();
    } else {
      setState(() => _remaining = remain);
    }
  }

  Future<void> _onSegmentEnd() async {
    _timer?.cancel();
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
    _timer?.cancel();
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
      _remaining = FocusScreen.focusMinutes * 60;
      _totalSeconds = _remaining;
      _segmentStart = null;
    });
  }

  Future<void> _pauseResume() async {
    if (_running) {
      // 暂停：冻结剩余时间，保留原总时长（进度环位置不变）
      _timer?.cancel();
      final elapsed = DateTime.now().difference(_segmentStart!).inSeconds;
      setState(() {
        _remaining =
            (_totalSeconds - elapsed).clamp(0, _totalSeconds);
        _running = false;
      });
      // 取消已调度的结束通知，恢复时按剩余时间重新调度
      ref.read(notificationServiceProvider).cancelPomodoroNotification();
    } else {
      setState(() => _running = true);
      // 按剩余时间回推段起点，保持真实时间差计算正确
      _segmentStart = DateTime.now()
          .subtract(Duration(seconds: _totalSeconds - _remaining));
      _scheduleTick();
      _scheduleEndNotification();
    }
  }

  String get _timeLabel {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: _totalSeconds == 0
                          ? 0
                          : 1 - _remaining / _totalSeconds,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: _phase == _Phase.breakTime
                          ? const Color(0xFF2F9D45)
                          : const Color(0xFFE04C4C),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_timeLabel,
                          style: theme.textTheme.displayMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (_phase == _Phase.focus && _selectedTask != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _selectedTask!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
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
      child: FutureBuilder<List<int>>(
        future: _statsFuture,
        builder: (_, snap) {
          final data = snap.data ?? const [0, 0];
          return Text(l10n.focusTodayStats(data[0], data[1]),
              style: theme.textTheme.labelLarge);
        },
      ),
    );
  }
}
