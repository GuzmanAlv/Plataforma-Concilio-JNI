// Export the existing code-native navbar emblem; no image service is involved.
// Run: flutter test tool/generate_app_icons.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concilio_jni_dreamrs/shared/widgets/dreamrs_mark.dart';

Future<void> exportIcon(
  String path,
  int size, {
  bool fullBleed = false,
  bool foreground = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  if (!foreground) {
    final paint = Paint()..color = DreamrsMark.color;
    if (fullBleed) {
      canvas.drawRect(rect, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(size * DreamrsMark.cornerRatio),
        ),
        paint,
      );
    }
  }
  final symbol = DreamrsMark.symbol;
  final text = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(symbol.codePoint),
      style: TextStyle(
        fontFamily: symbol.fontFamily,
        fontSize: size * DreamrsMark.symbolRatio,
        height: 1,
        color: Colors.white,
      ),
    ),
  )..layout();
  text.paint(canvas, Offset((size - text.width) / 2, (size - text.height) / 2));
  text.dispose();
  final picture = recorder.endRecording();
  final raster = await picture.toImage(size, size);
  final png = await raster.toByteData(format: ui.ImageByteFormat.png);
  final target = File(path);
  await target.parent.create(recursive: true);
  await target.writeAsBytes(png!.buffer.asUint8List());
  raster.dispose();
  picture.dispose();
}

void main() {
  testWidgets(
    'Export navbar emblem to Android, favicon and installed web icons',
    (tester) async {
      await tester.runAsync(() async {
        final configFile = File('.dart_tool/package_config.json').absolute;
        final config =
            jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
        final package = (config['packages'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['name'] == 'flutter');
        final flutterRoot = Directory.fromUri(
          configFile.uri.resolve(package['rootUri'] as String),
        ).uri;
        final fontFile = File.fromUri(
          flutterRoot.resolve(
            '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ),
        );
        final font = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(ByteData.sublistView(await fontFile.readAsBytes())),
          );
        await font.load();
        await exportIcon('web/favicon.png', 32);
      await exportIcon('web/icons/apple-touch-icon.png', 180, fullBleed: true);
        for (final size in [192, 512]) {
          await exportIcon('web/icons/Icon-$size.png', size);
          await exportIcon(
            'web/icons/Icon-maskable-$size.png',
            size,
            fullBleed: true,
          );
        }
        for (final entry in {
          'mdpi': 48,
          'hdpi': 72,
          'xhdpi': 96,
          'xxhdpi': 144,
          'xxxhdpi': 192,
        }.entries) {
          await exportIcon(
            'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
            entry.value,
          );
        }
        // Android's foreground is a 108dp layer, rendered here at xxxhdpi.
        await exportIcon(
          'android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png',
          432,
          foreground: true,
        );
      });
    },
  );
}
