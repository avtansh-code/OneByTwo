import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/profile/presentation/contact_support_fallback_dialog.dart';

void main() {
  const address = 'support@onebytwo.app';

  Widget harness() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ContactSupportFallbackDialog.show(
              context,
              supportEmailAddress: address,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  Finder addressFinder() =>
      find.byWidgetPredicate((w) => w is SelectableText && w.data == address);

  testWidgets('renders the title, selectable address, and actions', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('No Mail App Found'), findsOneWidget);
    expect(addressFinder(), findsOneWidget);
    expect(find.text('Copy Address'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Accessibility labels per wireframe 4.4.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is AlertDialog && w.semanticLabel == 'Alert: No Mail App Found',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Support email address: $address',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Copy Address writes the address to the clipboard, '
      'dismisses, and confirms with a snackbar', (tester) async {
    final clipboardCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls.add(call);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy Address'));
    await tester.pumpAndSettle();

    expect(clipboardCalls, hasLength(1));
    expect((clipboardCalls.single.arguments as Map)['text'], address);
    // Dialog dismissed and the confirmation snackbar shown.
    expect(find.text('No Mail App Found'), findsNothing);
    expect(
      find.text(ContactSupportFallbackDialog.copiedConfirmation),
      findsOneWidget,
    );
  });

  testWidgets('Close dismisses the dialog with no clipboard write', (
    tester,
  ) async {
    final clipboardCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls.add(call);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('No Mail App Found'), findsNothing);
    expect(clipboardCalls, isEmpty);
  });
}
