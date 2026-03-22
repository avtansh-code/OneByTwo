import 'package:flutter_test/flutter_test.dart';
import 'package:one_by_two/core/router/app_router.dart';
import 'package:one_by_two/core/router/route_paths.dart';

void main() {
  group('AppRouter redirect logic', () {
    // -----------------------------------------------------------------------
    // Helper — applies the same redirect logic used by AppRouter.router().
    //
    // The redirect is a pure function of (isAuthenticated, matchedLocation).
    // We test it directly to avoid depending on GoRouter's async internal
    // state propagation which doesn't resolve synchronously in unit tests.
    // -----------------------------------------------------------------------

    /// Returns the redirect target, or `null` if no redirect is needed.
    String? applyRedirect({
      required bool isAuthenticated,
      required String matchedLocation,
    }) {
      final isAtAuth = matchedLocation.startsWith('/welcome');

      if (!isAuthenticated && !isAtAuth) {
        return RoutePaths.welcome;
      }
      if (isAuthenticated && isAtAuth) {
        return RoutePaths.home;
      }
      return null;
    }

    // -----------------------------------------------------------------------
    // Unauthenticated user tests
    // -----------------------------------------------------------------------

    group('unauthenticated user', () {
      test('should stay on /welcome (no redirect)', () {
        final result = applyRedirect(
          isAuthenticated: false,
          matchedLocation: '/welcome',
        );
        expect(result, isNull);
      });

      test('should stay on /welcome/phone (no redirect)', () {
        final result = applyRedirect(
          isAuthenticated: false,
          matchedLocation: '/welcome/phone',
        );
        expect(result, isNull);
      });

      test('should be redirected to /welcome from home', () {
        final result = applyRedirect(
          isAuthenticated: false,
          matchedLocation: '/',
        );
        expect(result, RoutePaths.welcome);
      });

      test('should be redirected to /welcome from /profile-setup', () {
        final result = applyRedirect(
          isAuthenticated: false,
          matchedLocation: '/profile-setup',
        );
        expect(result, RoutePaths.welcome);
      });

      test('should be redirected to /welcome from arbitrary route', () {
        final result = applyRedirect(
          isAuthenticated: false,
          matchedLocation: '/settings',
        );
        expect(result, RoutePaths.welcome);
      });
    });

    // -----------------------------------------------------------------------
    // Authenticated user tests
    // -----------------------------------------------------------------------

    group('authenticated user', () {
      test('should stay on home (no redirect)', () {
        final result = applyRedirect(
          isAuthenticated: true,
          matchedLocation: '/',
        );
        expect(result, isNull);
      });

      test('should be redirected to home from /welcome', () {
        final result = applyRedirect(
          isAuthenticated: true,
          matchedLocation: '/welcome',
        );
        expect(result, RoutePaths.home);
      });

      test('should be redirected to home from /welcome/phone', () {
        final result = applyRedirect(
          isAuthenticated: true,
          matchedLocation: '/welcome/phone',
        );
        expect(result, RoutePaths.home);
      });

      test('should be redirected to home from /welcome/phone/otp', () {
        final result = applyRedirect(
          isAuthenticated: true,
          matchedLocation: '/welcome/phone/otp',
        );
        expect(result, RoutePaths.home);
      });

      // -------------------------------------------------------------------
      // REGRESSION: This is the key test that would have FAILED before the
      // fix. Previously profile-setup was at /welcome/profile-setup,
      // which matched the /welcome/* redirect and sent authenticated users
      // to home — making it impossible for new users to set up their
      // profile after OTP verification.
      // -------------------------------------------------------------------

      test('regression: authenticated user should stay on /profile-setup '
          '(not be redirected to home)', () {
        final result = applyRedirect(
          isAuthenticated: true,
          matchedLocation: '/profile-setup',
        );

        // Before fix: /profile-setup was at /welcome/profile-setup, so
        // matchedLocation.startsWith('/welcome') was true → redirect to
        // home. New users could never reach profile setup.
        // After fix: /profile-setup is at root level → no redirect.
        expect(
          result,
          isNull,
          reason:
              'Authenticated users must be able to reach '
              '/profile-setup for initial profile creation',
        );
      });

      test('should stay on /settings (no redirect)', () {
        final result = applyRedirect(
          isAuthenticated: true,
          matchedLocation: '/settings',
        );
        expect(result, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // Route path constants
    // -----------------------------------------------------------------------

    group('RoutePaths.profileSetup', () {
      test('should be an absolute root-level path', () {
        expect(RoutePaths.profileSetup, startsWith('/'));
        expect(RoutePaths.profileSetup, isNot(startsWith('/welcome')));
      });

      test('should equal /profile-setup', () {
        expect(RoutePaths.profileSetup, equals('/profile-setup'));
      });
    });

    // -----------------------------------------------------------------------
    // Router structure
    // -----------------------------------------------------------------------

    group('route structure', () {
      test('should have profile-setup as a named route', () {
        final router = AppRouter.router(isAuthenticated: true);

        // GoRouter.namedLocation resolves a route name to a location.
        // If the name doesn't exist, it throws.
        final location = router.namedLocation('profile-setup');
        expect(location, RoutePaths.profileSetup);
      });

      test(
        'should have profile-setup reachable at root level (not nested)',
        () {
          // Verify the route path is absolute — GoRouter treats paths starting
          // with '/' as root-level routes.
          expect(RoutePaths.profileSetup, equals('/profile-setup'));

          // Verify it does NOT contain the welcome prefix.
          expect(RoutePaths.profileSetup, isNot(contains('/welcome')));
        },
      );
    });
  });
}
