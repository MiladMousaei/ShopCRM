/// تست‌های پایه برای اطمینان از اجرا شدن برنامه
/// تست‌های جامع‌تر در test/utils/ و test/models/ قرار دارند
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';
import 'package:shop_crm/core/utils/currency_formatter.dart';
import 'package:shop_crm/core/utils/date_converter.dart';
import 'package:shop_crm/data/local/database.dart';
import 'package:shop_crm/domain/models/ledger_entry.dart';
import 'package:shop_crm/presentation/providers/ledger_provider.dart';
import 'package:shop_crm/presentation/providers/product_provider.dart';
import 'package:shop_crm/presentation/screens/accounting/accounting_screen.dart';
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
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await db.close();
    await tester.binding.setSurfaceSize(null);
    await tester.pump();
  });
}
