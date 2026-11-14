
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../inventory/data/models/product_model.dart';
import '../../../inventory/data/providers/product_provider.dart';

enum ScannerMode {
  continuousKasir,
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

  static Future<String?> scanSingleBarcode(
    BuildContext context,
  ) async {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(
          mode: ScannerMode.singleScan,
        ),
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
  late final MobileScannerController _scannerController;
  late final AnimationController _laserAnimController;
  late final Animation<double> _laserAnimation;

  final TextEditingController _manualTextController =
      TextEditingController();

  final FocusNode _manualFocusNode = FocusNode();

  bool _isTorchOn = false;
  bool _isSwitchingCamera = false;
  bool _isProcessing = false;
  bool _showManualInput = false;

  CameraFacing _currentFacing = CameraFacing.back;

  String? _lastScannedCode;
  DateTime? _lastScannedTime;

  ProductModel? _lastScannedProduct;
  String? _unrecognizedBarcode;

  int _sessionScanCount = 0;

  late int _liveCartCount;
  late double _liveCartTotal;

  bool get _isKasir =>
      widget.mode == ScannerMode.continuousKasir;

  @override
  void initState() {
    super.initState();

    _liveCartCount = widget.initialCartCount;
    _liveCartTotal = widget.initialCartTotal;

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      autoStart: true,
    );

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
    _manualFocusNode.dispose();
    super.dispose();
  }

