import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_crm/data/local/database.dart';
import 'package:shop_crm/data/repositories/customer_repository.dart';
import 'package:shop_crm/data/repositories/invoice_repository.dart';
import 'package:shop_crm/data/repositories/product_repository.dart';
import 'package:shop_crm/data/repositories/report_repository.dart';
import 'package:shop_crm/domain/models/customer.dart';
import 'package:shop_crm/domain/models/invoice.dart';
import 'package:shop_crm/domain/models/invoice_item.dart';
import 'package:shop_crm/domain/models/product.dart';

void main() {
  late AppDatabase db;
  late InvoiceRepository invoices;
  late ProductRepository products;
  late CustomerRepository customers;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    invoices = InvoiceRepository(db);
    products = ProductRepository(db);
    customers = CustomerRepository(db);
  });

  tearDown(() => db.close());

  test('فروش بیشتر از موجودی رد می‌شود و هیچ داده ناقصی باقی نمی‌ماند',
      () async {
    final product = await _product(products, stock: 2);
    final invoice = _invoice(product, quantity: 3);

    await expectLater(invoices.createSale(invoice), throwsStateError);

    expect(await db.select(db.invoicesTable).get(), isEmpty);
    expect(await db.select(db.invoiceItemsTable).get(), isEmpty);
    expect(await db.select(db.inventoryLogsTable).get(), isEmpty);
    expect((await products.findById(product.id))!.stockQuantity, 2);
  });

  test('فروش نسیه بدون مشتری رد می‌شود', () async {
    final product = await _product(products);
    await expectLater(
      invoices.createSale(
        _invoice(product, paymentMethod: PaymentMethod.credit),
      ),
      throwsStateError,
    );
    expect(await db.select(db.invoicesTable).get(), isEmpty);
  });

  test('تخفیف نامعتبر و مبلغ نهایی صفر یا منفی رد می‌شود', () async {
    final product = await _product(products, sellPrice: 100000);
    await expectLater(
      invoices.createSale(_invoice(product, discount: 100000)),
      throwsArgumentError,
    );
    await expectLater(
      invoices.createSale(
        _invoice(product, discount: 100, isDiscountPercent: true),
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.invoicesTable).get(), isEmpty);
  });

  test('فروش، موجودی، لاگ انبار و بدهی در یک تراکنش ثبت می‌شوند', () async {
    final product = await _product(products, stock: 5, sellPrice: 120000);
    final customer = await _customer(customers, creditLimit: 500000);
    final id = await invoices.createSale(
      _invoice(
        product,
        quantity: 2,
        customer: customer,
        paymentMethod: PaymentMethod.credit,
      ),
    );

    expect(id, greaterThan(0));
    expect((await products.findById(product.id))!.stockQuantity, 3);
    final logs = await db.select(db.inventoryLogsTable).get();
    expect(logs, hasLength(1));
    expect(logs.single.type, 'sale');
    expect(logs.single.invoiceId, id);
    expect((await customers.findById(customer.id))!.totalDebt, 240000);
  });

  test('خطای انتهای ثبت، فاکتور و تغییر موجودی را با هم rollback می‌کند',
      () async {
    final product = await _product(products, stock: 5);
    final customer = await _customer(customers);
    await db.customStatement('''
      CREATE TRIGGER fail_ledger BEFORE INSERT ON ledger_entries
      BEGIN SELECT RAISE(ABORT, 'ledger failed'); END
    ''');

    await expectLater(
      invoices.createSale(
        _invoice(
          product,
          customer: customer,
          paymentMethod: PaymentMethod.credit,
        ),
      ),
      throwsA(anything),
    );
    expect(await db.select(db.invoicesTable).get(), isEmpty);
    expect(await db.select(db.inventoryLogsTable).get(), isEmpty);
    expect((await products.findById(product.id))!.stockQuantity, 5);
  });

  test('سقف اعتبار واقعی اعمال می‌شود و تراکنش rollback می‌شود', () async {
    final product = await _product(products, stock: 5, sellPrice: 120000);
    final customer = await _customer(customers, creditLimit: 100000);

    await expectLater(
      invoices.createSale(
        _invoice(
          product,
          customer: customer,
          paymentMethod: PaymentMethod.credit,
        ),
      ),
      throwsStateError,
    );

    expect(await db.select(db.invoicesTable).get(), isEmpty);
    expect((await products.findById(product.id))!.stockQuantity, 5);
    expect((await customers.findById(customer.id))!.totalDebt, 0);
  });

  test('شماره فاکتور تکراری ثبت نمی‌شود', () async {
    final firstProduct = await _product(products, barcode: 'A-1');
    final secondProduct = await _product(products, barcode: 'A-2');
    await invoices.createSale(
      _invoice(firstProduct, invoiceNumber: 'FIXED-1'),
    );
    await expectLater(
      invoices.createSale(
        _invoice(secondProduct, invoiceNumber: 'FIXED-1'),
      ),
      throwsA(anything),
    );
    expect(await db.select(db.invoicesTable).get(), hasLength(1));
  });

  test('شماره‌های خودکار فاکتور یکتا هستند', () async {
    final firstProduct = await _product(products, barcode: 'AUTO-1');
    final secondProduct = await _product(products, barcode: 'AUTO-2');
    await invoices.createSale(_invoice(firstProduct));
    await invoices.createSale(_invoice(secondProduct));
    final rows = await db.select(db.invoicesTable).get();
    expect(rows.map((row) => row.invoiceNumber).toSet(), hasLength(2));
  });

  test('لغو یا مرجوعی فقط یک بار موجودی را برمی‌گرداند و لاگ می‌سازد',
      () async {
    final product = await _product(products, stock: 5);
    final id = await invoices.createSale(_invoice(product, quantity: 2));
    expect((await products.findById(product.id))!.stockQuantity, 3);

    await invoices.updateStatus(id, InvoiceStatus.cancelled);
    expect((await products.findById(product.id))!.stockQuantity, 5);
    await invoices.updateStatus(id, InvoiceStatus.cancelled);
    expect((await products.findById(product.id))!.stockQuantity, 5);
    final refundLogs = await (db.select(db.inventoryLogsTable)
          ..where((row) => row.type.equals('refund')))
        .get();
    expect(refundLogs, hasLength(1));
  });

  test('محصول حذف‌شده قابل فروش نیست و بارکد تکراری رد می‌شود', () async {
    final product = await _product(products, barcode: 'UNIQUE-1');
    await products.deleteProduct(product.id);
    await expectLater(
      invoices.createSale(_invoice(product)),
      throwsStateError,
    );
    await expectLater(
      _product(products, barcode: 'UNIQUE-1'),
      throwsA(anything),
    );
  });

  test('ویرایش مشتری و محصول فیلدهای سیستمی قبلی را حفظ می‌کند', () async {
    final product = await _product(products, stock: 7, serverId: 42);
    await products.saveProduct(Product(
      id: product.id,
      name: 'نام ویرایش‌شده',
      purchasePrice: 10,
      sellPrice: 20,
      stockQuantity: 1,
      updatedAt: DateTime.now(),
    ));
    final editedProduct = await products.findById(product.id);
    expect(editedProduct!.serverId, 42);
    expect(editedProduct.stockQuantity, 1);

    final customer = await _customer(customers, serverId: 84);
    await (db.update(db.customersTable)
          ..where((row) => row.id.equals(customer.id)))
        .write(const CustomersTableCompanion(totalDebt: Value(90000)));
    await customers.saveCustomer(Customer(
      id: customer.id,
      name: 'مشتری ویرایش‌شده',
      updatedAt: DateTime.now(),
    ));
    final editedCustomer = await customers.findById(customer.id);
    expect(editedCustomer!.serverId, 84);
    expect(editedCustomer.totalDebt, 90000);
  });

  test('گزارش روز پایان را کامل پوشش می‌دهد و سود را از قیمت خرید محاسبه می‌کند',
      () async {
    final product = await _product(
      products,
      purchasePrice: 60000,
      sellPrice: 100000,
    );
    await invoices.createSale(
      _invoice(
        product,
        quantity: 2,
        discount: 20000,
        createdAt: DateTime(2026, 4, 10, 23, 59),
      ),
    );
    final report = await ReportRepository(db, invoices).getReport(
      DateTime(2026, 4, 10),
      DateTime(2026, 4, 10),
    );
    expect(report.totalInvoices, 1);
    expect(report.totalSales, 180000);
    expect(report.totalProfit, 60000);
  });

  test('صفحه‌بندی فاکتورها موارد بعد از ردیف ۵۰ را برمی‌گرداند', () async {
    for (var index = 0; index < 51; index++) {
      await db.into(db.invoicesTable).insert(InvoicesTableCompanion.insert(
            invoiceNumber: 'PAGE-$index',
            createdAt: DateTime(2026, 1, 1).add(Duration(minutes: index)),
          ));
    }
    expect(await invoices.getInvoices(limit: 50), hasLength(50));
    final secondPage = await invoices.getInvoices(limit: 50, offset: 50);
    expect(secondPage, hasLength(1));
    expect(secondPage.single.invoiceNumber, 'PAGE-0');
  });
}

