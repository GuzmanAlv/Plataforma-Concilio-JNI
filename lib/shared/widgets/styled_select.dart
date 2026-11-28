import 'package:flutter/material.dart';

/// Shared form/menu styling. The parent owns the selected value.
class StyledSelect<T> extends StatelessWidget {
  const StyledSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon = Icons.tune_rounded,
    super.key,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey(value),
    initialValue: value,
    items: items,
    onChanged: onChanged,
    isExpanded: true,
    menuMaxHeight: 360,
    borderRadius: BorderRadius.circular(18),
    dropdownColor: Colors.white,
    icon: const Icon(Icons.expand_more_rounded, color: Color(0xFF6354D9)),
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF7F5FD),
      prefixIcon: Icon(icon, color: const Color(0xFF6354D9), size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2DDF2)),
      ),
    ),
  );
}
