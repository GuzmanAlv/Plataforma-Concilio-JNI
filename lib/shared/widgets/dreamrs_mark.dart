import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

/// The navbar emblem is also the source for generated launcher and web icons.
class DreamrsMark extends StatelessWidget {
  const DreamrsMark({this.size = 38, super.key});
  static const cornerRatio = 12 / 38;
  static const symbolRatio = 22 / 38;
  static const symbol = Icons.auto_awesome;
  static const color = AppTheme.purple;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * cornerRatio),
    ),
    child: Icon(symbol, color: Colors.white, size: size * symbolRatio),
  );
}
