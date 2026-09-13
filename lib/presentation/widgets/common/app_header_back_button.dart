import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// دکمه بازگشت یکسان برای هدر همه صفحه‌ها.
///
/// اگر صفحه از پشته باز شده باشد به صفحه قبل برمی‌گردد؛ در تب‌های اصلی که
/// پشته‌ای وجود ندارد، کاربر را به داشبورد (یا مسیر والد تعیین‌شده) می‌برد.
class AppHeaderBackButton extends StatelessWidget {
  final String fallbackRoute;
  final VoidCallback? onPressed;

  const AppHeaderBackButton({
    super.key,
    this.fallbackRoute = '/dashboard',
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'بازگشت',
        icon: const BackButtonIcon(),
        onPressed: onPressed ?? () => _goBack(context),
      );

  void _goBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    final currentPath = GoRouterState.of(context).uri.path;
    if (currentPath != fallbackRoute) context.go(fallbackRoute);
  }
}