  // ============================================================
  // PROSES BARCODE KAMERA
  // ============================================================

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _showManualInput) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();

      if (code != null && code.isNotEmpty) {
        _processCameraBarcode(code);
        break;
      }
    }
  }

  void _processCameraBarcode(String code) {
    if (!mounted || _isProcessing) return;

    final now = DateTime.now();

    if (_lastScannedCode == code &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!).inMilliseconds < 1400) {
      return;
    }

    _lastScannedCode = code;
    _lastScannedTime = now;

    _handleBarcodeResult(code);
  }

  // ============================================================
  // PROSES BARCODE MANUAL
  // ============================================================

  void _processManualBarcode(String code) {
    final value = code.trim();

    if (!mounted || value.isEmpty || _isProcessing) return;

    if (!_isKasir) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context, value);
      return;
    }

    _lastScannedCode = null;
    _lastScannedTime = null;

    _handleBarcodeResult(value);
  }

  // ============================================================
  // HASIL BARCODE
  // ============================================================

  void _handleBarcodeResult(String code) {
    if (!mounted || _isProcessing) return;

    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    if (!_isKasir) {
      Navigator.pop(context, code);
      return;
    }

    final allProducts = ref.read(productListProvider);

    final matchIndex = allProducts.indexWhere(
      (product) => product.skuBarcode.trim() == code,
    );

    if (matchIndex == -1) {
      HapticFeedback.heavyImpact();

      setState(() {
        _lastScannedProduct = null;
        _unrecognizedBarcode = code;
      });

      return;
    }

    final product = allProducts[matchIndex];

    setState(() {
      _lastScannedProduct = product;
      _unrecognizedBarcode = null;

      _sessionScanCount++;
      _liveCartCount++;
      _liveCartTotal += product.hargaJual;
    });

    widget.onProductScanned?.call(product);
  }

  // ============================================================
  // SENTER
  // ============================================================

  Future<void> _toggleTorch() async {
    debugPrint('Scanner: tombol senter ditekan');

    try {
      await _scannerController.toggleTorch();

      if (!mounted) return;

      setState(() {
        _isTorchOn = !_isTorchOn;
      });

      debugPrint('Scanner: status senter = $_isTorchOn');
    } catch (e) {
      debugPrint('Scanner: gagal mengaktifkan senter: $e');

      _showMessage(
        'Senter tidak tersedia pada kamera ini.',
      );
    }
  }

  // ============================================================
  // GANTI KAMERA
  // ============================================================

  Future<void> _switchCamera() async {
    if (_isSwitchingCamera) return;

    debugPrint('Scanner: tombol ganti kamera ditekan');

    setState(() {
      _isSwitchingCamera = true;
    });

    try {
      if (_isTorchOn) {
        try {
          await _scannerController.toggleTorch();
        } catch (e) {
          debugPrint('Scanner: gagal mematikan senter: $e');
        }
      }

      await _scannerController.switchCamera();

      if (!mounted) return;

      setState(() {
        _currentFacing = _currentFacing == CameraFacing.back
            ? CameraFacing.front
            : CameraFacing.back;

        _isTorchOn = false;
      });

      debugPrint('Scanner: kamera berhasil diganti');
    } catch (e) {
      debugPrint('Scanner: gagal mengganti kamera: $e');
      _showMessage('Kamera tidak dapat diganti.');
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  // ============================================================
  // INPUT MANUAL
  // ============================================================

  void _toggleManualInput() {
    debugPrint('Scanner: tombol keyboard ditekan');

    setState(() {
      _showManualInput = !_showManualInput;
    });

    if (_showManualInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showManualInput) {
          _manualFocusNode.requestFocus();
        }
      });
    } else {
      _manualFocusNode.unfocus();
      FocusScope.of(context).unfocus();
    }
  }

  void _submitManualInput() {
    final code = _manualTextController.text.trim();

    if (code.isEmpty) {
      _showMessage('Masukkan barcode terlebih dahulu.');
      return;
    }

    _processManualBarcode(code);

    if (_isKasir && mounted) {
      _manualTextController.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showManualInput) {
          _manualFocusNode.requestFocus();
        }
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ============================================================
  // BUILD UTAMA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;

          final windowWidth = (screenWidth - 48)
              .clamp(220.0, 300.0)
              .toDouble();

          const windowHeight = 155.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. PREVIEW KAMERA
              //
              // Perubahan utama:
              // IgnorePointer mencegah preview kamera mengambil
              // sentuhan tombol yang ada di atasnya.
              //
              // Deteksi barcode tetap berjalan melalui onDetect.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) {
                      return _buildCameraFallback(error);
                    },
                  ),
                ),
              ),

              // 2. OVERLAY SCANNER
              // Hanya dekorasi, tidak menerima sentuhan.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: _ScannerOverlayLayout(
                    windowWidth: windowWidth,
                    windowHeight: windowHeight,
                    laserAnimation: _laserAnimation,
                    showHint: !_showManualInput,
                  ),
                ),
              ),

              // 3. INPUT MANUAL
              if (_showManualInput)
                Positioned.fill(
                  child: SafeArea(
                    top: true,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        12,
                        112,
                        12,
                        12,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SingleChildScrollView(
                          child: _buildManualInputCard(),
                        ),
                      ),
                    ),
                  ),
                ),

              // 4. HEADER DAN TOMBOL KONTROL
              // Berada di atas preview kamera.
              SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopBar(),
                    _buildControlBar(),
                  ],
                ),
              ),

              // 5. FEEDBACK HASIL SCAN
              if (!_showManualInput)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: _isKasir ? 110 : 24,
                  child: _buildScanFeedbackCard(),
                ),

              // 6. RINGKASAN KERANJANG KASIR
              if (_isKasir)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildKasirBottomBar(),
                ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          _roundButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Kembali',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isKasir
                      ? 'Pemindai Barcode Kasir'
                      : 'Pindai Barcode Produk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isKasir
                      ? 'Arahkan kamera ke kemasan barang'
                      : 'Scan untuk mengisi kode SKU otomatis',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOMBOL KONTROL
  // ============================================================

  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _roundButton(
            icon: _isTorchOn
                ? Icons.flash_on_rounded
                : Icons.flash_off_rounded,
            color: _isTorchOn ? Colors.amber : Colors.white,
            tooltip: 'Lampu Senter',
            onPressed: _toggleTorch,
          ),
          const SizedBox(width: 8),
          _roundButton(
            icon: _isSwitchingCamera
                ? Icons.hourglass_top_rounded
                : Icons.flip_camera_ios_rounded,
            tooltip: _currentFacing == CameraFacing.back
                ? 'Ganti ke Kamera Depan'
                : 'Ganti ke Kamera Belakang',
            onPressed: _isSwitchingCamera ? null : _switchCamera,
          ),
          const SizedBox(width: 8),
          _roundButton(
            icon: _showManualInput
                ? Icons.close_rounded
                : Icons.keyboard_alt_rounded,
            color: _showManualInput
                ? AppColors.accent
                : Colors.white,
            tooltip: _showManualInput
                ? 'Tutup Input Manual'
                : 'Input Barcode Manual',
            onPressed: _toggleManualInput,
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color color = Colors.white,
    String? tooltip,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed == null
            ? null
            : () {
                debugPrint(
                  'Scanner: tombol ditekan - ${tooltip ?? "Kontrol"}',
                );
                onPressed();
              },
        child: SizedBox(
          width: 48,
          height: 48,
          child: Tooltip(
            message: tooltip ?? '',
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CAMERA FALLBACK
  // ============================================================

  Widget _buildCameraFallback(MobileScannerException error) {
    debugPrint('Scanner camera error: $error');

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
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kamera tidak tersedia atau izin kamera belum diberikan. '
              'Gunakan tombol keyboard untuk memasukkan barcode manual.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INPUT MANUAL
  // ============================================================

  Widget _buildManualInputCard() {
    return Card(
      color: const Color(0xFF1E293B),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Input Barcode / Reader USB',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleManualInput,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 19,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualTextController,
                    focusNode: _manualFocusNode,
                    autofocus: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitManualInput(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Masukkan kode barcode...',
                      hintStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitManualInput,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'Kirim',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                  _buildQuickTestChip(
                    '899123456001',
                    'Minyak 2L',
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTestChip(
                    '99000001',
                    'Beras Curah',
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTestChip(
                    '99000002',
                    'Telur Curah',
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTestChip(
                    '899999919012',
                    'Gula Pasir',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        _processManualBarcode(sku);

        if (_isKasir && mounted) {
          _manualTextController.clear();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _showManualInput) {
              _manualFocusNode.requestFocus();
            }
          });
        }
      },
    );
  }

  // ============================================================
  // FEEDBACK HASIL SCAN
  // ============================================================

  Widget _buildScanFeedbackCard() {
    if (_lastScannedProduct != null) {
      final product = _lastScannedProduct!;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.25),
              blurRadius: 14,
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.namaProduk,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${CurrencyFormatter.format(product.hargaJual)} '
                    '• SKU: ${product.skuBarcode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.accent,
                ),
              ),
              child: const Text(
                '+1 Masuk',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
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
          color: const Color(0xFF0F172A).withValues(alpha: 0.96),
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
              size: 25,
            ),
            const SizedBox(width: 10),
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
                  const SizedBox(height: 3),
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

  // ============================================================
  // BOTTOM BAR KASIR
  // ============================================================

  Widget _buildKasirBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                      Flexible(
                        child: Text(
                          '$_liveCartCount Item di Keranjang',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    CurrencyFormatter.format(_liveCartTotal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(
                Icons.check_circle_outline_rounded,
                size: 17,
              ),
              label: Text(
                _sessionScanCount > 0
                    ? 'Selesai ($_sessionScanCount)'
                    : 'Selesai Scan',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// OVERLAY SCANNER
// ================================================================

class _ScannerOverlayLayout extends StatelessWidget {
  final double windowWidth;
  final double windowHeight;
  final Animation<double> laserAnimation;
  final bool showHint;

  const _ScannerOverlayLayout({
    required this.windowWidth,
    required this.windowHeight,
    required this.laserAnimation,
    required this.showHint,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        final left = (screenWidth - windowWidth) / 2;
        final top = (screenHeight - windowHeight) / 2;

        return Stack(
          children: [
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

            // Sudut kotak scanner.
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

            // Garis laser.
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

            // Petunjuk scanner.
            if (showHint)
              Positioned(
                left: 20,
                right: 20,
                top: top + windowHeight + 15,
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

// ================================================================
// PAINTER SUDUT SCANNER
// ================================================================

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

    // Kiri atas.
    path.moveTo(0, cornerLength);
    path.lineTo(0, radius);
    path.arcToPoint(
      const Offset(radius, 0),
      radius: const Radius.circular(radius),
    );
    path.lineTo(cornerLength, 0);

    // Kanan atas.
    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width - radius, 0);
    path.arcToPoint(
      Offset(size.width, radius),
      radius: const Radius.circular(radius),
    );
    path.lineTo(size.width, cornerLength);

    // Kiri bawah.
    path.moveTo(0, size.height - cornerLength);
    path.lineTo(0, size.height - radius);
    path.arcToPoint(
      Offset(radius, size.height),
      radius: const Radius.circular(radius),
    );
    path.lineTo(cornerLength, size.height);

    // Kanan bawah.
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
  bool shouldRepaint(
    covariant _ViewfinderBracketPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}
