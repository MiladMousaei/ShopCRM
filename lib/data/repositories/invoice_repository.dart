import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/database.dart';
import '../../domain/models/invoice.dart';
import '../../domain/models/invoice_item.dart';
import '../../domain/models/product.dart';
import 'ledger_repository.dart';

class InvoiceRepository {
  final AppDatabase _db;

  InvoiceRepository(this._db);

  Stream<List<Invoice>> watchInvoices({int limit = 50, int offset = 0}) =>
      _db.invoicesDao
          .watchInvoices(limit: limit, offset: offset)
          .asyncMap((rows) async {
        final List<Invoice> result = [];
        for (final row in rows) {
          final items = await _db.invoicesDao.getInvoiceItems(row.id);
          result.add(_mapToModel(row, items));
        }
        return result;
      });

  Future<List<Invoice>> getInvoices({int limit = 50, int offset = 0}) async {
    final rows =
        await _db.invoicesDao.getInvoices(limit: limit, offset: offset);
    final result = <Invoice>[];
    for (final row in rows) {
      final items = await _db.invoicesDao.getInvoiceItems(row.id);
      result.add(_mapToModel(row, items));
    }
    return result;
  }

  Future<Invoice?> findById(int id) async {
    final row = await _db.invoicesDao.findById(id);
    if (row == null) return null;
    final items = await _db.invoicesDao.getInvoiceItems(id);
    return _mapToModel(row, items);
  }

  Future<List<Invoice>> getRecentInvoices({int limit = 5}) async {
    final rows = await _db.invoicesDao.getRecentInvoices(limit: limit);
    final result = <Invoice>[];
    for (final row in rows) {
      final items = await _db.invoicesDao.getInvoiceItems(row.id);
      result.add(_mapToModel(row, items));
    }
    return result;
  }

  Stream<List<Invoice>> watchRecentInvoices({int limit = 5}) =>
      _db.invoicesDao.watchRecentInvoices(limit: limit).asyncMap((rows) async {
        final result = <Invoice>[];
        for (final row in rows) {
          final items = await _db.invoicesDao.getInvoiceItems(row.id);
          result.add(_mapToModel(row, items));
        }
        return result;
      });

  Future<List<Invoice>> getInvoicesByPeriod(DateTime from, DateTime to) async {
    final rows = await _db.invoicesDao.getInvoicesByPeriod(from, to);
    final result = <Invoice>[];
    for (final row in rows) {
      final items = await _db.invoicesDao.getInvoiceItems(row.id);
      result.add(_mapToModel(row, items));
    }
    return result;
  }

  Future<List<Invoice>> getCustomerInvoices(int customerId) async {
    final rows = await _db.invoicesDao.getCustomerInvoices(customerId);
    final result = <Invoice>[];
    for (final row in rows) {
      final items = await _db.invoicesDao.getInvoiceItems(row.id);
      result.add(_mapToModel(row, items));
    }
    return result;
  }

  Future<int> saveInvoice(Invoice invoice) async {
    if (invoice.id != 0) {
      final changed = await (_db.update(_db.invoicesTable)
            ..where((row) => row.id.equals(invoice.id)))
          .write(InvoicesTableCompanion(
        serverId: Value(invoice.serverId),
        syncStatus: Value(invoice.syncStatus.name),
      ));
      if (changed != 1) throw StateError('فاکتور برای ویرایش پیدا نشد');
      return invoice.id;
    }
    final invoiceCompanion = InvoicesTableCompanion(
      id: const Value.absent(),
      serverId: Value(invoice.serverId),
      invoiceNumber: Value(invoice.invoiceNumber),
      customerId: Value(invoice.customerId),
      customerName: Value(invoice.customerName),
      userId: Value(invoice.userId),
      totalAmount: Value(invoice.totalAmount),
      discount: Value(invoice.discount),
      isDiscountPercent: Value(invoice.isDiscountPercent),
      tax: Value(invoice.tax),
      finalAmount: Value(invoice.finalAmount),
      paymentMethod: Value(invoice.paymentMethod.name),
      status: Value(invoice.status.name),
      notes: Value(invoice.notes),
      createdAt: Value(invoice.createdAt),
      syncStatus: Value(invoice.syncStatus.name),
    );

    final itemCompanions = invoice.items
        .map(
          (item) => InvoiceItemsTableCompanion(
            productId: Value(item.productId),
            productName: Value(item.productName),
            productBarcode: Value(item.productBarcode),
            quantity: Value(item.quantity),
            unitPrice: Value(item.unitPrice),
            purchasePrice: Value(item.purchasePrice),
            discountPercent: Value(item.discountPercent),
            subtotal: Value(item.subtotal),
          ),
        )
        .toList();

    return await _db.invoicesDao
        .insertInvoiceWithItems(invoiceCompanion, itemCompanions);
  }

