import 'package:flutter/material.dart';
import 'package:ticktodo/data/models/task.dart';

/// 四段式优先级选择
class PriorityPicker extends StatelessWidget {
  const PriorityPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final p in TaskPriority.values) ...[
          if (p != TaskPriority.values.first) const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: Text(p.label),
              selected: value == p,
              onSelected: (_) => onChanged(p),
              selectedColor: p == TaskPriority.none
                  ? null
                  : Color(p.colorValue).withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: value == p
                    ? (p == TaskPriority.none
                        ? Theme.of(context).colorScheme.onSurface
                        : Color(p.colorValue))
                    : null,
                fontWeight: value == p ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
