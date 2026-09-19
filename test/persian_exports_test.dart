import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_crm/data/repositories/report_repository.dart';
import 'package:shop_crm/domain/models/invoice.dart';
import 'package:shop_crm/domain/models/invoice_item.dart';
import 'package:shop_crm/domain/models/ledger_entry.dart';
import 'package:shop_crm/services/pdf_service.dart';
import 'package:shop_crm/services/excel_service.dart';
import 'package:shop_crm/services/printer/escpos_builder.dart';
import 'package:excel/excel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storeName = 'فروشگاه نمونه';

  test('PDF فاکتور فارسی با فونت embed شده تولید می‌شود', () async {
    final invoice = Invoice(
      id: 1,
      invoiceNumber: '۱۰۰۱',
      customerName: 'علی رضایی',
      items: const [
        InvoiceItem(
          id: 1,
          productId: 1,
          productName: 'کالای آزمایشی',
          quantity: 2,
          unitPrice: 50000,
        )
      ],
      paymentMethod: PaymentMethod.credit,
      status: InvoiceStatus.completed,
      createdAt: DateTime(2026, 1, 1),
    );
    final bytes =
        await PdfService.buildInvoicePdf(invoice, storeName: storeName);
    expect(bytes.take(4).toList(), [37, 80, 68, 70]);
    expect(bytes.length, greaterThan(5000));
  });

  test('PDF گزارش فروش فارسی تولید می‌شود', () async {
    const report = SalesReport(
      totalSales: 100000,
      totalProfit: 0,
      totalInvoices: 2,
      dailySales: {'2026-01-01': 100000},
      topProducts: [
        TopProduct(
          productId: 1,
          productName: 'محصول فارسی کامل',
          totalQuantity: 3,
          totalRevenue: 100000,
        ),
      ],
    );
    final bytes = await PdfService.buildSalesReportPdf(
      report,
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 2),
      storeName: storeName,
    );
    expect(bytes.take(4).toList(), [37, 80, 68, 70]);
    expect(bytes.length, greaterThan(10000));
  });

  test('Excel گزارش فروش دارای شیت و عنوان‌های فارسی است', () {
    const report = SalesReport(
      totalSales: 100000,
      totalProfit: 0,
      totalInvoices: 1,
      dailySales: {'2026-01-01': 100000},
      topProducts: [],
    );
    final bytes =
        ExcelService.buildSalesReportBytes(report, storeName: storeName);
    final workbook = Excel.decodeBytes(bytes);
    expect(workbook.tables.keys,
        containsAll(['فروش روزانه', 'پرفروش‌ترین محصولات']));
    expect(_worksheetXml(bytes), contains('rightToLeft="1"'));
    expect(workbook.tables['فروش روزانه']!.rows[1].first!.value.toString(),
        contains('تاریخ'));
    for (final sheet in workbook.tables.values) {
      expect(
        sheet.rows
            .expand((row) => row)
            .map((cell) => cell?.value.toString())
            .whereType<String>(),
        contains(storeName),
      );
    }
  });

  test('Excel فاکتور دارای ستون‌ها و مقادیر فارسی و RTL است', () {
    final invoice = Invoice(
      id: 1,
      invoiceNumber: '۱۰۰۳',
      customerName: 'مشتری فارسی',
      items: const [
        InvoiceItem(
          id: 1,
          productId: 1,
          productName: 'محصول',
          quantity: 1,
          unitPrice: 50000,
        )
      ],
      paymentMethod: PaymentMethod.credit,
      status: InvoiceStatus.completed,
      createdAt: DateTime(2026, 1, 1),
    );
    final bytes =
        ExcelService.buildInvoicesBytes([invoice], storeName: storeName);
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables['فاکتورها']!;
    expect(_worksheetXml(bytes), contains('rightToLeft="1"'));
    expect(sheet.rows[1].map((cell) => cell?.value.toString()),
        containsAll(['شماره فاکتور', 'روش پرداخت', 'وضعیت']));
    expect(sheet.rows[2].map((cell) => cell?.value.toString()),
        containsAll(['نسیه', 'تکمیل شده']));
  });

  test('Excel دفتر حساب دارای ستون‌های فارسی و RTL است', () {
    final entry = _ledgerEntry();
    final bytes = ExcelService.buildLedgerBytes([entry], storeName: storeName);
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables['دفتر حساب']!;
    expect(_worksheetXml(bytes), contains('rightToLeft="1"'));
    expect(sheet.rows[1].map((cell) => cell?.value.toString()),
        containsAll(['مشتری', 'بدهکار (تومان)', 'مانده (تومان)']));
    expect(sheet.rows[2].map((cell) => cell?.value.toString()),
        containsAll(['مشتری آزمایشی', 'بدهی', 'فعال']));
    expect(
      sheet.rows
          .expand((row) => row)
          .map((cell) => cell?.value.toString())
          .whereType<String>(),
      contains(storeName),
    );
  });

  test('PDF دفتر حساب فارسی تولید می‌شود', () async {
    final bytes = await PdfService.buildLedgerPdf(
      [_ledgerEntry()],
      storeName: storeName,
    );
    expect(bytes.take(4).toList(), [37, 80, 68, 70]);
    expect(bytes.length, greaterThan(5000));
  });

  test('چاپ حرارتی فاکتور به تصویر رستری واقعی تبدیل می‌شود', () async {
    final invoice = Invoice(
      id: 1,
      invoiceNumber: '۱۰۰۲',
      customerName: 'مشتری فارسی',
      items: const [
        InvoiceItem(
          id: 1,
          productId: 1,
          productName: 'محصول فارسی با نام طولانی برای بررسی پیچش متن',
          quantity: 1,
          unitPrice: 120000,
        )
      ],
      createdAt: DateTime(2026, 1, 1),
    );
    final bytes = await EscPosBuilder.buildReceiptBytes(
      invoice: invoice,
      storeName: 'فروشگاه هوشمند',
      storePhone: '۰۲۱۱۲۳۴۵۶۷۸',
      storeAddress: 'تهران',
    );
    final rasterHeader = bytes.indexOf(0x1D, 2);
    expect(rasterHeader, greaterThanOrEqualTo(0));
    expect(bytes[rasterHeader + 1], 0x76);
    final height = bytes[rasterHeader + 6] | (bytes[rasterHeader + 7] << 8);
    expect(height, greaterThan(0));
    expect(bytes.length, greaterThan(1000));
  });
}

LedgerEntry _ledgerEntry() => LedgerEntry(
      id: 'entry-1',
      customerId: 1,
      customerName: 'مشتری آزمایشی',
      type: LedgerEntryType.debt,
      amount: 250000,
      direction: LedgerDirection.debit,
      operationDate: DateTime(2026, 1, 1),
      description: 'بدهی اولیه',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      balanceAfter: 250000,
    );

String _worksheetXml(List<int> bytes) => ZipDecoder()
    .decodeBytes(bytes)
    .files
    .where((file) => file.name.startsWith('xl/worksheets/sheet'))
    .map((file) => utf8.decode(file.content as List<int>))
    .join('\n');
