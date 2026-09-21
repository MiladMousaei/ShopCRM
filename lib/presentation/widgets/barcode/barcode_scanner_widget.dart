import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';

/// ویجت اسکنر بارکد:
/// - موبایل: دوربین با overlay آبی
/// - ویندوز: TextField برای اسکنر USB
class BarcodeScannerWidget extends StatefulWidget {
  final ValueChanged<String> onDetected;
  final bool autoClose;

  const BarcodeScannerWidget({
    super.key,
    required this.onDetected,
    this.autoClose = true,
  });

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  MobileScannerController? _cameraController;
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    if (!_isDesktop) {
      _cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  void _handleBarcode(String barcode) {
    if (_detected) return;
    _detected = true;

    if (!_isDesktop) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    }

    widget.onDetected(barcode);
    if (widget.autoClose && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isDesktop ? _buildDesktopScanner() : _buildMobileScanner();
  }

  Widget _buildMobileScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _cameraController!,
          onDetect: (capture) {
            final barcode = capture.barcodes.firstOrNull?.rawValue;
            if (barcode != null) _handleBarcode(barcode);
          },
        ),
        // Overlay کادر آبی
        CustomPaint(
          painter: _ScannerOverlayPainter(),
          child: const SizedBox.expand(),
        ),
        // راهنما
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'بارکد را در کادر آبی قرار دهید',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        // دکمه بستن
        Positioned(
          top: 40,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        // تورچ
        Positioned(
          top: 40,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white, size: 28),
            onPressed: () => _cameraController?.toggleTorch(),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopScanner() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.barcode_reader, size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        const Text(
          'اسکنر USB را متصل کنید و بارکد را اسکن کنید',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            letterSpacing: 3,
          ),
          decoration: InputDecoration(
            hintText: 'بارکد اینجا وارد می‌شود...',
            hintStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                if (_textController.text.isNotEmpty) {
                  _handleBarcode(_textController.text.trim());
                }
              },
            ),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) _handleBarcode(value.trim());
          },
        ),
      ],
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final cutoutSize = size.width * 0.7;
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2;
    final rect = Rect.fromLTWH(left, top, cutoutSize, cutoutSize);

    // پس‌زمینه تاریک با سوراخ وسط
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
        ..fillType = PathFillType.evenOdd,
      bgPaint,
    );

    // کادر آبی
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      borderPaint,
    );

    // گوشه‌های روشن‌تر
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const cornerLen = 24.0;
    // گوشه‌ها
    for (final corner in [
      [rect.left, rect.top, 1.0, 1.0],
      [rect.right, rect.top, -1.0, 1.0],
      [rect.left, rect.bottom, 1.0, -1.0],
      [rect.right, rect.bottom, -1.0, -1.0],
    ]) {
      final x = corner[0], y = corner[1], dx = corner[2], dy = corner[3];
      canvas.drawLine(Offset(x, y), Offset(x + dx * cornerLen, y), cornerPaint);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * cornerLen), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
