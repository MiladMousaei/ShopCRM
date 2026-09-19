/// تست‌های پایه برای اطمینان از اجرا شدن برنامه
/// تست‌های جامع‌تر در test/utils/ و test/models/ قرار دارند
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';
import 'package:shop_crm/core/utils/currency_formatter.dart';
import 'package:shop_crm/core/utils/date_converter.dart';
import 'package:shop_crm/core/constants/app_colors.dart';
import 'package:shop_crm/data/repositories/report_repository.dart';
import 'package:shop_crm/data/local/database.dart';
import 'package:shop_crm/domain/models/ledger_entry.dart';
import 'package:shop_crm/presentation/providers/ledger_provider.dart';
import 'package:shop_crm/presentation/providers/auth_provider.dart';
import 'package:shop_crm/presentation/providers/product_provider.dart';
import 'package:shop_crm/presentation/screens/accounting/accounting_screen.dart';
import 'package:shop_crm/presentation/screens/auth/login_screen.dart';
import 'package:shop_crm/presentation/screens/invoice/new_invoice_screen.dart';
import 'package:shop_crm/presentation/screens/reports/reports_screen.dart';
import 'package:shop_crm/presentation/providers/report_provider.dart';
import 'package:shop_crm/presentation/widgets/common/app_header_back_button.dart';
import 'package:shop_crm/presentation/widgets/common/confirm_dialog.dart';
import 'package:shop_crm/app.dart';

