import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_converter.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../services/pdf_service.dart';
import '../../../services/excel_service.dart';
import '../../providers/report_provider.dart';
import '../../widgets/common/app_header_back_button.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/charts/sales_chart.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final report = ref.read(reportDataProvider);
    final params = ref.read(reportParamsProvider);
    if (!report.hasValue || report.value == null) return;
    try {
      await PdfService.shareSalesReport(
        report: report.value!,
        from: params.from,
        to: params.to,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطا در تولید PDF: $e',
              style: const TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _exportExcel(BuildContext context, WidgetRef ref) async {
    final report = ref.read(reportDataProvider);
    final params = ref.read(reportParamsProvider);
    if (!report.hasValue || report.value == null) return;
    try {
      await ExcelService.exportSalesReport(report.value!);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطا در تولید Excel: $e',
              style: const TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(reportParamsProvider);
    final report = ref.watch(reportDataProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppHeaderBackButton(),
          title: const Text(AppStrings.report),
          actions: [
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              onPressed: () => _exportExcel(context, ref),
              tooltip: AppStrings.exportExcel,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => _exportPdf(context, ref),
              tooltip: AppStrings.exportPdf,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // انتخاب بازه تاریخ
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بازه زمانی',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DateButton(
                              label: AppStrings.fromDate,
                              date: params.from,
                              onPick: (d) => ref
                                  .read(reportParamsProvider.notifier)
                                  .state = ReportParams(from: d, to: params.to),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('تا',
                                style: TextStyle(fontFamily: 'Vazirmatn')),
                          ),
                          Expanded(
                            child: _DateButton(
                              label: AppStrings.toDate,
                              date: params.to,
                              onPick: (d) => ref
                                      .read(reportParamsProvider.notifier)
                                      .state =
                                  ReportParams(from: params.from, to: d),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // دسترسی سریع
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text(AppStrings.daily,
                                style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 12,
                                    color: AppColors.textPrimary)),
                            backgroundColor: AppColors.infoLight,
                            onPressed: () {
                              final now = DateTime.now();
                              ref.read(reportParamsProvider.notifier).state =
                                  ReportParams(from: now, to: now);
                            },
                          ),
                          ActionChip(
                            label: const Text(AppStrings.weekly,
                                style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 12,
                                    color: AppColors.textPrimary)),
                            backgroundColor: AppColors.infoLight,
                            onPressed: () {
                              final now = DateTime.now();
                              ref.read(reportParamsProvider.notifier).state =
                                  ReportParams(
                                from: now.subtract(const Duration(days: 7)),
                                to: now,
                              );
                            },
                          ),
                          ActionChip(
                            label: const Text(AppStrings.monthly,
                                style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 12,
                                    color: AppColors.textPrimary)),
                            backgroundColor: AppColors.infoLight,
                            onPressed: () {
                              final now = DateTime.now();
                              ref.read(reportParamsProvider.notifier).state =
                                  ReportParams(
                                from: now.subtract(const Duration(days: 30)),
                                to: now,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // نتایج
              report.when(
                data: (data) => Column(
                  children: [
                    // کارت‌های خلاصه
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: AppStrings.totalSales,
                            value: CurrencyFormatter.format(data.totalSales),
                            icon: Icons.trending_up,
                            color: AppColors.cardSales,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'تعداد فاکتور',
                            value:
                                '${CurrencyFormatter.formatNumber(data.totalInvoices)} فاکتور',
                            icon: Icons.receipt_long,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // نمودار فروش روزانه
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('فروش روزانه',
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                )),
                            const SizedBox(height: 12),
                            SalesChart(dailySales: data.dailySales),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // پرفروش‌ترین محصولات
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(AppStrings.topProducts,
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                )),
                            const SizedBox(height: 12),
                            if (data.topProducts.isEmpty)
                              const Text('داده‌ای برای نمایش وجود ندارد',
                                  style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      color: AppColors.textSecondary))
                            else
                              DataTable(
                                columnSpacing: 12,
                                headingTextStyle: const TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                                dataTextStyle: const TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 12,
                                ),
                                columns: const [
                                  DataColumn(label: Text('محصول')),
                                  DataColumn(label: Text('تعداد')),
                                  DataColumn(label: Text('فروش')),
                                ],
                                rows: data.topProducts
                                    .take(10)
                                    .map((p) => DataRow(
                                          cells: [
                                            DataCell(Text(p.productName,
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                            DataCell(Text(
                                                CurrencyFormatter.formatNumber(
                                                    p.totalQuantity))),
                                            DataCell(Text(
                                                CurrencyFormatter.formatNumber(
                                                    p.totalRevenue))),
                                          ],
                                        ))
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                loading: () => const ShimmerList(itemCount: 4, itemHeight: 120),
                error: (_, __) => const Center(
                  child: Text('خطا در بارگذاری گزارش',
                      style: TextStyle(fontFamily: 'Vazirmatn')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;

  const _DateButton(
      {required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showPersianDatePicker(
          context: context,
          initialDate: Jalali.fromDateTime(date),
          firstDate: Jalali(1400),
          lastDate: Jalali(1410),
        );
        if (picked != null) onPick(picked.toDateTime());
      },
      child: Text(
        '${label}\n${DateConverter.toShamsi(date)}',
        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
          Text(title,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 11,
                color: Colors.white70,
              )),
        ],
      ),
    );
  }
}
