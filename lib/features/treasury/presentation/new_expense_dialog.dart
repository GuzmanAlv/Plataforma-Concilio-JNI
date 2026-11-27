import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/civil_date.dart';
import '../../../core/domain/council_period.dart';
import '../../../core/domain/money.dart';

class ExpensePhoto {
  const ExpensePhoto(this.bytes, this.mimeType, this.filename);
  final Uint8List bytes;
  final String mimeType;
  final String filename;
}

class ExpenseDraft {
  const ExpenseDraft({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    required this.amount,
    this.photo,
  });
  final String id;
  final String name;
  final String description;
  final CivilDate date;
  final Money amount;
  final ExpensePhoto? photo;
}

class NewExpenseDialog extends StatefulWidget {
  const NewExpenseDialog({this.onSave, this.pickPhoto, super.key});
  final Future<void> Function(ExpenseDraft)? onSave;
  final Future<XFile?> Function()? pickPhoto;
  @override
  State<NewExpenseDialog> createState() => _NewExpenseDialogState();
}

class _NewExpenseDialogState extends State<NewExpenseDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _date = TextEditingController();
  final _id = const Uuid().v4();
  bool _busy = false;
  bool _picking = false;
  bool _locked = false;
  String? _error;
  String? _photoError;
  ExpensePhoto? _photo;
  bool get _editable => !_busy && !_locked && !_picking;

  @override
  void initState() {
    super.initState();
    final period = CouncilPeriod.official;
    var today = CivilDate.today();
    if (today < period.start) today = period.start;
    if (today > period.end) today = period.end;
    _date.text = DateFormat('dd/MM/yyyy').format(today.toDateTime());
  }

  CivilDate? _parseDate(String value) {
    try {
      return CivilDate.fromDateTime(
        DateFormat('dd/MM/yyyy').parseStrict(value),
      );
    } catch (_) {
      return null;
    }
  }

  String? _validateAmount(String? value) {
    final input = (value ?? '').trim();
    if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(input)) {
      return 'Usa un monto con hasta dos decimales.';
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

  Future<void> _pickDate() async {
    final period = CouncilPeriod.official;
    final parsed = _parseDate(_date.text);
    final initial = parsed != null && period.contains(parsed)
        ? parsed
        : period.start;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.toDateTime(),
      firstDate: period.start.toDateTime(),
      lastDate: period.end.toDateTime(),
    );
    if (picked != null && mounted) {
      _date.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _pickPhoto() async {
    if (!_editable) return;
    setState(() {
      _picking = true;
      _photoError = null;
    });
    try {
      final file =
          await (widget.pickPhoto?.call() ??
              ImagePicker().pickImage(source: ImageSource.gallery));
      if (file == null) return;
      if (await file.length() > 10 * 1024 * 1024) {
        throw const FormatException('La foto debe pesar como máximo 10 MiB.');
      }
      const types = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
        'heic': 'image/heic',
        'heif': 'image/heif',
      };
      final mime = file.mimeType == 'image/jpg'
          ? 'image/jpeg'
          : file.mimeType ?? types[file.name.split('.').last.toLowerCase()];
      if (!types.values.contains(mime)) {
        throw const FormatException(
          'Elige una foto JPG, PNG, WEBP, HEIC o HEIF.',
        );
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('La imagen está vacía o supera 10 MiB.');
      }
      if (mounted) {
        setState(() => _photo = ExpensePhoto(bytes, mime!, file.name));
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _photoError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoError = 'No se pudo abrir la foto. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_busy ||
        _picking ||
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
      await widget.onSave!(
        ExpenseDraft(
          id: _id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          date: _parseDate(_date.text)!,
          amount: Money.parse(_amount.text.trim().replaceAll(',', '.')),
          photo: _photo,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo confirmar el guardado. Puedes reintentar el mismo envío o cerrar y revisar los movimientos.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Agregar egreso'),
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
                      'Vista previa. Conecta Supabase para guardar el egreso.',
                    ),
                  ),
                TextFormField(
                  controller: _name,
                  enabled: _editable,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del gasto',
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 2
                      ? 'Ingresa el nombre del gasto.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  enabled: _editable,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    prefixText: 'S/ ',
                  ),
                  validator: _validateAmount,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _date,
                  enabled: _editable,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Fecha del gasto',
                    hintText: 'dd/mm/aaaa',
                    suffixIcon: IconButton(
                      onPressed: _editable ? _pickDate : null,
                      icon: const Icon(Icons.calendar_month),
                    ),
                  ),
                  validator: (v) {
                    final date = _parseDate(v ?? '');
                    return date == null ||
                            !CouncilPeriod.official.contains(date)
                        ? 'Usa una fecha de noviembre 2026 a octubre 2027.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  enabled: _editable,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del gasto',
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 2
                      ? 'Describe el motivo del gasto.'
                      : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _editable ? _pickPhoto : null,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    _picking ? 'Leyendo foto…' : 'Adjuntar boleta (opcional)',
                  ),
                ),
                if (_photo != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: Image.memory(
                      _photo!.bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Center(child: Text('Foto seleccionada')),
                    ),
                  ),
                  Text(
                    _photo!.filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  TextButton(
                    onPressed: _editable
                        ? () => setState(() => _photo = null)
                        : null,
                    child: const Text('Quitar foto'),
                  ),
                ],
                if (_photoError != null)
                  Text(
                    _photoError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
          onPressed: _busy || _picking || widget.onSave == null ? null : _save,
          child: Text(
            _busy
                ? 'Guardando…'
                : _error == null
                ? 'Guardar egreso'
                : 'Reintentar guardado',
          ),
        ),
      ],
    ),
  );
}
