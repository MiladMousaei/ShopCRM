import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/products_table.dart';

part 'products_dao.g.dart';

/// دسترسی به جدول محصولات در SQLite
/// تمام عملیات CRUD محصولات از این DAO انجام می‌شود
@DriftAccessor(tables: [ProductsTable])
class ProductsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductsDaoMixin {
  ProductsDao(super.db);

  // ─── خواندن ──────────────────────────────────────────────────

  /// همه محصولات فعال (یک‌بار)
  Future<List<ProductsTableData>> getAllProducts() =>
      (select(productsTable)..where((t) => t.isActive.equals(true))).get();

  /// استریم محصولات فعال — UI با هر تغییر بروز می‌شود
  Stream<List<ProductsTableData>> watchAllProducts() =>
      (select(productsTable)..where((t) => t.isActive.equals(true))).watch();

  /// جستجو در نام یا بارکد (استریم)
  Stream<List<ProductsTableData>> watchProductsBySearch(String query) {
    final q = '%$query%';
    return (select(productsTable)
          ..where((t) => t.name.like(q) | t.barcode.like(q))
          ..where((t) => t.isActive.equals(true)))
        .watch();
  }

  /// پیدا کردن با بارکد (برای اسکن)
  Future<ProductsTableData?> findByBarcode(String barcode) =>
      (select(productsTable)
            ..where((t) => t.barcode.equals(barcode.trim()))
            ..where((t) => t.isActive.equals(true)))
          .getSingleOrNull();

  /// پیدا کردن با شناسه
  Future<ProductsTableData?> findById(int id) =>
      (select(productsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// محصولاتی که موجودی‌شان به حداقل رسیده (برای داشبورد)
  Future<List<ProductsTableData>> getLowStockProducts() =>
      (select(productsTable)
            ..where((t) => t.isActive.equals(true))
            ..where((t) =>
                t.stockQuantity.isSmallerOrEqual(t.minStockAlert)))
          .get();

  // ─── نوشتن ───────────────────────────────────────────────────

  /// درج محصول جدید — شناسه خودکار برمی‌گردد
  Future<int> insertProduct(ProductsTableCompanion product) =>
      into(productsTable).insert(product);

  /// بروزرسانی محصول موجود
  Future<int> updateProduct(int id, ProductsTableCompanion product) =>
      (update(productsTable)..where((t) => t.id.equals(id))).write(product);

  /// فقط موجودی را بروز کن (بهینه برای بعد از فروش)
  Future<void> updateStock(int productId, int newStock) =>
      (update(productsTable)..where((t) => t.id.equals(productId)))
          .write(ProductsTableCompanion(
        stockQuantity: Value(newStock),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'), // نیاز به sync
      ));

  /// حذف نرم (soft delete) — محصول غیرفعال می‌شود، حذف نمی‌شود
  Future<void> deactivateProduct(int id) =>
      (update(productsTable)..where((t) => t.id.equals(id)))
          .write(ProductsTableCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
      ));

  Future<int> imageReferenceCount(String imagePath) async {
    final count = productsTable.id.count();
    final query = selectOnly(productsTable)
      ..addColumns([count])
      ..where(productsTable.imageUrl.equals(imagePath) &
          productsTable.isActive.equals(true));
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<void> clearImage(int id) =>
      (update(productsTable)..where((t) => t.id.equals(id))).write(
        ProductsTableCompanion(
          imageUrl: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  // ─── Sync ─────────────────────────────────────────────────────

  /// محصولاتی که هنوز به سرور ارسال نشده‌اند
  Future<List<ProductsTableData>> getPendingProducts() =>
      (select(productsTable)..where((t) => t.syncStatus.equals('pending')))
          .get();

  /// بعد از sync موفق، serverId و وضعیت را ثبت کن
  Future<void> markAsSynced(int id, int serverId) =>
      (update(productsTable)..where((t) => t.id.equals(id)))
          .write(ProductsTableCompanion(
        serverId: Value(serverId),
        syncStatus: const Value('synced'),
      ));

  // ─── آمار ────────────────────────────────────────────────────

  /// تعداد کل محصولات فعال
  Future<int> getProductCount() async {
    final count = productsTable.id.count();
    final query = selectOnly(productsTable)
      ..addColumns([count])
      ..where(productsTable.isActive.equals(true));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
