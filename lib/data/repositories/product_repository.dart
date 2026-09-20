import 'package:drift/drift.dart';
import '../../data/local/database.dart';
import '../../domain/models/product.dart';
import '../../services/product_image_service.dart';

class ProductRepository {
  final AppDatabase _db;

  ProductRepository(this._db);

  Stream<List<Product>> watchProducts({String? search}) {
    final stream = search != null && search.isNotEmpty
        ? _db.productsDao.watchProductsBySearch(search)
        : _db.productsDao.watchAllProducts();
    return stream.map((rows) => rows.map(_mapToModel).toList());
  }

  Future<List<Product>> getProducts() async {
    final rows = await _db.productsDao.getAllProducts();
    return rows.map(_mapToModel).toList();
  }

  Future<Product?> findByBarcode(String barcode) async {
    final row = await _db.productsDao.findByBarcode(barcode);
    return row != null ? _mapToModel(row) : null;
  }

  Future<Product?> findById(int id) async {
    final row = await _db.productsDao.findById(id);
    return row != null ? _mapToModel(row) : null;
  }

  Future<List<Product>> getLowStockProducts() async {
    final rows = await _db.productsDao.getLowStockProducts();
    return rows.map(_mapToModel).toList();
  }

  Future<int> saveProduct(Product product) async {
    final barcode = product.barcode?.trim();
    final companion = ProductsTableCompanion(
      serverId: product.id == 0
          ? Value(product.serverId)
          : const Value.absent(),
      barcode: Value(barcode == null || barcode.isEmpty ? null : barcode),
      name: Value(product.name),
      categoryId: product.id == 0
          ? Value(product.categoryId)
          : const Value.absent(),
      purchasePrice: Value(product.purchasePrice),
      sellPrice: Value(product.sellPrice),
      stockQuantity: Value(product.stockQuantity),
      minStockAlert: Value(product.minStockAlert),
      imageUrl: Value(product.imageUrl),
      isActive:
          product.id == 0 ? Value(product.isActive) : const Value.absent(),
      updatedAt: Value(product.updatedAt),
      syncStatus: Value(product.syncStatus.name),
    );

    if (product.id == 0) {
      return await _db.productsDao.insertProduct(companion);
    } else {
      final changed = await _db.productsDao.updateProduct(product.id, companion);
      if (changed != 1) {
        throw StateError('محصول برای ویرایش پیدا نشد');
      }
      return product.id;
    }
  }

  Future<void> updateStock(int productId, int newStock) async {
    if (newStock < 0) throw ArgumentError('موجودی نمی‌تواند منفی باشد');
    await _db.productsDao.updateStock(productId, newStock);
  }

  Future<void> deleteProduct(int id) async {
    final product = await findById(id);
    await _db.transaction(() async {
      await _db.productsDao.deactivateProduct(id);
      await _db.productsDao.clearImage(id);
    });
    await deleteImageIfUnused(product?.imageUrl);
  }

  Future<void> deleteImageIfUnused(String? path) async {
    if (path == null) return;
    if (await _db.productsDao.imageReferenceCount(path) == 0) {
      await ProductImageService.delete(path);
    }
  }

  Future<int> getProductCount() => _db.productsDao.getProductCount();

  Product _mapToModel(ProductsTableData row) => Product(
        id: row.id,
        serverId: row.serverId,
        barcode: row.barcode,
        name: row.name,
        categoryId: row.categoryId,
        purchasePrice: row.purchasePrice,
        sellPrice: row.sellPrice,
        stockQuantity: row.stockQuantity,
        minStockAlert: row.minStockAlert,
        imageUrl: row.imageUrl,
        isActive: row.isActive,
        updatedAt: row.updatedAt,
        syncStatus: SyncStatus.values.firstWhere(
          (s) => s.name == row.syncStatus,
          orElse: () => SyncStatus.pending,
        ),
      );
}
