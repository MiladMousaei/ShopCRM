import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/invoice.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/customer.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/printer_provider.dart';
import '../../widgets/common/app_header_back_button.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/common/managed_product_image.dart';
import '../../widgets/invoice/cart_item_tile.dart';
import '../../widgets/invoice/invoice_summary_card.dart';
import '../../widgets/barcode/barcode_scanner_widget.dart';

class NewInvoiceScreen extends ConsumerStatefulWidget {
  const NewInvoiceScreen({super.key});

  @override
  ConsumerState<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends ConsumerState<NewInvoiceScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // کلیدهای میانبر ویندوز
  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f3) _openScanner();
          if (event.logicalKey == LogicalKeyboardKey.escape) _handleBack();
          if (event.logicalKey == LogicalKeyboardKey.keyP &&
              HardwareKeyboard.instance.isControlPressed) {
            _submitInvoice();
          }
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.newInvoice),
            leading: AppHeaderBackButton(
              onPressed: _handleBack,
            ),
            actions: [
              if (!cart.isEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep,
                      color: Colors.white, size: 20),
                  label: const Text('پاک کردن',
                      style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          color: Colors.white,
                          fontSize: 13)),
                  onPressed: _showClearCartDialog,
                ),
            ],
          ),
          resizeToAvoidBottomInset: false,
          body: LoadingOverlay(
            isLoading: cart.isSubmitting,
            message: 'در حال ثبت فاکتور...',
            child: Column(
              children: [
                // کارت خلاصه
                InvoiceSummaryCard(cart: cart),

                // ردیف اکشن‌ها
                _ActionRow(
                  onScan: _openScanner,
                  onSearch: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _searchController.clear();
                  }),
                  onCustomer: _openCustomerPicker,
                  customerName: cart.customer?.name,
                ),

                // فیلد جستجو (toggle) — بدون dropdown
                if (_showSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'نام یا بارکد محصول...',
                        hintStyle: const TextStyle(fontFamily: 'Vazirmatn'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _showSearch = false);
                          },
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),

                // لیست سبد یا جستجو
                Expanded(
                  child: _showSearch
                      ? _ProductSearchInline(
                          query: _searchController.text,
                          onProductSelected: (p) {
                            ref.read(cartProvider.notifier).addProduct(p);
                            _searchController.clear();
                            setState(() {});
                            _showAddedSnack(p.name);
                          },
                        )
                      : cart.isEmpty
                          ? _CartEmpty(onScan: _openScanner)
                          : ListView.builder(
                              itemCount: cart.items.length,
                              padding: const EdgeInsets.only(bottom: 8),
                              itemBuilder: (_, i) =>
                                  CartItemTile(item: cart.items[i]),
                            ),
                ),

                // bottom bar
                _BottomBar(
                  cart: cart,
                  onSubmit: _submitInvoice,
                  onDiscount: _openDiscountSheet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: BarcodeScannerWidget(
          onDetected: (barcode) async {
            final product = await ref
                .read(productRepositoryProvider)
                .findByBarcode(barcode);
            if (product != null) {
              ref.read(cartProvider.notifier).addProduct(product);
              _showAddedSnack(product.name);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('بارکد $barcode در سیستم ثبت نشده',
                      style: const TextStyle(fontFamily: 'Vazirmatn')),
                  backgroundColor: AppColors.warning,
                  action: SnackBarAction(
                    label: 'افزودن محصول',
                    textColor: Colors.white,
                    onPressed: () =>
                        context.go('/products/new?barcode=$barcode'),
                  ),
                ));
              }
            }
          },
        ),
      ),
    );
  }

  void _openCustomerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomerPickerSheet(
        onSelected: (customer) {
          ref.read(cartProvider.notifier).setCustomer(customer);
          Navigator.pop(context);
        },
        onClear: () {
          ref.read(cartProvider.notifier).setCustomer(null);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openDiscountSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DiscountSheet(
        currentDiscount: ref.read(cartProvider).discount,
        isPercent: ref.read(cartProvider).isDiscountPercent,
        onApply: (value, isPercent) {
          ref
              .read(cartProvider.notifier)
              .setDiscount(value, isPercent: isPercent);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// ثبت فاکتور + نمایش دیالوگ موفقیت با گزینه‌های بستن یا چاپ
  Future<void> _submitInvoice() async {
    final id = await ref.read(cartProvider.notifier).submitInvoice();

    if (id == null) {
      final err = ref.read(cartProvider).error;
      if (mounted && err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err, style: const TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    Invoice? invoice;
    try {
      invoice = await ref.read(invoiceRepositoryProvider).findById(id);
    } catch (_) {}

    ref.read(cartProvider.notifier).clearCart();

    if (!mounted) return;

    final shouldPrint = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InvoiceSuccessDialog(
        invoiceNumber: invoice?.invoiceNumber ?? 'INV-$id',
      ),
    );

    if (shouldPrint == true && invoice != null && mounted) {
      try {
        await ref.read(printerProvider.notifier).printInvoice(invoice);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پرینتر متصل نیست',
                  style: TextStyle(fontFamily: 'Vazirmatn')),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    }

    if (mounted) context.pop();
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('پاک کردن سبد'),
          content: const Text('آیا از پاک کردن سبد خرید مطمئن هستید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                ref.read(cartProvider.notifier).clearCart();
                Navigator.pop(dialogContext);
                _goBack();
              },
              child: const Text('پاک کردن'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBack() {
    if (ref.read(cartProvider).isEmpty) {
      _goBack();
    } else {
      _showClearCartDialog();
    }
  }

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _showAddedSnack(String productName) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"$productName" به سبد اضافه شد',
          style: const TextStyle(fontFamily: 'Vazirmatn')),
      duration: const Duration(milliseconds: 1500),
      backgroundColor: AppColors.success,
    ));
  }
}

class _ActionRow extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onSearch;
  final VoidCallback onCustomer;
  final String? customerName;

  const _ActionRow({
    required this.onScan,
    required this.onSearch,
    required this.onCustomer,
    this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _ActionBtn(
            icon: Icons.qr_code_scanner,
            label: 'بارکد',
            onTap: onScan,
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            icon: Icons.search,
            label: 'جستجوی محصولات',
            onTap: onSearch,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onCustomer,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: customerName != null
                        ? AppColors.secondary
                        : AppColors.border,
                    width: customerName != null ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: customerName != null
                      ? AppColors.secondary.withValues(alpha: 0.06)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      customerName != null
                          ? Icons.person
                          : Icons.person_outline,
                      size: 16,
                      color: customerName != null
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        customerName ?? 'مشتری',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          color: customerName != null
                              ? AppColors.secondary
                              : AppColors.textSecondary,
                          fontWeight: customerName != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

class _CartEmpty extends StatelessWidget {
  final VoidCallback onScan;
  const _CartEmpty({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 52, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text(
            'سبد خرید خالی است',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'بارکد اسکن کنید یا محصول را جستجو کنید',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              color: AppColors.textHint,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final CartState cart;
  final VoidCallback onSubmit;
  final VoidCallback onDiscount;

  const _BottomBar({
    required this.cart,
    required this.onSubmit,
    required this.onDiscount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          // روش پرداخت
          _PaymentMethodRow(cart: cart),
          const SizedBox(height: 8),
          Row(
            children: [
              // تخفیف
              OutlinedButton.icon(
                icon: const Icon(Icons.local_offer_outlined, size: 16),
                label: Text(
                  cart.discountAmount > 0
                      ? CurrencyFormatter.format(cart.discountAmount)
                      : 'تخفیف',
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                ),
                onPressed: onDiscount,
                style: cart.discountAmount > 0
                    ? OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              // ثبت فاکتور
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('ثبت فاکتور',
                      style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  onPressed: cart.isEmpty ? null : onSubmit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodRow extends ConsumerWidget {
  final CartState cart;
  const _PaymentMethodRow({required this.cart});

  List<PaymentMethod> _availableMethods() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // دسکتاپ: نقد، پوز، نسیه
      return [PaymentMethod.cash, PaymentMethod.pos, PaymentMethod.credit];
    }
    // موبایل: نقد، نسیه
    return [PaymentMethod.cash, PaymentMethod.credit];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = _availableMethods();
    return Row(
      children: methods.map((method) {
        final selected = cart.paymentMethod == method;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (method == PaymentMethod.pos) {
                _showPosDialog(context, ref, cart.finalAmount);
              } else {
                ref.read(cartProvider.notifier).setPaymentMethod(method);
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? _methodColor(method).withOpacity(0.15)
                    : AppColors.background,
                border: Border.all(
                  color: selected ? _methodColor(method) : AppColors.border,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                method.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color:
                      selected ? _methodColor(method) : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showPosDialog(BuildContext context, WidgetRef ref, double amount) {
    showDialog(
      context: context,
      builder: (_) => _PosPaymentDialog(
        amount: amount,
        onConfirm: (trackingNumber) {
          ref.read(cartProvider.notifier).setPosPayment(trackingNumber);
        },
      ),
    );
  }

  Color _methodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return AppColors.cashColor;
      case PaymentMethod.card:
        return AppColors.cardColor;
      case PaymentMethod.credit:
        return AppColors.creditColor;
      case PaymentMethod.pos:
        return AppColors.posColor;
    }
  }
}

class _PosPaymentDialog extends StatefulWidget {
  final double amount;
  final ValueChanged<String?> onConfirm;
  const _PosPaymentDialog({required this.amount, required this.onConfirm});

  @override
  State<_PosPaymentDialog> createState() => _PosPaymentDialogState();
}

class _PosPaymentDialogState extends State<_PosPaymentDialog> {
  bool _isManual = true;
  final _trackingCtrl = TextEditingController();
  bool _isConnecting = false;
  String? _autoStatus;

  @override
  void dispose() {
    _trackingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title:
            const Text('پرداخت پوز', style: TextStyle(fontFamily: 'Vazirmatn')),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // نمایش مبلغ
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.posColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.posColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('مبلغ قابل پرداخت',
                        style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(widget.amount),
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.posColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // انتخاب حالت
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isManual = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isManual
                              ? AppColors.posColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.posColor),
                        ),
                        child: Text(
                          'دستی',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                _isManual ? Colors.white : AppColors.posColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isManual = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isManual
                              ? AppColors.posColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.posColor),
                        ),
                        child: Text(
                          'اتوماتیک',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                !_isManual ? Colors.white : AppColors.posColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isManual) ...[
                const Text('شماره پیگیری تراکنش:',
                    style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 13,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _trackingCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'مثال: ۱۲۳۴۵۶۷۸۹',
                    hintStyle: const TextStyle(fontFamily: 'Vazirmatn'),
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 15),
                ),
              ] else ...[
                if (_autoStatus != null)
                  Text(_autoStatus!,
                      style: const TextStyle(
                          fontFamily: 'Vazirmatn', fontSize: 13)),
                if (_isConnecting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (!_isConnecting) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'دستگاه پوز باید از طریق USB یا سریال به سیستم متصل باشد.',
                    style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.credit_card),
                      label: const Text('شروع تراکنش روی پوز',
                          style: TextStyle(fontFamily: 'Vazirmatn')),
                      onPressed: _startAutoTransaction,
                    ),
                  ),
                  if (_trackingCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('شماره پیگیری: ${_trackingCtrl.text}',
                        style: const TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 13,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('انصراف', style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('تأیید پرداخت',
                style: TextStyle(fontFamily: 'Vazirmatn')),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.posColor),
            onPressed: () {
              final tracking = _trackingCtrl.text.trim();
              widget.onConfirm(tracking.isEmpty ? null : tracking);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startAutoTransaction() async {
    setState(() {
      _isConnecting = true;
      _autoStatus = 'در حال اتصال به دستگاه پوز...';
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isConnecting = false;
      _autoStatus = 'پوز متصل نشد. پورت COM را در تنظیمات پوز بررسی کنید.';
    });
  }
}

/// دیالوگ موفقیت ثبت فاکتور — نمایش شماره فاکتور + گزینه‌های بستن/چاپ
class _InvoiceSuccessDialog extends StatelessWidget {
  final String invoiceNumber;
  const _InvoiceSuccessDialog({required this.invoiceNumber});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 64),
            const SizedBox(height: 12),
            const Text(
              'فاکتور با موفقیت ثبت شد',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'شماره فاکتور',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    invoiceNumber,
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('بستن',
                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('چاپ فاکتور',
                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }
}

// جستجوی محصول — نمایش inline در ناحیه Expanded
class _ProductSearchInline extends ConsumerWidget {
  final String query;
  final ValueChanged<Product> onProductSelected;

  const _ProductSearchInline({
    required this.query,
    required this.onProductSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsStreamProvider).value ?? [];
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? products
        : products
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                (p.barcode?.contains(q) ?? false))
            .toList();

    if (products.isEmpty) {
      return const Center(
        child: Text('هنوز محصولی ثبت نشده',
            style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 14,
                color: AppColors.textHint)),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('"$query" یافت نشد',
                style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 14,
                    color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: filtered.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) {
        final p = filtered[i];
        return ListTile(
          dense: true,
          leading: ManagedProductImage(
            relativePath: p.imageUrl,
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(8),
          ),
          title: Text(p.name,
              style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          subtitle: Text(
            CurrencyFormatter.format(p.sellPrice),
            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:
                  p.isLowStock ? AppColors.errorLight : AppColors.successLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${p.stockQuantity} عدد',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: p.isLowStock ? AppColors.error : AppColors.success,
              ),
            ),
          ),
          onTap: () => onProductSelected(p),
        );
      },
    );
  }
}

// انتخاب مشتری
class _CustomerPickerSheet extends ConsumerStatefulWidget {
  final ValueChanged<Customer> onSelected;
  final VoidCallback onClear;

  const _CustomerPickerSheet({required this.onSelected, required this.onClear});

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase();
    // دریافت مشتریان از DB و فیلتر محلی
    final customersAsync = ref.watch(customersStreamProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // دسته کشیدن
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'انتخاب مشتری',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'جستجوی مشتری...',
                    hintStyle: const TextStyle(fontFamily: 'Vazirmatn'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              // گزینه بدون مشتری
              ListTile(
                leading: const Icon(Icons.person_off_outlined,
                    color: AppColors.textSecondary),
                title: const Text(AppStrings.noCustomer,
                    style: TextStyle(fontFamily: 'Vazirmatn')),
                onTap: widget.onClear,
              ),
              const Divider(height: 1, color: AppColors.divider),
              // لیست مشتریان از دیتابیس
              Expanded(
                child: customersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('خطا: $e',
                        style: const TextStyle(fontFamily: 'Vazirmatn')),
                  ),
                  data: (customers) {
                    final filtered = query.isEmpty
                        ? customers
                        : customers
                            .where((c) =>
                                c.name.toLowerCase().contains(query) ||
                                (c.phone ?? '').contains(query))
                            .toList();
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('مشتری یافت نشد',
                            style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                color: AppColors.textSecondary)),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.infoLight,
                            child: Text(
                              c.name.substring(0, 1),
                              style: const TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(c.name,
                              style: const TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontWeight: FontWeight.w600)),
                          subtitle: c.phone != null
                              ? Text(c.phone!,
                                  style: const TextStyle(
                                      fontFamily: 'Vazirmatn', fontSize: 12))
                              : null,
                          trailing: c.hasDebt
                              ? Text(
                                  CurrencyFormatter.format(c.totalDebt),
                                  style: const TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 11,
                                    color: AppColors.warning,
                                  ),
                                )
                              : null,
                          onTap: () => widget.onSelected(c),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// تخفیف
class _DiscountSheet extends StatefulWidget {
  final double currentDiscount;
  final bool isPercent;
  final void Function(double value, bool isPercent) onApply;

  const _DiscountSheet({
    required this.currentDiscount,
    required this.isPercent,
    required this.onApply,
  });

  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  late TextEditingController _ctrl;
  late bool _isPercent;

  @override
  void initState() {
    super.initState();
    _isPercent = widget.isPercent;
    _ctrl = TextEditingController(
      text: widget.currentDiscount > 0 ? widget.currentDiscount.toString() : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('تخفیف',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 16),
            // toggle درصد / مبلغ
            Row(
              children: [
                ChoiceChip(
                  label: const Text('مبلغ (تومان)',
                      style: TextStyle(fontFamily: 'Vazirmatn')),
                  selected: !_isPercent,
                  onSelected: (_) => setState(() => _isPercent = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('درصد',
                      style: TextStyle(fontFamily: 'Vazirmatn')),
                  selected: _isPercent,
                  onSelected: (_) => setState(() => _isPercent = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _isPercent ? 'درصد تخفیف' : 'مبلغ تخفیف',
                hintStyle: const TextStyle(fontFamily: 'Vazirmatn'),
                suffixText: _isPercent ? '٪' : 'تومان',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final v = double.tryParse(
                        CurrencyFormatter.toEnglishNumber(_ctrl.text)
                            .replaceAll(',', '')) ??
                    0;
                widget.onApply(v, _isPercent);
              },
              child: const Text('اعمال تخفیف',
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
          ],
        ),
      ),
    );
  }
}
