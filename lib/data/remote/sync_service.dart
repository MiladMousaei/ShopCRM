// سرویس همگام‌سازی داده‌ها با سرور مرکزی
// پشتیبانی از push (ارسال داده‌های محلی) و pull (دریافت از سرور)
// مکانیزم retry با backoff نمایی: ۲، ۴، ۸ ثانیه
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../data/local/database.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../domain/models/product.dart';
import '../../domain/models/customer.dart';

class SyncService {
  final Dio _dio;
  final ProductRepository _productRepo;
  final InvoiceRepository _invoiceRepo;
  final CustomerRepository _customerRepo;

  SyncService({
    required AppDatabase db,
    required Dio dio,
  })  : _dio = dio,
        _productRepo = ProductRepository(db),
        _invoiceRepo = InvoiceRepository(db),
        _customerRepo = CustomerRepository(db);

  // ─── sync کامل: push سپس pull ──────────────────────────────────────────────

  /// اجرای کامل چرخه همگام‌سازی
  /// ابتدا داده‌های محلی به سرور ارسال می‌شود
  /// سپس آخرین داده‌های سرور دریافت می‌شود
  Future<SyncResult> syncAll({DateTime? since}) async {
    final errors = <String>[];
    int pushed = 0;
    int pulled = 0;

    debugPrint('[SyncService] شروع همگام‌سازی کامل...');

    // ─── مرحله ۱: ارسال محصولات pending ─────────────────────────
    try {
      pushed += await _retryWithBackoff(
        () => pushPendingProducts(),
        label: 'push products',
      );
    } catch (e) {
      errors.add('خطا در ارسال محصولات: $e');
      debugPrint('[SyncService] خطا: $e');
    }

    // ─── مرحله ۲: ارسال فاکتورهای pending ───────────────────────
    try {
      pushed += await _retryWithBackoff(
        () => pushPendingInvoices(),
        label: 'push invoices',
      );
    } catch (e) {
      errors.add('خطا در ارسال فاکتورها: $e');
      debugPrint('[SyncService] خطا: $e');
    }

    // ─── مرحله ۲ب: ارسال مشتریان pending ────────────────────────
    try {
      pushed += await _retryWithBackoff(
        () => _pushPendingCustomers(),
        label: 'push customers',
      );
    } catch (e) {
      errors.add('خطا در ارسال مشتریان: $e');
      debugPrint('[SyncService] خطا: $e');
    }

    // ─── مرحله ۳: دریافت از سرور ────────────────────────────────
    try {
      pulled = await _retryWithBackoff(
        () => pullFromServer(since),
        label: 'pull from server',
      );
    } catch (e) {
      errors.add('خطا در دریافت از سرور: $e');
      debugPrint('[SyncService] خطا: $e');
    }

    debugPrint('[SyncService] اتمام: ارسال=$pushed، دریافت=$pulled');
    return SyncResult(pushed: pushed, pulled: pulled, errors: errors);
  }

  // ─── ارسال محصولات pending ──────────────────────────────────────────────────

  /// ارسال محصولاتی که status آنها pending است به سرور
  /// پس از موفقیت، status به synced تغییر می‌کند
  Future<int> pushPendingProducts() async {
    // دریافت محصولات از دیتابیس محلی
    final allProducts = await _productRepo.getProducts();
    final pendingProducts = allProducts
        .where((p) => p.syncStatus == SyncStatus.pending)
        .toList();

    if (pendingProducts.isEmpty) {
      debugPrint('[SyncService] هیچ محصول pending‌ای وجود ندارد');
      return 0;
    }

    debugPrint(
        '[SyncService] ارسال ${pendingProducts.length} محصول به سرور...');

    // ارسال به endpoint سرور
    final response = await _dio.post(
      '/api/sync/push',
      data: {
        'type': 'products',
        'data': pendingProducts.map((p) => p.toJson()).toList(),
      },
    );

    if (response.statusCode == 200) {
      // بروزرسانی status محصولات در دیتابیس محلی به synced
      for (final product in pendingProducts) {
        final updated = product.copyWith(syncStatus: SyncStatus.synced);
        await _productRepo.saveProduct(updated);
      }
      return pendingProducts.length;
    }

    throw Exception('سرور پاسخ غیرمنتظره داد: ${response.statusCode}');
  }

  // ─── ارسال فاکتورهای pending ────────────────────────────────────────────────

  /// ارسال فاکتورهایی که هنوز با سرور همگام نشده‌اند
  Future<int> pushPendingInvoices() async {
    // دریافت فاکتورها از دیتابیس محلی
    final allInvoices = await _invoiceRepo.getInvoices(limit: 1000);
    final pendingInvoices = allInvoices
        .where((inv) => inv.syncStatus == SyncStatus.pending)
        .toList();

    if (pendingInvoices.isEmpty) {
      debugPrint('[SyncService] هیچ فاکتور pending‌ای وجود ندارد');
      return 0;
    }

    debugPrint(
        '[SyncService] ارسال ${pendingInvoices.length} فاکتور به سرور...');

    // ارسال به سرور
    final response = await _dio.post(
      '/api/sync/push',
      data: {
        'type': 'invoices',
        'data': pendingInvoices.map((inv) => inv.toJson()).toList(),
      },
    );

    if (response.statusCode == 200) {
      // علامت‌گذاری فاکتورها به عنوان synced در دیتابیس محلی
      for (final invoice in pendingInvoices) {
        final updated = invoice.copyWith(syncStatus: SyncStatus.synced);
        await _invoiceRepo.saveInvoice(updated);
      }
      return pendingInvoices.length;
    }

    throw Exception('سرور پاسخ غیرمنتظره داد: ${response.statusCode}');
  }

