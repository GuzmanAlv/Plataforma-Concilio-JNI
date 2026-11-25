import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class ConcilioApp extends ConsumerWidget {
  const ConcilioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Concilio JNI Dreamrs',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('es', 'PE'),
    supportedLocales: const [Locale('es', 'PE')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: ref.watch(appRouterProvider),
  );
}
