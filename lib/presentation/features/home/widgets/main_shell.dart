import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Main app shell with bottom navigation
/// 
/// This widget provides the bottom navigation bar that persists across
/// the main app screens (Home, Activity, Profile).
class MainShell extends StatelessWidget {
  const MainShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNavBar(
        currentPath: GoRouterState.of(context).uri.path,
      ),
    );
  }
}

/// Bottom navigation bar for main app screens
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentPath,
  });

  final String currentPath;

  int get _currentIndex {
    if (currentPath.startsWith('/home')) {
      return 0;
    }
    if (currentPath.startsWith('/activity')) {
      return 1;
    }
    if (currentPath.startsWith('/profile')) {
      return 2;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/home');
          case 1:
            context.go('/activity');
          case 2:
            context.go('/profile');
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'Activity',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
