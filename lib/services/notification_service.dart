import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const windows = WindowsInitializationSettings(
      appName: 'فروشگاه هوشمند',
      appUserModelId: 'MiladMousaei.ShopCRM',
      guid: '8c92a520-6c1d-4ef3-ae32-4f79d17912f1',
    );
    const darwin = DarwinInitializationSettings();
    const linux = LinuxInitializationSettings(
      defaultActionName: 'باز کردن',
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
      windows: windows,
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> showLowStockAlert(String productName, int stock) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'low_stock',
        'هشدار موجودی',
        channelDescription: 'اعلان‌های کمبود موجودی محصولات',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      windows: WindowsNotificationDetails(),
    );
    await _plugin.show(
      productName.hashCode,
      'هشدار کمبود موجودی',
      'موجودی "$productName" به $stock عدد رسیده است',
      details,
    );
  }

  static Future<void> showSyncSuccess() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'sync',
        'همگام‌سازی',
        channelDescription: 'وضعیت همگام‌سازی با سرور',
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/ic_launcher',
      ),
      windows: WindowsNotificationDetails(),
    );
    await _plugin.show(1, 'همگام‌سازی موفق', 'داده‌ها با سرور همگام شدند', details);
  }
}
