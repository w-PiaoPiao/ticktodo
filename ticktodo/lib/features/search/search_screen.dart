import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/detail/task_detail_screen.dart';
import 'package:ticktodo/features/shared/task_list_view.dart';
import 'package:ticktodo/l10n/app_localizations.dart';
import 'package:ticktodo/widgets/empty_state.dart';

/// 全局搜索：标题/备注关键词，300ms 防抖实时搜索。
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Task>? _results;
  ProviderSubscription<int>? _mutationSub;

  @override
  void initState() {
    super.initState();
    // 任务变更（完成/删除/编辑）后自动刷新搜索结果
    _mutationSub = ref.listenManual(taskMutationProvider, (_, _) => _search());
  }

  @override
  void dispose() {
    _mutationSub?.close();
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty || !mounted) return;
    final r = await ref.read(taskRepoProvider).searchTasks(q);
    if (mounted) setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: _results == null
          ? EmptyState(icon: Icons.search, title: l10n.searchInitialHint)
          : _results!.isEmpty
              ? EmptyState(icon: Icons.search_off, title: l10n.searchEmpty)
              : TaskListView(
                  tasks: _results!,
                  emptyTitle: '',
                  onTapTask: (t) => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TaskDetailScreen(taskId: t.id ?? 0),
                  )),
                ),
    );
  }
}
