import 'package:flutter/material.dart';

/// 滴答绿主题色
const Color kSeedColor = Color(0xFF2F9D45);

/// 清单色板（选择清单/标签颜色用）
const List<int> kPalette = [
  0xFF2F9D45, // 绿
  0xFFE04C4C, // 红
  0xFF4C9AFF, // 蓝
  0xFFF29900, // 橙
  0xFF9B59B6, // 紫
  0xFF00B8A9, // 青
  0xFFE85D9E, // 粉
  0xFF607D8B, // 灰蓝
  0xFF8B7355, // 棕
  0xFF3F51B5, // 靛蓝
];

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kSeedColor);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF7F8F7),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kSeedColor,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}
