import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../services/printer/bluetooth_printer_service.dart';
import '../../../services/printer/wifi_printer_service.dart';
import '../../../services/printer/usb_printer_service.dart';
import '../../providers/printer_provider.dart';
import '../../widgets/common/app_header_back_button.dart';
import '../../widgets/common/loading_overlay.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _storePhoneCtrl = TextEditingController();
  final _storeAddressCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _initialized = false;

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _storeNameCtrl.dispose();
    _storePhoneCtrl.dispose();
    _storeAddressCtrl.dispose();
    super.dispose();
  }

  void _initControllers(PrinterSettings s) {
    if (_initialized) return;
    _ipCtrl.text = s.wifiIp;
    _portCtrl.text = s.wifiPort.toString();
    _storeNameCtrl.text = s.storeName;
    _storePhoneCtrl.text = s.storePhone;
    _storeAddressCtrl.text = s.storeAddress;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printerProvider);
    _initControllers(state.settings);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppHeaderBackButton(fallbackRoute: '/settings'),
          title: const Text(AppStrings.printerSettings),
        ),
        body: LoadingOverlay(
          isLoading: state.isLoading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // انتخاب نوع پرینتر
                  _Section(
                    title: 'نوع پرینتر',
                    child: Row(
                      children: PrinterType.values
                          // بلوتوث فقط روی موبایل
                          .where((t) =>
                              t != PrinterType.bluetooth ||
                              (!Platform.isWindows &&
                                  !Platform.isLinux &&
                                  !Platform.isMacOS))
                          // USB فقط روی ویندوز
                          .where(
                              (t) => t != PrinterType.usb || Platform.isWindows)
                          .map((type) {
                        final selected = state.settings.type == type;
                        IconData icon;
                        String label;
                        switch (type) {
                          case PrinterType.bluetooth:
                            icon = Icons.bluetooth;
                            label = AppStrings.bluetoothPrinter;
                          case PrinterType.wifi:
                            icon = Icons.wifi;
                            label = AppStrings.wifiPrinter;
                          case PrinterType.usb:
                            icon = Icons.usb;
                            label = 'پرینتر USB/کابل';
                        }
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              ref.read(printerProvider.notifier).saveSettings(
                                    state.settings.copyWith(type: type),
                                  );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.background,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: selected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Icon(icon,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      size: 28),
                                  const SizedBox(height: 6),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // تنظیمات وای‌فای
                  if (state.settings.type == PrinterType.wifi)
                    _Section(
                      title: AppStrings.wifiPrinter,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _ipCtrl,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(
                                    labelText: AppStrings.printerIp,
                                    hintText: '192.168.1.100',
                                  ),
                                  validator: Validators.ipAddress,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _portCtrl,
                                  textDirection: TextDirection.ltr,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: AppStrings.printerPort,
                                    hintText: '9100',
                                  ),
                                  validator: Validators.port,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon:
                                      const Icon(Icons.network_ping, size: 18),
                                  label: const Text(AppStrings.testConnection,
                                      style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 13)),
                                  onPressed: _testWifiConnection,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.print, size: 18),
                                  label: const Text(AppStrings.testPrint,
                                      style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 13)),
                                  onPressed: _testPrint,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // دکمه کشف پرینتر در شبکه
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text('کشف پرینتر در شبکه',
                                  style: TextStyle(
                                      fontFamily: 'Vazirmatn', fontSize: 13)),
                              onPressed: _discoverWifiPrinters,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // تنظیمات بلوتوث
                  if (state.settings.type == PrinterType.bluetooth)
                    _Section(
                      title: AppStrings.bluetoothPrinter,
                      child: Column(
                        children: [
                          if (state.settings.bluetoothDeviceName != null)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.bluetooth_connected,
                                  color: AppColors.primary),
                              title: Text(
                                state.settings.bluetoothDeviceName!,
                                style: const TextStyle(fontFamily: 'Vazirmatn'),
                              ),
                              trailing: state.isConnected
                                  ? const Chip(
                                      label: Text('متصل',
                                          style: TextStyle(
                                              fontFamily: 'Vazirmatn',
                                              fontSize: 11)),
                                      backgroundColor: AppColors.successLight,
                                    )
                                  : null,
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text(AppStrings.scanDevices,
                                  style: TextStyle(fontFamily: 'Vazirmatn')),
                              onPressed: _scanBluetooth,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // تنظیمات USB
                  if (state.settings.type == PrinterType.usb)
                    _Section(
                      title: 'پرینتر USB/کابل',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.settings.usbPrinterName.isNotEmpty)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.print,
                                  color: AppColors.primary),
                              title: Text(state.settings.usbPrinterName,
                                  style: const TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontWeight: FontWeight.w600)),
                              trailing: const Chip(
                                label: Text('انتخاب‌شده',
                                    style: TextStyle(
                                        fontFamily: 'Vazirmatn', fontSize: 11)),
                                backgroundColor: AppColors.successLight,
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text('کشف پرینترهای متصل به ویندوز',
                                  style: TextStyle(fontFamily: 'Vazirmatn')),
                              onPressed: _discoverUsbPrinters,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon:
                                      const Icon(Icons.network_ping, size: 18),
                                  label: const Text('تست اتصال',
                                      style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 13)),
                                  onPressed: _testWifiConnection,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.print, size: 18),
                                  label: const Text(AppStrings.testPrint,
                                      style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontSize: 13)),
                                  onPressed: _testPrint,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // اطلاعات فروشگاه
                  _Section(
                    title: 'اطلاعات فروشگاه (روی رسید)',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _storeNameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'نام فروشگاه'),
                          validator: (v) =>
                              Validators.required(v, fieldName: 'نام فروشگاه'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _storePhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                              labelText: AppStrings.phone),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _storeAddressCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: AppStrings.address),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // پیام خطا
                  if (state.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                            fontFamily: 'Vazirmatn',
                            color: AppColors.error,
                            fontSize: 13),
                      ),
                    ),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text(AppStrings.save,
                          style:
                              TextStyle(fontFamily: 'Vazirmatn', fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _testWifiConnection() async {
    if (!_formKey.currentState!.validate()) return;
    await _saveSettings();
    final ok = await ref.read(printerProvider.notifier).connect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          ok ? AppStrings.printerConnected : AppStrings.printerNotFound,
          style: const TextStyle(fontFamily: 'Vazirmatn'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
    }
  }

  Future<void> _testPrint() async {
    await _saveSettings();
    try {
      await ref.read(printerProvider.notifier).testPrint();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('پرینت تست ارسال شد ✓',
              style: TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطا در پرینت: $e',
              style: const TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _scanBluetooth() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BluetoothScanDialog(
        onSelect: (deviceId, deviceName) {
          ref.read(printerProvider.notifier).saveSettings(
                ref.read(printerProvider).settings.copyWith(
                      bluetoothDeviceId: deviceId,
                      bluetoothDeviceName: deviceName,
                    ),
              );
        },
      ),
    );
  }

  /// نمایش dialog کشف پرینتر در شبکه
  Future<void> _discoverWifiPrinters() async {
    // استخراج subnet از IP جاری
    final ip = _ipCtrl.text.trim();
    final subnet =
        ip.contains('.') ? ip.split('.').take(3).join('.') : '192.168.1';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WifiDiscoveryDialog(
        subnet: subnet,
        onSelect: (foundIp) {
          _ipCtrl.text = foundIp;
        },
      ),
    );
  }

  Future<void> _saveSettings() async {
    final current = ref.read(printerProvider).settings;
    await ref.read(printerProvider.notifier).saveSettings(
          current.copyWith(
            wifiIp: _ipCtrl.text.trim(),
            wifiPort: int.tryParse(_portCtrl.text) ?? 9100,
            storeName: _storeNameCtrl.text.trim(),
            storePhone: _storePhoneCtrl.text.trim(),
            storeAddress: _storeAddressCtrl.text.trim(),
          ),
        );
  }

  Future<void> _discoverUsbPrinters() async {
    List<String> printers;
    try {
      printers = await UsbPrinterService.listWindowsPrinters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطا در کشف پرینتر: $e',
              style: const TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    if (!mounted) return;
    if (printers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('پرینتری یافت نشد. مطمئن شوید پرینتر نصب و روشن است.',
            style: TextStyle(fontFamily: 'Vazirmatn')),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('پرینترهای ویندوز',
              style: TextStyle(
                  fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: printers
                  .map((name) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.print_outlined,
                            color: AppColors.primary),
                        title: Text(name,
                            style: const TextStyle(fontFamily: 'Vazirmatn')),
                        onTap: () {
                          ref.read(printerProvider.notifier).saveSettings(
                                ref
                                    .read(printerProvider)
                                    .settings
                                    .copyWith(usbPrinterName: name),
                              );
                          Navigator.of(dialogCtx)
                              .pop(); // use dialogCtx not context
                        },
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text(AppStrings.close,
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _saveSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(AppStrings.operationSuccess,
            style: TextStyle(fontFamily: 'Vazirmatn')),
        backgroundColor: AppColors.success,
      ));
    }
  }
}

// ─── Dialog اسکن پرینترهای بلوتوث ───────────────────────────────────────────

class _BluetoothScanDialog extends StatefulWidget {
  final void Function(String deviceId, String deviceName) onSelect;

  const _BluetoothScanDialog({required this.onSelect});

  @override
  State<_BluetoothScanDialog> createState() => _BluetoothScanDialogState();
}

class _BluetoothScanDialogState extends State<_BluetoothScanDialog> {
  List<Map<String, String>> _devices = [];
  bool _scanning = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    setState(() {
      _scanning = true;
      _devices = [];
      _error = null;
    });
    BluetoothPrinterService.scanDevices().listen(
      (devices) {
        if (mounted) setState(() => _devices = devices);
      },
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _scanning = false;
            _error = 'بلوتوث در دسترس نیست یا مجوز داده نشده';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('اسکن پرینتر بلوتوث',
            style: TextStyle(
                fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 300,
          child: _error != null
              ? Text(_error!,
                  style: const TextStyle(
                      fontFamily: 'Vazirmatn', color: AppColors.error))
              : _scanning && _devices.isEmpty
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('در حال اسکن بلوتوث (۵ ثانیه)...',
                            style: TextStyle(fontFamily: 'Vazirmatn')),
                      ],
                    )
                  : _devices.isEmpty
                      ? const Text(
                          'هیچ دستگاهی یافت نشد.\nمطمئن شوید پرینتر روشن و در حالت Pairing است.',
                          style: TextStyle(fontFamily: 'Vazirmatn'),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _devices
                              .map((d) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.bluetooth,
                                        color: AppColors.primary),
                                    title: Text(d['name'] ?? '',
                                        style: const TextStyle(
                                            fontFamily: 'Vazirmatn',
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text(d['rssi'] ?? '',
                                        style: const TextStyle(
                                            fontFamily: 'Vazirmatn',
                                            fontSize: 11)),
                                    onTap: () {
                                      widget.onSelect(d['id']!, d['name']!);
                                      Navigator.of(context).pop();
                                    },
                                  ))
                              .toList(),
                        ),
        ),
        actions: [
          if (!_scanning || _devices.isNotEmpty)
            TextButton(
              onPressed: _startScan,
              child: const Text('اسکن مجدد',
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.close,
                style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ],
      ),
    );
  }
}

// ─── Dialog کشف پرینتر WiFi در شبکه محلی ────────────────────────────────────

class _WifiDiscoveryDialog extends StatefulWidget {
  final String subnet;
  final ValueChanged<String> onSelect;

  const _WifiDiscoveryDialog({
    required this.subnet,
    required this.onSelect,
  });

  @override
  State<_WifiDiscoveryDialog> createState() => _WifiDiscoveryDialogState();
}

class _WifiDiscoveryDialogState extends State<_WifiDiscoveryDialog> {
  List<String> _found = [];
  bool _scanning = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _found = [];
    });
    try {
      final result =
          await WiFiPrinterService.discoverPrinters(subnet: widget.subnet);
      if (mounted) {
        setState(() {
          _found = result;
          _scanning = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('کشف پرینتر در شبکه',
            style: TextStyle(
                fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 300,
          child: _scanning
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('در حال اسکن شبکه...',
                        style: TextStyle(fontFamily: 'Vazirmatn')),
                  ],
                )
              : _found.isEmpty
                  ? const Text(
                      'پرینتری در شبکه یافت نشد.\nمطمئن شوید پرینتر روشن و متصل به همین شبکه است.',
                      style: TextStyle(fontFamily: 'Vazirmatn'),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_found.length} پرینتر یافت شد:',
                            style: const TextStyle(
                                fontFamily: 'Vazirmatn',
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                        const SizedBox(height: 8),
                        ..._found.map((ip) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.print_outlined,
                                  color: AppColors.primary),
                              title: Text(ip,
                                  style: const TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontWeight: FontWeight.w600)),
                              onTap: () {
                                widget.onSelect(ip);
                                Navigator.of(context).pop();
                              },
                            )),
                      ],
                    ),
        ),
        actions: [
          if (!_scanning)
            TextButton(
              onPressed: _scan,
              child: const Text('اسکن مجدد',
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.close,
                style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
