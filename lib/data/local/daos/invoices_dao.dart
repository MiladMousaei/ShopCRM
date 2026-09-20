import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/invoices_table.dart';
import '../tables/products_table.dart';
import '../tables/customers_table.dart';

part 'invoices_dao.g.dart';

/// دسترسی به جداول فاکتور و آیتم‌های فاکتور
@DriftAccessor(
    tables: [InvoicesTable, InvoiceItemsTable, CustomersTable, ProductsTable])
class InvoicesDao extends DatabaseAccessor<AppDatabase>
    with _$InvoicesDaoMixin {
  InvoicesDao(super.db);

  // ─── ثبت فاکتور ───────────────────────────────────────────────

  /// ثبت فاکتور + تمام آیتم‌هایش در یک تراکنش اتمیک
  /// اگر هر قدمی شکست بخورد، همه چیز برمی‌گردد (rollback)
  Future<int> insertInvoiceWithItems(
    InvoicesTableCompanion invoice,
    List<InvoiceItemsTableCompanion> items,
  ) async {
    return await transaction(() async {
      final invoiceId = await into(invoicesTable).insert(invoice);
      for (final item in items) {
        await into(invoiceItemsTable)
            .insert(item.copyWith(invoiceId: Value(invoiceId)));
      }
      return invoiceId;
    });
  }

  // ─── خواندن فاکتورها ──────────────────────────────────────────

  /// استریم فاکتورها برای UI (جدیدترین اول)
  Stream<List<InvoicesTableData>> watchInvoices({
    int limit = 50,
    int offset = 0,
  }) =>
      (select(invoicesTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit, offset: offset))
          .watch();

  /// لیست فاکتورها با صفحه‌بندی
  Future<List<InvoicesTableData>> getInvoices({
    int limit = 50,
    int offset = 0,
  }) =>
      (select(invoicesTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit, offset: offset))
          .get();

  /// فاکتورهای امروز (برای محاسبه فروش روز)
  Future<List<InvoicesTableData>> getTodayInvoices() {
    final startOfDay = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(invoicesTable)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(startOfDay))
          ..where((t) => t.createdAt.isSmallerThanValue(endOfDay))
          ..where((t) => t.status.equals('completed')))
        .get();
  }

  /// فاکتورهای یک بازه زمانی مشخص (برای گزارش)
  Future<List<InvoicesTableData>> getInvoicesByPeriod(
    DateTime from,
    DateTime to,
  ) {
    final start = DateTime(from.year, from.month, from.day);
    final endExclusive = DateTime(to.year, to.month, to.day)
        .add(const Duration(days: 1));
    return (select(invoicesTable)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start))
          ..where((t) => t.createdAt.isSmallerThanValue(endExclusive))
            ..where((t) => t.status.equals('completed'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// یک فاکتور با شناسه
  Future<InvoicesTableData?> findById(int id) =>
      (select(invoicesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// آیتم‌های یک فاکتور
  Future<List<InvoiceItemsTableData>> getInvoiceItems(int invoiceId) =>
      (select(invoiceItemsTable)..where((t) => t.invoiceId.equals(invoiceId)))
          .get();

  /// ۵ فاکتور آخر (برای داشبورد)
  Future<List<InvoicesTableData>> getRecentInvoices({int limit = 5}) =>
      (select(invoicesTable)
            ..where((t) => t.status.equals('completed'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  /// فاکتورهای آخر به‌صورت زنده برای داشبورد
  Stream<List<InvoicesTableData>> watchRecentInvoices({int limit = 5}) =>
      (select(invoicesTable)
            ..where((t) => t.status.equals('completed'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .watch();

  /// تمام فاکتورهای یک مشتری
  Future<List<InvoicesTableData>> getCustomerInvoices(int customerId) =>
      (select(invoicesTable)
            ..where((t) => t.customerId.equals(customerId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  // ─── بروزرسانی ────────────────────────────────────────────────

  /// تغییر وضعیت فاکتور (مثلاً completed → cancelled)
  Future<void> updateStatus(int id, String status) =>
      (update(invoicesTable)..where((t) => t.id.equals(id)))
          .write(InvoicesTableCompanion(status: Value(status)));

  // ─── Sync ─────────────────────────────────────────────────────

  Future<List<InvoicesTableData>> getPendingInvoices() =>
      (select(invoicesTable)..where((t) => t.syncStatus.equals('pending')))
          .get();

  Future<void> markAsSynced(int id, int serverId) =>
      (update(invoicesTable)..where((t) => t.id.equals(id)))
          .write(InvoicesTableCompanion(
        serverId: Value(serverId),
        syncStatus: const Value('synced'),
      ));

  // ─── آمار ────────────────────────────────────────────────────

  /// جمع فروش امروز
  Future<double> getTodaySalesTotal() async {
    final invoices = await getTodayInvoices();
    return invoices.fold<double>(
        0.0, (sum, inv) => sum + (inv.finalAmount as double));
  }
}
