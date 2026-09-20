/// صفحه جزئیات فاکتور
/// نمایش کامل یک فاکتور: اطلاعات، آیتم‌ها، خلاصه مالی
/// امکان پرینت و اشتراک‌گذاری متن فاکتور
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_converter.dart';
import '../../../domain/models/invoice.dart';
import '../../../domain/models/invoice_item.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/printer_provider.dart';
import '../../widgets/common/app_header_back_button.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../../services/pdf_service.dart';
import 'package:printing/printing.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  /// شناسه فاکتور — از مسیر ناوبری گرفته می‌شود
  final int invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // دریافت اطلاعات فاکتور از provider
    final invoiceAsync = ref.watch(invoiceByIdProvider(invoiceId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: invoiceAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(
            leading: const AppHeaderBackButton(fallbackRoute: '/invoices'),
            title: const Text('جزئیات فاکتور'),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(
            leading: const AppHeaderBackButton(fallbackRoute: '/invoices'),
            title: const Text('خطا'),
          ),
          body: Center(
            child: Text('خطا در بارگذاری فاکتور: $e',
                style: const TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ),
        data: (invoice) {
          if (invoice == null) {
            return Scaffold(
              appBar: AppBar(
                leading: const AppHeaderBackButton(fallbackRoute: '/invoices'),
              ),
              body: const Center(
                child: Text('فاکتور یافت نشد',
                    style: TextStyle(fontFamily: 'Vazirmatn')),
              ),
            );
          }
          return _InvoiceDetailBody(invoice: invoice);
        },
      ),
    );
  }
}

/// بدنه اصلی صفحه جزئیات فاکتور
class _InvoiceDetailBody extends ConsumerWidget {
  final Invoice invoice;

