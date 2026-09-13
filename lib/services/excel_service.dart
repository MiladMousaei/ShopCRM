// سرویس خروجی Excel برای گزارش‌های فروش و فاکتورها.
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart'
    as file_selector;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/utils/date_converter.dart';
import '../core/utils/currency_formatter.dart';
import '../domain/models/invoice.dart';
import '../domain/models/ledger_entry.dart';
import '../data/repositories/report_repository.dart';

class ExcelService {
  ExcelService._();

  // ─── خروجی Excel گزارش فروش ────────────────────────────────────────────────

  /// تولید فایل Excel گزارش فروش
  /// شیت ۱: فروش روزانه (تاریخ، مبلغ فروش)
  /// شیت ۲: پرفروش‌ترین محصولات (نام، تعداد، درآمد)
  static Excel buildSalesReportWorkbook(SalesReport report) {
    // ایجاد کتاب Excel جدید
    final excel = Excel.createExcel();

    // ─── شیت ۱: فروش روزانه ─────────────────────────────────────────────────
    final dailySheet = excel['فروش روزانه'];
    dailySheet.isRTL = true;
    // حذف شیت پیش‌فرض Sheet1
    excel.delete('Sheet1');

    // هدر ستون‌های شیت فروش روزانه
    _addRow(
        dailySheet,
        [
          'تاریخ',
          'مبلغ فروش (تومان)',
          'تعداد فاکتور',
        ],
        isHeader: true);

    // داده‌های روزانه — مرتب‌شده بر اساس تاریخ
    final sortedDailySales = report.dailySales.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedDailySales) {
      // تبدیل تاریخ میلادی به شمسی برای نمایش
      final shamsiDate = _convertDateKey(entry.key);
      _addRow(dailySheet, [
        shamsiDate,
        CurrencyFormatter.formatNumber(entry.value),
        '', // تعداد فاکتور در این نسخه محاسبه نمی‌شود
      ]);
    }

    // اضافه کردن ردیف جمع کل در انتها
    _addRow(
        dailySheet,
        [
          'جمع کل',
          CurrencyFormatter.formatNumber(report.totalSales),
          CurrencyFormatter.formatNumber(report.totalInvoices),
        ],
        isHeader: true);

    // ─── شیت ۲: پرفروش‌ترین محصولات ─────────────────────────────────────────
    final topSheet = excel['پرفروش‌ترین محصولات'];
    topSheet.isRTL = true;

    // هدر ستون‌های شیت محصولات
    _addRow(
        topSheet,
        [
          'نام محصول',
          'تعداد فروش',
          'درآمد (تومان)',
        ],
        isHeader: true);

    // داده‌های پرفروش‌ترین محصولات — از قبل مرتب‌شده
    for (final product in report.topProducts) {
      _addRow(topSheet, [
        product.productName,
        CurrencyFormatter.formatNumber(product.totalQuantity),
        CurrencyFormatter.formatNumber(product.totalRevenue),
      ]);
    }

