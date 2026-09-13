/// صفحه مدیریت انبار — نمایش موجودی همه محصولات
/// با رنگ‌بندی وضعیت: قرمز = کمبود موجودی، سبز = موجودی کافی
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/product.dart';
import '../../providers/product_provider.dart';
import '../../widgets/common/app_header_back_button.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  /// کنترلر فیلد جستجو
  final _searchController = TextEditingController();

  /// کلید RefreshIndicator برای pull-to-refresh
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// بارگذاری مجدد داده‌ها با invalidate کردن provider
  Future<void> _onRefresh() async {
    ref.invalidate(productsStreamProvider);
    // کمی صبر تا stream ری‌ست شود
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    // دریافت لیست محصولات فیلترشده از provider
    final productsAsync = ref.watch(productsStreamProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // ─── نوار بالا ───────────────────────────────────────────
        appBar: AppBar(
          leading: const AppHeaderBackButton(),
          title: const Text(
            AppStrings.inventory,
            style:
                TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
          ),
          actions: [
            // دکمه تازه‌سازی دستی
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'بارگذاری مجدد',
              onPressed: () => _refreshKey.currentState?.show(),
            ),
          ],
          // نوار جستجو در پایین AppBar
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'جستجو در انبار...',
                  hintStyle:
                      const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  // دکمه پاک‌کردن جستجو
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            // ری‌ست کردن query provider
                            ref
                                .read(productSearchQueryProvider.notifier)
                                .state = '';
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (q) {
                  // بروزرسانی query برای فیلتر stream
                  ref.read(productSearchQueryProvider.notifier).state = q;
                },
              ),
            ),
          ),
        ),

        // ─── محتوای اصلی ─────────────────────────────────────────
        body: RefreshIndicator(
          key: _refreshKey,
          onRefresh: _onRefresh,
          child: productsAsync.when(
            // حالت بارگذاری — نمایش skeleton
            loading: () => _buildSkeletonList(),
            // حالت خطا
            error: (error, _) => _buildErrorState(error.toString()),
            // حالت موفق — نمایش لیست
            data: (products) {
              if (products.isEmpty) return _buildEmptyState();
              return _buildProductList(products);
            },
          ),
        ),

        // ─── دکمه شناور برای تنظیم موجودی ────────────────────────
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/inventory/adjust'),
          icon: const Icon(Icons.tune_outlined),
          label: const Text(
            AppStrings.adjustStock,
            style: TextStyle(fontFamily: 'Vazirmatn'),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  /// ساختار لیست محصولات با سربرگ آمار
  Widget _buildProductList(List<Product> products) {
    // محاسبه تعداد محصولات کم‌موجودی برای نمایش خلاصه
    final lowStockCount = products.where((p) => p.isLowStock).length;
    final totalCount = products.length;

    return Column(
      children: [
        // ─── خلاصه وضعیت انبار ───────────────────────────────────
        _InventorySummaryBar(
          totalCount: totalCount,
          lowStockCount: lowStockCount,
        ),
        // ─── لیست اسکرول‌پذیر محصولات ────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: products.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              return _InventoryProductTile(product: products[index]);
            },
          ),
        ),
      ],
    );
  }

  /// نمایش skeleton هنگام بارگذاری
  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 10,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => const _SkeletonTile(),
    );
  }

  /// حالت خطا با امکان retry
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            'خطا در بارگذاری انبار',
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text(AppStrings.retry,
                style: TextStyle(fontFamily: 'Vazirmatn')),
            onPressed: () => ref.invalidate(productsStreamProvider),
          ),
        ],
      ),
    );
  }

  /// حالت خالی — هیچ محصولی نیست
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warehouse_outlined,
              size: 80, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'انبار خالی است',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ابتدا محصولاتی به سیستم اضافه کنید',
            style:
                TextStyle(fontFamily: 'Vazirmatn', color: AppColors.textHint),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('افزودن محصول',
                style: TextStyle(fontFamily: 'Vazirmatn')),
            onPressed: () => context.go('/products/new'),
          ),
        ],
      ),
    );
  }
}

// ─── ویجت خلاصه وضعیت انبار ─────────────────────────────────────────────────

/// نوار خلاصه‌ای که تعداد کل و کم‌موجود را نشان می‌دهد
class _InventorySummaryBar extends StatelessWidget {
  final int totalCount;
  final int lowStockCount;

  const _InventorySummaryBar({
    required this.totalCount,
    required this.lowStockCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // تعداد کل محصولات
          _SummaryChip(
            label: 'کل محصولات',
            value: totalCount.toString(),
            color: AppColors.primary,
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(width: 12),
          // تعداد محصولات کم‌موجودی
          _SummaryChip(
            label: 'کمبود موجودی',
            value: lowStockCount.toString(),
            color: lowStockCount > 0 ? AppColors.error : AppColors.success,
            icon: Icons.warning_amber_outlined,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ردیف محصول در لیست انبار ───────────────────────────────────────────────

/// هر ردیف: نام محصول، موجودی فعلی، حداقل موجودی، نشان‌گر وضعیت
class _InventoryProductTile extends StatelessWidget {
  final Product product;

  const _InventoryProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    // تعیین رنگ بر اساس وضعیت موجودی
    final isLow = product.isLowStock;
    final stockColor = isLow ? AppColors.error : AppColors.success;
    final stockBgColor = isLow ? AppColors.errorLight : AppColors.successLight;

    return InkWell(
      onTap: () => context.go('/inventory/adjust?productId=${product.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ─── آیکون وضعیت انبار ──────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: stockBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLow
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: stockColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // ─── نام و بارکد محصول ──────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // حداقل موجودی
                  Text(
                    'حداقل: ${CurrencyFormatter.formatNumber(product.minStockAlert)} عدد',
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // ─── نشان‌گر موجودی فعلی با رنگ‌بندی ──────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Badge موجودی با رنگ متناسب
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stockBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stockColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    '${CurrencyFormatter.formatNumber(product.stockQuantity)} عدد',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: stockColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // برچسب وضعیت
                Text(
                  isLow ? 'کمبود موجودی' : 'موجودی کافی',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 10,
                    color: stockColor,
                  ),
                ),
              ],
            ),

            // آیکون ناوبری برای تنظیم موجودی
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton برای حالت بارگذاری ────────────────────────────────────────────

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // آیکون skeleton
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          // متن skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 160,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 11,
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // badge skeleton
          Container(
            height: 28,
            width: 70,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}
