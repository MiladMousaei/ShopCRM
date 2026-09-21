// صفحه تنظیم موجودی انبار
// کاربر می‌تواند ورود، خروج یا تعدیل موجودی ثبت کند
// اگر productId ارسال شود، محصول از قبل انتخاب است؛ وگرنه ابتدا جستجو نمایش می‌یابد
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/local/database.dart';
import '../../../domain/models/inventory_log.dart';
import '../../../domain/models/product.dart';
import '../../../services/notification_service.dart';
import '../../../services/log_service.dart';
import '../../providers/product_provider.dart';
import '../../widgets/common/app_header_back_button.dart';

class AdjustStockScreen extends ConsumerStatefulWidget {
  /// شناسه محصول — اختیاری
  /// اگر null باشد صفحه جستجو نشان داده می‌شود
  final int? productId;

  const AdjustStockScreen({super.key, this.productId});

  @override
  ConsumerState<AdjustStockScreen> createState() => _AdjustStockScreenState();
}

class _AdjustStockScreenState extends ConsumerState<AdjustStockScreen> {
  /// کلید فرم برای اعتبارسنجی
  final _formKey = GlobalKey<FormState>();

  /// کنترلرهای متن
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _searchController = TextEditingController();

  /// محصول انتخاب‌شده
  Product? _selectedProduct;

  /// نوع تراکنش انبار
  InventoryLogType _selectedType = InventoryLogType.stockIn;

  /// در حال پردازش؟
  bool _isSaving = false;

  /// نتایج جستجو
  List<Product> _searchResults = [];

