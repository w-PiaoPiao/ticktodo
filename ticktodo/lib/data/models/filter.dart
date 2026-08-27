import 'dart:convert';

import 'package:ticktodo/core/logger.dart';

/// 自定义过滤器日期模式
enum FilterDateMode {
  any(0, '不限'),
  today(1, '今天'),
  week(2, '最近7天'),
  overdue(3, '已过期'),
  noDate(4, '无日期');

  const FilterDateMode(this.value, this.label);
  final int value;
  final String label;

  static FilterDateMode fromValue(int? v) => FilterDateMode.values
      .firstWhere((m) => m.value == v, orElse: () => FilterDateMode.any);
}

/// 自定义过滤器（智能清单）：清单 + 标签 + 最低优先级 + 日期模式组合。
class Filter {
  const Filter({
    this.id,
    required this.name,
    this.listIds = const [],
    this.tagIds = const [],
    this.minPriority = 0,
    this.dateMode = FilterDateMode.any,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final String name;

  /// 命中的清单 id；空 = 全部清单
  final List<int> listIds;

  /// 命中的标签 id；空 = 不限标签
  final List<int> tagIds;

  /// 最低优先级（0=不限，1=低以上，2=中以上，3=仅高）
  final int minPriority;
  final FilterDateMode dateMode;
  final int sortOrder;
  final int? createdAt;
  final int? updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  Filter copyWith({
    int? id,
    String? name,
    List<int>? listIds,
    List<int>? tagIds,
    int? minPriority,
    FilterDateMode? dateMode,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Filter(
      id: id ?? this.id,
      name: name ?? this.name,
      listIds: listIds ?? this.listIds,
      tagIds: tagIds ?? this.tagIds,
      minPriority: minPriority ?? this.minPriority,
      dateMode: dateMode ?? this.dateMode,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'listIds': jsonEncode(listIds),
        'tagIds': jsonEncode(tagIds),
        'minPriority': minPriority,
        'dateMode': dateMode.value,
        'sortOrder': sortOrder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory Filter.fromMap(Map<String, Object?> map) => Filter(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        listIds: _decodeList(map['listIds']),
        tagIds: _decodeList(map['tagIds']),
        minPriority: map['minPriority'] as int? ?? 0,
        dateMode: FilterDateMode.fromValue(map['dateMode'] as int?),
        sortOrder: map['sortOrder'] as int? ?? 0,
        createdAt: map['createdAt'] as int?,
        updatedAt: map['updatedAt'] as int?,
        deletedAt: map['deletedAt'] as int?,
      );

  static List<int> _decodeList(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      try {
        return (jsonDecode(raw) as List).cast<int>();
      } catch (e) {
        AppLogger.warn('Filter._decodeList', '$e');
      }
    }
    return const [];
  }

  @override
  bool operator ==(Object other) =>
      other is Filter && other.id == id && other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(id, updatedAt);
}
