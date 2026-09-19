import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/backup_service.dart';
import 'services/log_service.dart';
import 'data/local/database.dart';
import 'data/repositories/local_auth_repository.dart';
import 'presentation/providers/product_provider.dart';

/// نقطه شروع برنامه
void main() async {
  // اطمینان از آماده بودن Flutter binding قبل از هر کار async
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    unawaited(windowManager.waitUntilReadyToShow(null, () async {
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    }));
  }

  // پشتیبانی از هر دو جهت نمایش (portrait + landscape)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // شفافیت نوار وضعیت اندروید
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final database = AppDatabase();
  try {
    await database.customSelect('SELECT 1').getSingle();
    await LocalAuthRepository(database).ensureDefaultUser();
    BackupService.configure(database);
    NotificationService.init().catchError((error, stack) {
      return LogService.error('راه‌اندازی اعلان‌ها ناموفق بود', error, stack);
    });
    BackupService.autoBackupIfNeeded();
    runApp(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const ShopCrmApp(),
    ));
  } catch (error, stack) {
    await LogService.error(
        'بازکردن یا migration دیتابیس ناموفق بود', error, stack);
    await database.close();
    runApp(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: Text('خطا در بازکردن پایگاه داده: $error')),
        ),
      ),
    ));
  }
}
