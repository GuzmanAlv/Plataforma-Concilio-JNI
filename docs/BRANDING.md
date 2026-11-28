# Ícono de DREAMRS

El símbolo del navbar se define en `lib/shared/widgets/dreamrs_mark.dart`: fondo morado y el mismo glifo Material `auto_awesome` blanco. Se conservan las proporciones del navbar original (38 px, símbolo de 22 px y esquinas de 12 px).

Los íconos se exportan desde esas constantes usando el motor de Flutter y su fuente Material Icons, sin dependencias nuevas ni imágenes aproximadas.

```powershell
flutter test tool/generate_app_icons.dart
```

El generador actualiza:

- Favicon de 32 px.
- Íconos Web de 192 y 512 px y sus versiones maskable con fondo opaco.
- Apple touch icon de 180 px, opaco para que el sistema aplique su máscara.
- Íconos Android mdpi, hdpi, xhdpi, xxhdpi y xxxhdpi.
- Capa transparente de primer plano del ícono adaptativo Android, con el mismo símbolo blanco. El fondo del recurso adaptativo es `dreamrs_icon_background`, definido en `colors.xml`.

El recurso adaptativo mantiene el símbolo centrado dentro de la zona segura de las máscaras del launcher, según la [guía oficial de íconos adaptativos](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive). Si cambia el color de marca, también debe actualizarse el color de fondo del recurso Android y los colores de tema en `web/index.html` y `web/manifest.json`.

El favicon tiene una versión en su URL para evitar reutilizar el antiguo ícono de Flutter. Los cambios de launcher requieren reconstruir e instalar la aplicación; no se aplican mediante hot reload.
