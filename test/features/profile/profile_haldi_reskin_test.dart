// Profile cluster Haldi reskin gate (DC-10; 04-qa-test-strategy.md §D).
//
// Pins the reskin-specific contracts the behavioural per-surface suites do not
// assert:
//   - change-phone (AC-2, behaviour-frozen): the OTP "sent to" line shows a
//     MASKED number (never the raw current number); the ADR-0015 "sync pending
//     -> Try again" recovery is tinted with OBTColors.warning, NOT the danger
//     token; the +91 prefix stays locked on new-number entry;
//   - delete-account: the destructive primary action keeps the error token;
//   - contact-support: the selectable email uses the OBTColors.link token and
//     the dialog adopts the radiusCard corner;
//   - photo picker: the destructive "Remove" keeps the error token, and the
//     sheet is labelled and >= 48 dp;
//   - the marigold contrast gate holds incl. the white-on-marigold NEGATIVE
//     case (the DC-01 ink-not-white rule), with the link token clearing AA;
//   - the converted surfaces do not overflow at 2.0x dynamic type.
//
// The no-`Color(0x…)` structural guard lives in the boundary-contract grep
// (profile_haldi_boundary_contract_test.dart). Profile is a NON-HERO cluster,
// so goldens are light-only and queued (skipped) in dc10_profile_golden_test.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/features/profile/application/change_phone_controller.dart';
import 'package:onebytwo/features/profile/application/delete_account_controller.dart';
import 'package:onebytwo/features/profile/presentation/change_phone_screen.dart';
import 'package:onebytwo/features/profile/presentation/contact_support_fallback_dialog.dart';
import 'package:onebytwo/features/profile/presentation/delete_account_screen.dart';
import 'package:onebytwo/features/profile/presentation/widgets/photo_picker_sheet.dart';

import '../../support/widget_test_harness.dart';
import 'helpers/profile_fakes.dart';

const _address = 'support@onebytwo.app';

