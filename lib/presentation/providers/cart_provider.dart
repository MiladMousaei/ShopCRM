import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/invoice.dart';
import '../../domain/models/invoice_item.dart';
import '../../domain/models/product.dart';
import '../../domain/models/customer.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/customer_repository.dart';
import 'product_provider.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(databaseProvider));
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(databaseProvider));
});

/// وضعیت سبد خرید جاری (فاکتور در حال ثبت)
class CartState {
  final List<InvoiceItem> items; // آیتم‌های سبد
  final Customer? customer; // مشتری انتخاب‌شده (اختیاری)
  final double discount; // مقدار تخفیف
  final bool isDiscountPercent; // نوع تخفیف: ریال یا درصد
  final double tax; // درصد مالیات
  final PaymentMethod paymentMethod; // روش پرداخت
  final bool isSubmitting; // در حال ثبت فاکتور
  final String? error; // پیام خطا
  final int? lastInvoiceId; // شناسه فاکتور ثبت‌شده (برای پرینت)
  final String? posTrackingNumber; // شماره پیگیری پوز

  const CartState({
    this.items = const [],
    this.customer,
    this.discount = 0,
    this.isDiscountPercent = false,
    this.tax = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.isSubmitting = false,
    this.error,
    this.lastInvoiceId,
    this.posTrackingNumber,
  });

  /// جمع کل قبل از تخفیف
  double get totalAmount => items.fold(0, (sum, item) => sum + item.subtotal);

  /// مبلغ تخفیف به ریال
  double get discountAmount {
    if (isDiscountPercent) return totalAmount * discount / 100;
    return discount;
  }

  double get taxAmount => (totalAmount - discountAmount) * tax / 100;
  double get finalAmount => totalAmount - discountAmount + taxAmount;

  /// تعداد کل اقلام (مجموع quantity)
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<InvoiceItem>? items,
    Customer? customer,
    bool clearCustomer = false,
    double? discount,
    bool? isDiscountPercent,
    double? tax,
    PaymentMethod? paymentMethod,
    bool? isSubmitting,
    String? error,
    int? lastInvoiceId,
    String? posTrackingNumber,
    bool clearPosTracking = false,
  }) {
    return CartState(
      items: items ?? this.items,
      customer: clearCustomer ? null : (customer ?? this.customer),
      discount: discount ?? this.discount,
      isDiscountPercent: isDiscountPercent ?? this.isDiscountPercent,
      tax: tax ?? this.tax,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      lastInvoiceId: lastInvoiceId ?? this.lastInvoiceId,
      posTrackingNumber: clearPosTracking
          ? null
          : (posTrackingNumber ?? this.posTrackingNumber),
    );
  }
}

/// منطق مدیریت سبد خرید
class CartNotifier extends StateNotifier<CartState> {
  final InvoiceRepository _invoiceRepo;

  CartNotifier(this._invoiceRepo) : super(const CartState());

  /// افزودن محصول به سبد
  /// اگر محصول قبلاً در سبد است، فقط تعداد افزایش می‌یابد
  void addProduct(Product product, {int quantity = 1}) {
    if (!product.isActive) {
      state = state.copyWith(error: 'محصول حذف‌شده قابل فروش نیست');
      return;
    }
    if (quantity <= 0 || quantity > product.stockQuantity) {
      state = state.copyWith(error: 'موجودی «${product.name}» کافی نیست');
      return;
    }
    final existing = state.items.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      final nextQuantity = state.items[existing].quantity + quantity;
      if (nextQuantity > product.stockQuantity) {
        state = state.copyWith(error: 'موجودی «${product.name}» کافی نیست');
        return;
      }
      // محصول هست → تعداد را اضافه کن
      final updated = List<InvoiceItem>.from(state.items);
      updated[existing] = state.items[existing].copyWith(
        quantity: nextQuantity,
      );
      state = state.copyWith(items: updated);
    } else {
      // محصول جدید → به انتهای لیست اضافه کن
      state = state.copyWith(
        items: [
          ...state.items,
          InvoiceItem.fromProduct(product, quantity: quantity)
        ],
      );
    }
  }

  /// حذف یک ردیف از سبد
  void removeItem(int productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.productId != productId).toList(),
    );
  }

  /// تغییر تعداد یک محصول — اگر صفر شد حذف می‌شود
  void updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final updated = state.items
        .map(
          (i) => i.productId == productId ? i.copyWith(quantity: quantity) : i,
        )
        .toList();
    state = state.copyWith(items: updated);
  }

  void incrementQuantity(int productId) {
    final item = state.items.firstWhere((i) => i.productId == productId);
    updateQuantity(productId, item.quantity + 1);
  }

  void decrementQuantity(int productId) {
    final item = state.items.firstWhere((i) => i.productId == productId);
    updateQuantity(productId, item.quantity - 1);
  }

  /// تنظیم مشتری (null = بدون مشتری)
  void setCustomer(Customer? customer) {
    if (customer == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(customer: customer);
    }
  }

  /// تنظیم تخفیف
  void setDiscount(double value, {bool isPercent = false}) {
    state = state.copyWith(discount: value, isDiscountPercent: isPercent);
  }

  void setPaymentMethod(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method, clearPosTracking: true);

  void setPosPayment(String? trackingNumber) {
    state = state.copyWith(
      paymentMethod: PaymentMethod.pos,
      posTrackingNumber: trackingNumber,
    );
  }

  void setTax(double tax) => state = state.copyWith(tax: tax);

  /// ثبت نهایی فاکتور
  /// ترتیب: ۱) ذخیره فاکتور  ۲) کاهش موجودی  ۳) ثبت بدهی نسیه
  Future<int?> submitInvoice() async {
    if (state.isSubmitting) return null;
    if (state.items.isEmpty) {
      state = state.copyWith(error: 'فاکتور بدون کالا قابل ثبت نیست');
      return null;
    }
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final posNote = state.posTrackingNumber != null
          ? 'پوز - شماره پیگیری: ${state.posTrackingNumber}'
          : null;

      final invoice = Invoice(
        id: 0,
        invoiceNumber: '',
        customerId: state.customer?.id,
        customerName: state.customer?.name,
        items: state.items,
        discount: state.discount,
        isDiscountPercent: state.isDiscountPercent,
        tax: state.tax,
        paymentMethod: state.paymentMethod,
        status: InvoiceStatus.completed,
        notes: posNote,
        createdAt: DateTime.now(),
      );

      final id = await _invoiceRepo.createSale(invoice);

      state = state.copyWith(isSubmitting: false, lastInvoiceId: id);
      return id;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'خطا در ثبت فاکتور: $e',
      );
      return null;
    }
  }

  /// پاک کردن کامل سبد برای فاکتور جدید
  void clearCart() => state = const CartState();

}

/// Provider سبد خرید — یک instance در کل اپ
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(
    ref.watch(invoiceRepositoryProvider),
  );
});
