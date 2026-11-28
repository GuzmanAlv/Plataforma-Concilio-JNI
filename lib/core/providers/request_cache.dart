import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension SuccessfulRequestCache on Ref {
  /// Call only after success. Keep recent data across navigation, without
  /// retaining every visited date/filter indefinitely. Invalidation still wins.
  void cacheSuccess({Duration duration = const Duration(minutes: 5)}) {
    if (!mounted) return;
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
