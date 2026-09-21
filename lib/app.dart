import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/keyboard_shortcuts.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/invoice/new_invoice_screen.dart';
import 'presentation/screens/invoice/invoice_list_screen.dart';
import 'presentation/screens/invoice/invoice_detail_screen.dart';
import 'presentation/screens/inventory/inventory_screen.dart';
import 'presentation/screens/inventory/adjust_stock_screen.dart';
import 'presentation/screens/customers/customers_screen.dart';
import 'presentation/screens/customers/customer_detail_screen.dart';
import 'presentation/screens/customers/customer_form_screen.dart';
import 'presentation/screens/products/products_screen.dart';
import 'presentation/screens/products/product_form_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/settings/printer_settings_screen.dart';
import 'presentation/screens/reports/reports_screen.dart';
import 'presentation/screens/accounting/accounting_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: authState.isLoggedIn ? '/dashboard' : '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
      final isLoginRoute = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
              path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(
              path: '/invoice/new',
              builder: (_, __) => const NewInvoiceScreen()),
          GoRoute(
              path: '/invoices', builder: (_, __) => const InvoiceListScreen()),
          GoRoute(
            path: '/invoices/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return InvoiceDetailScreen(invoiceId: id);
            },
          ),
          GoRoute(
              path: '/products', builder: (_, __) => const ProductsScreen()),
          GoRoute(
            path: '/products/new',
            builder: (context, state) {
              final barcode = state.uri.queryParameters['barcode'];
              return ProductFormScreen(initialBarcode: barcode);
            },
          ),
          GoRoute(
            path: '/products/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return ProductFormScreen(productId: id);
            },
          ),
          GoRoute(
              path: '/inventory', builder: (_, __) => const InventoryScreen()),
          GoRoute(
            path: '/inventory/adjust',
            builder: (context, state) {
              final productIdStr = state.uri.queryParameters['productId'];
              final productId =
                  productIdStr != null ? int.tryParse(productIdStr) : null;
              return AdjustStockScreen(productId: productId);
            },
          ),
          GoRoute(
              path: '/customers', builder: (_, __) => const CustomersScreen()),
          GoRoute(
              path: '/customers/new',
              builder: (_, __) => const CustomerFormScreen()),
          GoRoute(
            path: '/customers/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return CustomerDetailScreen(customerId: id);
            },
          ),
          GoRoute(
            path: '/customers/:id/edit',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return CustomerFormScreen(customerId: id);
            },
          ),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(
              path: '/accounting',
              builder: (_, state) => AccountingScreen(
                    customerId: int.tryParse(
                        state.uri.queryParameters['customerId'] ?? ''),
                  )),
          GoRoute(
              path: '/settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(
              path: '/settings/printer',
              builder: (_, __) => const PrinterSettingsScreen()),
        ],
      ),
    ],
  );
});

class ShopCrmApp extends ConsumerStatefulWidget {
  const ShopCrmApp({super.key});

  @override
  ConsumerState<ShopCrmApp> createState() => _ShopCrmAppState();
}

class _ShopCrmAppState extends ConsumerState<ShopCrmApp> with WindowListener {
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (Platform.isWindows) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (_isClosing) return;
    final context = _rootNavigatorKey.currentContext;
    if (context == null) return;
    final confirmed = await showExitConfirmation(context);
    if (!confirmed) return;
    _isClosing = true;
    await windowManager.hide();
    try {
      await ref.read(authProvider.notifier).logout();
    } finally {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        Widget content = Directionality(
          textDirection: TextDirection.rtl,
          child: AppKeyboardShortcuts(child: child ?? const SizedBox()),
        );
        if (Platform.isWindows) {
          final media = MediaQuery.of(context);
          final currentScale = media.textScaler.scale(14) / 14;
          if (currentScale < 1.12) {
            content = MediaQuery(
              data: media.copyWith(textScaler: const TextScaler.linear(1.12)),
              child: content,
            );
          }
        }
        return content;
      },
    );
  }
}

