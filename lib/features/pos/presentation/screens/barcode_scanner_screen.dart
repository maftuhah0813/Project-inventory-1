
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../inventory/data/models/product_model.dart';
import '../../../inventory/data/providers/product_provider.dart';

/// Mode operasional scanner
enum ScannerMode {
  /// Mode Kasir: scan berulang-ulang tanpa menutup kamera,
  /// otomatis tambah ke keranjang.
  continuousKasir,

  /// Mode Tunggal: scan 1 barcode lalu langsung pop
  /// dan return string barcode (untuk input master produk).
  singleScan,
}

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final ScannerMode mode;
  final void Function(ProductModel product)? onProductScanned;
  final int initialCartCount;
  final double initialCartTotal;

  const BarcodeScannerScreen({
    super.key,
    this.mode = ScannerMode.continuousKasir,
    this.onProductScanned,
    this.initialCartCount = 0,
    this.initialCartTotal = 0.0,
  });

  /// Helper untuk membuka scanner dalam mode singleScan
  /// dan mengembalikan nilai barcode String.
  static Future<String?> scanSingleBarcode(BuildContext context) async {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const BarcodeScannerScreen(mode: ScannerMode.singleScan),
      ),
    );
  }

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState
    extends ConsumerState<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  // State
  bool _isTorchOn = false;
  CameraFacing _currentFacing = CameraFacing.back;
  bool _showManualInput = false;

  final TextEditingController _manualTextController =
      TextEditingController();

  // Terakhir kali di-scan (pencegah duplikasi barcode)
  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  // Feedback produk terakhir yang di-scan
  ProductModel? _lastScannedProduct;
  String? _unrecognizedBarcode;

  int _sessionScanCount = 0;
  late int _liveCartCount;
  late double _liveCartTotal;

  @override
  void initState() {
    super.initState();

    _liveCartCount = widget.initialCartCount;
    _liveCartTotal = widget.initialCartTotal;

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: _currentFacing,
      torchEnabled: false,
    );

    // Animasi garis laser pemindai bergerak naik-turun.
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(
      begin: 0.05,
      end: 0.95,
    ).animate(
      CurvedAnimation(
        parent: _laserAnimController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    _manualTextController.dispose();
    super.dispose();
  }

  /// Menerima hasil deteksi barcode dari kamera.
  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;

    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final code = barcode.rawValue?.trim();

      if (code != null && code.isNotEmpty) {
        _processBarcode(code);
        break;
      }
    }
  }

  /// Memproses barcode yang berhasil dipindai.
  void _processBarcode(String code) {
    final now = DateTime.now();

    // Debounce: abaikan barcode yang sama
    // jika dipindai dalam waktu kurang dari 1,4 detik.
    if (_lastScannedCode == code &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!).inMilliseconds < 1400) {
      return;
    }

    _lastScannedCode = code;
    _lastScannedTime = now;

    // Haptic dan sound feedback.
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    // Mode singleScan: langsung mengembalikan barcode.
    if (widget.mode == ScannerMode.singleScan) {
      Navigator.pop(context, code);
      return;
    }

    // Mode Kasir: cari produk dalam katalog.
    final allProducts = ref.read(productListProvider);

    final matchIndex = allProducts.indexWhere(
      (p) => p.skuBarcode == code,
    );

    setState(() {
      if (matchIndex != -1) {
        final product = allProducts[matchIndex];

        _lastScannedProduct = product;
        _unrecognizedBarcode = null;

        _sessionScanCount++;
        _liveCartCount++;
        _liveCartTotal += product.hargaJual;

        widget.onProductScanned?.call(product);
      } else {
        _lastScannedProduct = null;
        _unrecognizedBarcode = code;

        HapticFeedback.heavyImpact();
      }
    });
  }

  /// Mengaktifkan atau menonaktifkan lampu senter.
  void _toggleTorch() {
    _scannerController.toggleTorch();

    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  /// Mengganti kamera depan dan belakang.
  void _switchCamera() {
    _scannerController.switchCamera();

    setState(() {
      _currentFacing = _currentFacing == CameraFacing.back
          ? CameraFacing.front
          : CameraFacing.back;
    });
  }

  @override
  Widget build(BuildContext context) {
    const windowWidth = 280.0;
    const windowHeight = 160.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Camera Preview.
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,

            // API mobile_scanner 7.5.0:
            // errorBuilder hanya menerima context dan error.
            errorBuilder: (context, error) {
              return _buildCameraFallback(error);
            },
          ),

          // 2. Custom Viewfinder Overlay.
          Positioned.fill(
            child: _ScannerOverlayLayout(
              windowWidth: windowWidth,
              windowHeight: windowHeight,
              laserAnimation: _laserAnimation,
            ),
          ),

          // 3. Top Action Bar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.mode == ScannerMode.continuousKasir
                              ? 'Pemindai Barcode Kasir'
                              : 'Pindai Barcode Produk',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          widget.mode == ScannerMode.continuousKasir
                              ? 'Arahkan kamera ke kemasan barang'
                              : 'Scan untuk mengisi kode SKU otomatis',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: Icon(
                        _isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _isTorchOn ? Colors.amber : Colors.white,
                      ),
                      tooltip: 'Lampu Senter',
                      onPressed: _toggleTorch,
                    ),
                  ),

                  const SizedBox(width: 8),

                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: const Icon(
                        Icons.flip_camera_ios_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Balik Kamera',
                      onPressed: _switchCamera,
                    ),
                  ),

                  const SizedBox(width: 8),

                  CircleAvatar(
                    backgroundColor: _showManualInput
                        ? AppColors.accent
                        : Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: const Icon(
                        Icons.keyboard_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Ketik Barcode Manual',
                      onPressed: () {
                        setState(() {
                          _showManualInput = !_showManualInput;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Panel Input Barcode Manual.
          if (_showManualInput)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: _buildManualInputCard(),
            ),

          // 5. Floating Bottom Result Card.
          Positioned(
            left: 16,
            right: 16,
            bottom: widget.mode == ScannerMode.continuousKasir
                ? 90
                : 24,
            child: _buildScanFeedbackCard(),
          ),

          // 6. Bottom Kasir Bar.
          if (widget.mode == ScannerMode.continuousKasir)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildKasirBottomBar(),
            ),
        ],
      ),
    );
  }

  /// Tampilan jika kamera error atau tidak tersedia.
  Widget _buildCameraFallback(MobileScannerException error) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.amber,
              size: 56,
            ),

            const SizedBox(height: 16),

            const Text(
              'Pratinjau Kamera Tidak Aktif',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Kamera fisik tidak terdeteksi atau sedang berjalan di Desktop/Simulator.\nAnda dapat menggunakan mode Input Barcode Manual di bawah ini:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.keyboard_rounded),
              label: const Text('Buka Input Barcode Manual'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                setState(() {
                  _showManualInput = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Card Input Barcode Manual dan Tombol Uji Cepat.
  Widget _buildManualInputCard() {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.barcode_reader,
                  color: AppColors.accent,
                  size: 20,
                ),

                const SizedBox(width: 8),

                const Text(
                  'Input Barcode / Reader USB',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),

                const Spacer(),

                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _showManualInput = false;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualTextController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: 'Ketik SKU (contoh: 899123456001)...',
                      hintStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _processBarcode(val.trim());
                        _manualTextController.clear();
                      }
                    },
                  ),
                ),

                const SizedBox(width: 8),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final text = _manualTextController.text.trim();

                    if (text.isNotEmpty) {
                      _processBarcode(text);
                      _manualTextController.clear();
                    }
                  },
                  child: const Text(
                    'Kirim',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const Text(
              'Uji Cepat Barcode Katalog:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),

            const SizedBox(height: 6),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickTestChip('899123456001', 'Minyak 2L'),
                  const SizedBox(width: 6),
                  _buildQuickTestChip('99000001', 'Beras Curah'),
                  const SizedBox(width: 6),
                  _buildQuickTestChip('99000002', 'Telur Curah'),
                  const SizedBox(width: 6),
                  _buildQuickTestChip('899999919012', 'Gula Pasir'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chip untuk pengujian barcode katalog.
  Widget _buildQuickTestChip(String sku, String label) {
    return ActionChip(
      backgroundColor: Colors.white.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      label: Text(
        '$label ($sku)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
      onPressed: () {
        _processBarcode(sku);
      },
    );
  }

  /// Card Feedback saat barcode berhasil dikenali
  /// atau tidak terdaftar.
  Widget _buildScanFeedbackCard() {
    if (_lastScannedProduct != null) {
      final p = _lastScannedProduct!;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.namaProduk,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '${CurrencyFormatter.format(p.hargaJual)} • SKU: ${p.skuBarcode}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent),
              ),
              child: const Text(
                '+1 Masuk',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_unrecognizedBarcode != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.ewsCritical,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.ewsCritical,
              size: 24,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Barcode Tidak Terdaftar!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),

                  Text(
                    'Kode: $_unrecognizedBarcode',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Bottom Bar Kasir: menampilkan total barang dan tombol selesai.
  Widget _buildKasirBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.accent,
                        size: 16,
                      ),

                      const SizedBox(width: 6),

                      Text(
                        '$_liveCartCount Item di Keranjang',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  Text(
                    CurrencyFormatter.format(_liveCartTotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            ElevatedButton.icon(
              icon: const Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
              ),
              label: Text(
                _sessionScanCount > 0
                    ? 'Selesai ($_sessionScanCount Baru)'
                    : 'Selesai Scan',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Viewfinder Overlay dengan sudut hijau
/// dan garis laser pemindai.
class _ScannerOverlayLayout extends StatelessWidget {
  final double windowWidth;
  final double windowHeight;
  final Animation<double> laserAnimation;

  const _ScannerOverlayLayout({
    required this.windowWidth,
    required this.windowHeight,
    required this.laserAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        final left = (screenWidth - windowWidth) / 2;
        final top = (screenHeight - windowHeight) / 2 - 40;

        return Stack(
          children: [
            // Gelap di luar jendela pemindaian.
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.55),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),

                  Positioned(
                    left: left,
                    top: top,
                    width: windowWidth,
                    height: windowHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4 Sudut Bidik Hijau.
            Positioned(
              left: left,
              top: top,
              width: windowWidth,
              height: windowHeight,
              child: CustomPaint(
                painter: _ViewfinderBracketPainter(
                  color: AppColors.accent,
                ),
              ),
            ),

            // Garis Laser Pemindai Bergerak.
            Positioned(
              left: left + 8,
              top: top,
              width: windowWidth - 16,
              height: windowHeight,
              child: AnimatedBuilder(
                animation: laserAnimation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(
                        top: windowHeight * laserAnimation.value,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accent.withValues(alpha: 0.1),
                                AppColors.accent,
                                AppColors.accent.withValues(alpha: 0.1),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Hint Text di bawah jendela.
            Positioned(
              left: 20,
              right: 20,
              top: top + windowHeight + 16,
              child: const Center(
                child: Text(
                  'Arahkan barcode produk ke dalam kotak pemindai',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Painter untuk 4 sudut siku-siku jendela bidik.
class _ViewfinderBracketPainter extends CustomPainter {
  final Color color;

  const _ViewfinderBracketPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 22.0;
    const radius = 12.0;

    final path = Path();

    // Kiri Atas.
    path.moveTo(0, cornerLength);
    path.lineTo(0, radius);
    path.arcToPoint(
      const Offset(radius, 0),
      radius: const Radius.circular(radius),
    );
    path.lineTo(cornerLength, 0);

    // Kanan Atas.
    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width - radius, 0);
    path.arcToPoint(
      Offset(size.width, radius),
      radius: const Radius.circular(radius),
    );
    path.lineTo(size.width, cornerLength);

    // Kiri Bawah.
    path.moveTo(0, size.height - cornerLength);
    path.lineTo(0, size.height - radius);
    path.arcToPoint(
      Offset(radius, size.height),
      radius: const Radius.circular(radius),
    );
    path.lineTo(cornerLength, size.height);

    // Kanan Bawah.
    path.moveTo(size.width - cornerLength, size.height);
    path.lineTo(size.width - radius, size.height);
    path.arcToPoint(
      Offset(size.width, size.height - radius),
      radius: const Radius.circular(radius),
    );
    path.lineTo(size.width, size.height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
