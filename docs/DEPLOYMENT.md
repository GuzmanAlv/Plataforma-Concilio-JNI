# Web y Android

La aplicación comparte el código Dart entre la Web responsiva y Android. Esta base fija Flutter **3.44.4 / Dart 3.12.2** en Render y GitHub Actions; `pubspec.lock` se versiona para repetir la resolución de paquetes.

## Ejecutar localmente

1. Instalar Flutter 3.44.4. Para Android, instalar Android Studio, SDK y JDK compatibles y revisar `flutter doctor`.
2. Ejecutar `flutter pub get --enforce-lockfile`.
3. Crear `config/local.json` con la URL del proyecto Supabase y su clave **publishable** (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`). Este archivo está excluido de Git.
4. Aplicar la migración y crear un usuario autorizado según [SUPABASE.md](SUPABASE.md).

```powershell
flutter run -d chrome --dart-define-from-file=config/local.json
flutter run -d android --dart-define-from-file=config/local.json
```

Para Android, sustituir `android` por el identificador que devuelve `flutter devices` si no hay un dispositivo con ese nombre. Sin configuración Supabase, la aplicación permite revisar la base de navegación con los estados iniciales definidos; no se conecta a una base real.

Las variables `--dart-define` se incorporan al binario y al JavaScript publicado. Usar exclusivamente la URL y la clave pública del proyecto; la autorización de datos depende de Auth, perfiles y RLS. Cambiar estos valores requiere volver a compilar.

## Render Static Site

`render.yaml` declara un **Static Site**, el comando `bash scripts/render-build.sh`, la carpeta `build/web` y las dos variables a completar en Render. El script obtiene la versión fijada de Flutter y crea un build Web de producción con los recursos gráficos del motor servidos desde el propio sitio.

1. Conectar `GuzmanAlv/Plataforma-Concilio-JNI` en Render y crear un Blueprint desde `render.yaml`.
2. Elegir la rama que contiene esta base y completar `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` con los valores de Supabase.
3. Revisar el plan y crear el sitio. No se requiere un servidor Dart en ejecución.
4. En Supabase Auth, configurar la URL HTTPS del sitio y las URL de redirección que se utilicen para autenticación o recuperación de cuenta.
5. Probar en el sitio publicado `/`, las rutas de los módulos y la recarga directa de una ruta interna.

La regla `/* → /index.html` es un **rewrite** para que el router de Flutter resuelva las rutas al recargar. Los archivos existentes se sirven normalmente. La configuración sigue la [referencia de Blueprints](https://render.com/docs/blueprint-spec) y las [reglas SPA de Render](https://render.com/docs/redirects-rewrites).

El Blueprint establece `autoDeployTrigger: checksPass`: los cambios se despliegan cuando pasan las verificaciones de GitHub de la rama conectada. El primer despliegue se inicia al crear el sitio. Si se configura manualmente un Static Site, copiar también el rewrite y las cabeceras del YAML.

Los recursos tienen `Cache-Control: no-cache` para que el navegador los revalide. Esto facilita actualizar el código cuando el SDK produce nombres de archivo sin hash. Una pestaña abierta necesita recargarse para recibir un nuevo build. No se promete uso sin conexión. El proceso estándar genera los archivos distribuibles en `build/web`, según la [guía Web de Flutter](https://docs.flutter.dev/deployment/web).

## Navegadores móviles e iPhone

Abrir la URL HTTPS de Render en Safari o Chrome móvil. La Web usa `viewport-fit=cover`, orientación libre y los espacios seguros de Flutter para adaptarse al dispositivo. En iPhone se puede añadir el enlace a la pantalla de inicio desde Safari. Un APK es exclusivo de Android; los usuarios de iPhone acceden por la Web.

Antes de publicar, verificar en Safari/iPhone y Chrome/Android: navegación y Drawer, teclado y formularios, recarga de rutas internas, sesión, permisos de cuenta y selección/carga de una imagen. La base de esta entrega prepara esos puntos; las pantallas y flujos de carga se validan al completarlos.

## APK de desarrollo

```powershell
flutter build apk --debug --dart-define-from-file=config/local.json
```

Resultado: `build/app/outputs/flutter-apk/app-debug.apk`. Está firmado con la clave de desarrollo y sirve para pruebas. El artefacto `android-debug-preview` de GitHub Actions se compila sin credenciales para revisar la base; no se conecta al proyecto real.

Si Flutter informa licencias del SDK pendientes, una persona debe revisar y aceptar las condiciones mediante `flutter doctor --android-licenses`, después repetir `flutter doctor`. El proceso de esta entrega no acepta condiciones de licencia en nombre del propietario.

## APK firmado para distribución

La variante `release` exige una clave propia y nunca utiliza la clave `debug` por defecto. Conservar la misma clave y el mismo `applicationId` para instalar futuras actualizaciones sobre la aplicación existente.

1. Crear una clave de distribución fuera del repositorio, por ejemplo con `keytool`:

```powershell
keytool -genkeypair -v -keystore C:/Claves/concilio-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias concilio
```

2. Crear `android/key.properties` localmente. El archivo y los keystores están excluidos de Git:

```properties
storeFile=C:/Claves/concilio-release.jks
storePassword=REEMPLAZAR_LOCALMENTE
keyAlias=concilio
keyPassword=REEMPLAZAR_LOCALMENTE
```

3. Compilar con un número de build mayor al de la distribución anterior:

```powershell
flutter build apk --release --build-name=0.1.0 --build-number=1 --dart-define-from-file=config/local.json
```

Resultado: `build/app/outputs/flutter-apk/app-release.apk`. Respaldar la clave de firma en un lugar seguro. La configuración sigue la [guía Android de Flutter](https://docs.flutter.dev/deployment/android).

## Distribución y control de versiones

Publicar el APK firmado en una ubicación HTTPS con URL de descarga directa, por ejemplo un asset de GitHub Releases. Validar primero su descarga y actualización en un Android de prueba. Después actualizar, como administrador, la fila única de `configuracion_app` en Supabase:

```sql
update public.configuracion_app
set version_actual = '0.1.0',
    build_actual = 1,
    url_apk = 'https://github.com/GuzmanAlv/Plataforma-Concilio-JNI/releases/download/v0.1.0/app-release.apk'
where id = 1;
```

La URL de ejemplo presupone que ese release y ese asset ya fueron publicados. `build_actual` permite comparar versiones sin ordenar cadenas. El esquema y el modelo quedan listos para añadir el aviso de actualización en Android; esta entrega no implementa instalación automática. Android pide al usuario autorizar la instalación desde su navegador o gestor de archivos.

## Verificaciones en GitHub

`.github/workflows/flutter.yml` ejecuta formato, análisis, pruebas y compilación Web, además de compilar un APK de desarrollo en un job independiente. Los artefactos duran siete días. La publicación en Render y la distribución de un APK firmado requieren configurar los servicios y la clave del propietario; el workflow no publica releases ni usa claves de firma.
