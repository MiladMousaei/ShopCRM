import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/invoice.dart';
import '../../services/printer/printer_service.dart';
import '../../services/printer/bluetooth_printer_service.dart';
import '../../services/printer/escpos_builder.dart';
import '../../services/printer/wifi_printer_service.dart';
import '../../services/printer/usb_printer_service.dart';

enum PrinterType { bluetooth, wifi, usb }

class PrinterSettings {
  final PrinterType type;
  final String? bluetoothDeviceId;
  final String? bluetoothDeviceName;
  final String wifiIp;
  final int wifiPort;
  final String usbPrinterName;
  final String storeName;
  final String storePhone;
  final String storeAddress;

  const PrinterSettings({
    this.type = PrinterType.wifi,
    this.bluetoothDeviceId,
    this.bluetoothDeviceName,
    this.wifiIp = '192.168.1.100',
    this.wifiPort = 9100,
    this.usbPrinterName = '',
    this.storeName = 'فروشگاه هوشمند',
    this.storePhone = '',
    this.storeAddress = '',
  });

  PrinterSettings copyWith({
    PrinterType? type,
    String? bluetoothDeviceId,
    String? bluetoothDeviceName,
    String? wifiIp,
    int? wifiPort,
    String? usbPrinterName,
    String? storeName,
    String? storePhone,
    String? storeAddress,
  }) {
    return PrinterSettings(
      type: type ?? this.type,
      bluetoothDeviceId: bluetoothDeviceId ?? this.bluetoothDeviceId,
      bluetoothDeviceName: bluetoothDeviceName ?? this.bluetoothDeviceName,
      wifiIp: wifiIp ?? this.wifiIp,
      wifiPort: wifiPort ?? this.wifiPort,
      usbPrinterName: usbPrinterName ?? this.usbPrinterName,
      storeName: storeName ?? this.storeName,
      storePhone: storePhone ?? this.storePhone,
      storeAddress: storeAddress ?? this.storeAddress,
    );
  }
}

class PrinterState {
  final PrinterSettings settings;
  final bool isConnected;
  final bool isLoading;
  final String? error;
  final List<PrinterDevice> scannedDevices;

  const PrinterState({
    this.settings = const PrinterSettings(),
    this.isConnected = false,
    this.isLoading = false,
    this.error,
    this.scannedDevices = const [],
  });

  PrinterState copyWith({
    PrinterSettings? settings,
    bool? isConnected,
    bool? isLoading,
    String? error,
    List<PrinterDevice>? scannedDevices,
  }) {
    return PrinterState(
      settings: settings ?? this.settings,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      scannedDevices: scannedDevices ?? this.scannedDevices,
    );
  }
}

class PrinterDevice {
  final String id;
  final String name;
  final String? address;

  const PrinterDevice({required this.id, required this.name, this.address});
}

class PrinterNotifier extends StateNotifier<PrinterState> {
  PrinterService? _service;

  PrinterNotifier() : super(const PrinterState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString('printer_type') ?? 'wifi';
    final type = PrinterType.values.firstWhere(
      (t) => t.name == typeStr, orElse: () => PrinterType.wifi);
    state = state.copyWith(
      settings: PrinterSettings(
        type: type,
        bluetoothDeviceId: prefs.getString('bt_device_id'),
        bluetoothDeviceName: prefs.getString('bt_device_name'),
        wifiIp: prefs.getString('wifi_ip') ?? '192.168.1.100',
        wifiPort: prefs.getInt('wifi_port') ?? 9100,
        usbPrinterName: prefs.getString('usb_printer_name') ?? '',
        storeName: prefs.getString('store_name') ?? 'فروشگاه هوشمند',
        storePhone: prefs.getString('store_phone') ?? '',
        storeAddress: prefs.getString('store_address') ?? '',
      ),
    );
  }

  Future<void> saveSettings(PrinterSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_type', settings.type.name);
    await prefs.setString('wifi_ip', settings.wifiIp);
    await prefs.setInt('wifi_port', settings.wifiPort);
    await prefs.setString('usb_printer_name', settings.usbPrinterName);
    await prefs.setString('store_name', settings.storeName);
    await prefs.setString('store_phone', settings.storePhone);
    await prefs.setString('store_address', settings.storeAddress);
    if (settings.bluetoothDeviceId != null) {
      await prefs.setString('bt_device_id', settings.bluetoothDeviceId!);
      await prefs.setString('bt_device_name', settings.bluetoothDeviceName ?? '');
    }
    state = state.copyWith(settings: settings);
    _service = null;
    state = state.copyWith(isConnected: false);
  }

  Future<bool> connect() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      switch (state.settings.type) {
        case PrinterType.bluetooth:
          _service = BluetoothPrinterService(
            deviceId: state.settings.bluetoothDeviceId ?? '',
            deviceName: state.settings.bluetoothDeviceName ?? '',
          );
        case PrinterType.usb:
          _service = UsbPrinterService(
            printerName: state.settings.usbPrinterName,
          );
        case PrinterType.wifi:
          _service = WiFiPrinterService(
            ip: state.settings.wifiIp,
            port: state.settings.wifiPort,
          );
      }
      final connected = await _service!.connect();
      state = state.copyWith(isConnected: connected, isLoading: false,
          error: connected ? null : 'اتصال به پرینتر ناموفق بود');
      return connected;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'خطا در اتصال: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _service?.disconnect();
    _service = null;
    state = state.copyWith(isConnected: false);
  }

  /// پرینت رسید فاکتور — اگر متصل نباشد ابتدا اتصال برقرار می‌کند
  Future<void> printInvoice(Invoice invoice) async {
    if (_service == null) await connect();
    if (!state.isConnected) throw Exception('پرینتر متصل نیست');
    await _service!.printReceipt(
      invoice,
      storeName: state.settings.storeName,
      storePhone: state.settings.storePhone,
      storeAddress: state.settings.storeAddress,
    );
  }

  /// پرینت تست ASCII — تأیید اتصال بدون فاکتور واقعی
  Future<void> testPrint() async {
    if (_service == null) await connect();
    if (!state.isConnected) throw Exception('پرینتر متصل نیست');

    // WiFi printer: ارسال مستقیم bytes تست
    if (_service is WiFiPrinterService) {
      final bytes = EscPosBuilder.buildTestPrint(state.settings.storeName);
      final wifiService = _service as WiFiPrinterService;
      // دسترسی مستقیم به socket از طریق printRaw
      await wifiService.printRaw(bytes);
    } else if (_service is UsbPrinterService) {
      final bytes = EscPosBuilder.buildTestPrint(state.settings.storeName);
      await (_service as UsbPrinterService).printRaw(bytes);
    }
    // بلوتوث: پیاده‌سازی در BluetoothPrinterService
  }

  /// اسکن پرینترهای WiFi در شبکه محلی
  Future<List<String>> discoverWifiPrinters({String subnet = '192.168.1'}) async {
    state = state.copyWith(isLoading: true);
    try {
      final found = await WiFiPrinterService.discoverPrinters(subnet: subnet);
      state = state.copyWith(isLoading: false);
      return found;
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return [];
    }
  }

  PrinterService? get service => _service;
}

final printerProvider = StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  return PrinterNotifier();
});
