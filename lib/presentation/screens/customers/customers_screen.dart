/// صفحه لیست مشتریان
/// جستجو، نمایش بدهی، و ناوبری به جزئیات هر مشتری
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/customer.dart';
import '../../../domain/models/product.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common/app_header_back_button.dart';

/// Provider برای جستجوی مشتریان
final customerSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider استریم مشتریان با فیلتر جستجو
final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  final query = ref.watch(customerSearchQueryProvider);
  return repo.watchCustomers(search: query.isEmpty ? null : query);
});

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  /// کنترلر فیلد جستجو
  final _searchController = TextEditingController();

  /// کلید برای pull-to-refresh
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// بارگذاری مجدد با invalidate کردن provider
  Future<void> _onRefresh() async {
    ref.invalidate(customersStreamProvider);
    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// باز کردن دیالوگ افزودن مشتری جدید
  void _openAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CustomerFormDialog(
        onSaved: () {
          ref.invalidate(customersStreamProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // دریافت لیست مشتریان از stream
    final customersAsync = ref.watch(customersStreamProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // ─── نوار بالا ───────────────────────────────────────────
        appBar: AppBar(
          leading: const AppHeaderBackButton(),
          title: const Text(
            AppStrings.customers,
            style:
                TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
          ),
          actions: [
            // دکمه بارگذاری مجدد
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
                  hintText: 'جستجو در مشتریان (نام یا تلفن)...',
                  hintStyle:
                      const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  // دکمه پاک کردن جستجو
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(customerSearchQueryProvider.notifier)
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
                  // بروزرسانی query provider
                  ref.read(customerSearchQueryProvider.notifier).state = q;
                },
              ),
            ),
          ),
        ),

        // ─── محتوای اصلی ─────────────────────────────────────────
        body: RefreshIndicator(
          key: _refreshKey,
          onRefresh: _onRefresh,
          child: customersAsync.when(
            loading: () => _buildSkeletonList(),
            error: (error, _) => _buildErrorState(error.toString()),
            data: (customers) {
              if (customers.isEmpty) return _buildEmptyState();
              return _buildCustomerList(customers);
            },
          ),
        ),

        // ─── دکمه شناور برای افزودن مشتری ────────────────────────
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddCustomerDialog,
          icon: const Icon(Icons.person_add_outlined),
          label: const Text(
            AppStrings.addCustomer,
            style: TextStyle(fontFamily: 'Vazirmatn'),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  /// ساخت لیست مشتریان با خلاصه آمار بدهی
  Widget _buildCustomerList(List<Customer> customers) {
    // محاسبه تعداد بدهکاران برای نوار خلاصه
    final debtorCount = customers.where((c) => c.hasDebt).length;
    final totalDebt = customers.fold<double>(0, (sum, c) => sum + c.totalDebt);

    return Column(
      children: [
        // نوار خلاصه آمار مشتریان
        if (debtorCount > 0)
          _DebtSummaryBar(debtorCount: debtorCount, totalDebt: totalDebt),
        // لیست مشتریان
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: customers.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              return _CustomerTile(customer: customers[index]);
            },
          ),
        ),
      ],
    );
  }

  /// Skeleton برای حالت بارگذاری
  Widget _buildSkeletonList() {
    return ListView.separated(
      itemCount: 8,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => const _SkeletonCustomerTile(),
    );
  }

  /// حالت خطا
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            'خطا در بارگذاری مشتریان',
            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text(AppStrings.retry,
                style: TextStyle(fontFamily: 'Vazirmatn')),
            onPressed: () => ref.invalidate(customersStreamProvider),
          ),
        ],
      ),
    );
  }

  /// حالت خالی — هیچ مشتری‌ای ثبت نشده
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'هیچ مشتری‌ای ثبت نشده',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'برای افزودن مشتری جدید دکمه + را بزنید',
            style:
                TextStyle(fontFamily: 'Vazirmatn', color: AppColors.textHint),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_outlined),
            label: const Text(AppStrings.addCustomer,
                style: TextStyle(fontFamily: 'Vazirmatn')),
            onPressed: _openAddCustomerDialog,
          ),
        ],
      ),
    );
  }
}

// ─── نوار خلاصه بدهی ─────────────────────────────────────────────────────────

class _DebtSummaryBar extends StatelessWidget {
  final int debtorCount;
  final double totalDebt;

  const _DebtSummaryBar({
    required this.debtorCount,
    required this.totalDebt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.errorLight,
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$debtorCount مشتری بدهکار — جمع بدهی: ${CurrencyFormatter.format(totalDebt)}',
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ردیف مشتری ──────────────────────────────────────────────────────────────

/// ردیف نمایش یک مشتری در لیست
class _CustomerTile extends StatelessWidget {
  final Customer customer;

  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final hasDebt = customer.hasDebt;

    return InkWell(
      // ناوبری به صفحه جزئیات مشتری
      onTap: () => context.go('/customers/${customer.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ─── آواتار نام مشتری ────────────────────────────────
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  hasDebt ? AppColors.errorLight : AppColors.infoLight,
              child: Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: hasDebt ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ─── اطلاعات مشتری ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (customer.phone != null)
                    Text(
                      customer.phone!,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            // ─── نشان‌گر بدهی ────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: hasDebt ? AppColors.errorLight : AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
                border: hasDebt
                    ? Border.all(color: AppColors.error.withOpacity(0.4))
                    : null,
              ),
              child: Text(
                hasDebt ? 'بدهکار' : 'تسویه',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: hasDebt ? AppColors.error : AppColors.success,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ────────────────────────────────────────────────────────────────

class _SkeletonCustomerTile extends StatelessWidget {
  const _SkeletonCustomerTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // آواتار skeleton
          const CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.background,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
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
          Container(
            height: 36,
            width: 80,
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

// ─── دیالوگ فرم مشتری ────────────────────────────────────────────────────────

/// دیالوگ افزودن / ویرایش مشتری
class CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? customer; // اگر null → افزودن، وگرنه → ویرایش
  final VoidCallback? onSaved;

  const CustomerFormDialog({this.customer, this.onSaved});

  @override
  ConsumerState<CustomerFormDialog> createState() => CustomerFormDialogState();
}

class CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _creditLimitController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // پر کردن فیلدها از مشتری موجود (ویرایش) یا خالی (افزودن)
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController =
        TextEditingController(text: widget.customer?.phone ?? '');
    _addressController =
        TextEditingController(text: widget.customer?.address ?? '');
    _creditLimitController = TextEditingController(
        text: widget.customer?.creditLimit.toStringAsFixed(0) ?? '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(customerRepositoryProvider);
      final customer = Customer(
        id: widget.customer?.id ?? 0,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        creditLimit: double.tryParse(_creditLimitController.text) ?? 0,
        totalDebt: widget.customer?.totalDebt ?? 0,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );
      await repo.saveCustomer(customer);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: $e',
                style: const TextStyle(fontFamily: 'Vazirmatn')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(
          isEdit ? 'ویرایش مشتری' : AppStrings.addCustomer,
          style: const TextStyle(
              fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // نام مشتری
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: AppStrings.customerName,
                    labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'نام الزامی است' : null,
                ),
                const SizedBox(height: 12),
                // شماره تلفن
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: AppStrings.phone,
                    labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // آدرس
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: AppStrings.address,
                    labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // سقف اعتبار
                TextFormField(
                  controller: _creditLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: AppStrings.creditLimit,
                    labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
                    prefixIcon: Icon(Icons.credit_card_outlined),
                    suffixText: 'تومان',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel,
                style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(AppStrings.save,
                    style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ],
      ),
    );
  }
}
