import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/product.dart';
import '../../providers/product_provider.dart';
import '../../widgets/common/app_header_back_button.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/common/managed_product_image.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final products = ref.watch(productsStreamProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppHeaderBackButton(),
          title: const Text(AppStrings.products),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'جستجوی محصول...',
                  hintStyle:
                      const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
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
                onChanged: (q) =>
                    ref.read(productSearchQueryProvider.notifier).state = q,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            _CategoryFilterRow(),
            Expanded(child: _buildBody(context, ref, products, isWide)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/products/new'),
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.addProduct,
              style: TextStyle(fontFamily: 'Vazirmatn')),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      AsyncValue<List<Product>> products, bool isWide) {
    return products.when(
      data: (list) => list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 64, color: AppColors.textHint),
                  const SizedBox(height: 12),
                  const Text('محصولی یافت نشد',
                      style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text(AppStrings.addProduct,
                        style: TextStyle(fontFamily: 'Vazirmatn')),
                    onPressed: () => context.go('/products/new'),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 4 : 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => _ProductCard(product: list[i]),
            ),
      loading: () => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 4 : 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 8,
        itemBuilder: (_, __) =>
            const ShimmerList(itemCount: 1, itemHeight: 180),
      ),
      error: (_, __) => const Center(
        child: Text('خطا در بارگذاری محصولات',
            style: TextStyle(fontFamily: 'Vazirmatn')),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.go('/products/${product.id}'),
      onLongPress: () => _showQuickEdit(context, ref),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // تصویر
            Expanded(
              flex: 3,
              child: product.imageUrl != null
                  ? ManagedProductImage(
                      relativePath: product.imageUrl,
                      width: double.infinity,
                    )
                  : _Placeholder(),
            ),
            // اطلاعات
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CurrencyFormatter.format(product.sellPrice),
                          style: const TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        _StockBadge(
                            stock: product.stockQuantity,
                            isLow: product.isLowStock),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickEdit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('ویرایش محصول',
                  style: TextStyle(fontFamily: 'Vazirmatn')),
              onTap: () {
                Navigator.pop(context);
                context.go('/products/${product.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('تغییر سریع قیمت',
                  style: TextStyle(fontFamily: 'Vazirmatn')),
              onTap: () {
                Navigator.pop(context);
                _showPriceDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(
      text: CurrencyFormatter.formatNumber(product.sellPrice),
    );
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'قیمت: ${product.name}',
            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 15),
          ),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'قیمت فروش (تومان)',
              labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف',
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
            ElevatedButton(
              onPressed: () async {
                final raw = ctrl.text.replaceAll(',', '').trim();
                final price = double.tryParse(raw);
                if (price == null || price <= 0) return;
                final updated = product.copyWith(sellPrice: price);
                await ref.read(productRepositoryProvider).saveProduct(updated);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('ذخیره',
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
          ],
        ),
      ),
    );
  }
}

/// ردیف چیپ‌های فیلتر دسته‌بندی — بالای لیست محصولات
class _CategoryFilterRow extends ConsumerWidget {
  const _CategoryFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(availableCategoriesProvider);
    final selected = ref.watch(productCategoryFilterProvider);

    return categories.when(
      data: (cats) {
        if (cats.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // چیپ "همه"
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilterChip(
                  label: const Text('همه',
                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
                  selected: selected == null,
                  onSelected: (_) => ref
                      .read(productCategoryFilterProvider.notifier)
                      .state = null,
                ),
              ),
              // چیپ هر دسته
              for (final cat in cats)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    label: Text(cat,
                        style: const TextStyle(
                            fontFamily: 'Vazirmatn', fontSize: 12)),
                    selected: selected == cat,
                    onSelected: (_) => ref
                        .read(productCategoryFilterProvider.notifier)
                        .state = selected == cat ? null : cat,
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(Icons.inventory_2_outlined,
            size: 40, color: AppColors.textHint),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int stock;
  final bool isLow;
  const _StockBadge({required this.stock, required this.isLow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLow ? AppColors.errorLight : AppColors.successLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${CurrencyFormatter.formatNumber(stock)}',
        style: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isLow ? AppColors.error : AppColors.success,
        ),
      ),
    );
  }
}
