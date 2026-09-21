import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/database.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/models/product.dart';
import '../../domain/models/inventory_log.dart';

// دیتابیس singleton — یک بار ساخته می‌شود و در کل اپ استفاده می‌شود
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(databaseProvider));
});

// جستجوی فعال
final productSearchQueryProvider = StateProvider<String>((ref) => '');

// فیلتر دسته‌بندی (null = همه دسته‌ها)
final productCategoryFilterProvider = StateProvider<String?>((ref) => null);

// استریم محصولات با فیلتر جستجو (بدون فیلتر دسته — raw stream)
final _rawProductsStreamProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  final query = ref.watch(productSearchQueryProvider);
  return repo.watchProducts(search: query.isEmpty ? null : query);
});

// استریم محصولات با فیلتر جستجو + دسته‌بندی
final productsStreamProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final category = ref.watch(productCategoryFilterProvider);
  return ref.watch(_rawProductsStreamProvider).whenData((products) {
    if (category == null) return products;
    return products.where((p) => p.categoryName == category).toList();
  });
});

// لیست دسته‌بندی‌های موجود از محصولات فعلی
final availableCategoriesProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(_rawProductsStreamProvider).whenData((products) {
    final cats = products
        .map((p) => p.categoryName)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return cats;
  });
});

// محصولات زیر حداقل موجودی
final lowStockProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).getLowStockProducts();
});

// یک محصول خاص
final productByIdProvider = FutureProvider.family<Product?, int>((ref, id) {
  return ref.watch(productRepositoryProvider).findById(id);
});

// پیدا کردن با بارکد
final productByBarcodeProvider =
    FutureProvider.family<Product?, String>((ref, barcode) {
  return ref.watch(productRepositoryProvider).findByBarcode(barcode);
});

// CRUD state
class ProductFormState {
  final bool isLoading;
  final String? error;
  final bool isDone;

  const ProductFormState({
    this.isLoading = false,
    this.error,
    this.isDone = false,
  });

  ProductFormState copyWith({bool? isLoading, String? error, bool? isDone}) {
    return ProductFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isDone: isDone ?? this.isDone,
    );
  }
}

class ProductFormNotifier extends StateNotifier<ProductFormState> {
  final ProductRepository _repo;

  ProductFormNotifier(this._repo) : super(const ProductFormState());

  Future<bool> save(Product product) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.saveProduct(product);
      state = state.copyWith(isLoading: false, isDone: true);
      return true;
    } catch (e) {
      state =
          state.copyWith(isLoading: false, error: 'خطا در ذخیره محصول: $e');
      return false;
    }
  }

  Future<bool> delete(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.deleteProduct(id);
      state = state.copyWith(isLoading: false, isDone: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'خطا در حذف محصول');
      return false;
    }
  }

  void reset() => state = const ProductFormState();
}

final productFormProvider =
    StateNotifierProvider.autoDispose<ProductFormNotifier, ProductFormState>(
        (ref) {
  return ProductFormNotifier(ref.watch(productRepositoryProvider));
});

// ─── لاگ‌های انبار ────────────────────────────────────────────────────────────

/// Provider برای دریافت لاگ‌های انبار یک محصول خاص
/// استفاده در صفحه جزئیات محصول و سابقه انبار
final inventoryLogsByProductProvider =
    FutureProvider.family<List<InventoryLog>, int>((ref, productId) async {
  final db = ref.watch(databaseProvider);
  // دریافت لاگ‌های انبار برای محصول مشخص، مرتب‌شده از جدیدترین به قدیمی‌ترین
  final rows = await (db.select(db.inventoryLogsTable)
        ..where((t) => t.productId.equals(productId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(50))
      .get();

  return rows
      .map((row) => InventoryLog(
            id: row.id,
            productId: row.productId,
            type: InventoryLogType.values.firstWhere(
              (t) => t.name == row.type,
              orElse: () => InventoryLogType.adjust,
            ),
            quantity: row.quantity,
            previousStock: row.previousStock,
            newStock: row.newStock,
            reason: row.reason,
            invoiceId: row.invoiceId,
            createdAt: row.createdAt,
          ))
      .toList();
});

/// Provider برای دریافت آخرین لاگ‌های انبار (برای نمایش فعالیت اخیر انبار)
/// مرتب‌شده از جدیدترین — محدود به ۲۰ رکورد
final recentInventoryLogsProvider =
    FutureProvider<List<InventoryLog>>((ref) async {
  final db = ref.watch(databaseProvider);
  // ۲۰ لاگ آخر از همه محصولات، از جدیدترین
  final rows = await (db.select(db.inventoryLogsTable)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(20))
      .get();

  return rows
      .map((row) => InventoryLog(
            id: row.id,
            productId: row.productId,
            type: InventoryLogType.values.firstWhere(
              (t) => t.name == row.type,
              orElse: () => InventoryLogType.adjust,
            ),
            quantity: row.quantity,
            previousStock: row.previousStock,
            newStock: row.newStock,
            reason: row.reason,
            invoiceId: row.invoiceId,
            createdAt: row.createdAt,
          ))
      .toList();
});
