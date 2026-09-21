import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../presentation/providers/cart_provider.dart';

class InvoiceSummaryCard extends StatelessWidget {
  final CartState cart;

  const InvoiceSummaryCard({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _badge('${cart.itemCount} قلم'),
              const Text(
                'جمع کل',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.format(cart.finalAmount),
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          if (cart.discountAmount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'تخفیف: ${CurrencyFormatter.format(cart.discountAmount)}',
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12,
                    color: Colors.white70,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}