  /// ثبت قطعی فروش. تمام اعتبارسنجی‌ها و تغییرات مالی/انبار در یک
  /// transaction انجام می‌شوند تا هیچ فاکتور نیمه‌ثبت‌شده‌ای باقی نماند.
  Future<int> createSale(Invoice invoice) async {
    _validateSale(invoice);

    return _db.transaction(() async {
      final customer = invoice.customerId == null
          ? null
          : await _db.customersDao.findById(invoice.customerId!);
      if (invoice.customerId != null && customer == null) {
        throw StateError('مشتری انتخاب‌شده وجود ندارد');
      }
      if (invoice.paymentMethod == PaymentMethod.credit) {
        if (customer == null) {
          throw StateError('برای فروش نسیه انتخاب مشتری الزامی است');
        }
        final currentDebt = await _db.ledgerDao.customerBalance(customer.id);
        final newDebt = currentDebt + invoice.finalAmount.round();
        if (customer.creditLimit > 0 && newDebt > customer.creditLimit.round()) {
          throw StateError('مبلغ فاکتور از سقف اعتبار مشتری بیشتر است');
        }
      }

      final products = <int, ProductsTableData>{};
      final requested = <int, int>{};
      for (final item in invoice.items) {
        requested[item.productId] =
            (requested[item.productId] ?? 0) + item.quantity;
      }
      for (final entry in requested.entries) {
        final product = await _db.productsDao.findById(entry.key);
        if (product == null || !product.isActive) {
          throw StateError('محصول حذف شده یا در دسترس نیست');
        }
        if (product.stockQuantity < entry.value) {
          throw StateError('موجودی «${product.name}» کافی نیست');
        }
        products[entry.key] = product;
      }

      final invoiceNumber = invoice.invoiceNumber.trim().isEmpty
          ? _generateInvoiceNumber(invoice.createdAt)
          : invoice.invoiceNumber.trim();
      final normalizedItems = invoice.items
          .map((item) => item.copyWith(
                productName: products[item.productId]!.name,
                productBarcode: products[item.productId]!.barcode,
                purchasePrice: products[item.productId]!.purchasePrice,
              ))
          .toList();
      final normalizedInvoice = invoice.copyWith(
        invoiceNumber: invoiceNumber,
        customerName: customer?.name,
        items: normalizedItems,
      );

      final id = await saveInvoice(normalizedInvoice);
      for (final entry in requested.entries) {
        final product = products[entry.key]!;
        final newStock = product.stockQuantity - entry.value;
        await _db.productsDao.updateStock(product.id, newStock);
        await _db.into(_db.inventoryLogsTable).insert(
              InventoryLogsTableCompanion.insert(
                productId: product.id,
                type: 'sale',
                quantity: entry.value,
                previousStock: product.stockQuantity,
                newStock: newStock,
                reason: Value('فروش فاکتور $invoiceNumber'),
                invoiceId: Value(id),
                createdAt: invoice.createdAt,
              ),
            );
      }

      if (invoice.paymentMethod == PaymentMethod.credit) {
        await LedgerRepository(_db).createCreditPurchase(
          customerId: customer!.id,
          amount: normalizedInvoice.finalAmount.round(),
          invoiceId: id,
        );
      }
      return id;
    });
  }

