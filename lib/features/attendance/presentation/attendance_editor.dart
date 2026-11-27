import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/widgets/async_panel.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../groups/domain/group.dart';
import '../application/attendance_providers.dart';
import '../application/attendance_sheet_provider.dart';
import '../data/supabase_attendance_repository.dart';
import '../domain/attendance.dart';

class AttendanceEditor extends ConsumerStatefulWidget {
  const AttendanceEditor({
    required this.date,
    required this.group,
    this.onSave,
    super.key,
  });
  final CivilDate date;
  final GroupId group;
  final Future<void> Function(AttendanceSubmission)? onSave;
  @override
  ConsumerState<AttendanceEditor> createState() => _AttendanceEditorState();
}

class _AttendanceEditorState extends ConsumerState<AttendanceEditor> {
  Set<String>? _present;
  bool _busy = false;
  String? _error;
  Future<void> _save() async {
    final client = ref.read(supabaseClientProvider);
    if (_busy ||
        (client == null && widget.onSave == null) ||
        _present == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final submission = AttendanceSubmission(
        groupId: widget.group,
        date: widget.date,
        presentMemberIds: _present!,
      );
      if (widget.onSave != null) {
        await widget.onSave!(submission);
      } else {
        await SupabaseAttendanceRepository(client!).save(submission);
      }
      ref.invalidate(attendanceSheetProvider);
      ref.invalidate(attendanceSummaryProvider);
      ref.invalidate(dashboardInsightsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar. Revisa tu conexión y vuelve a abrir la lista si hubo cambios de grupo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = attendanceSheetProvider((
      date: widget.date,
      group: widget.group,
    ));
    final sheetValue = ref.watch(provider);
    if (_present == null && sheetValue.asData != null) {
      _present = {...sheetValue.asData!.value.present};
    }
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          '${widget.group.groupName}\n${DateFormat('d MMMM yyyy', 'es_PE').format(widget.date.toDateTime())}',
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: AsyncPanel(
              value: sheetValue,
              onRetry: () => ref.invalidate(provider),
              builder: (sheet) {
                _present ??= {...sheet.present};
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      sheet.saved
                          ? 'Corrige las marcas y guarda sobre el mismo sábado.'
                          : 'Marca a los presentes. Las personas sin marca quedarán ausentes.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_present!.length} presentes de ${sheet.roster.length} convocados',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _present = sheet.roster
                                      .map((e) => e.member.id)
                                      .toSet(),
                                ),
                          child: const Text('Marcar todos'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _present = {}),
                          child: const Text('Desmarcar todos'),
                        ),
                      ],
                    ),
                    if (sheet.roster.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hay integrantes asignados a este grupo en esta fecha. Al guardar se registrará una sesión sin convocados.',
                        ),
                      ),
                    ...sheet.roster.map(
                      (e) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.member.fullName),
                        subtitle: Text(e.membership!.role.label),
                        value: _present!.contains(e.member.id),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _present!.add(e.member.id);
                                } else {
                                  _present!.remove(e.member.id);
                                }
                              }),
                      ),
                    ),
                    if (ref.watch(supabaseClientProvider) == null &&
                        widget.onSave == null)
                      const Text(
                        'Vista previa: conecta Supabase para guardar.',
                      ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed:
                _busy ||
                    _present == null ||
                    (ref.watch(supabaseClientProvider) == null &&
                        widget.onSave == null)
                ? null
                : _save,
            child: Text(_busy ? 'Guardando…' : 'Guardar asistencia'),
          ),
        ],
      ),
    );
  }
}