  // ─── ارسال مشتریان pending ─────────────────────────────────────────────────

  /// ارسال مشتریانی که هنوز با سرور همگام نشده‌اند
  Future<int> _pushPendingCustomers() async {
    final customers = await _customerRepo.getCustomers();
    final pending = customers
        .where((c) => c.syncStatus == SyncStatus.pending)
        .toList();
    if (pending.isEmpty) return 0;
    debugPrint('[SyncService] ارسال ${pending.length} مشتری به سرور...');
    final response = await _dio.post(
      '/api/sync/push',
      data: {
        'type': 'customers',
        'data': pending.map((c) => c.toJson()).toList(),
      },
    );
    if (response.statusCode == 200) {
      for (final c in pending) {
        await _customerRepo.saveCustomer(c.copyWith(syncStatus: SyncStatus.synced));
      }
      return pending.length;
    }
    throw Exception('سرور پاسخ غیرمنتظره داد: ${response.statusCode}');
  }

  // ─── دریافت از سرور ─────────────────────────────────────────────────────────

  /// دریافت آخرین داده‌های سرور و ادغام با دیتابیس محلی
  /// پارامتر since: اگر ارسال شود فقط داده‌های جدیدتر دریافت می‌شود
  Future<int> pullFromServer(DateTime? since) async {
    // ساخت query parameter زمان
    final Map<String, String> queryParams = {};
    if (since != null) {
      queryParams['since'] = since.toIso8601String();
    }

    debugPrint('[SyncService] دریافت داده‌های جدید از سرور...');

    final response = await _dio.get(
      '/api/sync/pull',
      queryParameters: queryParams,
    );

    if (response.statusCode != 200) {
      throw Exception('خطا در pull: ${response.statusCode}');
    }

    final data = response.data as Map<String, dynamic>;
    int totalPulled = 0;

    // ─── ادغام محصولات دریافتی ──────────────────────────────────
    final productsJson = data['products'] as List<dynamic>? ?? [];
    for (final json in productsJson) {
      try {
        final product = Product.fromJson(json as Map<String, dynamic>);
        await _productRepo.saveProduct(product);
        totalPulled++;
      } catch (e) {
        debugPrint('[SyncService] خطا در ادغام محصول: $e');
      }
    }

    // ─── ادغام مشتریان دریافتی ──────────────────────────────────
    final customersJson = data['customers'] as List<dynamic>? ?? [];
    debugPrint('[SyncService] دریافت ${customersJson.length} مشتری از سرور');
    for (final json in customersJson) {
      try {
        final customer = Customer.fromJson(json as Map<String, dynamic>);
        await _customerRepo.saveCustomer(customer);
        totalPulled++;
      } catch (e) {
        debugPrint('[SyncService] خطا در ادغام مشتری: $e');
      }
    }

    debugPrint('[SyncService] مجموع دریافت‌شده: $totalPulled رکورد');
    return totalPulled;
  }

  // ─── retry با backoff نمایی ─────────────────────────────────────────────────

  /// اجرای یک عملیات async با retry خودکار
  /// در صورت شکست:
  ///   - تلاش ۱ → صبر ۲ ثانیه
  ///   - تلاش ۲ → صبر ۴ ثانیه
  ///   - تلاش ۳ → صبر ۸ ثانیه
  ///   - بعد از ۳ تلاش ناموفق → استثنا پرتاب می‌شود
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() fn, {
    String label = 'operation',
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          debugPrint('[SyncService] $label ناموفق پس از $maxRetries تلاش: $e');
          rethrow;
        }
        // محاسبه تأخیر نمایی: 2^attempt ثانیه
        final delay = Duration(seconds: _pow2(attempt));
        debugPrint(
            '[SyncService] $label — تلاش $attempt/$maxRetries — صبر ${delay.inSeconds} ثانیه...');
        await Future.delayed(delay);
      }
    }
  }

  /// توان ۲ برای محاسبه backoff: 2, 4, 8
  int _pow2(int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= 2;
    }
    return result;
  }
}

/// نتیجه عملیات همگام‌سازی
class SyncResult {
  final int pushed;    // تعداد رکوردهای ارسال‌شده
  final int pulled;    // تعداد رکوردهای دریافت‌شده
  final List<String> errors; // لیست خطاها (اگر وجود داشت)

  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.errors,
  });

  /// آیا همگام‌سازی کاملاً موفق بود؟
  bool get isSuccess => errors.isEmpty;

  /// آیا هیچ داده‌ای تغییر نکرد؟
  bool get noChanges => pushed == 0 && pulled == 0;
}
