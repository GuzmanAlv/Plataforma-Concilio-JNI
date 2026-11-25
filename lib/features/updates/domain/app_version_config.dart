import '../../../core/domain/json_fields.dart';

final class AppVersionConfig {
  AppVersionConfig({
    required this.currentVersion,
    required this.currentBuild,
    this.apkUrl,
  }) {
    requireNonEmpty(currentVersion, 'La versión');
    if (currentBuild < 1) {
      throw ArgumentError('El número de compilación debe ser positivo.');
    }
    if (apkUrl != null && (apkUrl!.scheme != 'https' || apkUrl!.host.isEmpty)) {
      throw ArgumentError('La URL del APK debe usar HTTPS.');
    }
  }
  factory AppVersionConfig.fromJson(JsonMap json) {
    if (jsonInt(json, 'id') != 1) {
      throw FormatException('Configuración de versión inválida.');
    }
    final url = jsonNullableString(json, 'url_apk');
    return AppVersionConfig(
      currentVersion: jsonString(json, 'version_actual'),
      currentBuild: jsonInt(json, 'build_actual'),
      apkUrl: url == null ? null : Uri.parse(url),
    );
  }
  final String currentVersion;
  final int currentBuild;
  final Uri? apkUrl;
  bool hasUpdateFor(int installedBuild) => currentBuild > installedBuild;
  JsonMap toJson() => {
    'id': 1,
    'version_actual': currentVersion,
    'build_actual': currentBuild,
    'url_apk': apkUrl?.toString(),
  };
}
