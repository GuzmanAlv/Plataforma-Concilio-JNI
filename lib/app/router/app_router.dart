import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/members/presentation/members_page.dart';
import '../../features/treasury/presentation/treasury_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../shell/responsive_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
      ShellRoute(
        builder: (context, state, child) =>
            ResponsiveShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(
            path: '/asistencia',
            builder: (_, _) => const AttendancePage(),
          ),
          GoRoute(path: '/integrantes', builder: (_, _) => const MembersPage()),
          GoRoute(path: '/tesoreria', builder: (_, _) => const TreasuryPage()),
          GoRoute(
            path: '/inventario',
            builder: (_, _) => const InventoryPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/dashboard'),
          child: const Text('Volver al inicio'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