  /// آیا جستجو در حال انجام است؟
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // اگر productId داده شده، محصول را بارگذاری کن
    if (widget.productId != null) {
      _loadProduct(widget.productId!);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// بارگذاری محصول با شناسه مشخص
  Future<void> _loadProduct(int id) async {
    final repo = ref.read(productRepositoryProvider);
    final product = await repo.findById(id);
    if (mounted && product != null) {
      setState(() => _selectedProduct = product);
    }
  }

  /// جستجوی محصول بر اساس متن
  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      final products = await repo.getProducts();
      // فیلتر محلی برای جستجو
      final filtered = products
          .where((p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              (p.barcode ?? '').contains(query))
          .take(20)
          .toList();
      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  /// ذخیره تراکنش انبار
  Future<void> _save() async {
    // اعتبارسنجی فرم
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      _showError('لطفاً ابتدا یک محصول انتخاب کنید');
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      _showError('تعداد باید بزرگ‌تر از صفر باشد');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final productId = _selectedProduct!.id;
      late int previousStock;
      late int newStock;
      late String productName;
      late int minStockAlert;
      await db.transaction(() async {
        final fresh = await db.productsDao.findById(productId);
        if (fresh == null || !fresh.isActive) {
          throw StateError('محصول حذف شده یا در دسترس نیست');
        }
        previousStock = fresh.stockQuantity;
        productName = fresh.name;
        minStockAlert = fresh.minStockAlert;
        switch (_selectedType) {
          case InventoryLogType.stockIn:
            newStock = previousStock + quantity;
            break;
          case InventoryLogType.stockOut:
            if (quantity > previousStock) {
              throw StateError('موجودی برای خروج این تعداد کافی نیست');
            }
            newStock = previousStock - quantity;
            break;
          case InventoryLogType.adjust:
            newStock = quantity;
            break;
          default:
            throw StateError('نوع عملیات انبار نامعتبر است');
        }
        await db.productsDao.updateStock(productId, newStock);
        await db.into(db.inventoryLogsTable).insert(
              InventoryLogsTableCompanion.insert(
                productId: productId,
                type: _selectedType.name,
                quantity: quantity,
                previousStock: previousStock,
                newStock: newStock,
                reason: drift.Value(_reasonController.text.isEmpty
                    ? null
                    : _reasonController.text),
                createdAt: DateTime.now(),
              ),
            );
      });

      if (newStock <= minStockAlert) {
        try {
          await NotificationService.showLowStockAlert(productName, newStock);
        } catch (error, stack) {
          await LogService.error('نمایش اعلان کمبود موجودی ناموفق بود', error, stack);
        }
      }

      if (mounted) {
        // نمایش پیام موفقیت و برگشت به صفحه قبل
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'موجودی با موفقیت تنظیم شد: $previousStock → $newStock عدد',
              style: const TextStyle(fontFamily: 'Vazirmatn'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      _showError('خطا در ثبت تراکنش: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Vazirmatn')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // ─── نوار بالا ───────────────────────────────────────────
        appBar: AppBar(
          leading: const AppHeaderBackButton(fallbackRoute: '/inventory'),
          title: const Text(
            AppStrings.adjustStock,
            style:
                TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
          ),
        ),

        // ─── محتوای اصلی ─────────────────────────────────────────
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // اگر محصولی انتخاب نشده → نمایش جستجو
                if (_selectedProduct == null) ...[
                  _buildProductSearch(),
                ] else ...[
                  // کارت اطلاعات محصول انتخاب‌شده
                  _buildSelectedProductCard(),
                  const SizedBox(height: 20),

                  // نوع تراکنش با Radio فارسی
                  _buildTypeSelector(),
                  const SizedBox(height: 16),

                  // فیلد تعداد
                  _buildQuantityField(),
                  const SizedBox(height: 16),

                  // فیلد دلیل (اختیاری)
                  _buildReasonField(),
                  const SizedBox(height: 24),

                  // دکمه ذخیره
                  _buildSaveButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ویجت جستجوی محصول — وقتی productId داده نشده نمایش می‌یابد
  Widget _buildProductSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ابتدا محصول مورد نظر را جستجو کنید:',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        // فیلد جستجو
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'نام یا بارکد محصول...',
            hintStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
            prefixIcon: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: _searchProducts,
        ),
        const SizedBox(height: 8),
        // نتایج جستجو
        if (_searchResults.isNotEmpty)
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final product = _searchResults[index];
                return ListTile(
                  title: Text(
                    product.name,
                    style: const TextStyle(
                        fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'موجودی: ${CurrencyFormatter.formatQuantity(product.stockQuantity)}',
                    style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: product.isLowStock
                          ? AppColors.errorLight
                          : AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.isLowStock ? 'کمبود' : 'موجود',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11,
                        color: product.isLowStock
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ),
                  // انتخاب محصول از نتایج جستجو
                  onTap: () {
                    setState(() {
                      _selectedProduct = product;
                      _searchResults = [];
                      _searchController.clear();
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  /// کارت نمایش محصول انتخاب‌شده
  Widget _buildSelectedProductCard() {
    final product = _selectedProduct!;
    final isLow = product.isLowStock;

    return Card(
      elevation: 0,
      color: AppColors.infoLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // آیکون وضعیت موجودی
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isLow ? AppColors.errorLight : AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: isLow ? AppColors.error : AppColors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // اطلاعات محصول
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'موجودی فعلی: ${CurrencyFormatter.formatQuantity(product.stockQuantity)}',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: isLow ? AppColors.error : AppColors.textSecondary,
                      fontWeight: isLow ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    'حداقل موجودی: ${CurrencyFormatter.formatQuantity(product.minStockAlert)}',
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // دکمه تغییر محصول — فقط اگر productId ارسال نشده باشد
            if (widget.productId == null)
              TextButton(
                onPressed: () => setState(() => _selectedProduct = null),
                child: const Text(
                  'تغییر',
                  style: TextStyle(fontFamily: 'Vazirmatn'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// انتخاب نوع تراکنش با Radio button فارسی
  Widget _buildTypeSelector() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نوع عملیات:',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // ورود کالا
            _buildTypeRadio(
              type: InventoryLogType.stockIn,
              label: AppStrings.stockIn,
              icon: Icons.add_circle_outline,
              color: AppColors.success,
            ),
            // خروج کالا
            _buildTypeRadio(
              type: InventoryLogType.stockOut,
              label: AppStrings.stockOut,
              icon: Icons.remove_circle_outline,
              color: AppColors.error,
            ),
            // تعدیل موجودی
            _buildTypeRadio(
              type: InventoryLogType.adjust,
              label: AppStrings.stockAdjust,
              icon: Icons.tune_outlined,
              color: AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }

  /// یک ردیف Radio button برای نوع تراکنش
  Widget _buildTypeRadio({
    required InventoryLogType type,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
            Icon(icon,
                color: isSelected ? color : AppColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// فیلد ورود تعداد
  Widget _buildQuantityField() {
    // توضیح متناسب با نوع تراکنش
    final hint = _selectedType == InventoryLogType.adjust
        ? 'موجودی جدید (عدد دقیق)'
        : 'تعداد ${_selectedType == InventoryLogType.stockIn ? "ورودی" : "خروجی"}';

    return TextFormField(
      controller: _quantityController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: AppStrings.quantity,
        labelStyle: const TextStyle(fontFamily: 'Vazirmatn'),
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
        prefixIcon: const Icon(Icons.numbers_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'تعداد الزامی است';
        final n = int.tryParse(v);
        if (n == null || n <= 0) return 'عدد معتبر وارد کنید';
        return null;
      },
    );
  }

  /// فیلد دلیل تغییر موجودی (اختیاری)
  Widget _buildReasonField() {
    return TextFormField(
      controller: _reasonController,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: '${AppStrings.reason} (اختیاری)',
        labelStyle: const TextStyle(fontFamily: 'Vazirmatn'),
        hintText: 'مثال: دریافت از تأمین‌کننده / خرابی / انبارگردانی',
        hintStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
        prefixIcon: const Icon(Icons.note_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  /// دکمه ذخیره نهایی
  Widget _buildSaveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_circle_outline),
        label: Text(
          _isSaving ? 'در حال ذخیره...' : AppStrings.save,
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
