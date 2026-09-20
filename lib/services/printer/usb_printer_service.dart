import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'printer_service.dart';
import 'escpos_builder.dart';
import '../../domain/models/invoice.dart';

/// پرینتر USB از طریق Windows Printer API
/// از PowerShell برای شناسایی و پرینت استفاده می‌کند
class UsbPrinterService extends PrinterService {
  final String printerName;
  bool _connected = false;

  UsbPrinterService({required this.printerName});

  @override
  bool get isConnected => _connected;

  @override
  Future<bool> connect() async {
    if (printerName.isEmpty) return false;
    if (!Platform.isWindows) return false;
    try {
      // PowerShell برای بررسی وجود پرینتر (wmic در Windows 11 منسوخ شده)
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'$p = Get-Printer -Name $args[0] -ErrorAction SilentlyContinue; '
              r'if ($null -ne $p) { $p.Name }',
          printerName,
        ],
        stdoutEncoding: const SystemEncoding(),
      );
      _connected = result.stdout.toString().trim().isNotEmpty;
      return _connected;
    } catch (_) {
      _connected = false;
      return false;
    }
  }

  @override
  Future<void> printReceipt(Invoice invoice, {
    required String storeName,
    required String storePhone,
    required String storeAddress,
  }) async {
    final bytes = await EscPosBuilder.buildReceiptBytes(
      invoice: invoice,
      storeName: storeName,
      storePhone: storePhone,
      storeAddress: storeAddress,
    );
    await _sendRaw(bytes);
  }

  /// ارسال داده خام ESC/POS به پرینتر از طریق پورت مستقیم
  Future<void> _sendRaw(List<int> bytes) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('پرینت USB فقط در ویندوز پشتیبانی می‌شود');
    }
    if (!_connected && !await connect()) {
      throw StateError('پرینتر USB در ویندوز پیدا نشد');
    }

    final temp = await getTemporaryDirectory();
    final file = File('${temp.path}\\receipt_${DateTime.now().millisecondsSinceEpoch}.bin');
    await file.writeAsBytes(bytes);

    try {
      // دریافت نام پورت پرینتر از PowerShell
      final portResult = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'$p = Get-Printer -Name $args[0] -ErrorAction SilentlyContinue; '
              r'if ($null -ne $p) { $p.PortName }',
          printerName,
        ],
        stdoutEncoding: const SystemEncoding(),
      );
      final portName = portResult.stdout.toString().trim();

      if (portName.isNotEmpty) {
        // ارسال مستقیم به پورت (USB001، COM1 و غیره)
        final result = await Process.run(
          'cmd',
          ['/c', 'copy', '/b', file.path, r'\\.\' + portName],
        );
        if (result.exitCode != 0) {
          throw ProcessException(
            'cmd',
            ['/c', 'copy', '/b'],
            result.stderr.toString(),
            result.exitCode,
          );
        }
      } else {
        // fallback: ارسال از طریق PowerShell با System.Printing
        await _sendViaPowerShell(file.path);
      }
    } finally {
      await file.delete().catchError((_) => file);
    }
  }

  /// ارسال از طریق .NET System.Printing (برای پرینترهای شبکه یا مدرن)
  Future<void> _sendViaPowerShell(String filePath) async {
    final script = r'''
param([string]$PrinterName, [string]$FilePath)
Add-Type -AssemblyName System.Printing
$ErrorActionPreference = "Stop"
$ps = New-Object System.Printing.LocalPrintServer
$pq = $ps.GetPrintQueue($PrinterName)
$job = $pq.AddJob("ESC/POS")
$stream = $job.JobStream
$bytes = [System.IO.File]::ReadAllBytes($FilePath)
$stream.Write($bytes, 0, $bytes.Length)
$stream.Close()
''';

    final temp = await getTemporaryDirectory();
    final scriptFile = File('${temp.path}\\ps_print_${DateTime.now().millisecondsSinceEpoch}.ps1');
    await scriptFile.writeAsString(script, encoding: const SystemEncoding());

    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
        '-PrinterName',
        printerName,
        '-FilePath',
        filePath,
      ],
    );
    await scriptFile.delete().catchError((_) => scriptFile);
    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell',
        ['-File', scriptFile.path],
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }

  Future<void> printRaw(List<int> bytes) => _sendRaw(bytes);

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  /// لیست تمام پرینترهای نصب‌شده در ویندوز (از PowerShell)
  static Future<List<String>> listWindowsPrinters() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run(
        'powershell',
        ['-Command', 'Get-Printer | Select-Object -ExpandProperty Name'],
        stdoutEncoding: const SystemEncoding(),
      );
      return result.stdout
          .toString()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