  Future<void> updateStatus(int id, InvoiceStatus status) async {
    await _db.transaction(() async {
      final current = await _db.invoicesDao.findById(id);
      if (current == null) throw StateError('فاکتور پیدا نشد');
      final currentStatus = InvoiceStatus.values.firstWhere(
        (value) => value.name == current.status,
        orElse: () => InvoiceStatus.draft,
      );
      if (currentStatus == status) return;

      final isCancellation = status == InvoiceStatus.cancelled ||
          status == InvoiceStatus.refunded;
      if (isCancellation && currentStatus == InvoiceStatus.completed) {
        final items = await _db.invoicesDao.getInvoiceItems(id);
        final quantities = <int, int>{};
        for (final item in items) {
          quantities[item.productId] =
              (quantities[item.productId] ?? 0) + item.quantity;
        }
        for (final entry in quantities.entries) {
          final product = await _db.productsDao.findById(entry.key);
          if (product == null) {
            throw StateError('محصول فاکتور برای بازگردانی موجودی پیدا نشد');
          }
          final newStock = product.stockQuantity + entry.value;
          await _db.productsDao.updateStock(product.id, newStock);
          await _db.into(_db.inventoryLogsTable).insert(
                InventoryLogsTableCompanion.insert(
                  productId: product.id,
                  type: 'refund',
                  quantity: entry.value,
                  previousStock: product.stockQuantity,
                  newStock: newStock,
                  reason: Value(status == InvoiceStatus.refunded
                      ? 'مرجوعی فاکتور ${current.invoiceNumber}'
                      : 'لغو فاکتور ${current.invoiceNumber}'),
                  invoiceId: Value(id),
                  createdAt: DateTime.now(),
                ),
              );
        }
      } else if (isCancellation &&
          (currentStatus == InvoiceStatus.cancelled ||
              currentStatus == InvoiceStatus.refunded)) {
        return;
      }
      await _db.invoicesDao.updateStatus(id, status.name);
      if (isCancellation) {
        final ledger = await _db.ledgerDao.activeEntryForInvoice(id);
        if (ledger != null) await LedgerRepository(_db).voidEntry(ledger.id);
      }
    });
  }

  Future<double> getTodaySalesTotal() => _db.invoicesDao.getTodaySalesTotal();

  Invoice _mapToModel(
      InvoicesTableData row, List<InvoiceItemsTableData> itemRows) {
    return Invoice(
      id: row.id,
      serverId: row.serverId,
      invoiceNumber: row.invoiceNumber,
      customerId: row.customerId,
      customerName: row.customerName,
      userId: row.userId,
      items: itemRows
          .map((item) => InvoiceItem(
                id: item.id,
                invoiceId: item.invoiceId,
                productId: item.productId,
                productName: item.productName,
                productBarcode: item.productBarcode,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                purchasePrice: item.purchasePrice,
                discountPercent: item.discountPercent,
              ))
          .toList(),
      discount: row.discount,
      isDiscountPercent: row.isDiscountPercent,
      tax: row.tax,
      paymentMethod: PaymentMethod.values.firstWhere(
        (p) => p.name == row.paymentMethod,
        orElse: () => PaymentMethod.cash,
      ),
      status: InvoiceStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => InvoiceStatus.draft,
      ),
      notes: row.notes,
      createdAt: row.createdAt,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == row.syncStatus,
        orElse: () => SyncStatus.pending,
      ),
    );
  }

  void _validateSale(Invoice invoice) {
    if (invoice.items.isEmpty) {
      throw StateError('فاکتور بدون کالا قابل ثبت نیست');
    }
    for (final item in invoice.items) {
      if (item.quantity <= 0 || item.unitPrice <= 0) {
        throw ArgumentError('تعداد و قیمت کالا باید بزرگ‌تر از صفر باشد');
      }
      if (item.discountPercent < 0 || item.discountPercent >= 100) {
        throw ArgumentError('تخفیف ردیف کالا باید بین صفر و کمتر از صد باشد');
      }
    }
    if (invoice.discount < 0) {
      throw ArgumentError('تخفیف نمی‌تواند منفی باشد');
    }
    if (invoice.isDiscountPercent) {
      if (invoice.discount >= 100) {
        throw ArgumentError('درصد تخفیف باید کمتر از صد باشد');
      }
    } else if (invoice.discount >= invoice.totalAmount) {
      throw ArgumentError('تخفیف مبلغی باید کمتر از جمع فاکتور باشد');
    }
    if (invoice.tax < 0 || invoice.tax > 100) {
      throw ArgumentError('درصد مالیات نامعتبر است');
    }
    if (invoice.finalAmount.round() <= 0) {
      throw ArgumentError('مبلغ نهایی فاکتور باید بزرگ‌تر از صفر باشد');
    }
    if (invoice.paymentMethod == PaymentMethod.credit &&
        invoice.customerId == null) {
      throw StateError('برای فروش نسیه انتخاب مشتری الزامی است');
    }
  }

  String _generateInvoiceNumber(DateTime createdAt) {
    String two(int value) => value.toString().padLeft(2, '0');
    final suffix = const Uuid().v4().replaceAll('-', '').substring(0, 10);
    return 'INV-${createdAt.year}${two(createdAt.month)}${two(createdAt.day)}-'
        '${two(createdAt.hour)}${two(createdAt.minute)}${two(createdAt.second)}-'
        '$suffix';
  }
}
