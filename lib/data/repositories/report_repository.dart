import '../../data/local/database.dart';
import 'invoice_repository.dart';

class SalesReport {
  final double totalSales;
  final double totalProfit;
  final int totalInvoices;
  final Map<String, double> dailySales; // تاریخ → مبلغ
  final List<TopProduct> topProducts;

  const SalesReport({
    required this.totalSales,
    required this.totalProfit,
    required this.totalInvoices,
    required this.dailySales,
    required this.topProducts,
  });
}

class TopProduct {
  final int productId;
  final String productName;
  final int totalQuantity;
  final double totalRevenue;

  const TopProduct({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}

class ReportRepository {
  final InvoiceRepository _invoiceRepo;

  ReportRepository(AppDatabase _, this._invoiceRepo);

  Future<SalesReport> getReport(DateTime from, DateTime to) async {
    final invoices = await _invoiceRepo.getInvoicesByPeriod(from, to);

    double totalSales = 0;
    double totalProfit = 0;
    final Map<String, double> dailySales = {};
    final Map<int, TopProduct> productMap = {};

    for (final invoice in invoices) {
      totalSales += invoice.finalAmount;
      final invoiceDiscount = invoice.discountAmount;

      // فروش روزانه
      final dateKey = '${invoice.createdAt.year}-${invoice.createdAt.month.toString().padLeft(2, '0')}-${invoice.createdAt.day.toString().padLeft(2, '0')}';
      dailySales[dateKey] = (dailySales[dateKey] ?? 0) + invoice.finalAmount;

      // پرفروش‌ترین
      for (final item in invoice.items) {
        final discountShare = invoice.totalAmount == 0
            ? 0
            : invoiceDiscount * (item.subtotal / invoice.totalAmount);
        final netRevenue = item.subtotal - discountShare;
        totalProfit +=
            netRevenue - (item.purchasePrice * item.quantity);
        final existing = productMap[item.productId];
        if (existing != null) {
          productMap[item.productId] = TopProduct(
            productId: item.productId,
            productName: item.productName,
            totalQuantity: existing.totalQuantity + item.quantity,
            totalRevenue: existing.totalRevenue + item.subtotal,
          );
        } else {
          productMap[item.productId] = TopProduct(
            productId: item.productId,
            productName: item.productName,
            totalQuantity: item.quantity,
            totalRevenue: item.subtotal,
          );
        }
      }
    }

    final topProducts = productMap.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return SalesReport(
      totalSales: totalSales,
      totalProfit: totalProfit,
      totalInvoices: invoices.length,
      dailySales: dailySales,
      topProducts: topProducts.take(10).toList(),
    );
  }

  Future<Map<String, double>> getWeeklySales() async {
    final now = DateTime.now();
    final firstDay = now.subtract(const Duration(days: 6));
    final from = DateTime(firstDay.year, firstDay.month, firstDay.day);
    final to = DateTime(now.year, now.month, now.day);
    final invoices = await _invoiceRepo.getInvoicesByPeriod(from, to);

    final Map<String, double> result = {};
    // مقداردهی اولیه برای ۷ روز
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
      result[key] = 0;
    }

    for (final invoice in invoices) {
      final key = '${invoice.createdAt.year}-${invoice.createdAt.month.toString().padLeft(2,'0')}-${invoice.createdAt.day.toString().padLeft(2,'0')}';
      result[key] = (result[key] ?? 0) + invoice.finalAmount;
    }

    return result;
  }
}
