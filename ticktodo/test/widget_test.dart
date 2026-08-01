import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticktodo/app.dart';

void main() {
  testWidgets('应用骨架冒烟：底部导航渲染', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TickTodoApp()));
    expect(find.text('今天'), findsWidgets);
    expect(find.text('最近7天'), findsWidgets);
    expect(find.text('日历'), findsWidgets);
    expect(find.text('全部'), findsWidgets);
  });
}
