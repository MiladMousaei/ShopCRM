import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../../services/app_paths.dart';
import 'tables/products_table.dart';
import 'tables/invoices_table.dart';
import 'tables/customers_table.dart';
import 'tables/inventory_table.dart';
import 'tables/users_table.dart';
import 'tables/ledger_entries_table.dart';
import 'daos/products_dao.dart';
import 'daos/invoices_dao.dart';
import 'daos/customers_dao.dart';
import 'daos/ledger_dao.dart';

part 'database.g.dart';

/// پایگاه داده اصلی برنامه (SQLite از طریق Drift)
///
/// تمام داده‌ها اول اینجا ذخیره می‌شوند (offline-first).
/// بعداً با سرور sync می‌شوند.
/// فایل دیتابیس: shop_crm_db.sqlite
@DriftDatabase(
  tables: [
    ProductsTable,
    InvoicesTable,
    InvoiceItemsTable,
    CustomersTable,
    InventoryLogsTable,
    UsersTable,
    SessionsTable,
    LedgerEntriesTable,
    LedgerEntryAuditsTable,
  ],
  daos: [
    ProductsDao,
    InvoicesDao,
    CustomersDao,
    LedgerDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  static const databaseFileName = 'shop_crm.sqlite';

  static Future<String> databaseFilePath() async {
    final dataDir = await AppPaths.dataDirectory();
    return p.join(dataDir.path, databaseFileName);
  }

  /// نسخه schema — با هر تغییر ساختار جدول باید افزایش یابد
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS
            invoices_invoice_number_unique ON invoices(invoice_number)
          ''');
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS products_barcode_unique
            ON products(barcode COLLATE NOCASE)
            WHERE barcode IS NOT NULL AND barcode <> ''
          ''');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
        },
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            await m.addColumn(invoicesTable, invoicesTable.customerName);
          }
          if (from < 4) {
            await m.createTable(usersTable);
            await m.createTable(sessionsTable);
            await m.createTable(ledgerEntriesTable);
            await m.createTable(ledgerEntryAuditsTable);
            // انتقال بدهی فعلی کاربران به سند افتتاحیه، بدون حذف یا بازنویسی داده‌ها.
            await customStatement('''
          INSERT INTO ledger_entries
            (id, customer_id, type, amount, direction, operation_date,
             description, created_at, updated_at, is_active)
          SELECT lower(hex(randomblob(16))), id, 'debt', round(total_debt),
                 'debit', updated_at, 'مانده انتقالی از نسخه قبلی',
                 updated_at, updated_at, 1
          FROM customers WHERE total_debt > 0
        ''');
          }
          if (from < 5) {
            final columns = await customSelect(
              "PRAGMA table_info('invoice_items')",
            ).get();
            final hasPurchasePrice = columns.any(
              (row) => row.read<String>('name') == 'purchase_price',
            );
            if (!hasPurchasePrice) {
              await m.addColumn(
                invoiceItemsTable,
                invoiceItemsTable.purchasePrice,
              );
              await customStatement('''
                UPDATE invoice_items
                SET purchase_price = COALESCE(
                  (SELECT purchase_price FROM products
                   WHERE products.id = invoice_items.product_id), 0)
              ''');
            }

            // هیچ رکورد قدیمی حذف نمی‌شود. در صورت وجود مقدار تکراری، شناسه
            // همان رکورد به انتهای مقدار افزوده می‌شود و سپس قید یکتا می‌آید.
            await customStatement('''
              UPDATE invoices
              SET invoice_number = invoice_number || '-DUP-' || id
              WHERE id NOT IN (
                SELECT MIN(id) FROM invoices GROUP BY invoice_number
              )
            ''');
            await customStatement('''
              CREATE UNIQUE INDEX IF NOT EXISTS
              invoices_invoice_number_unique ON invoices(invoice_number)
            ''');
            await customStatement('''
              UPDATE products SET barcode = trim(barcode)
              WHERE barcode IS NOT NULL
            ''');
            await customStatement('''
              UPDATE products
              SET barcode = barcode || '-DUP-' || id
              WHERE barcode IS NOT NULL AND barcode <> '' AND id NOT IN (
                SELECT MIN(id) FROM products
                WHERE barcode IS NOT NULL AND barcode <> ''
                GROUP BY barcode COLLATE NOCASE
              )
            ''');
            await customStatement('''
              CREATE UNIQUE INDEX IF NOT EXISTS products_barcode_unique
              ON products(barcode COLLATE NOCASE)
              WHERE barcode IS NOT NULL AND barcode <> ''
            ''');
          }
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final file = File(await databaseFilePath());
      return NativeDatabase.createInBackground(file, logStatements: false);
    });
  }
}