Future<void> _pumpThemedScreen(
  WidgetTester tester,
  Widget child, {
  required List<Override> overrides,
  double textScale = 1.0,
  Size surfaceSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ChangePhoneController _changePhoneController(FakeUserRepo users) =>
    ChangePhoneController(
      uid: 'uid-1',
      currentPhoneNumber: '+919876543210',
      analytics: FakeAnalytics(),
      accountRepository: FakeAccountRepo(),
      userRepository: users,
    );

DeleteAccountController _deleteController() => DeleteAccountController(
  currentPhoneNumber: '+919876543210',
  analytics: FakeAnalytics(),
  accountRepository: FakeAccountRepo(),
  deleteAccountRepository: FakeDeleteRepo(),
  signOut: () async {},
);

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrastRatio(Color a, Color b) {
  final la = _luminance(a) + 0.05;
  final lb = _luminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  // ---- change-phone (AC-2): masked numbers, behaviour-frozen re-auth ----
  group('change-phone reskin (AC-2)', () {
    testWidgets('step headings render in ink, not marigold (AA)', (
      tester,
    ) async {
      await _pumpThemedScreen(
        tester,
        const ChangePhoneScreen(),
        overrides: <Override>[
          changePhoneControllerProvider.overrideWith(
            (ref) => _changePhoneController(FakeUserRepo()),
          ),
        ],
      );

      final heading = tester.widget<Text>(
        find.text('Verify your current number'),
      );
      expect(heading.style?.color, AppTheme.light.colorScheme.onSurface);
      expect(heading.style?.color, isNot(AppTheme.light.colorScheme.primary));
    });

    testWidgets('the re-auth OTP step masks the number, never the raw one', (
      tester,
    ) async {
      await _pumpThemedScreen(
        tester,
        const ChangePhoneScreen(),
        overrides: <Override>[
          changePhoneControllerProvider.overrideWith(
            (ref) => _changePhoneController(FakeUserRepo()),
          ),
        ],
      );

      // Re-auth must be requested before any code is shown.
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();

      // The "sent to" line is masked; the raw current number is not shown.
      expect(find.textContaining('XXXXXX3210'), findsOneWidget);
      expect(find.text('+919876543210'), findsNothing);
    });

    testWidgets('the +91 prefix stays locked on new-number entry', (
      tester,
    ) async {
      await _pumpThemedScreen(
        tester,
        const ChangePhoneScreen(),
        overrides: <Override>[
          changePhoneControllerProvider.overrideWith(
            (ref) => _changePhoneController(FakeUserRepo()),
          ),
        ],
      );

      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();

      // New-number entry: the +91 country code is a fixed, non-editable chip.
      expect(find.text('Enter your new number'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
    });

    testWidgets('sync-pending recovery is warning-toned, not danger', (
      tester,
    ) async {
      await _pumpThemedScreen(
        tester,
        const ChangePhoneScreen(),
        overrides: <Override>[
          changePhoneControllerProvider.overrideWith(
            (ref) => _changePhoneController(FakeUserRepo(throwOnSync: true)),
          ),
        ],
      );

      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '9123456780');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '654321');
      await tester.pumpAndSettle();

      // The recovery affordance is present and tinted with warning, not error.
      expect(find.text('Try again'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.sync_problem));
      expect(icon.color, OBTColors.light.warning);
      expect(icon.color, isNot(AppTheme.light.colorScheme.error));
    });
  });

  // ---- delete-account: the destructive action keeps the error token ----
  testWidgets('delete-account Continue uses the error (danger) token', (
    tester,
  ) async {
    await _pumpThemedScreen(
      tester,
      const DeleteAccountScreen(),
      overrides: <Override>[
        deleteAccountControllerProvider.overrideWith(
          (ref) => _deleteController(),
        ),
      ],
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    final background = button.style?.backgroundColor?.resolve(<WidgetState>{});
    expect(background, AppTheme.light.colorScheme.error);
  });

  // ---- contact-support: link token + radiusCard dialog ----
  group('contact-support reskin', () {
    Widget launcher() => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ContactSupportFallbackDialog.show(
              context,
              supportEmailAddress: _address,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    testWidgets('the selectable email uses the link token; dialog radius is '
        'radiusCard', (tester) async {
      await tester.pumpWidget(launcher());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final email = tester.widget<SelectableText>(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == _address,
        ),
      );
      expect(email.style?.color, OBTColors.light.link);

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AppTheme.radiusCard));
    });

    testWidgets('the dialog does not overflow at 2.0x dynamic type', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: Scaffold(
                body: Builder(
                  builder: (inner) => ElevatedButton(
                    onPressed: () => ContactSupportFallbackDialog.show(
                      inner,
                      supportEmailAddress: _address,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ---- photo picker: destructive token + labelling + 48 dp ----
  group('photo picker reskin', () {
    testWidgets('Remove keeps the error token; rows labelled and >= 48 dp', (
      tester,
    ) async {
      await pumpThemed(tester, const PhotoPickerSheet(hasExistingPhoto: true));

      final removeTitle = tester.widget<Text>(find.text('Remove Photo'));
      expect(removeTitle.style?.color, AppTheme.light.colorScheme.error);

      await expectAllInteractiveNodesLabelled(tester);
      await expectAllTapTargetsMeetMinSize(tester);
    });

    testWidgets('the sheet does not overflow at 2.0x dynamic type', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const PhotoPickerSheet(hasExistingPhoto: true),
        textScale: 2,
        surfaceSize: const Size(320, 844),
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ---- B.1 / B.2: contrast gate incl. the white-on-marigold negative case ---
  group('contrast gate', () {
    test('white on marigold fails AA; ink on marigold passes', () {
      final scheme = AppTheme.light.colorScheme;
      expect(
        _contrastRatio(Colors.white, scheme.primary),
        lessThan(3.0),
        reason: 'white on marigold must fail even AA-large',
      );
      expect(
        _contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
        reason: 'ink on marigold must clear AA',
      );
    });

    test('the contact-support link token clears AA on the surface', () {
      expect(
        _contrastRatio(
          OBTColors.light.link,
          AppTheme.light.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test(
      'ink clears AA on the scaffold; marigold fails (B1 negative case)',
      () {
        final scheme = AppTheme.light.colorScheme;
        final background = AppTheme.light.scaffoldBackgroundColor;
        expect(
          _contrastRatio(scheme.onSurface, background),
          greaterThanOrEqualTo(4.5),
          reason: 'step headings must be ink so they clear AA on the cream',
        );
        expect(
          _contrastRatio(scheme.primary, background),
          lessThan(4.5),
          reason: 'marigold-on-cream fails AA — headings must not use primary',
        );
      },
    );
  });
}
