import 'package:flutter/material.dart';
import 'package:ticktodo/core/repeat_rule.dart';

/// 底部弹窗选择重复规则。
///
/// 返回 RRULE 编码字符串；`''` 表示"不重复"；`null` 表示取消/未选择。
Future<String?> showRepeatPicker(BuildContext context, {String? currentEncoded}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: _RepeatPickerBody(currentEncoded: currentEncoded),
    ),
  );
}

class _RepeatPickerBody extends StatefulWidget {
  const _RepeatPickerBody({this.currentEncoded});

  final String? currentEncoded;

  @override
  State<_RepeatPickerBody> createState() => _RepeatPickerBodyState();
}

class _RepeatPickerBodyState extends State<_RepeatPickerBody> {
  late final Set<int> _customDays;
  bool _showCustom = false;

  @override
  void initState() {
    super.initState();
    final current = RepeatRule.parse(widget.currentEncoded);
    _customDays = (current != null && current.byWeekdays.isNotEmpty)
        ? Set<int>.of(current.byWeekdays)
        : <int>{};
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child:
                Text('重复', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final preset in kRepeatPresets)
            ListTile(
              dense: true,
              leading: const Icon(Icons.repeat),
              title: Text(preset.label),
              trailing:
                  preset.encode() == widget.currentEncoded
                      ? const Icon(Icons.check)
                      : null,
              onTap: () => Navigator.pop(context, preset.encode()),
            ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.date_range_outlined),
            title: const Text('自定义每周…'),
            trailing: Icon(_showCustom ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _showCustom = !_showCustom),
          ),
          if (_showCustom)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(['一', '二', '三', '四', '五', '六', '日'][d - 1]),
                          selected: _customDays.contains(d),
                          onSelected: (sel) => setState(
                              () => sel ? _customDays.add(d) : _customDays.remove(d)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _customDays.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            RepeatRule(
                                    freq: RepeatFreq.weekly,
                                    byWeekdays: _customDays)
                                .encode()),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.block),
            title: const Text('不重复'),
            onTap: () => Navigator.pop(context, ''),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
