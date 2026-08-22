import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/habit.dart' show PomodoroSession;
import 'package:ticktodo/data/models/task.dart';

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startFocus() {
    setState(() {
      _phase = _Phase.focus;
      _totalSeconds = FocusScreen.focusMinutes * 60;
      _remaining = _totalSeconds;
      _segmentStart = DateTime.now();
      _running = true;
    });
    _scheduleTick();
    _notifyAtEnd('专注完成', '番茄结束，休息一下吧 🎉');
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
    _notifyAtEnd('休息结束', long ? '长休结束，开始新一轮专注！' : '休息结束，继续加油！');
  }

  /// 段结束时发即时通知（App 在后台也能收到）
  void _notifyAtEnd(String title, String body) {
    final secondsLeft = _totalSeconds;
    Future.delayed(Duration(seconds: secondsLeft), () async {
      if (!mounted || !_running) return;
      await ref
          .read(notificationServiceProvider)
          .showNow(title: title, body: body, id: 900000);
    });
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🍅 第 $_finishedFocusCount 个番茄完成！'),
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
      // 暂停：记录暂停时刻的剩余
      _timer?.cancel();
      final elapsed = DateTime.now().difference(_segmentStart!).inSeconds;
      setState(() {
        _remaining = _totalSeconds - elapsed;
        _running = false;
      });
      // 用剩余重设起点，恢复时按新窗口计时
      _totalSeconds = _remaining;
      _segmentStart = DateTime.now();
    } else {
      setState(() => _running = true);
      _scheduleTick();
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
    return Scaffold(
      appBar: AppBar(title: const Text('番茄专注')),
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
                    label: const Text('开始专注'),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _running ? _pauseResume : _pauseResume,
                    icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                    label: Text(_running ? '暂停' : '继续'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _giveUp,
                    icon: const Icon(Icons.stop),
                    label: const Text('放弃'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (_phase == _Phase.idle) _taskPicker(theme),
            const SizedBox(height: 8),
            Text('已完成 $_finishedFocusCount 个番茄 · 今日统计见下方',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            _todayStats(theme),
          ],
        ),
      ),
    );
  }

  Widget _phaseLabel(ThemeData theme) {
    final text = switch (_phase) {
      _Phase.idle => '准备就绪',
      _Phase.focus => '专注中',
      _Phase.breakTime => '休息中',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: FutureBuilder<List<Task>>(
        future:
            ref.read(taskRepoProvider).queryAll(includeCompleted: false),
        builder: (_, snap) {
          final tasks = snap.data ?? const <Task>[];
          return DropdownButtonFormField<Task?>(
            initialValue: _selectedTask,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '关联任务（可选）',
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
              const DropdownMenuItem(value: null, child: Text('不关联')),
              for (final t in tasks.take(50))
                DropdownMenuItem(
                    value: t,
                    child: Text(t.title.isEmpty ? '无标题任务' : t.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _selectedTask = v),
          );
        },
      ),
    );
  }

  Widget _todayStats(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: FutureBuilder<List<int>>(
        future: Future.wait([
          ref.read(pomodoroRepoProvider).todayCount(),
          ref.read(pomodoroRepoProvider).todayMinutes(),
        ]),
        builder: (_, snap) {
          final data = snap.data ?? const [0, 0];
          return Text('今日 ${data[0]} 个番茄 · 累计专注 ${data[1]} 分钟',
              style: theme.textTheme.labelLarge);
        },
      ),
    );
  }
}
