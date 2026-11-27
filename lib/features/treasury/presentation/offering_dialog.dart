import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../../core/domain/money.dart';
import '../domain/treasury.dart';

class OfferingDialog extends StatefulWidget {
  const OfferingDialog({
    required this.offerings,
    this.onSave,
    this.initialDate,
    this.initialAmount,
    super.key,
  });
  final List<Offering> offerings;
  final Future<void> Function(CivilDate, Money)? onSave;
  final CivilDate? initialDate;
  final Money? initialAmount;
  @override
  State<OfferingDialog> createState() => _OfferingDialogState();
}

class _OfferingDialogState extends State<OfferingDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late CivilDate _date;
  bool _busy = false;
  bool _locked = false;
  String? _error;
  Offering? get _existing =>
      widget.offerings.where((o) => o.date == _date).firstOrNull;
  OfferingBreakdown? get _breakdown {
    if (_validateAmount(_amount.text) != null) return null;
    return OfferingBreakdown(
      Money.parse(_amount.text.trim().replaceAll(',', '.')),
    );
  }

  @override
  void initState() {
    super.initState();
    final days = CouncilPeriod.official.saturdays;
    _date =
        widget.initialDate ??
        days.where((d) => d >= CivilDate.today()).firstOrNull ??
        days.last;
    _amount.text = (_existing?.gross ?? widget.initialAmount)?.decimal ?? '';
  }

  String? _validateAmount(String? value) {
    final input = (value ?? '').trim();
    if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(input)) {
      return 'Ingresa un monto con hasta dos decimales.';
    }
    try {
      final cents = Money.parse(input.replaceAll(',', '.')).cents;
      if (cents <= 0 || cents > 999999999999) {
        return 'Ingresa un monto mayor a cero y menor a S/ 10 mil millones.';
      }
    } catch (_) {
      return 'Ingresa un monto válido.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy || widget.onSave == null || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _locked = true;
      _error = null;
    });
    try {
      await widget.onSave!(_date, _breakdown!.gross);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo confirmar el guardado. Reintenta el mismo envío o cierra y revisa los movimientos.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _breakdown;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          _existing == null ? 'Registrar ofrenda' : 'Corregir ofrenda',
        ),
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
                        'Vista previa. Conecta Supabase para guardar la ofrenda.',
                      ),
                    ),
                  DropdownButtonFormField<CivilDate>(
                    key: ValueKey(_date),
                    initialValue: _date,
                    isExpanded: true,
                    menuMaxHeight: 360,
                    decoration: const InputDecoration(
                      labelText: 'Fecha del sábado',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    items: CouncilPeriod.official.saturdays
                        .map(
                          (day) => DropdownMenuItem(
                            value: day,
                            child: Text(
                              DateFormat(
                                'EEE d MMM yyyy',
                                'es_PE',
                              ).format(day.toDateTime()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _locked
                        ? null
                        : (day) {
                            if (day != null) {
                              setState(() {
                                _date = day;
                                _amount.text =
                                    (_existing?.gross ?? widget.initialAmount)
                                        ?.decimal ??
                                    '';
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  if (_existing != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Este sábado ya tiene una ofrenda de ${_existing!.gross.formatted}. Al guardar se actualizará el mismo registro.',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _amount,
                    enabled: !_locked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto bruto recogido',
                      prefixText: 'S/ ',
                    ),
                    validator: _validateAmount,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),
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
                          'Desglose de la ofrenda',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Distrito (10%): ${breakdown?.district.formatted ?? '—'}',
                        ),
                        const SizedBox(height: 8),
                        const Text('Colaboración fija: S/ 10.00'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(),
                        ),
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
                  if (breakdown?.net.isNegative == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'El neto es negativo porque el monto recogido no cubre el aporte al distrito y la colaboración fija.',
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
            onPressed: _busy || widget.onSave == null ? null : _save,
            child: Text(
              _busy
                  ? 'Guardando…'
                  : _error != null
                  ? 'Reintentar guardado'
                  : _existing == null
                  ? 'Guardar ofrenda'
                  : 'Guardar corrección',
            ),
          ),
        ],
      ),
    );
  }
}
