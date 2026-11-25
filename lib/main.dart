import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'core/supabase/supabase_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await initializeDateFormatting('es_PE');
  const environment = AppEnvironment.fromDefines();
  SupabaseClient? client;
  String? startupError;
  try {
    environment.validate();
    if (environment.isConfigured) {
      await Supabase.initialize(
        url: environment.supabaseUrl,
        publishableKey: environment.supabasePublishableKey,
      );
      client = Supabase.instance.client;
    }
  } catch (_) {
    startupError =
        'No se pudo iniciar la conexión. Revisa la configuración y vuelve a abrir la aplicación.';
  }
  runApp(
    ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(client),
        startupErrorProvider.overrideWithValue(startupError),
      ],
      child: const ConcilioApp(),
    ),
  );
}