Future<bool> showExitConfirmation(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(children: [
            Icon(Icons.exit_to_app, color: Colors.red),
            SizedBox(width: 8),
            Text('خروج از برنامه'),
          ]),
          content: const Text('آیا می‌خواهید از برنامه خارج شوید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('بازگشت'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('خروج', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ) ??
    false;

void showApplicationAboutDialog(BuildContext context) => showAboutDialog(
      context: context,
      applicationName: AppStrings.appName,
      applicationVersion: AppStrings.appVersion,
      applicationIcon: const Icon(Icons.storefront, size: 40),
      children: const [Text('سامانه محلی مدیریت فروشگاه و مشتریان')],
    );

// ─── Shell ریسپانسیو ──────────────────────────────────────────────────────────

class _AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell>
    with WidgetsBindingObserver {
  // ─── آیتم‌های دسکتاپ (همه ۹ مسیر) ──────────────────────────────────────
  static const _routes = [
    '/dashboard',
    '/invoice/new',
    '/invoices',
    '/products',
    '/inventory',
    '/customers',
    '/accounting',
    '/reports',
    '/settings',
  ];
  static const _labels = [
    AppStrings.dashboard,
    AppStrings.newInvoice,
    AppStrings.invoices,
    AppStrings.products,
    AppStrings.inventory,
    AppStrings.customers,
    'حسابداری',
    AppStrings.reports,
    AppStrings.settings,
  ];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.add_circle_outline,
    Icons.receipt_long_outlined,
    Icons.inventory_2_outlined,
    Icons.warehouse_outlined,
    Icons.people_outline,
    Icons.account_balance_outlined,
    Icons.bar_chart_outlined,
    Icons.settings_outlined,
  ];
  static const _selectedIcons = [
    Icons.dashboard,
    Icons.add_circle,
    Icons.receipt_long,
    Icons.inventory_2,
    Icons.warehouse,
    Icons.people,
    Icons.account_balance,
    Icons.bar_chart,
    Icons.settings,
  ];

  // ─── آیتم‌های موبایل (۴ مسیر اصلی + «بیشتر») ────────────────────────────
  static const _mobileRoutes = [
    '/dashboard',
    '/invoice/new',
    '/invoices',
    '/products'
  ];
  static const _mobileLabels = [
    AppStrings.dashboard,
    AppStrings.newInvoice,
    AppStrings.invoices,
    AppStrings.products,
  ];
  static const _mobileIcons = [
    Icons.dashboard_outlined,
    Icons.add_circle_outline,
    Icons.receipt_long_outlined,
    Icons.inventory_2_outlined,
  ];
  static const _mobileSelectedIcons = [
    Icons.dashboard,
    Icons.add_circle,
    Icons.receipt_long,
    Icons.inventory_2,
  ];

  // ─── آیتم‌های «بیشتر» ────────────────────────────────────────────────────
  static const _moreItems = <({String route, String label, IconData icon})>[
    (
      route: '/inventory',
      label: AppStrings.inventory,
      icon: Icons.warehouse_outlined
    ),
    (
      route: '/customers',
      label: AppStrings.customers,
      icon: Icons.people_outline
    ),
    (
      route: '/accounting',
      label: 'حسابداری',
      icon: Icons.account_balance_outlined
    ),
    (
      route: '/reports',
      label: AppStrings.reports,
      icon: Icons.bar_chart_outlined
    ),
    (
      route: '/settings',
      label: AppStrings.settings,
      icon: Icons.settings_outlined
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;
    try {
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
        return true;
      }
    } catch (_) {}
    if (!mounted) return false;
    await _requestExit();
    return true;
  }

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  int _mobileIndexFromLocation(String loc) {
    for (int i = 0; i < _mobileRoutes.length; i++) {
      if (loc == _mobileRoutes[i] ||
          loc.startsWith('${_mobileRoutes[i]}/')) {
        return i;
      }
    }
    return 4; // «بیشتر»
  }

  int _desktopIndexFromLocation(String loc) {
    for (int i = 0; i < _routes.length; i++) {
      if (loc == _routes[i] || loc.startsWith('${_routes[i]}/')) {
        return i;
      }
    }
    return 0;
  }

  void _navigate(String route) => context.go(route);

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ..._moreItems.map((item) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22),
                    ),
                    title: Text(item.label,
                        style: const TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(context);
                      _navigate(item.route);
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestExit() async {
    if (!await showExitConfirmation(context) || !mounted) return;
    if (Platform.isWindows) {
      await windowManager.hide();
      try {
        await ref.read(authProvider.notifier).logout();
      } finally {
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
      }
    } else {
      await ref.read(authProvider.notifier).logout();
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    String location = '/dashboard';
    try {
      location = GoRouterState.of(context).matchedLocation;
    } catch (_) {}

    // ─── دسکتاپ: فقط روی ویندوز/لینوکس/مک یا نمایشگر عریض غیراندروید ────────
    final isMobileOS = Platform.isAndroid || Platform.isIOS;
    if (!isMobileOS && (_isDesktop || isWide)) {
      final idx = _desktopIndexFromLocation(location);
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: isWide,
              destinations: List.generate(
                _routes.length,
                (i) => NavigationRailDestination(
                  icon: Icon(_icons[i]),
                  selectedIcon: Icon(_selectedIcons[i]),
                  label: Text(_labels[i],
                      style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: Platform.isWindows ? 14 : 12)),
                ),
              ),
              selectedIndex: idx,
              onDestinationSelected: (i) => _navigate(_routes[i]),
              leading: const SizedBox(height: 16),
              trailing: Platform.isWindows
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (isWide)
                          TextButton.icon(
                            onPressed: () =>
                                showApplicationAboutDialog(context),
                            icon: const Icon(Icons.info_outline),
                            label: const Text('درباره ما'),
                          )
                        else
                          IconButton(
                            tooltip: 'درباره ما',
                            onPressed: () =>
                                showApplicationAboutDialog(context),
                            icon: const Icon(Icons.info_outline),
                          ),
                        if (isWide)
                          TextButton.icon(
                            onPressed: _requestExit,
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: const Text('خروج',
                                style: TextStyle(color: Colors.red)),
                          )
                        else
                          IconButton(
                            tooltip: 'خروج',
                            onPressed: _requestExit,
                            icon: const Icon(Icons.logout, color: Colors.red),
                          ),
                      ]),
                    )
                  : null,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // ─── موبایل: NavigationBar ۵ آیتمه + دیالوگ خروج ────────────────────────
    final mobileIdx = _mobileIndexFromLocation(location);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIdx,
        onDestinationSelected: (i) {
          if (i < _mobileRoutes.length) {
            _navigate(_mobileRoutes[i]);
          } else {
            _showMoreSheet(context);
          }
        },
        destinations: [
          ...List.generate(
            _mobileRoutes.length,
            (i) => NavigationDestination(
              icon: Icon(_mobileIcons[i]),
              selectedIcon: Icon(_mobileSelectedIcons[i]),
              label: _mobileLabels[i],
            ),
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'بیشتر',
          ),
        ],
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 65,
      ),
    );
  }
}
