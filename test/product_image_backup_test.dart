import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_crm/data/local/database.dart';
import 'package:shop_crm/services/backup_service.dart';
import 'package:shop_crm/services/product_image_service.dart';

class _FakePaths extends PathProviderPlatform {
  final String root;
  _FakePaths(this.root);
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('shopcrm_files_test_');
    PathProviderPlatform.instance = _FakePaths(temp.path);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('تصویر فشرده با نام نسبی ذخیره، نمایش، تغییر و حذف می‌شود', () async {
    final source = File('${temp.path}/source.png');
    await source
        .writeAsBytes(img.encodePng(img.Image(width: 1800, height: 900)));
    final first = await ProductImageService.importImage(XFile(source.path));
    expect(first, isNot(contains(temp.path)));
    expect(first, endsWith('.jpg'));
    final firstFile = await ProductImageService.resolve(first);
    expect(firstFile, isNotNull);
    final decoded = img.decodeImage(await firstFile!.readAsBytes());
    expect(decoded!.width, lessThanOrEqualTo(1280));

    final second = await ProductImageService.importImage(XFile(source.path));
    expect(second, isNot(first));
    await ProductImageService.delete(first);
    expect(await ProductImageService.resolve(first), isNull);
    expect(await ProductImageService.resolve('missing.jpg'), isNull);
    expect(await ProductImageService.resolve(source.absolute.path), isNull);
  });

  test('پشتیبان ZIP شامل SQLite سالم و تصاویر است', () async {
    final dbFile = File('${temp.path}/live.sqlite');
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    await db.into(db.customersTable).insert(CustomersTableCompanion.insert(
          name: 'مشتری پشتیبان',
          updatedAt: DateTime.now(),
        ));
    final source = File('${temp.path}/source.png');
    await source.writeAsBytes(img.encodePng(img.Image(width: 20, height: 20)));
    final imageName = await ProductImageService.importImage(XFile(source.path));
    BackupService.configure(db);
    final backup = await BackupService.createBackup();
    expect(backup, isNotNull);
    final archive = ZipDecoder().decodeBytes(await backup!.readAsBytes());
    expect(archive.findFile('database/${AppDatabase.databaseFileName}'),
        isNotNull);
    expect(archive.findFile('product_images/$imageName'), isNotNull);
    final databaseEntry =
        archive.findFile('database/${AppDatabase.databaseFileName}')!;
    final restored = File('${temp.path}/restored.sqlite');
    await restored.writeAsBytes(databaseEntry.content as List<int>);
    final restoredDb = AppDatabase.forTesting(NativeDatabase(restored));
    expect(
        await restoredDb.select(restoredDb.customersTable).get(), hasLength(1));
    await restoredDb.close();
    await db.close();
  });

  test('بازیابی امن بکاپ، دیتابیس و تصاویر را برمی‌گرداند', () async {
    final dbFile = File('${temp.path}/live_restore.sqlite');
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    await db.into(db.customersTable).insert(CustomersTableCompanion.insert(
          name: 'نسخه داخل بکاپ',
          updatedAt: DateTime.now(),
        ));
    final source = File('${temp.path}/restore_source.png');
    await source.writeAsBytes(img.encodePng(img.Image(width: 20, height: 20)));
    final imageName = await ProductImageService.importImage(XFile(source.path));
    BackupService.configure(db);
    final backup = await BackupService.createBackup();
    expect(backup, isNotNull);

    await db.into(db.customersTable).insert(CustomersTableCompanion.insert(
          name: 'داده بعد از بکاپ',
          updatedAt: DateTime.now(),
        ));
    await ProductImageService.delete(imageName);
    expect(await ProductImageService.resolve(imageName), isNull);

    expect(
      await BackupService.restoreBackup(
        backup!,
        targetDatabaseFile: dbFile,
        restartApplication: false,
      ),
      isTrue,
    );
    final restored = AppDatabase.forTesting(NativeDatabase(dbFile));
    final customers = await restored.select(restored.customersTable).get();
    expect(customers.map((row) => row.name), ['نسخه داخل بکاپ']);
    expect(await ProductImageService.resolve(imageName), isNotNull);
    await restored.close();
  });

  test('فایل خراب رد می‌شود و دیتابیس فعلی دست‌نخورده می‌ماند', () async {
    final dbFile = File('${temp.path}/safe.sqlite');
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    await db.into(db.customersTable).insert(CustomersTableCompanion.insert(
          name: 'داده سالم',
          updatedAt: DateTime.now(),
        ));
    BackupService.configure(db);
    final corrupt = File('${temp.path}/corrupt.zip');
    await corrupt.writeAsString('not a zip');

    expect(
      await BackupService.restoreBackup(
        corrupt,
        targetDatabaseFile: dbFile,
        restartApplication: false,
      ),
      isFalse,
    );
    expect(await db.select(db.customersTable).get(), hasLength(1));
    await db.close();
  });
}
