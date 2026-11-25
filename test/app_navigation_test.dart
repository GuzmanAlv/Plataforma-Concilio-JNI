import 'package:concilio_jni_dreamrs/app/app.dart';
import 'package:concilio_jni_dreamrs/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_PE'));

  testWidgets('Desktop navigation opens every module without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: ConcilioApp()));
    await tester.pumpAndSettle();
    expect(find.text('Cada sábado cuenta.'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    for (final label in [
      'Integrantes',
      'Tesorería',
      'Inventario',
      'Asistencia & Dashboard',
    ]) {
      await tester.tap(find.widgetWithText(TextButton, label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Grupo Amarillo'), findsOneWidget);
    expect(find.text('Grupo Verde'), findsOneWidget);
    expect(find.text('Grupo Rojo'), findsOneWidget);
    expect(find.text('Grupo Celeste'), findsOneWidget);
  });

  testWidgets(
    'Mobile drawer navigates and offering calculator uses net income',
    (tester) async {
      tester.view.physicalSize = const Size(375, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const ProviderScope(child: ConcilioApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Tesorería'));
      await tester.pumpAndSettle();
      final input = find.byType(TextField);
      await tester.ensureVisible(input);
      await tester.enterText(input, '100.00');
      await tester.pumpAndSettle();
      expect(find.text('Neto de caja: S/ 80.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Narrow mobile preserves usable navigation', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ConcilioApp(),
      ),
    );
    await tester.pumpAndSettle();
    for (final path in ['/integrantes', '/tesoreria', '/inventario']) {
      container.read(appRouterProvider).go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
