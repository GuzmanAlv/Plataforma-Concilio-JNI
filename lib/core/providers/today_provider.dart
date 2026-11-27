import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/civil_date.dart';

final todayProvider = Provider<CivilDate>((ref) => CivilDate.today());
