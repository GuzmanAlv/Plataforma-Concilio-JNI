import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../../shared/widgets/civil_date_field.dart';
import '../../../shared/widgets/styled_select.dart';
import '../../groups/domain/group.dart';
import '../domain/member.dart';
import '../data/supabase_members_repository.dart';

typedef CreateMember =
    Future<void> Function(
      String name,
      CivilDate birthDate,
      GroupId group,
      MemberRole role,
      CivilDate startDate,
    );

class NewMemberDialog extends StatefulWidget {
  const NewMemberDialog({this.onSave, this.initialEntry, super.key});
  final CreateMember? onSave;
  final MemberDirectoryEntry? initialEntry;
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
  bool get _editing => widget.initialEntry != null;
  bool get _assignmentChanged =>
      _editing &&
      (_group != widget.initialEntry!.membership?.groupId ||
          _role != widget.initialEntry!.membership?.role);

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    if (entry != null) {
      _name.text = entry.member.fullName;
      _birth.text = DateFormat(
        'dd/MM/yyyy',
      ).format(entry.member.birthDate.toDateTime());
      _group = entry.membership?.groupId ?? GroupId.amarillo;
      _role = entry.membership?.role ?? MemberRole.integrante;
      var effective = CivilDate.today();
      if (effective < CouncilPeriod.official.start) {
        effective = CouncilPeriod.official.start;
      }
      if (effective > CouncilPeriod.official.end) {
        effective = CouncilPeriod.official.end;
      }
      _start.text = DateFormat('dd/MM/yyyy').format(effective.toDateTime());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _birth.dispose();
    _start.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate() || widget.onSave == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave!(
        _name.text.trim(),
        parseDisplayDate(_birth.text)!,
        _group,
        _role,
        parseDisplayDate(_start.text)!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar. Revisa la conexión y la fecha del cambio de grupo. Cierra y revisa el listado antes de reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
        color: AppTheme.purple,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final today = CivilDate.today();
    final birth = parseDisplayDate(_birth.text);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.person_outline_rounded, color: AppTheme.purple),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_editing ? 'Editar integrante' : 'Nuevo integrante'),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2EFFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _editing
                          ? 'Actualiza sus datos. Los cambios de grupo conservan el historial.'
                          : 'Completa sus datos personales y asigna su grupo.',
                      style: const TextStyle(color: AppTheme.purple),
                    ),
                  ),
                  if (widget.onSave == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Vista previa. Conecta Supabase para guardar integrantes.',
                      ),
                    ),
                  _heading('DATOS PERSONALES'),
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Escribe el nombre completo.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CivilDateField(
                    controller: _birth,
                    label: 'Fecha de nacimiento',
                    first: CivilDate(1900, 1, 1),
                    last: today,
                    enabled: !_busy,
                    yearFirst: true,
                    onChanged: () => setState(() {}),
                  ),
                  if (birth != null && birth <= today)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Edad actual: ${birth.ageOn(today)} años',
                        style: const TextStyle(
                          color: AppTheme.purple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _heading('ASIGNACIÓN DE GRUPO'),
                  StyledSelect<GroupId>(
                    value: _group,
                    label: 'Grupo',
                    icon: Icons.groups_outlined,
                    items: GroupId.values
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: AppTheme.groupColors[g.name],
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(g.groupName)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (g) => setState(() => _group = g!),
                  ),
                  const SizedBox(height: 16),
                  StyledSelect<MemberRole>(
                    value: _role,
                    label: 'Rol',
                    icon: Icons.workspace_premium_outlined,
                    items: MemberRole.values
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.label)),
                        )
                        .toList(),
                    onChanged: _busy ? null : (r) => setState(() => _role = r!),
                  ),
                  const SizedBox(height: 16),
                  if (!_editing || _assignmentChanged)
                    CivilDateField(
                      controller: _start,
                      label: _editing
                          ? 'Fecha efectiva del cambio'
                          : 'Fecha de ingreso al grupo',
                      first: CouncilPeriod.official.start,
                      last: _editing && today < CouncilPeriod.official.end
                          ? today
                          : CouncilPeriod.official.end,
                      enabled: !_busy,
                      helper: _editing
                          ? 'El cambio debe ser posterior al inicio de su asignación actual. Las asistencias guardadas se conservan.'
                          : 'Desde esta fecha figurará en las asistencias.',
                      validator: (value) {
                        final date = parseDisplayDate(value ?? '');
                        if (date == null ||
                            !CouncilPeriod.official.contains(date) ||
                            (_editing && date > today)) {
                          return 'Indica una fecha válida del ciclo, sin cambios futuros.';
                        }
                        final current = widget.initialEntry?.membership;
                        if (_assignmentChanged &&
                            current != null &&
                            date <= current.startDate) {
                          return 'Usa una fecha posterior al inicio de su asignación actual.';
                        }
                        return null;
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
          FilledButton.icon(
            onPressed: _busy || widget.onSave == null ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(
              _busy
                  ? 'Guardando…'
                  : _editing
                  ? 'Guardar cambios'
                  : 'Guardar integrante',
            ),
          ),
        ],
      ),
    );
  }
}
