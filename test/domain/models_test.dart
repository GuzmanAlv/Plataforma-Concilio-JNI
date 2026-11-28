import 'package:concilio_jni_dreamrs/core/domain/civil_date.dart';
import 'package:concilio_jni_dreamrs/core/domain/money.dart';
import 'package:concilio_jni_dreamrs/features/attendance/domain/attendance.dart';
import 'package:concilio_jni_dreamrs/features/groups/domain/group.dart';
import 'package:concilio_jni_dreamrs/features/inventory/domain/inventory_item.dart';
import 'package:concilio_jni_dreamrs/features/members/domain/member.dart';
import 'package:concilio_jni_dreamrs/features/treasury/domain/treasury.dart';
import 'package:concilio_jni_dreamrs/features/updates/domain/app_version_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exactamente cuatro grupos con identificadores SQL estables', () {
    expect(GroupId.values.map((group) => group.name), [
      'amarillo',
      'verde',
      'rojo',
      'celeste',
    ]);
    expect(() => GroupId.parse('morado'), throwsFormatException);
    final group = Group.fromJson({
      'id': 'amarillo',
      'nombre': 'Grupo Amarillo',
      'activo': false,
    });
    expect(group.name, 'Grupo Amarillo');
    expect(group.active, isFalse);
  });

  test('integrante e historial convierten JSON con fin exclusivo', () {
    final member = Member.fromJson({
      'id': 'joven-1',
      'nombre_completo': 'Ana Pérez',
      'fecha_nacimiento': '2005-01-02',
      'activo': true,
    });
    expect(Member.fromJson(member.toJson()).fullName, 'Ana Pérez');
    expect(member.ageOn(CivilDate(2026, 11, 25)), 21);
    final history = GroupMembership.fromJson({
      'id': 'historia-1',
      'integrante_id': member.id,
      'grupo_id': 'verde',
      'rol': 'lider',
      'fecha_inicio': '2026-11-01',
      'fecha_fin': '2027-01-09',
    });
    expect(history.contains(CivilDate(2026, 11, 1)), isTrue);
    expect(history.contains(CivilDate(2027, 1, 8)), isTrue);
    expect(history.contains(CivilDate(2027, 1, 9)), isFalse);
    expect(history.role, MemberRole.lider);
    expect(
      GroupMembership.fromJson(history.toJson()).endDate,
      CivilDate(2027, 1, 9),
    );
  });

  test('payload de asistencia deduplica presentes y valida sábado', () {
    final submission = AttendanceSubmission(
      groupId: GroupId.rojo,
      date: CivilDate(2026, 11, 7),
      presentMemberIds: ['a', 'a', 'b'],
    );
    expect(submission.toRpcParams(), {
      'p_grupo_id': 'rojo',
      'p_fecha': '2026-11-07',
      'p_presentes': ['a', 'b'],
    });
    expect(() => submission.presentMemberIds.add('c'), throwsUnsupportedError);
    expect(
      () => AttendanceSubmission(
        groupId: GroupId.rojo,
        date: CivilDate(2026, 11, 8),
        presentMemberIds: [],
      ),
      throwsArgumentError,
    );
  });

  test(
    'caja suma solo netos, resta egresos y excluye campos generados al escribir',
    () {
      final offering = Offering.fromJson({
        'id': 'ofrenda-1',
        'fecha_caja': '2026-11-28',
        'mes': '2026-11-01',
        'monto_bruto': 100,
        'aporte_distrito': '10.00',
        'colaboracion_fija': '10.00',
        'monto_neto': '80.00',
      });
      final expense = Expense.fromJson({
        'id': 'egreso-1',
        'fecha': '2026-11-08',
        'monto': '25.50',
        'concepto': 'Materiales',
        'comprobante_path': 'egreso-1/boleta.jpg',
      });
      final settings = CashSettings(initialBalance: Money.parse('50.00'));
      expect(
        settings.balance(offerings: [offering], expenses: [expense]).decimal,
        '104.50',
      );
      expect(offering.toJson()['mes'], '2026-11-01');
      expect(
        Expense.fromJson(expense.toJson()).receiptPath,
        'egreso-1/boleta.jpg',
      );
      expect(
        () => Offering.fromJson({...offering.toJson(), 'monto_neto': '100.00'}),
        throwsArgumentError,
      );
    },
  );

  test('inventario y versión APK validan contratos extensibles', () {
    final item = InventoryItem.fromJson({
      'id': 'item-1',
      'nombre': 'Sillas',
      'cantidad': 12,
      'estado': 'bueno',
      'observaciones': '',
    });
    expect(InventoryItem.fromJson(item.toJson()).quantity, 12);
    final config = AppVersionConfig.fromJson({
      'id': 1,
      'version_actual': '0.2.0',
      'build_actual': 2,
      'url_apk': 'https://example.org/dreamrs.apk',
    });
    expect(config.hasUpdateFor(1), isTrue);
    expect(config.hasUpdateFor(2), isFalse);
    expect(
      () => AppVersionConfig(
        currentVersion: '0.2.0',
        currentBuild: 2,
        apkUrl: Uri.parse('http://example.org/app.apk'),
      ),
      throwsArgumentError,
    );
  });
}
