import 'package:flutter/material.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

/// 测试用 MaterialApp 包装：固定 zh locale（与测试中文断言一致）。
MaterialApp testApp(Widget home, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}