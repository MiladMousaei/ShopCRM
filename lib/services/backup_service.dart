import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/database.dart';
import 'app_paths.dart';
import 'log_service.dart';

class BackupService {
  BackupService._();

  static const _lastBackupKey = 'last_auto_backup';
  static const _autoEnabledKey = 'auto_backup_enabled';
  static const _retainedBackups = 10;
  static AppDatabase? _database;
  static Future<File?>? _activeBackup;

  static void configure(AppDatabase database) => _database = database;

  static Future<File?> createBackup({bool share = false}) async {
    final active = _activeBackup;
    if (active != null) {
      final file = await active;
      if (share && file != null) await _shareBackup(file);
      return file;
    }
    final operation = _createBackup(share: share);
    _activeBackup = operation;
    try {
      return await operation;
    } finally {
      _activeBackup = null;
    }
  }

  static Future<File?> _createBackup({required bool share}) async {
    final db = _database;
    if (db == null) throw StateError('BackupService پیکربندی نشده است');
    File? snapshot;
    try {
      final backupDir = await AppPaths.backupsDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}${_two(now.month)}${_two(now.day)}_'
          '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}_'
          '${now.millisecond.toString().padLeft(3, '0')}';
      snapshot = File(p.join(backupDir.path, 'shopcrm_$stamp.sqlite'));

      await db.customStatement('PRAGMA wal_checkpoint(FULL)');
      final escaped = snapshot.path.replaceAll("'", "''");
      await db.customStatement("VACUUM INTO '$escaped'");

      final zipFile = File(p.join(backupDir.path, 'shopcrm_$stamp.zip'));
      final encoder = ZipFileEncoder()..create(zipFile.path);
      encoder.addFile(snapshot, 'database/${AppDatabase.databaseFileName}');
      final images = await AppPaths.productImagesDirectory();
      await for (final entity in images.list()) {
        if (entity is File) {
          encoder.addFile(
              entity, p.join('product_images', p.basename(entity.path)));
        }
      }
      encoder.close();
      await snapshot.delete();
      snapshot = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, now.toIso8601String());
      await _applyRetention(backupDir);

