// Provider های مرکزی گزارش‌گیری
// قبلاً در dashboard_screen و reports_screen تعریف شده بودند
// این فایل آن‌ها را یکجا جمع می‌کند
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/report_repository.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(
    ref.watch(databaseProvider),
    ref.watch(invoiceRepositoryProvider),
  );
});

class ReportParams {
  final DateTime from;
  final DateTime to;
  const ReportParams({required this.from, required this.to});
}

final reportParamsProvider = StateProvider<ReportParams>((ref) {
  final now = DateTime.now();
  return ReportParams(
    from: now.subtract(const Duration(days: 30)),
    to: now,
  );
});

final reportDataProvider = FutureProvider<SalesReport>((ref) {
  final params = ref.watch(reportParamsProvider);
  return ref.watch(reportRepositoryProvider).getReport(params.from, params.to);
});

final weeklySalesProvider = FutureProvider<Map<String, double>>((ref) {
  return ref.watch(reportRepositoryProvider).getWeeklySales();
});
