import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../groups/domain/group.dart';
import '../domain/member.dart';

typedef CreateMember =
    Future<void> Function(
      String name,
      CivilDate birthDate,
      GroupId group,
      MemberRole role,
      CivilDate startDate,
    );

class NewMemberDialog extends StatefulWidget {
  const NewMemberDialog({this.onSave, super.key});
  final CreateMember? onSave;
  @override
  State<NewMemberDialog> createState() => _NewMemberDialogState();
}

class _NewMemberDialogState extends State<NewMemberDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _birth = TextEditingController();
  final _start = TextEditingController(text: '01/11/2026');
  GroupId _group = GroupId.amarillo;
  MemberRole _role = MemberRole.integrante;
  bool _busy = false;
  String? _error;
  CivilDate? _parse(String value) {
    try {
      return CivilDate.fromDateTime(
        DateFormat('dd/MM/yyyy').parseStrict(value),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _birth.dispose();
    _start.dispose();
    super.dispose();
  }

  Future<void> _pick(
    TextEditingController controller, {
    required bool birth,
  }) async {
    final period = CouncilPeriod.official;
    final today = CivilDate.today();
    final first = birth ? CivilDate(1900, 1, 1) : period.start;
    final last = birth ? today : period.end;
    var initial =
        _parse(controller.text) ??
        (birth ? CivilDate(2005, 1, 1) : period.start);
    if (initial < first) initial = first;
    if (initial > last) initial = last;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.toDateTime(),
      firstDate: first.toDateTime(),
      lastDate: last.toDateTime(),
    );
    if (date != null && mounted)
      setState(() => controller.text = DateFormat('dd/MM/yyyy').format(date));
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_form.currentState!.validate() || widget.onSave == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave!(
        _name.text.trim(),
        _parse(_birth.text)!,
        _group,
        _role,
        _parse(_start.text)!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'No se pudo confirmar el registro. Revisa la conexión, tus permisos y el listado antes de volver a enviarlo.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final birth = _parse(_birth.text);
    final today = CivilDate.today();
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Nuevo integrante'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.onSave == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Vista previa del formulario. Conecta Supabase para guardar integrantes.',
                      ),
                    ),
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Escribe el nombre completo.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _birth,
                    enabled: !_busy,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: 'Fecha de nacimiento',
                      hintText: 'dd/mm/aaaa',
                      suffixIcon: IconButton(
                        onPressed: _busy
                            ? null
                            : () => _pick(_birth, birth: true),
                        icon: const Icon(Icons.calendar_month),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final date = _parse(v ?? '');
                      return date == null ||
                              date < CivilDate(1900, 1, 1) ||
                              date > today
                          ? 'Ingresa una fecha válida, sin fechas futuras.'
                          : null;
                    },
                  ),
                  if (birth != null && birth <= today)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Edad actual: ${birth.ageOn(today)} años'),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<GroupId>(
                    initialValue: _group,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Grupo'),
                    items: GroupId.values
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(g.groupName),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (g) => setState(() => _group = g!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<MemberRole>(
                    initialValue: _role,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: MemberRole.values
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.label)),
                        )
                        .toList(),
                    onChanged: _busy ? null : (r) => setState(() => _role = r!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _start,
                    enabled: !_busy,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: 'Fecha de ingreso al grupo',
                      hintText: 'dd/mm/aaaa',
                      helperText:
                          'Desde esta fecha figurará en las asistencias.',
                      suffixIcon: IconButton(
                        onPressed: _busy
                            ? null
                            : () => _pick(_start, birth: false),
                        icon: const Icon(Icons.calendar_month),
                      ),
                    ),
                    validator: (v) {
                      final date = _parse(v ?? '');
                      return date == null ||
                              !CouncilPeriod.official.contains(date)
                          ? 'Usa una fecha de noviembre 2026 a octubre 2027.'
                          : null;
                    },
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _busy || widget.onSave == null ? null : _save,
            child: Text(_busy ? 'Guardando…' : 'Guardar integrante'),
          ),
        ],
      ),
    );
  }
}
