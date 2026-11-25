import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_version_config.dart';

final class SupabaseAppVersionRepository {
  const SupabaseAppVersionRepository(this._client);
  final SupabaseClient _client;

  Future<AppVersionConfig> loadConfig() async => AppVersionConfig.fromJson(
    await _client.from('configuracion_app').select().eq('id', 1).single(),
  );
}
