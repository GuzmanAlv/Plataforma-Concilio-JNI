import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/members/application/members_providers.dart';
import '../features/attendance/application/attendance_sheet_provider.dart';
import '../features/attendance/application/attendance_providers.dart';
import '../features/dashboard/application/dashboard_providers.dart';
import '../features/treasury/application/treasury_providers.dart';
import '../features/inventory/application/inventory_providers.dart';

void refreshAppData(WidgetRef ref) {
  ref.invalidate(memberDirectoryProvider);
  ref.invalidate(attendanceRosterProvider);
  ref.invalidate(attendanceSheetProvider);
  ref.invalidate(attendanceSummaryProvider);
  ref.invalidate(dashboardInsightsProvider);
  ref.invalidate(cashSummaryProvider);
  ref.invalidate(cashEvolutionProvider);
  ref.invalidate(treasuryMovementsProvider);
  ref.invalidate(offeringMonthsProvider);
  ref.invalidate(saturdayOfferingsProvider);
  ref.invalidate(inventoryItemsProvider);
}
