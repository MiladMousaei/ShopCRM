import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_crm/data/local/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('migration نسخه ۵ رکوردها را حفظ و مقادیر تکراری را یکتا می‌کند',
      () async {
    final directory = await Directory.systemTemp.createTemp('shopcrm_v4_');
    final file = File('${directory.path}/v4.sqlite');
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        barcode TEXT,
        name TEXT NOT NULL,
        category_id INTEGER,
        purchase_price REAL NOT NULL DEFAULT 0,
        sell_price REAL NOT NULL DEFAULT 0,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        min_stock_alert INTEGER NOT NULL DEFAULT 5,
        image_url TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    raw.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        invoice_number TEXT NOT NULL,
        customer_id INTEGER,
        customer_name TEXT,
        user_id INTEGER,
        total_amount REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        is_discount_percent INTEGER NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        final_amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        status TEXT NOT NULL DEFAULT 'draft',
        notes TEXT,
        created_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    raw.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        product_barcode TEXT,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        discount_percent REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL
      )
    ''');
    raw.execute('''
      INSERT INTO products
        (barcode, name, purchase_price, updated_at)
      VALUES ('DUP-1', 'اول', 60000, 1), ('DUP-1', 'دوم', 70000, 1)
    ''');
    raw.execute('''
      INSERT INTO invoices (invoice_number, created_at)
      VALUES ('INV-DUP', 1), ('INV-DUP', 2)
    ''');
    raw.execute('''
      INSERT INTO invoice_items
        (invoice_id, product_id, product_name, quantity, unit_price, subtotal)
      VALUES (1, 1, 'اول', 1, 100000, 100000)
    ''');
    raw.execute('PRAGMA user_version = 4');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    final products = await db.customSelect(
      'SELECT barcode FROM products ORDER BY id',
    ).get();
    final invoices = await db.customSelect(
      'SELECT invoice_number FROM invoices ORDER BY id',
    ).get();
    final item = await db.customSelect(
      'SELECT purchase_price FROM invoice_items WHERE id = 1',
    ).getSingle();

    expect(products, hasLength(2));
    expect(products[0].read<String>('barcode'), 'DUP-1');
    expect(products[1].read<String>('barcode'), startsWith('DUP-1-DUP-'));
    expect(invoices, hasLength(2));
    expect(invoices[0].read<String>('invoice_number'), 'INV-DUP');
    expect(
      invoices[1].read<String>('invoice_number'),
      startsWith('INV-DUP-DUP-'),
    );
    expect(item.read<double>('purchase_price'), 60000);

    await db.close();
    await directory.delete(recursive: true);
  });
}