      if (share) {
        await _shareBackup(zipFile);
      }
      return zipFile;
    } catch (error, stack) {
      await LogService.error('ایجاد پشتیبان ناموفق بود', error, stack);
      try {
        if (snapshot != null && await snapshot.exists()) {
          await snapshot.delete();
        }
      } catch (cleanupError, cleanupStack) {
        await LogService.error(
          'پاک‌سازی فایل موقت بکاپ ناموفق بود',
          cleanupError,
          cleanupStack,
        );
      }
      return null;
    }
  }

  static Future<void> _shareBackup(File file) =>
      SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'پشتیبان فروشگاه هوشمند',
        text: 'پشتیبان داده‌ها و تصاویر فروشگاه',
      ));

  /// بازیابی امن یک ZIP ساخته‌شده توسط برنامه. ابتدا دیتابیس داخل فایل در
  /// پوشه موقت باز، migrate و با integrity_check بررسی می‌شود. سپس از وضعیت
  /// فعلی یک بکاپ ایمنی گرفته می‌شود و جایگزینی فایل دیتابیس به‌صورت مرحله‌ای
  /// انجام می‌گیرد. تصاویر بازیابی‌شده با تصاویر فعلی ادغام می‌شوند.
  static Future<bool> restoreBackup(
    File backup, {
    File? targetDatabaseFile,
    bool restartApplication = true,
  }) async {
    final db = _database;
    if (db == null) throw StateError('BackupService پیکربندی نشده است');
    Directory? staging;
    File? previousDatabase;
    File? target;
    var databaseClosed = false;
    try {
      if (!await backup.exists() ||
          !backup.path.toLowerCase().endsWith('.zip')) {
        throw const FormatException('فایل پشتیبان معتبر نیست');
      }
      final archive =
          ZipDecoder().decodeBytes(await backup.readAsBytes(), verify: true);
      final databaseEntry =
          archive.findFile('database/${AppDatabase.databaseFileName}');
      if (databaseEntry == null || !databaseEntry.isFile) {
        throw const FormatException('دیتابیس در فایل پشتیبان وجود ندارد');
      }

      staging = await Directory.systemTemp.createTemp('shopcrm_restore_');
      final stagedDatabase = File(p.join(staging.path, 'restored.sqlite'));
      await stagedDatabase.writeAsBytes(
        databaseEntry.content as List<int>,
        flush: true,
      );
      final stagedDb = AppDatabase.forTesting(NativeDatabase(stagedDatabase));
      try {
        final integrity = await stagedDb
            .customSelect('PRAGMA integrity_check')
            .getSingle();
        if (integrity.data.values.single.toString().toLowerCase() != 'ok') {
          throw const FormatException('دیتابیس پشتیبان آسیب‌دیده است');
        }
      } finally {
        await stagedDb.close();
      }

      final safetyBackup = await createBackup();
      if (safetyBackup == null) {
        throw StateError('ساخت بکاپ ایمنی پیش از بازیابی ناموفق بود');
      }
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      await db.close();
      databaseClosed = true;
      _database = null;

      target = targetDatabaseFile ?? File(await AppDatabase.databaseFilePath());
      await target.parent.create(recursive: true);
      previousDatabase = File('${target.path}.before_restore');
      if (await previousDatabase.exists()) await previousDatabase.delete();
      if (await target.exists()) await target.rename(previousDatabase.path);
      final incoming = File('${target.path}.restoring');
      if (await incoming.exists()) await incoming.delete();
      await stagedDatabase.copy(incoming.path);
      await incoming.rename(target.path);
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('${target.path}$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }

      final images = await AppPaths.productImagesDirectory();
      for (final entry in archive.files.where((entry) => entry.isFile)) {
        final normalized = entry.name.replaceAll('\\', '/');
        if (!normalized.startsWith('product_images/')) continue;
        final relative = normalized.substring('product_images/'.length);
        if (relative.isEmpty || relative.contains('/') || p.basename(relative) != relative) {
          throw const FormatException('مسیر تصویر نامعتبر در فایل پشتیبان');
        }
        await File(p.join(images.path, relative)).writeAsBytes(
          entry.content as List<int>,
          flush: true,
        );
      }
      if (await previousDatabase.exists()) await previousDatabase.delete();

      if (restartApplication && Platform.isWindows) {
        await Process.start(
          Platform.resolvedExecutable,
          const [],
          mode: ProcessStartMode.detached,
        );
        exit(0);
      }
      return true;
    } catch (error, stack) {
      await LogService.error('بازیابی پشتیبان ناموفق بود', error, stack);
      if (target != null &&
          previousDatabase != null &&
          await previousDatabase.exists()) {
        if (await target.exists()) await target.delete();
        await previousDatabase.rename(target.path);
      }
      if (databaseClosed && restartApplication && Platform.isWindows) {
        await Process.start(
          Platform.resolvedExecutable,
          const [],
          mode: ProcessStartMode.detached,
        );
        exit(1);
      }
      return false;
    } finally {
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  static Future<void> _applyRetention(Directory directory) async {
    final backups = await directory
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.zip'))
        .cast<File>()
        .toList();
    backups
        .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final old in backups.skip(_retainedBackups)) {
      await old.delete();
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static Future<bool> isAutoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoEnabledKey) ?? true;
  }

  static Future<void> setAutoEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoEnabledKey, value);
  }

  static Future<String?> getLastBackupLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_lastBackupKey);
    if (str == null) return 'هرگز';
    final dt = DateTime.tryParse(str);
    if (dt == null) return 'نامشخص';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'همین الان';
    if (diff.inHours < 1) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inDays < 1) return '${diff.inHours} ساعت پیش';
    return '${diff.inDays} روز پیش';
  }

  static Future<void> autoBackupIfNeeded() async {
    if (!await isAutoEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_lastBackupKey);
    if (str != null) {
      final last = DateTime.tryParse(str);
      if (last != null && DateTime.now().difference(last).inMinutes < 30) {
        return;
      }
    }
    await createBackup();
  }
}
