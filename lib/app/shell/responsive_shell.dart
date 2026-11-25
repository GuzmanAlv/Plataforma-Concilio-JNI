import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_providers.dart';
import '../../features/auth/presentation/access_gate.dart';
import '../theme/app_theme.dart';

const appDestinations = <({String path, String label, IconData icon})>[
  (
    path: '/asistencia',
    label: 'Asistencia & Dashboard',
    icon: Icons.insights_outlined,
  ),
  (path: '/integrantes', label: 'Integrantes', icon: Icons.people_outline),
  (
    path: '/tesoreria',
    label: 'Tesorería',
    icon: Icons.account_balance_wallet_outlined,
  ),
  (path: '/inventario', label: 'Inventario', icon: Icons.inventory_2_outlined),
];

class ResponsiveShell extends ConsumerWidget {
  const ResponsiveShell({
    required this.location,
    required this.child,
    super.key,
  });
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    final client = ref.watch(supabaseClientProvider);
    ref.watch(authStateProvider);
    final signedIn = client?.auth.currentSession != null;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        automaticallyImplyLeading: !wide,
        title: _Brand(compact: wide && MediaQuery.sizeOf(context).width < 1200),
        actions: [
          if (wide)
            ...appDestinations.map(
              (destination) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: location == destination.path
                        ? AppTheme.purple
                        : const Color(0xFF656B80),
                    backgroundColor: location == destination.path
                        ? const Color(0xFFF0EEFC)
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () => context.go(destination.path),
                  icon: Icon(destination.icon, size: 19),
                  label: Text(destination.label),
                ),
              ),
            ),
          if (signedIn)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                try {
                  await client!.auth.signOut();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No se pudo cerrar sesión. Inténtalo de nuevo.',
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout, size: 20),
            ),
          SizedBox(width: wide ? 16 : 8),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(padding: EdgeInsets.all(24), child: _Brand()),
                    const Divider(),
                    ...appDestinations.map(
                      (destination) => ListTile(
                        leading: Icon(destination.icon),
                        title: Text(destination.label),
                        selected: destination.path == location,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go(destination.path);
                        },
                      ),
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Un año para crecer juntos.\nNov 2026 — Oct 2027',
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: ValueKey(location),
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 36 : 16,
            vertical: 28,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (client == null &&
                      ref.watch(startupErrorProvider) == null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEAFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Vista previa · Los datos del concilio aparecerán al conectar tu cuenta.',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  AccessGate(child: child),
                  const SizedBox(height: 36),
                  const Text(
                    'JNI DREAMRS  /  PERÚ  /  2026–2027',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: Color(0xFF8C90A1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.purple,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
      ),
      if (!compact) const SizedBox(width: 10),
      if (!compact)
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DREAMRS',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            Text(
              'Concilio JNI',
              style: TextStyle(fontSize: 11, color: Color(0xFF74798C)),
            ),
          ],
        ),
    ],
  );
}
