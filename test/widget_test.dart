import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/main.dart';

void main() {
  testWidgets('app boots and shows the OneByTwo text', (tester) async {
    await tester.pumpWidget(const OneBytwoApp());
    await tester.pumpAndSettle();

    expect(find.text('OneByTwo'), findsOneWidget);
  });
}
