import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import 'auth_providers.dart';

/// Provides the [GoRouter] instance for the app.
///
/// Watches [authStateProvider] and recreates the router when auth state
/// changes (sign-in / sign-out). This replaces the previous approach of
/// calling `AppRouter.router()` directly inside `OneByTwoApp.build()`,
/// which created a new router on every widget rebuild — including spurious
/// rebuilds from `AsyncLoading` → `AsyncData` transitions.
///
/// By isolating the router behind a provider, the router is only recreated
/// when the auth state *value* actually changes, not on every widget rebuild.
final appRouterProvider = Provider.autoDispose<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final isAuthenticated = authState.valueOrNull != null;
  return AppRouter.router(isAuthenticated: isAuthenticated);
});
