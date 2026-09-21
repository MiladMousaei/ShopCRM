import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'printer_service.dart';
import 'escpos_builder.dart';
import '../../domain/models/invoice.dart';

/// سرویس پرینتر بلوتوث با flutter_blue_plus
/// روی ویندوز غیرفعال می‌شود (WiFi اولویت دارد)
///
/// اکثر پرینترهای حرارتی BT از SPP UUID استفاده می‌کنند:
/// 0000ff02-0000-1000-8000-00805f9b34fb (write characteristic)
class BluetoothPrinterService extends PrinterService {
  final String deviceId;
  final String deviceName;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  bool _connected = false;

  BluetoothPrinterService({
    required this.deviceId,
    required this.deviceName,
  });

  @override
  bool get isConnected => _connected;

  @override
  Future<bool> connect() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return false;
    }
    try {
      _device = BluetoothDevice.fromId(deviceId);
      await _device!.connect(timeout: const Duration(seconds: 10));

      final services = await _device!.discoverServices();

      // جستجو در سرویس‌ها برای پیدا کردن characteristic قابل نوشتن
      for (final service in services) {
        for (final char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            // اولویت با UUID استاندارد SPP
            if (service.uuid.toString().toLowerCase().contains('18f0') ||
                char.uuid.toString().toLowerCase().contains('2af1')) {
              _writeChar = char;
              break;
            }
            // fallback: اولین characteristic قابل نوشتن
            _writeChar ??= char;
          }
        }
        if (_writeChar != null) break;
      }

      _connected = _writeChar != null;
      return _connected;
    } catch (_) {
      _connected = false;
      return false;
    }
  }

  @override
  Future<void> printReceipt(
    Invoice invoice, {
    required String storeName,
    required String storePhone,
    required String storeAddress,
  }) async {
    if (!_connected || _writeChar == null) {
      throw Exception('پرینتر بلوتوث متصل نیست');
    }
    final bytes = await EscPosBuilder.buildReceiptBytes(
      invoice: invoice,
      storeName: storeName,
      storePhone: storePhone,
      storeAddress: storeAddress,
    );
    // ارسال داده در بلوک‌های ۵۱۲ بایتی (محدودیت MTU بلوتوث)
    const chunkSize = 512;
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      final chunk = bytes.sublist(i, end);
      await _writeChar!.write(chunk, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } catch (_) {}
    _connected = false;
    _writeChar = null;
    _device = null;
  }

  /// اسکن دستگاه‌های بلوتوث اطراف — فقط Android
  static Stream<List<Map<String, String>>> scanDevices() async* {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      yield [];
      return;
    }
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      yield* FlutterBluePlus.scanResults.map(
        (results) => results
            .map((r) => {
                  'id': r.device.remoteId.str,
                  'name': r.device.platformName.isEmpty
                      ? 'دستگاه ناشناس'
                      : r.device.platformName,
                  'rssi': '${r.rssi} dBm',
                })
            .toList(),
      );
    } catch (_) {
      yield [];
    }
  }

  /// بررسی وضعیت بلوتوث دستگاه
  static Future<bool> isBluetoothOn() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return false;
    }
    return FlutterBluePlus.adapterState.first.then(
      (state) => state == BluetoothAdapterState.on,
    );
  }
}
