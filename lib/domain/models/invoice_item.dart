import 'package:equatable/equatable.dart';
import 'product.dart';

/// یک ردیف در سبد خرید / فاکتور
class InvoiceItem extends Equatable {
  final int? id;
  final int? invoiceId;
  final int productId;
  final String productName;    // ذخیره نام در زمان فروش (مستقل از تغییرات بعدی محصول)
  final String? productBarcode;
  final int quantity;          // تعداد
  final double unitPrice;      // قیمت واحد در زمان فروش
  final double purchasePrice;  // قیمت خرید در زمان فروش (برای سود تاریخی)
  final double discountPercent; // درصد تخفیف روی این ردیف (جدا از تخفیف کل)

  const InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productId,
    required this.productName,
    this.productBarcode,
    required this.quantity,
    required this.unitPrice,
    this.purchasePrice = 0,
    this.discountPercent = 0,
  });

  /// جمع این ردیف پس از تخفیف
  double get subtotal {
    final gross = unitPrice * quantity;
    return gross - (gross * discountPercent / 100);
  }

  /// مبلغ تخفیف این ردیف
  double get discountAmount => unitPrice * quantity * discountPercent / 100;

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    int? productId,
    String? productName,
    String? productBarcode,
    int? quantity,
    double? unitPrice,
    double? purchasePrice,
    double? discountPercent,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  /// ساخت آیتم از روی یک محصول (برای افزودن به سبد)
  factory InvoiceItem.fromProduct(Product product, {int quantity = 1}) {
    return InvoiceItem(
      productId: product.id,
      productName: product.name,
      productBarcode: product.barcode,
      quantity: quantity,
      unitPrice: product.sellPrice, // قیمت فروش فعلی
      purchasePrice: product.purchasePrice,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoice_id': invoiceId,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'unit_price': unitPrice,
    'purchase_price': purchasePrice,
    'discount_percent': discountPercent,
    'subtotal': subtotal,
  };

  @override
  List<Object?> get props =>
      [productId, quantity, unitPrice, purchasePrice, discountPercent];
}
