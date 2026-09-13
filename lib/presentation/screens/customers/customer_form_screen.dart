/// فرم افزودن / ویرایش مشتری
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/models/customer.dart';
import '../../../domain/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/common/app_header_back_button.dart';
import '../../widgets/common/currency_input.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final int? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  double _creditLimit = 0;
  bool _isLoading = false;

  bool get _isEdit => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadCustomer();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);
    final customer =
        await ref.read(customerRepositoryProvider).findById(widget.customerId!);
    if (customer != null && mounted) {
      _nameController.text = customer.name;
      _phoneController.text = customer.phone ?? '';
      _addressController.text = customer.address ?? '';
      setState(() {
        _creditLimit = customer.creditLimit;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final customer = Customer(
      id: widget.customerId ?? 0,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      creditLimit: _creditLimit,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    final success =
        await ref.read(customerFormProvider.notifier).save(customer);
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'مشتری ویرایش شد' : 'مشتری افزوده شد',
            style: const TextStyle(fontFamily: 'Vazirmatn'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(customerFormProvider);
    final isSaving = formState.isLoading;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppHeaderBackButton(fallbackRoute: '/customers'),
          title: Text(
            _isEdit ? 'ویرایش مشتری' : AppStrings.addCustomer,
            style: const TextStyle(
                fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // نام مشتری
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: AppStrings.customerName,
                          labelStyle: const TextStyle(fontFamily: 'Vazirmatn'),
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontFamily: 'Vazirmatn'),
                        validator: Validators.required,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // شماره تلفن
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: '${AppStrings.phone} (اختیاری)',
                          labelStyle: const TextStyle(fontFamily: 'Vazirmatn'),
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontFamily: 'Vazirmatn'),
                        validator: (v) => v != null && v.isNotEmpty
                            ? Validators.phone(v)
                            : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // آدرس
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: '${AppStrings.address} (اختیاری)',
                          labelStyle: const TextStyle(fontFamily: 'Vazirmatn'),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontFamily: 'Vazirmatn'),
                      ),
                      const SizedBox(height: 16),

                      // سقف اعتبار نسیه
                      CurrencyInput(
                        label:
                            '${AppStrings.creditLimit} (اختیاری — ۰ = بدون محدودیت)',
                        initialValue: _creditLimit,
                        onChanged: (v) => setState(() => _creditLimit = v),
                      ),
                      const SizedBox(height: 24),

                      // دکمه ذخیره
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isSaving ? null : _save,
                          icon: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            isSaving ? 'در حال ذخیره...' : AppStrings.save,
                            style: const TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
