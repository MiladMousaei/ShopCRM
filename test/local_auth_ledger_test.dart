import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shop_crm/data/local/database.dart';
import 'package:shop_crm/data/repositories/ledger_repository.dart';
import 'package:shop_crm/data/repositories/local_auth_repository.dart';
import 'package:shop_crm/presentation/providers/auth_provider.dart';
import 'package:shop_crm/domain/models/ledger_entry.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('اولین اجرا admin را با رمز hash شده می‌سازد و رمز اشتباه رد می‌شود',
      () async {
    final auth = LocalAuthRepository(db);
    await auth.ensureDefaultUser();
    final users = await db.select(db.usersTable).get();
    expect(users, hasLength(1));
    expect(users.single.username, 'admin');
    expect(users.single.passwordHash, isNot('1234'));
    expect(await auth.authenticate('admin', '1234'), isNotNull);
    expect(await auth.authenticate('admin', 'wrong'), isNull);
  });

  test('تغییر نام و رمز ماندگار است و admin دوباره ساخته نمی‌شود', () async {
    final auth = LocalAuthRepository(db);
    await auth.ensureDefaultUser();
    final session = await auth.authenticate('admin', '1234');
    await auth.changeCredentials(
      userId: session!.userId,
      username: 'owner',
      currentPassword: '1234',
      newPassword: 'secure-pass',
    );
    await auth.ensureDefaultUser();
    expect(await auth.authenticate('admin', '1234'), isNull);
    expect(await auth.authenticate('owner', 'secure-pass'), isNotNull);
    expect(await db.select(db.usersTable).get(), hasLength(1));
  });

  test('session قابل اعتبارسنجی و پس از خروج باطل است', () async {
    final auth = LocalAuthRepository(db);
    await auth.ensureDefaultUser();
    final session = await auth.authenticate('admin', '1234');
    expect(await auth.resumeSession(session!.token), isNotNull);
    await auth.revokeSession(session.token);
    expect(await auth.resumeSession(session.token), isNull);
  });

  test('گزینه مرا به خاطر بسپار نام کاربری و رمز را امن ذخیره می‌کند',
      () async {
    final secureValues = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(secureValues);
    final repository = LocalAuthRepository(db);
    await repository.ensureDefaultUser();
    final notifier = AuthNotifier(const FlutterSecureStorage(), repository);
    await Future<void>.delayed(Duration.zero);

    expect(
      await notifier.login('admin', '1234', remember: true),
      isTrue,
    );
    expect(secureValues['remembered_username'], 'admin');
    expect(secureValues['remembered_password'], '1234');

    expect(
      await notifier.login('admin', '1234', remember: false),
      isTrue,
    );
    expect(secureValues['remembered_username'], isNull);
    expect(secureValues['remembered_password'], isNull);
  });

  test('فاکتورهای آخر داشبورد پس از ثبت به‌صورت زنده به‌روز می‌شوند', () async {
    final updates = StreamIterator(db.invoicesDao.watchRecentInvoices());
    expect(await updates.moveNext(), isTrue);
    expect(updates.current, isEmpty);
    await db.into(db.invoicesTable).insert(InvoicesTableCompanion.insert(
          invoiceNumber: 'INV-100',
          status: const Value('completed'),
          createdAt: DateTime(2026, 1, 1),
        ));
    expect(await updates.moveNext(), isTrue);
    final invoices = updates.current;
    expect(invoices, hasLength(1));
    expect(invoices.single.invoiceNumber, 'INV-100');
    await updates.cancel();
  });

  test('دفتر حساب بدون فاکتور، بدهی و پرداخت و مانده دقیق را نگه می‌دارد',
      () async {
    final customerId =
        await _insertCustomer(db, 'مشتری آزمایشی', '09120000000');
    final ledger = LedgerRepository(db);
    await ledger.create(
      customerId: customerId,
      type: LedgerEntryType.debt,
      amount: 100000,
      direction: LedgerDirection.debit,
      operationDate: DateTime(2026, 1, 1),
      description: 'بدهی اولیه',
    );
    await ledger.create(
      customerId: customerId,
      type: LedgerEntryType.payment,
      amount: 40000,
      direction: LedgerDirection.credit,
      operationDate: DateTime(2026, 1, 2),
    );
    expect(await ledger.balanceForCustomer(customerId), 60000);
    final customer = await (db.select(db.customersTable)
          ..where((t) => t.id.equals(customerId)))
        .getSingle();
    expect(customer.totalDebt, 60000);
  });

  test('جست‌وجو، فیلتر، ویرایش و حذف سند دستی درست عمل می‌کند', () async {
    final customerId = await _insertCustomer(db, 'علی رضایی', '09121111111');
    final ledger = LedgerRepository(db);
    await ledger.create(
      customerId: customerId,
      type: LedgerEntryType.debt,
      amount: 50000,
      direction: LedgerDirection.debit,
      operationDate: DateTime(2026, 2, 1),
    );
    var rows =
        await ledger.watchEntries(const LedgerFilter(query: '0912')).first;
    expect(rows, hasLength(1));
    await ledger.updateManual(
      rows.single,
      type: LedgerEntryType.adjustment,
      amount: 70000,
      direction: LedgerDirection.debit,
      operationDate: DateTime(2026, 2, 2),
      description: 'اصلاح',
    );
    expect(await ledger.balanceForCustomer(customerId), 70000);
    rows = await ledger
        .watchEntries(const LedgerFilter(
          direction: LedgerDirection.debit,
          hasInvoice: false,
        ))
        .first;
    expect(rows.single.amount, 70000);
    await ledger.deleteManual(rows.single.id);
    expect(await ledger.balanceForCustomer(customerId), 0);
    expect(await db.select(db.ledgerEntryAuditsTable).get(), isNotEmpty);
  });

  test('سند فاکتور مستقیم حذف نمی‌شود و با سند اصلاحی ابطال می‌شود', () async {
    final customerId = await _insertCustomer(db, 'مشتری اعتباری', null);
    final invoiceId = await db.into(db.invoicesTable).insert(
          InvoicesTableCompanion.insert(
            invoiceNumber: '1001',
            customerId: Value(customerId),
            customerName: const Value('مشتری اعتباری'),
            createdAt: DateTime(2026, 3, 1),
          ),
        );
    final ledger = LedgerRepository(db);
    await ledger.createCreditPurchase(
      customerId: customerId,
      amount: 250000,
      invoiceId: invoiceId,
    );
    final linked =
        (await ledger.watchEntries(const LedgerFilter(hasInvoice: true)).first)
            .single;
    await expectLater(ledger.deleteManual(linked.id), throwsStateError);
    await ledger.voidEntry(linked.id);
    expect(await ledger.balanceForCustomer(customerId), 0);
    final rows = await db.ledgerDao.entriesForCustomer(customerId);
    expect(rows, hasLength(2));
    expect(rows.where((e) => e.reversesEntryId == linked.id), hasLength(1));
  });

  test('داده پس از بستن و بازکردن دوباره فایل دیتابیس باقی می‌ماند', () async {
    final directory = await Directory.systemTemp.createTemp('shopcrm_db_test_');
    final file = File('${directory.path}/persistence.sqlite');
    final first = AppDatabase.forTesting(NativeDatabase(file));
    await _insertCustomer(first, 'ماندگار', null);
    await first.close();
    final second = AppDatabase.forTesting(NativeDatabase(file));
    expect(await second.select(second.customersTable).get(), hasLength(1));
    await second.close();
    await directory.delete(recursive: true);
  });

  test('migration نسخه ۳ داده‌های محصول، مشتری و فاکتور را حفظ می‌کند',
      () async {
    final directory = await Directory.systemTemp.createTemp('shopcrm_v3_test_');
    final file = File('${directory.path}/migration.sqlite');
    final seed = AppDatabase.forTesting(NativeDatabase(file));
    final customerId =
        await _insertCustomer(seed, 'مشتری قدیمی', '09123334444');
    await (seed.update(seed.customersTable)
          ..where((t) => t.id.equals(customerId)))
        .write(const CustomersTableCompanion(totalDebt: Value(85000.0)));
    await seed.into(seed.productsTable).insert(ProductsTableCompanion.insert(
          name: 'محصول قدیمی',
          updatedAt: DateTime(2025, 1, 1),
        ));
    await seed.into(seed.invoicesTable).insert(InvoicesTableCompanion.insert(
          invoiceNumber: 'OLD-1',
          customerId: Value(customerId),
          createdAt: DateTime(2025, 1, 2),
        ));
    await seed.close();

    final raw = sqlite.sqlite3.open(file.path);
    for (final table in [
      'ledger_entry_audits',
      'ledger_entries',
      'sessions',
      'users',
    ]) {
      raw.execute('DROP TABLE IF EXISTS $table');
    }
    raw.execute('PRAGMA user_version = 3');
    raw.dispose();

    final migrated = AppDatabase.forTesting(NativeDatabase(file));
    expect(await migrated.select(migrated.productsTable).get(), hasLength(1));
    expect(await migrated.select(migrated.customersTable).get(), hasLength(1));
    expect(await migrated.select(migrated.invoicesTable).get(), hasLength(1));
    final opening = await migrated.select(migrated.ledgerEntriesTable).get();
    expect(opening, hasLength(1));
    expect(opening.single.amount, 85000);
    await migrated.close();
    await directory.delete(recursive: true);
  });
}

Future<int> _insertCustomer(AppDatabase db, String name, String? phone) =>
    db.into(db.customersTable).insert(CustomersTableCompanion.insert(
          name: name,
          phone: Value(phone),
          updatedAt: DateTime.now(),
        ));