    return excel;
  }

  static List<int> buildSalesReportBytes(SalesReport report) {
    return _encodeRtl(buildSalesReportWorkbook(report));
  }

  static Future<void> exportSalesReport(SalesReport report) async {
    await _saveAndShare(
      buildSalesReportWorkbook(report),
      'گزارش_فروش_${_today()}',
    );
  }

  // ─── خروجی Excel لیست فاکتورها ──────────────────────────────────────────────

  /// تولید فایل Excel از لیست فاکتورها
  /// یک ردیف به ازای هر فاکتور: شماره، تاریخ، مشتری، مبلغ، روش پرداخت
  static Excel buildInvoicesWorkbook(List<Invoice> invoices) {
    final excel = Excel.createExcel();

    // شیت فاکتورها
    final sheet = excel['فاکتورها'];
    sheet.isRTL = true;
    excel.delete('Sheet1');

    // هدر ستون‌ها
    _addRow(
        sheet,
        [
          'شماره فاکتور',
          'تاریخ',
          'نام مشتری',
          'جمع کل (تومان)',
          'تخفیف (تومان)',
          'مالیات (تومان)',
          'مبلغ نهایی (تومان)',
          'روش پرداخت',
          'وضعیت',
        ],
        isHeader: true);

    // ردیف‌های فاکتورها
    for (final invoice in invoices) {
      _addRow(sheet, [
        invoice.invoiceNumber,
        DateConverter.toShamsi(invoice.createdAt),
        invoice.customerName ?? 'مشتری ناشناس',
        CurrencyFormatter.formatNumber(invoice.totalAmount),
        CurrencyFormatter.formatNumber(invoice.discountAmount),
        CurrencyFormatter.formatNumber(invoice.taxAmount),
        CurrencyFormatter.formatNumber(invoice.finalAmount),
        invoice.paymentMethod.label,
        invoice.status.label,
      ]);
    }

    // ردیف جمع کل مبلغ نهایی
    final totalFinal =
        invoices.fold<double>(0, (sum, inv) => sum + inv.finalAmount);
    _addRow(
        sheet,
        [
          'جمع کل',
          '',
          '',
          '',
          '',
          '',
          CurrencyFormatter.formatNumber(totalFinal),
          '',
          '',
        ],
        isHeader: true);

    return excel;
  }

  static List<int> buildInvoicesBytes(List<Invoice> invoices) {
    return _encodeRtl(buildInvoicesWorkbook(invoices));
  }

  static Future<void> exportInvoices(List<Invoice> invoices) async {
    await _saveAndShare(
        buildInvoicesWorkbook(invoices), 'فاکتورها_${_today()}');
  }

  static Excel buildLedgerWorkbook(List<LedgerEntry> entries) {
    final excel = Excel.createExcel();
    final sheet = excel['دفتر حساب'];
    sheet.isRTL = true;
    excel.delete('Sheet1');
    _addRow(
        sheet,
        [
          'مشتری',
          'تاریخ ثبت',
          'نوع عملیات',
          'بدهکار (تومان)',
          'بستانکار (تومان)',
          'مانده (تومان)',
          'شماره فاکتور',
          'توضیحات',
          'تاریخ ایجاد',
          'آخرین ویرایش',
          'وضعیت',
        ],
        isHeader: true);
    for (final entry in entries) {
      _addRow(sheet, [
        entry.customerName,
        DateConverter.toShamsi(entry.operationDate),
        entry.type.label,
        entry.direction == LedgerDirection.debit
            ? CurrencyFormatter.formatNumber(entry.amount)
            : '-',
        entry.direction == LedgerDirection.credit
            ? CurrencyFormatter.formatNumber(entry.amount)
            : '-',
        CurrencyFormatter.formatNumber(entry.balanceAfter),
        entry.invoiceNumber ?? '-',
        entry.description ?? '-',
        DateConverter.toShamsiWithTime(entry.createdAt),
        DateConverter.toShamsiWithTime(entry.updatedAt),
        entry.isActive ? 'فعال' : 'باطل‌شده',
      ]);
    }
    return excel;
  }

  static List<int> buildLedgerBytes(List<LedgerEntry> entries) =>
      _encodeRtl(buildLedgerWorkbook(entries));

  static Future<void> exportLedger(List<LedgerEntry> entries) => _saveAndShare(
        buildLedgerWorkbook(entries),
        'دفتر_حساب_${_today()}',
      );

  // ─── توابع کمکی ────────────────────────────────────────────────────────────

  /// اضافه کردن یک ردیف به شیت Excel
  /// isHeader: اگر true باشد سلول‌ها bold می‌شوند
  static void _addRow(
    Sheet sheet,
    List<String> values, {
    bool isHeader = false,
  }) {
    final rowIndex = sheet.maxRows;
    for (int col = 0; col < values.length; col++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = TextCellValue(values[col]);
      cell.cellStyle = CellStyle(
        bold: isHeader,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Top,
        textWrapping: TextWrapping.WrapText,
      );
    }
  }

  /// در ویندوز فایل واقعی xlsx را در مسیر انتخابی کاربر ذخیره می‌کند.
  /// در سایر پلتفرم‌ها رفتار اشتراک‌گذاری موجود حفظ می‌شود.
  static Future<void> _saveAndShare(Excel excel, String filename) async {
    try {
      final bytes = _encodeRtl(excel);
      if (Platform.isWindows) {
        final location =
            await file_selector.FileSelectorPlatform.instance.getSaveLocation(
          acceptedTypeGroups: const [
            file_selector.XTypeGroup(
              label: 'فایل Excel',
              extensions: ['xlsx'],
            ),
          ],
          options: file_selector.SaveDialogOptions(
            suggestedName: '$filename.xlsx',
          ),
        );
        if (location == null) return;

        final selectedPath = location.path;
        final filePath = selectedPath.toLowerCase().endsWith('.xlsx')
            ? selectedPath
            : '$selectedPath.xlsx';
        await File(filePath).writeAsBytes(bytes, flush: true);
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$filename.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      // اشتراک‌گذاری فایل از طریق share_plus
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile(filePath,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        text: 'فایل صفحه‌گسترده فروشگاه هوشمند',
      ));
    } catch (e) {
      debugPrint('[ExcelService] خطا در ذخیره/اشتراک: $e');
      rethrow;
    }
  }

  /// تبدیل کلید تاریخ میلادی (YYYY-MM-DD) به شمسی
  static String _convertDateKey(String key) {
    try {
      final parts = key.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return DateConverter.toShamsi(date);
    } catch (_) {
      return key; // اگر تبدیل ناموفق بود، همان کلید را برگردان
    }
  }

  /// تاریخ امروز برای نام فایل (بدون کاراکترهای ویژه)
  static String _today() {
    final now = DateTime.now();
    return DateConverter.toShamsi(now).replaceAll('/', '-');
  }

  static List<int> _encodeRtl(Excel excel) {
    final source = excel.save();
    if (source == null) throw StateError('خطا در تولید فایل Excel');
    final input = ZipDecoder().decodeBytes(source);
    final output = Archive();
    for (final entry in input.files) {
      var content = entry.content as List<int>;
      if (entry.name.startsWith('xl/worksheets/sheet') &&
          entry.name.endsWith('.xml')) {
        final xml = utf8.decode(content).replaceAll(
              '<sheetView workbookViewId="0"/>',
              '<sheetView rightToLeft="1" workbookViewId="0"/>',
            );
        content = utf8.encode(xml);
      }
      output.addFile(ArchiveFile(entry.name, content.length, content));
    }
    return ZipEncoder().encode(output)!;
  }
}
