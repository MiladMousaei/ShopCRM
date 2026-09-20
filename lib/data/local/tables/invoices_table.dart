import 'package:drift/drift.dart';
import 'customers_table.dart';

class InvoicesTable extends Table {
  @override
  String get tableName => 'invoices';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get invoiceNumber => text().withLength(min: 1, max: 50)();
  IntColumn get customerId => integer().nullable().references(CustomersTable, #id)();
  TextColumn get customerName => text().nullable()();
  IntColumn get userId => integer().nullable()();
  RealColumn get totalAmount => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  BoolColumn get isDiscountPercent => boolean().withDefault(const Constant(false))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get finalAmount => real().withDefault(const Constant(0))();
  // cash | card | credit
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  // draft | completed | cancelled | refunded
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

class InvoiceItemsTable extends Table {
  @override
  String get tableName => 'invoice_items';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(InvoicesTable, #id)();
  IntColumn get productId => integer()();
  TextColumn get productName => text()();
  TextColumn get productBarcode => text().nullable()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get purchasePrice => real().withDefault(const Constant(0))();
  RealColumn get discountPercent => real().withDefault(const Constant(0))();
  RealColumn get subtotal => real()();
}
