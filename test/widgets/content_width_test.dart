import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:thingviewer/widgets/content_width.dart';

void main() {
  Future<Rect> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContentWidth(child: SizedBox.expand(key: Key('content'))),
        ),
      ),
    );
    return tester.getRect(find.byKey(const Key('content')));
  }

  testWidgets('caps the width and centres the content on wide screens', (
    tester,
  ) async {
    final rect = await pumpAt(tester, 1600);

    expect(rect.width, ContentWidth.maxWidth);
    expect(rect.left, (1600 - ContentWidth.maxWidth) / 2);
    expect(rect.height, 800);
  });

  testWidgets('uses the full width on narrow screens', (tester) async {
    final rect = await pumpAt(tester, 400);

    expect(rect.width, 400);
    expect(rect.left, 0);
  });
}