void main() {
  test('CurrencyFormatter: فرمت پایه کار می‌کند', () {
    expect(CurrencyFormatter.format(0), '۰ تومان');
    expect(CurrencyFormatter.format(1000), '۱,۰۰۰ تومان');
  });

  test('DateConverter: تبدیل اعداد انگلیسی به فارسی', () {
    final result = DateConverter.toEnglish('۱۴۰۳');
    expect(result, '1403');
  });

  test('DateConverter: تبدیل تاریخ میلادی به شمسی', () {
    final date = DateTime(2024, 3, 20);
    final shamsi = DateConverter.toShamsi(date);
    expect(shamsi, isNotEmpty);
    expect(shamsi.contains('/'), isTrue);
  });

  testWidgets('ConfirmDialog موجود در عرض دسکتاپ و موبایل بدون overflow است',
      (tester) async {
    for (final size in [const Size(375, 700), const Size(1100, 700)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ConfirmDialog(
            title: 'تأیید حذف',
            message: 'آیا از حذف این مورد مطمئن هستید؟',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('تأیید حذف'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('بستن پنجره قبل از خروج تأیید می‌گیرد', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showExitConfirmation(context),
          child: const Text('خروج'),
        ),
      ),
    ));
    await tester.tap(find.text('خروج'));
    await tester.pumpAndSettle();
    expect(find.text('آیا می‌خواهید از برنامه خارج شوید؟'), findsOneWidget);
    await tester.tap(find.text('بازگشت'));
    await tester.pumpAndSettle();
    expect(find.text('آیا می‌خواهید از برنامه خارج شوید؟'), findsNothing);
  });

  testWidgets('فلش هدر در تب اصلی به داشبورد برمی‌گردد', (tester) async {
    final router = GoRouter(
      initialLocation: '/reports',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const Scaffold(body: Text('داشبورد')),
        ),
        GoRoute(
          path: '/reports',
          builder: (_, __) => Scaffold(
            appBar: AppBar(leading: const AppHeaderBackButton()),
            body: const Text('گزارش‌ها'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pumpAndSettle();

    expect(find.text('داشبورد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('فیلترهای حسابداری در عرض محدود بدون overflow مرتب می‌شوند',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.binding.setSurfaceSize(const Size(620, 760));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ledgerEntriesProvider.overrideWith(
          (_) => Stream.value(const <LedgerEntry>[]),
        ),
      ],
      child: const MaterialApp(home: AccountingScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('همه'), findsOneWidget);
    expect(find.text('بستانکار'), findsOneWidget);
    expect(find.text('بازه تاریخ'), findsOneWidget);
    expect(find.byType(Wrap), findsWidgets);
    expect(find.byKey(const ValueKey('accounting-primary-filters')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('accounting-export-actions')),
        findsOneWidget);
    final excelText = tester.widget<Text>(find.descendant(
      of: find.byKey(const ValueKey('accounting-export-actions')),
      matching: find.text('Excel'),
    ));
    expect(excelText.style?.fontSize, 12);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await db.close();
    await tester.binding.setSurfaceSize(null);
    await tester.pump();
  });

  testWidgets('جدول حسابداری در عرض ویندوز کامل داخل صفحه می‌ماند',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime(2026, 9, 13);
    final entry = LedgerEntry(
      id: 'entry-1',
      customerId: 1,
      customerName: 'مشتری نمونه',
      type: LedgerEntryType.creditPurchase,
      amount: 5000000,
      direction: LedgerDirection.debit,
      operationDate: now,
      invoiceId: 1,
      invoiceNumber: 'INV-1001',
      createdAt: now,
      updatedAt: now,
      balanceAfter: 5000000,
    );
    await tester.binding.setSurfaceSize(const Size(895, 760));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ledgerEntriesProvider.overrideWith((_) => Stream.value([entry])),
      ],
      child: const MaterialApp(home: AccountingScreen()),
    ));
    await tester.pumpAndSettle();

    final tableRect = tester.getRect(find.byType(DataTable));
    expect(tableRect.left, greaterThanOrEqualTo(0));
    expect(tableRect.right, lessThanOrEqualTo(895));
    expect(
        find.byKey(const ValueKey('accounting-fitted-table')), findsOneWidget);
    final editCenter = tester.getCenter(find.byIcon(Icons.edit_outlined));
    final deleteCenter = tester.getCenter(find.byIcon(Icons.cancel_outlined));
    expect((editCenter.dy - deleteCenter.dy).abs(), lessThan(1));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await db.close();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('رنگ دکمه‌های خروجی حسابداری سبز و قرمز است', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.binding.setSurfaceSize(const Size(895, 760));
    final entry = LedgerEntry(
      id: 'entry-colors',
      customerId: 1,
      customerName: 'مشتری نمونه',
      type: LedgerEntryType.debt,
      amount: 1000,
      direction: LedgerDirection.debit,
      operationDate: DateTime(2026, 9, 16),
      createdAt: DateTime(2026, 9, 16),
      updatedAt: DateTime(2026, 9, 16),
      balanceAfter: 1000,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ledgerEntriesProvider.overrideWith((_) => Stream.value([entry])),
      ],
      child: const MaterialApp(home: AccountingScreen()),
    ));
    await tester.pumpAndSettle();

    final excelButton = tester.widget<OutlinedButton>(find.ancestor(
      of: find.text('Excel'),
      matching: find.byType(OutlinedButton),
    ));
    final pdfButton = tester.widget<OutlinedButton>(find.ancestor(
      of: find.text('PDF'),
      matching: find.byType(OutlinedButton),
    ));
    expect(excelButton.style?.foregroundColor?.resolve({}), AppColors.success);
    expect(pdfButton.style?.foregroundColor?.resolve({}), AppColors.error);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await db.close();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('رنگ خروجی‌های گزارش سبز و قرمز است و صفحه اسکرول دارد',
      (tester) async {
    const report = SalesReport(
      totalSales: 0,
      totalProfit: 0,
      totalInvoices: 0,
      dailySales: {},
      topProducts: [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reportDataProvider.overrideWith((_) async => report),
      ],
      child: const MaterialApp(home: ReportsScreen()),
    ));
    await tester.pumpAndSettle();

    final excelButton = tester.widget<IconButton>(find.ancestor(
      of: find.byTooltip('خروجی Excel'),
      matching: find.byType(IconButton),
    ));
    final pdfButton = tester.widget<IconButton>(find.ancestor(
      of: find.byTooltip('خروجی PDF'),
      matching: find.byType(IconButton),
    ));
    expect(excelButton.color, AppColors.success);
    expect(pdfButton.color, AppColors.error);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('اطلاعات ورود ذخیره‌شده در فرم ورود تکمیل می‌شود',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
      'remembered_username': 'admin',
      'remembered_password': '1234',
    });
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ));
    await tester.pumpAndSettle();

    final username = tester.widget<TextFormField>(
      find.byType(TextFormField).at(0),
    );
    final password = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(username.controller?.text, 'admin');
    expect(password.controller?.text, '1234');
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await db.close();
  });

  testWidgets('دکمه بازگشت فاکتور جدید بدون history به داشبورد می‌رود',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final router = GoRouter(
      initialLocation: '/invoice/new',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const Scaffold(body: Text('داشبورد')),
        ),
        GoRoute(
          path: '/invoice/new',
          builder: (_, __) => const NewInvoiceScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pumpAndSettle();

    expect(find.text('داشبورد'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await db.close();
    await tester.binding.setSurfaceSize(null);
  });
}
