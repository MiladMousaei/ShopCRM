import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_converter.dart';
import '../../providers/product_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/common/app_header_back_button.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/charts/sales_chart.dart';
import '../../../domain/models/invoice.dart';
import '../../providers/theme_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySales = ref.watch(todaySalesTotalProvider);
    final productCount = ref.watch(productsStreamProvider);
    final customerCount = ref.watch(customersStreamProvider);
    final recentInvoices = ref.watch(recentInvoicesProvider);
    final weeklySales = ref.watch(weeklySalesProvider);
    final syncState = ref.watch(syncProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppHeaderBackButton(),
          title: const Text(AppStrings.dashboard),
          actions: [
            IconButton(
              icon: Icon(isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
              onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
              tooltip: isDark ? 'حالت روشن' : 'حالت تاریک',
            ),
            // وضعیت sync
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _SyncStatusChip(syncState: syncState),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(syncProvider.notifier).sync(),
              tooltip: 'همگام‌سازی',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todaySalesTotalProvider);
            ref.invalidate(weeklySalesProvider);
            ref.invalidate(recentInvoicesProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // تاریخ امروز
                Text(
                  DateConverter.toShamsiLong(DateTime.now()),
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // کارت‌های آمار — ۲ ستون روی موبایل، ۴ ستون روی دسکتاپ
                LayoutBuilder(builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isWide ? 2.2 : 1.25,
                    children: [
                      StatCard(
                        title: AppStrings.todaySales,
                        value: todaySales.when(
                          data: (v) => CurrencyFormatter.format(v),
                          loading: () => '...',
                          error: (_, __) => '---',
                        ),
                        icon: Icons.point_of_sale,
                        color: AppColors.cardSales,
                        onTap: () => context.go('/invoices'),
                      ),
                      StatCard(
                        title: AppStrings.totalInventory,
                        value: productCount.when(
                          data: (products) =>
                              '${CurrencyFormatter.formatNumber(products.length)} محصول',
                          loading: () => '...',
                          error: (_, __) => '---',
                        ),
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.cardInventory,
                        onTap: () => context.go('/products'),
                      ),
                      StatCard(
                        title: AppStrings.inventory,
                        value: productCount.when(
                          data: (products) =>
                              '${CurrencyFormatter.formatNumber(products.fold<int>(0, (s, p) => s + p.stockQuantity))} عدد',
                          loading: () => '...',
                          error: (_, __) => '---',
                        ),
                        icon: Icons.warehouse_outlined,
                        color: AppColors.cardAlert,
                        onTap: () => context.go('/inventory'),
                      ),
                      StatCard(
                        title: AppStrings.customers,
                        value: customerCount.when(
                          data: (list) =>
                              '${CurrencyFormatter.formatNumber(list.length)} نفر',
                          loading: () => '...',
                          error: (_, __) => '---',
                        ),
                        icon: Icons.people_outline,
                        color: AppColors.cardDebt,
                        onTap: () => context.go('/customers'),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 16),

                // نمودار فروش هفتگی
                const _SectionHeader(title: AppStrings.weeklySalesChart),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: weeklySales.when(
                      data: (data) => SalesChart(dailySales: data),
                      loading: () => const SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => const SizedBox(
                        height: 100,
                        child: Center(
                            child: Text('خطا در بارگذاری نمودار',
                                style: TextStyle(fontFamily: 'Vazirmatn'))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // آخرین فاکتورها
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _SectionHeader(title: AppStrings.recentInvoices),
                    TextButton(
                      onPressed: () => context.go('/invoices'),
                      child: const Text('مشاهده همه',
                          style:
                              TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                recentInvoices.when(
                  data: (invoices) => invoices.isEmpty
                      ? const _EmptyState(
                          icon: Icons.receipt_long_outlined,
                          message: 'هنوز فاکتوری ثبت نشده',
                        )
                      : Column(
                          children: invoices
                              .map((inv) => _InvoiceTile(invoice: inv))
                              .toList(),
                        ),
                  loading: () =>
                      const ShimmerList(itemCount: 3, itemHeight: 64),
                  error: (_, __) => _ErrorWidget(
                    onRetry: () => ref.invalidate(recentInvoicesProvider),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/invoice/new'),
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.newInvoice,
              style: TextStyle(fontFamily: 'Vazirmatn')),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_outlined,
              color: AppColors.primary, size: 22),
        ),
        title: Text(
          invoice.invoiceNumber,
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          DateConverter.toShamsiWithTime(invoice.createdAt),
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Text(
          CurrencyFormatter.format(invoice.finalAmount),
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        onTap: () => context.go('/invoices/${invoice.id}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text('خطا در بارگذاری',
              style:
                  TextStyle(fontFamily: 'Vazirmatn', color: AppColors.error)),
          TextButton(
            onPressed: onRetry,
            child: const Text(AppStrings.retry,
                style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusChip extends StatelessWidget {
  final dynamic syncState;
  const _SyncStatusChip({required this.syncState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: syncState.isOnline ? Colors.greenAccent : Colors.orange,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            syncState.isOnline ? AppStrings.online : AppStrings.offline,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