Future<Product> _product(
  ProductRepository repository, {
  int stock = 10,
  double purchasePrice = 50000,
  double sellPrice = 100000,
  String? barcode,
  int? serverId,
}) async {
  final id = await repository.saveProduct(Product(
    id: 0,
    serverId: serverId,
    barcode: barcode,
    name: 'محصول ${barcode ?? DateTime.now().microsecondsSinceEpoch}',
    purchasePrice: purchasePrice,
    sellPrice: sellPrice,
    stockQuantity: stock,
    updatedAt: DateTime.now(),
  ));
  return (await repository.findById(id))!;
}

Future<Customer> _customer(
  CustomerRepository repository, {
  double creditLimit = 0,
  int? serverId,
}) async {
  final id = await repository.saveCustomer(Customer(
    id: 0,
    serverId: serverId,
    name: 'مشتری آزمایشی',
    creditLimit: creditLimit,
    updatedAt: DateTime.now(),
  ));
  return (await repository.findById(id))!;
}

Invoice _invoice(
  Product product, {
  int quantity = 1,
  Customer? customer,
  PaymentMethod paymentMethod = PaymentMethod.cash,
  double discount = 0,
  bool isDiscountPercent = false,
  String invoiceNumber = '',
  DateTime? createdAt,
}) =>
    Invoice(
      id: 0,
      invoiceNumber: invoiceNumber,
      customerId: customer?.id,
      customerName: customer?.name,
      items: [InvoiceItem.fromProduct(product, quantity: quantity)],
      discount: discount,
      isDiscountPercent: isDiscountPercent,
      paymentMethod: paymentMethod,
      status: InvoiceStatus.completed,
      createdAt: createdAt ?? DateTime.now(),
    );