  const _InvoiceDetailBody({required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // ─── نوار بالا ─────────────────────────────────────────────
      appBar: AppBar(
        leading: const AppHeaderBackButton(fallbackRoute: '/invoices'),
        title: Text(
          'فاکتور ${invoice.invoiceNumber}',
          style: const TextStyle(
              fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
        ),
        actions: [
          // دکمه اشتراک‌گذاری متن فاکتور
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'اشتراک‌گذاری',
            onPressed: () => _shareInvoice(context, invoice),
          ),
          // دکمه پرینت — تولید PDF و چاپ
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'پرینت',
            onPressed: () => _printInvoice(context, ref, invoice),
          ),
        ],
      ),

      // ─── محتوا ─────────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── هدر فاکتور ─────────────────────────────────────
            _buildInvoiceHeader(invoice),
            const SizedBox(height: 16),

            // ─── لیست اقلام فاکتور ──────────────────────────────
            _buildItemsSection(invoice.items),
            const SizedBox(height: 16),

            // ─── خلاصه مالی ─────────────────────────────────────
            _buildFinancialSummary(invoice),
            if (invoice.status == InvoiceStatus.completed) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _changeStatus(
                        context,
                        ref,
                        invoice,
                        InvoiceStatus.cancelled,
                      ),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('لغو فاکتور'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _changeStatus(
                        context,
                        ref,
                        invoice,
                        InvoiceStatus.refunded,
                      ),
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: const Text('مرجوعی'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
    InvoiceStatus status,
  ) async {
    final isRefund = status == InvoiceStatus.refunded;
    final confirmed = await ConfirmDialog.show(
      context,
      title: isRefund ? 'مرجوعی فاکتور' : 'لغو فاکتور',
      message:
          'موجودی کالاها بازگردانده و سند بدهی مرتبط ابطال می‌شود. ادامه می‌دهید؟',
      confirmText: isRefund ? 'ثبت مرجوعی' : 'لغو فاکتور',
      confirmColor: isRefund ? AppColors.warning : AppColors.error,
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .updateStatus(invoice.id, status);
      ref.invalidate(invoiceByIdProvider(invoice.id));
      ref.invalidate(todaySalesTotalProvider);
      ref.invalidate(reportDataProvider);
      ref.invalidate(weeklySalesProvider);
      ref.invalidate(lowStockProductsProvider);
      ref.invalidate(totalDebtAmountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isRefund ? 'مرجوعی ثبت شد' : 'فاکتور لغو شد'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('انجام عملیات ناموفق بود: $error'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  /// هدر فاکتور: شماره، تاریخ، نام مشتری، روش پرداخت
  Widget _buildInvoiceHeader(Invoice invoice) {
    // تعیین رنگ وضعیت
    Color statusColor;
    switch (invoice.status) {
      case InvoiceStatus.completed:
        statusColor = AppColors.success;
        break;
      case InvoiceStatus.cancelled:
        statusColor = AppColors.error;
        break;
      case InvoiceStatus.refunded:
        statusColor = AppColors.warning;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ردیف اول: شماره و وضعیت
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.invoiceNumber,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                // نشان‌گر وضعیت
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    invoice.status.label,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // ردیف دوم: تاریخ و ساعت
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: AppStrings.invoiceDate,
              value: DateConverter.toShamsiLong(invoice.createdAt),
              subValue: DateConverter.toTime(invoice.createdAt),
            ),
            const SizedBox(height: 12),

            // ردیف سوم: نام مشتری
            _buildInfoRow(
              icon: Icons.person_outline,
              label: AppStrings.customer,
              value: invoice.customerName ?? AppStrings.noCustomer,
            ),
            const SizedBox(height: 12),

            // ردیف چهارم: روش پرداخت
            _buildInfoRow(
              icon: _paymentIcon(invoice.paymentMethod),
              label: AppStrings.paymentMethod,
              value: invoice.paymentMethod.label,
              valueColor: _paymentColor(invoice.paymentMethod),
            ),
          ],
        ),
      ),
    );
  }

  /// یک ردیف اطلاعات با آیکون
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
        if (subValue != null)
          Text(
            subValue,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  /// بخش لیست اقلام فاکتور
  Widget _buildItemsSection(List<InvoiceItem> items) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان بخش
            Row(
              children: [
                const Icon(Icons.list_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'اقلام فاکتور',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length} قلم',
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // هدر جدول
            _buildTableHeader(),
            const Divider(height: 12),

            // ردیف‌های اقلام
            ...items.asMap().entries.map((entry) {
              return Column(
                children: [
                  _InvoiceItemRow(item: entry.value, index: entry.key),
                  if (entry.key < items.length - 1)
                    const Divider(height: 8, color: AppColors.divider),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  /// هدر جدول اقلام
  Widget _buildTableHeader() {
    return const Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            'نام محصول',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            'تعداد',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(
            'قیمت واحد',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(
            'جمع جزء',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  /// بخش خلاصه مالی: جمع کل، تخفیف، مالیات، مبلغ نهایی
  Widget _buildFinancialSummary(Invoice invoice) {
    return Card(
      elevation: 0,
      color: AppColors.infoLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // جمع کل قبل از تخفیف
            _buildSummaryRow(
              label: AppStrings.totalAmount,
              value: CurrencyFormatter.format(invoice.totalAmount),
            ),
            const SizedBox(height: 8),

            // تخفیف
            if (invoice.discountAmount > 0) ...[
              _buildSummaryRow(
                label: invoice.isDiscountPercent
                    ? '${AppStrings.discount} (${CurrencyFormatter.formatPercent(invoice.discount)})'
                    : AppStrings.discount,
                value: '- ${CurrencyFormatter.format(invoice.discountAmount)}',
                valueColor: AppColors.error,
              ),
              const SizedBox(height: 8),
            ],

            // مالیات
            if (invoice.taxAmount > 0) ...[
              _buildSummaryRow(
                label:
                    '${AppStrings.tax} (${CurrencyFormatter.formatPercent(invoice.tax)})',
                value: '+ ${CurrencyFormatter.format(invoice.taxAmount)}',
                valueColor: AppColors.warning,
              ),
              const SizedBox(height: 8),
            ],

            // خط جداکننده
            const Divider(height: 16),

            // مبلغ نهایی — بزرگ‌تر و پررنگ‌تر
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  AppStrings.finalAmount,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(invoice.finalAmount),
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// یک ردیف در خلاصه مالی
  Widget _buildSummaryRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// پرینت فاکتور از طریق PDF Service
  Future<void> _printInvoice(
      BuildContext context, WidgetRef ref, Invoice invoice) async {
    try {
      // نمایش اندیکاتور بارگذاری
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('در حال آماده‌سازی PDF...',
                style: TextStyle(fontFamily: 'Vazirmatn')),
            duration: Duration(seconds: 2),
          ),
        );
      }
      // تولید PDF از فاکتور
      final pdfBytes = await PdfService.buildInvoicePdf(invoice);
      // باز کردن دیالوگ پرینت سیستمی
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'فاکتور_${invoice.invoiceNumber}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در پرینت: $e',
                style: const TextStyle(fontFamily: 'Vazirmatn')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// اشتراک‌گذاری متن ساده فاکتور
  void _shareInvoice(BuildContext context, Invoice invoice) {
    final buffer = StringBuffer();
    buffer.writeln('=== ${AppStrings.appName} ===');
    buffer.writeln('شماره فاکتور: ${invoice.invoiceNumber}');
    buffer
        .writeln('تاریخ: ${DateConverter.toShamsiWithTime(invoice.createdAt)}');
    if (invoice.customerName != null) {
      buffer.writeln('مشتری: ${invoice.customerName}');
    }
    buffer.writeln('─────────────────────────');
    // اقلام فاکتور
    for (final item in invoice.items) {
      buffer.writeln(
          '${item.productName} × ${item.quantity} = ${CurrencyFormatter.format(item.subtotal)}');
    }
    buffer.writeln('─────────────────────────');
    // خلاصه مالی
    buffer.writeln(
        '${AppStrings.totalAmount}: ${CurrencyFormatter.format(invoice.totalAmount)}');
    if (invoice.discountAmount > 0) {
      buffer.writeln(
          '${AppStrings.discount}: ${CurrencyFormatter.format(invoice.discountAmount)}');
    }
    if (invoice.taxAmount > 0) {
      buffer.writeln(
          '${AppStrings.tax}: ${CurrencyFormatter.format(invoice.taxAmount)}');
    }
    buffer.writeln(
        '${AppStrings.finalAmount}: ${CurrencyFormatter.format(invoice.finalAmount)}');
    buffer.writeln('روش پرداخت: ${invoice.paymentMethod.label}');
    buffer.writeln('─────────────────────────');
    buffer.writeln(AppStrings.receiptThankYou);

    // اشتراک‌گذاری متن از طریق share_plus
    Share.share(
      buffer.toString(),
      subject: 'فاکتور ${invoice.invoiceNumber}',
    );
  }

  /// آیکون روش پرداخت
  IconData _paymentIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      case PaymentMethod.card:
        return Icons.credit_card_outlined;
      case PaymentMethod.credit:
        return Icons.account_balance_wallet_outlined;
      case PaymentMethod.pos:
        return Icons.credit_card;
    }
  }

  /// رنگ روش پرداخت
  Color _paymentColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return AppColors.success;
      case PaymentMethod.card:
        return AppColors.primary;
      case PaymentMethod.credit:
        return AppColors.warning;
      case PaymentMethod.pos:
        return AppColors.posColor;
    }
  }
}

// ─── ردیف آیتم فاکتور ────────────────────────────────────────────────────────

class _InvoiceItemRow extends StatelessWidget {
  final InvoiceItem item;
  final int index;

  const _InvoiceItemRow({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // نام محصول
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // اگر تخفیف ردیف وجود دارد، نشان بده
                if (item.discountPercent > 0)
                  Text(
                    'تخفیف: ${CurrencyFormatter.formatPercent(item.discountPercent)}',
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 10,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
          // تعداد
          SizedBox(
            width: 40,
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // قیمت واحد
          SizedBox(
            width: 100,
            child: Text(
              CurrencyFormatter.formatNumber(item.unitPrice),
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          // جمع جزء
          SizedBox(
            width: 100,
            child: Text(
              CurrencyFormatter.formatNumber(item.subtotal),
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
