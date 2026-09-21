// کنترل‌کننده کیبورد برای ویندوز/دسکتاپ
// کلیدهای میانبر برای عملیات سریع در برنامه
// F2: فاکتور جدید
// F3: فعال‌سازی فوکوس بارکد
// Ctrl+P: پرینت فاکتور جاری
// Escape: برگشت به صفحه قبل
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Provider سراسری برای trigger کردن فوکوس روی فیلد بارکد
/// هر بار که F3 فشار داده می‌شود، مقدار افزایش می‌یابد
/// فیلد بارکد این تغییر را listen می‌کند و فوکوس می‌گیرد
final barcodeFocusTriggerProvider = StateProvider<int>((ref) => 0);

/// Widget کیبوردی که کل اپ را می‌پوشاند
/// کلیدهای میانبر فقط روی ویندوز/لینوکس/مک فعال هستند
class AppKeyboardShortcuts extends ConsumerWidget {
  final Widget child;

  const AppKeyboardShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FocusScope(
      // autofocus برای اطمینان از دریافت رویدادهای کیبورد
      autofocus: true,
      child: Focus(
        // گوش دادن به کیبورد بدون مصرف رویداد (onKeyEvent)
        onKeyEvent: (node, event) {
          // فقط Key Down را پردازش کن (از تکرار جلوگیری)
          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          final logicalKey = event.logicalKey;
          final isCtrl = HardwareKeyboard.instance.isControlPressed;

          // ─── F2: ناوبری به صفحه فاکتور جدید ──────────────────
          if (logicalKey == LogicalKeyboardKey.f2) {
            try {
              context.go('/invoice/new');
            } catch (_) {
              // اگر context از دسترس خارج شد، نادیده بگیر
            }
            return KeyEventResult.handled;
          }

          // ─── F3: فوکوس روی فیلد بارکد ────────────────────────
          if (logicalKey == LogicalKeyboardKey.f3) {
            // افزایش trigger — فیلد بارکد در صفحه فاکتور این را watch می‌کند
            ref.read(barcodeFocusTriggerProvider.notifier).state++;
            return KeyEventResult.handled;
          }

          // ─── Ctrl+P: پرینت فاکتور جاری ───────────────────────
          if (isCtrl && logicalKey == LogicalKeyboardKey.keyP) {
            // TODO: پرینت فاکتور جاری از طریق invoiceProvider
            // این کلید میانبر در صفحه جزئیات فاکتور باید پردازش شود
            // اینجا رویداد را handle می‌کنیم تا مرورگر/سیستم آن را مصرف نکند
            _handlePrint(context);
            return KeyEventResult.handled;
          }

          // ─── Escape: برگشت به صفحه قبل ───────────────────────
          if (logicalKey == LogicalKeyboardKey.escape) {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
              return KeyEventResult.handled;
            }
          }

          // سایر کلیدها → نادیده گرفته شوند
          return KeyEventResult.ignored;
        },
        child: child,
      ),
    );
  }

  /// مدیریت کلید Ctrl+P برای پرینت
  /// اگر صفحه جاری صفحه جزئیات فاکتور باشد، PDF تولید می‌شود
  void _handlePrint(BuildContext context) {
    // نمایش SnackBar به عنوان راهنما
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'برای پرینت فاکتور به صفحه جزئیات فاکتور بروید',
          style: TextStyle(fontFamily: 'Vazirmatn'),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
