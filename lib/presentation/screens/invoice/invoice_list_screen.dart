import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_converter.dart';
import '../../../domain/models/invoice.dart';
import '../../providers/invoice_provider.dart';
import '../../widgets/common/app_header_back_button.dart';
import '../../widgets/common/loading_overlay.dart';

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesStreamProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppHeaderBackButton(),
          title: const Text(AppStrings.invoices),
        ),
        body: invoices.when(
          data: (list) => list.isEmpty
              ? const Center(
                  child: Text('هیچ فاکتوری ثبت نشده',
                      style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          color: AppColors.textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _InvoiceCard(invoice: list[i]),
                ),
          loading: () => const ShimmerList(),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('خطا در بارگذاری فاکتورها',
                    style: TextStyle(fontFamily: 'Vazirmatn')),
                TextButton(
                  onPressed: () => ref.invalidate(invoicesStreamProvider),
                  child: const Text(AppStrings.retry,
                      style: TextStyle(fontFamily: 'Vazirmatn')),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.go('/invoice/new'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceCard({required this.invoice});

  Color get _statusColor {
    switch (invoice.status) {
      case InvoiceStatus.completed:
        return AppColors.success;
      case InvoiceStatus.cancelled:
        return AppColors.error;
      case InvoiceStatus.refunded:
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/invoices/${invoice.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // آیکون وضعیت
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.receipt_outlined, color: _statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          DateConverter.toShamsiWithTime(invoice.createdAt),
                          style: const TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (invoice.customerName != null) ...[
                          const Text(' · ',
                              style: TextStyle(color: AppColors.textHint)),
                          Text(
                            invoice.customerName!,
                            style: const TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(invoice.finalAmount),
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      invoice.paymentMethod.label,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11,
                        color: _statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
