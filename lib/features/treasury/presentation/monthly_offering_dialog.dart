import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/domain/money.dart';
import '../../../shared/widgets/styled_select.dart';
import '../domain/treasury.dart';

class MonthlyOfferingDialog extends StatefulWidget {
  const MonthlyOfferingDialog({
    required this.months,
    this.initialMonth,
    this.onSave,
    super.key,
  });
  final List<OfferingMonth> months;
  final CivilDate? initialMonth;
  final Future<void> Function(OfferingMonth month, Money gross, String reason)?
  onSave;
  @override
  State<MonthlyOfferingDialog> createState() => _MonthlyOfferingDialogState();
}

class _MonthlyOfferingDialogState extends State<MonthlyOfferingDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  late OfferingMonth _month;
  bool _busy = false;
  bool _locked = false;
  String? _error;
  String? _validate(String? text) {
    final input = (text ?? '').trim();
    if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(input)) {
      return 'Ingresa un monto con hasta dos decimales.';
    }
    try {
      final gross = Money.parse(input.replaceAll(',', '.'));
      if (gross.cents <= 0 || gross.cents > 999999999999) {
        return 'Ingresa un monto mayor a cero y menor a S/ 10 mil millones.';
      }
    } catch (_) {
      return 'Ingresa un monto válido.';
    }
    return null;
  }

  OfferingBreakdown? get _breakdown => _validate(_amount.text) == null
      ? OfferingBreakdown(Money.parse(_amount.text.trim().replaceAll(',', '.')))
      : null;
  bool get _adjusted =>
      _month.saturdayCount > 0 &&
      _breakdown != null &&
      _breakdown!.gross != _month.saturdayTotal;
  bool get _future =>
      _month.month >
      CivilDate(CivilDate.today().year, CivilDate.today().month, 1);
  void _load(OfferingMonth month) {
    _month = month;
    final gross = month.needsReview
        ? month.saturdayTotal
        : month.confirmed?.gross ?? month.saturdayTotal;
    _amount.text = gross.cents > 0 ? gross.decimal : '';
    _reason.text = month.reason;
  }

  @override
  void initState() {
    super.initState();
    final today = CivilDate.today();
    _load(
      widget.months
              .where(
                (m) =>
                    m.month == widget.initialMonth ||
                    (widget.initialMonth == null &&
                        m.month.year == today.year &&
                        m.month.month == today.month),
              )
              .firstOrNull ??
          widget.months.first,
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy ||
        _future ||
        widget.onSave == null ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _locked = true;
      _error = null;
    });
    try {
      await widget.onSave!(_month, _breakdown!.gross, _reason.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo confirmar. Si otro usuario cambió los sábados o el cierre, cierra este formulario y vuelve a abrirlo con los datos actualizados. Si fue un fallo de red, puedes reintentar el mismo envío.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _breakdown;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Ofrenda mensual'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Revisa el acumulado, ajusta el total si es necesario y confirma. Solo este neto mensual se suma a caja.',
                  ),
                  const SizedBox(height: 20),
                  StyledSelect<CivilDate>(
                    label: 'Mes de la ofrenda',
                    value: _month.month,
                    icon: Icons.calendar_month_outlined,
                    items: widget.months
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.month,
                            child: Text(
                              toBeginningOfSentenceCase(
                                DateFormat(
                                  'MMMM yyyy',
                                  'es_PE',
                                ).format(m.month.toDateTime()),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _locked
                        ? null
                        : (month) => setState(
                            () => _load(
                              widget.months.firstWhere((m) => m.month == month),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2EFFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acumulado de sábados: ${_month.saturdayTotal.formatted}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6354D9),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_month.saturdayCount} sábados registrados · ${_month.confirmed == null
                              ? 'Pendiente de confirmar'
                              : _month.needsReview
                              ? 'Cierre con cambios por revisar'
                              : 'Cierre confirmado'}',
                        ),
                        if (_month.confirmed != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Total confirmado anterior: ${_month.confirmed!.gross.formatted}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amount,
                    enabled: !_locked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto bruto mensual',
                      prefixText: 'S/ ',
                      helperText:
                          'Puedes registrar el total directamente o usar la suma de los sábados.',
                      helperMaxLines: 3,
                    ),
                    validator: _validate,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_month.saturdayCount > 0 && !_locked)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () => _amount.text = _month.saturdayTotal.decimal,
                        ),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Usar acumulado de sábados'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reason,
                    enabled: !_locked,
                    maxLength: 300,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: _adjusted
                          ? 'Motivo del ajuste (obligatorio)'
                          : 'Observación (opcional)',
                    ),
                    validator: (text) =>
                        _adjusted && (text?.trim().length ?? 0) < 3
                        ? 'Explica la diferencia respecto al acumulado.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F6FC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Desglose mensual',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Distrito (10%): ${breakdown?.district.formatted ?? '—'}',
                        ),
                        const SizedBox(height: 8),
                        const Text('Colaboración del mes: S/ 10.00'),
                        const Divider(height: 24),
                        Text(
                          'Neto de caja: ${breakdown?.net.formatted ?? '—'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6354D9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Los meses con sábados pendientes también pueden confirmarse con un total revisado. Si luego cambian las ofrendas sabatinas, el cierre se marcará para revisión.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF79718D)),
                  ),
                  if (breakdown?.net.isNegative == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'El total no cubre los aportes y el neto mensual es negativo.',
                      ),
                    ),
                  if (_future)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Puedes consultar este mes, pero no confirmar meses futuros.',
                      ),
                    ),
                  if (widget.onSave == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Vista previa: conecta Supabase para confirmar.',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
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
            onPressed: _busy || _future || widget.onSave == null ? null : _save,
            child: Text(
              _busy
                  ? 'Confirmando…'
                  : _error != null
                  ? 'Reintentar confirmación'
                  : 'Confirmar mes',
            ),
          ),
        ],
      ),
    );
  }
}
