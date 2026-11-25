import 'dart:math';

import 'package:concilio_jni_dreamrs/core/domain/json_fields.dart';
import 'package:concilio_jni_dreamrs/core/supabase/pagination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'carga más de mil filas incluso con un límite servidor menor al solicitado',
    () async {
      final source = List<JsonMap>.generate(1407, (index) => {'id': index});
      var requests = 0;
      final rows = await loadAllRows((from, to) async {
        requests++;
        final until = min(source.length, min(to + 1, from + 170));
        return source.sublist(from, until);
      });
      expect(rows.length, 1407);
      expect(rows.map((row) => row['id']).toSet().length, 1407);
      expect(rows.last['id'], 1406);
      expect(requests, 10);
    },
  );

  test(
    'un error de página no devuelve resultados incompletos como éxito',
    () async {
      final result = loadAllRows((from, to) async {
        if (from != 0) throw StateError('Conexión perdida');
        return [
          {'id': 1},
        ];
      });
      await expectLater(result, throwsStateError);
    },
  );
}
