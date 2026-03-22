import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_by_two/core/l10n/generated/app_localizations.dart';
import 'package:one_by_two/presentation/features/auth/screens/profile_setup_screen.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  /// Wraps [ProfileSetupScreen] with GoRouter (including [initialExtra]),
  /// Riverpod, and l10n.
  ///
  /// The screen reads `GoRouterState.of(context).extra` to obtain `uid` and
  /// `phone`. Passing [extra] populates these values. When omitted both
  /// default to empty strings via the screen's null-coalescing fallback.
  ///
  /// The [profileSetupNotifierProvider] auto-initialises to `AsyncData(null)`
  /// — no Firebase dependency at init time.
  Widget buildSubject({Map<String, String>? extra}) {
    final router = GoRouter(
      initialLocation: '/test',
      initialExtra: extra,
      routes: [
        GoRoute(path: '/test', builder: (_, __) => const ProfileSetupScreen()),
        // Navigation target after successful profile creation.
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  /// Default extra map simulating navigation from OTP verification.
  const defaultExtra = <String, String>{
    'uid': 'test-uid-123',
    'phone': '+919876543210',
  };

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  group('ProfileSetupScreen', () {
    group('rendering', () {
      testWidgets('should display title from l10n', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Set up your profile'), findsOneWidget);
      });

      testWidgets('should display subtitle from l10n', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Tell us a bit about yourself'), findsOneWidget);
      });

      testWidgets('should display person icon as avatar placeholder', (
        tester,
      ) async {
        // Arrange & Act — no image selected, name is empty → person icon
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('should display camera badge icon on avatar', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      });

      testWidgets('should display Change Photo label', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Change Photo'), findsOneWidget);
      });

      testWidgets('should display name input field with hint', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Your name'), findsOneWidget);
        // Person outline icon used as prefix
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
      });

      testWidgets('should display email input field with hint', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Email (optional)'), findsOneWidget);
        // Email icon used as prefix
        expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      });

      testWidgets('should display Complete button with l10n text', (
        tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert
        expect(find.widgetWithText(FilledButton, 'Complete'), findsOneWidget);
      });

      testWidgets('should have Complete button enabled initially', (
        tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert — button is enabled by default; validation happens on submit
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Complete'),
        );
        expect(button.onPressed, isNotNull);
      });

      testWidgets('should contain exactly two TextFormFields', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert — name + email
        expect(find.byType(TextFormField), findsNWidgets(2));
      });

      testWidgets('should contain a Form widget', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(Form), findsOneWidget);
      });

      testWidgets('should wrap body content in SafeArea', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(SafeArea), findsOneWidget);
      });
    });

    group('form validation', () {
      testWidgets('should show name required error on submit with empty name', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Act — tap Complete without entering a name.
        // _formKey.validate() returns false → _onSubmit returns early
        // (no Firebase Storage call).
        await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
        await tester.pumpAndSettle();

        // Assert — Validators.displayName('') returns 'Name is required'
        expect(find.text('Name is required'), findsOneWidget);
      });

      testWidgets(
        'should not show email error when email is left empty on submit',
        (tester) async {
          // Arrange
          await tester.pumpWidget(buildSubject(extra: defaultExtra));
          await tester.pumpAndSettle();

          // Act — leave both fields empty, tap Complete
          await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
          await tester.pumpAndSettle();

          // Assert — name error shows but email does NOT (email is optional)
          expect(find.text('Name is required'), findsOneWidget);
          expect(find.text('Enter a valid email address'), findsNothing);
          expect(find.text('Email is required'), findsNothing);
        },
      );

      testWidgets(
        'should show email validation error on submit with invalid email',
        (tester) async {
          // Arrange
          await tester.pumpWidget(buildSubject(extra: defaultExtra));
          await tester.pumpAndSettle();

          // Act — enter invalid email in the second TextFormField (index 1)
          // Leave name empty so validate() returns false → no Firebase call.
          final emailField = find.byType(TextFormField).at(1);
          await tester.enterText(emailField, 'not-an-email');
          await tester.pump();

          await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
          await tester.pumpAndSettle();

          // Assert — both name and email errors appear
          expect(find.text('Name is required'), findsOneWidget);
          expect(find.text('Enter a valid email address'), findsOneWidget);
        },
      );

      testWidgets(
        'should not show email error on submit with valid email format',
        (tester) async {
          // Arrange
          await tester.pumpWidget(buildSubject(extra: defaultExtra));
          await tester.pumpAndSettle();

          // Act — enter valid email, leave name empty
          final emailField = find.byType(TextFormField).at(1);
          await tester.enterText(emailField, 'user@example.com');
          await tester.pump();

          await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
          await tester.pumpAndSettle();

          // Assert — name error shows, but email passes validation
          expect(find.text('Name is required'), findsOneWidget);
          expect(find.text('Enter a valid email address'), findsNothing);
        },
      );

      testWidgets('should show name error for whitespace-only name on submit', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Act — enter spaces only in the name field
        final nameField = find.byType(TextFormField).at(0);
        await tester.enterText(nameField, '   ');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
        await tester.pumpAndSettle();

        // Assert — Validators.displayName('   ') returns 'Name is required'
        expect(find.text('Name is required'), findsOneWidget);
      });
    });

    group('avatar section', () {
      testWidgets('should show avatar with CircleAvatar when name is empty', (
        tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Assert — CircleAvatar is used for the placeholder
        expect(find.byType(CircleAvatar), findsOneWidget);
      });

      testWidgets('should show bottom sheet when avatar area is tapped', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(buildSubject(extra: defaultExtra));
        await tester.pumpAndSettle();

        // Act — tap the Change Photo area (GestureDetector wrapping avatar)
        await tester.tap(find.text('Change Photo'));
        await tester.pumpAndSettle();

        // Assert — bottom sheet shows avatar picker options
        expect(find.text('Profile Photo'), findsOneWidget);
        expect(find.text('Take Photo'), findsOneWidget);
        expect(find.text('Choose from Gallery'), findsOneWidget);
        // "Remove Photo" is only shown when an image is already selected
        expect(find.text('Remove Photo'), findsNothing);
      });
    });
  });
}
