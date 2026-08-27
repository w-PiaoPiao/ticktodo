import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticktodo/widgets/repeat_picker.dart';

import 'support/test_app.dart';

void main() {
  Future<void> Function(WidgetTester, String? currentEncoded,
      void Function(String?) onResult) buildHost() {
    return (tester, currentEncoded, onResult) async {
      await tester.pumpWidget(testApp(
        Builder(builder: (ctx) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final r = await showRepeatPicker(ctx, currentEncoded: currentEncoded);
                  onResult(r);
                },
                child: const Text('open'),
              ),
            ),
          );
        }),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    };
  }

  testWidgets('选择每天返回 FREQ=DAILY', (tester) async {
    String? result;
    await buildHost()(tester, null, (r) => result = r);
    await tester.tap(find.text('每天'));
    await tester.pumpAndSettle();
    expect(result, 'FREQ=DAILY');
  });

  testWidgets('自定义周一三返回 BYDAY 编码', (tester) async {
    String? result;
    await buildHost()(tester, null, (r) => result = r);
    await tester.tap(find.text('自定义每周…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('一'));
    await tester.tap(find.text('三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(result, 'FREQ=WEEKLY;BYDAY=MO,WE');
  });

  testWidgets('选择不重复返回空串', (tester) async {
    String? result;
    await buildHost()(tester, 'FREQ=DAILY', (r) => result = r);
    expect(find.byIcon(Icons.check), findsOneWidget); // 当前选中"每天"
    await tester.tap(find.text('不重复'));
    await tester.pumpAndSettle();
    expect(result, '');
  });

  testWidgets('点外部关闭返回 null（不清除已有规则）', (tester) async {
    String? result;
    await buildHost()(tester, 'FREQ=DAILY', (r) => result = r);
    await tester.tapAt(const Offset(50, 50));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
