
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../inventory/data/models/product_model.dart';
import '../../../inventory/data/providers/product_provider.dart';
import '../../../inventory/presentation/screens/product_management_screen.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/providers/transaction_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import 'barcode_scanner_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final List<CartItemModel> _cart = [];

  final TextEditingController _manualBarcodeController =
      TextEditingController();

  final FocusNode _manualBarcodeFocusNode = FocusNode();

  String _searchQuery = '';
  bool _isScannerActive = false;
  final bool _isOnline = true;

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    _manualBarcodeFocusNode.dispose();
    super.dispose();
  }

  // =====================================================
  // BARCODE SCANNER
  // =====================================================

  void _handleBarcodeScanned(String rawBarcode) {
    final code = rawBarcode.trim();

    if (code.isEmpty) {
      _showMessage('Masukkan barcode terlebih dahulu.');
      return;
    }

    final catalog = ref.read(productListProvider);

    final matchIndex = catalog.indexWhere(
      (product) => product.skuBarcode.trim() == code,
    );

    if (matchIndex != -1) {
      final product = catalog[matchIndex];

      _addToCart(product);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Berhasil scan: ${product.namaProduk}'),
              ),
            ],
          ),
          backgroundColor: AppColors.accent,
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Barcode "$code" tidak terdaftar di sistem',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.ewsCritical,
          duration: const Duration(milliseconds: 2000),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openCameraScanner() async {
    FocusScope.of(context).unfocus();
    _manualBarcodeFocusNode.unfocus();

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (scannerContext) => BarcodeScannerScreen(
          mode: ScannerMode.continuousKasir,
          initialCartCount: _totalQuantity,
          initialCartTotal: _totalPrice,
          onProductScanned: (product) {
            if (!mounted) return;
            _addToCart(product);
          },
        ),
      ),
    );

    if (!mounted) return;
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

  // =====================================================
  // PERHITUNGAN KERANJANG
  // =====================================================

  double get _totalPrice {
    return _cart.fold(
      0.0,
      (sum, item) => sum + item.subtotal,
    );
  }

  int get _totalQuantity {
    return _cart.fold(
      0,
      (sum, item) => sum + item.qty,
    );
  }

  void _addToCart(ProductModel product) {
    if (!mounted) return;

    setState(() {
      final index = _cart.indexWhere(
        (item) => item.product.idProduk == product.idProduk,
      );

      if (index != -1) {
        _cart[index] = _cart[index].copyWith(
          qty: _cart[index].qty + 1,
        );
      } else {
        _cart.add(
          CartItemModel(
            product: product,
            qty: 1,
          ),
        );
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.namaProduk} ditambahkan'),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _updateQuantity(int index, int delta) {
    if (index < 0 || index >= _cart.length) return;

    setState(() {
      final newQty = _cart[index].qty + delta;

      if (newQty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index] = _cart[index].copyWith(
          qty: newQty,
        );
      }
    });
  }

  // =====================================================
  // CHECKOUT DAN PEMBAYARAN
  // =====================================================

  void _openCheckoutDialog() {
    if (_cart.isEmpty) return;

    FocusScope.of(context).unfocus();

    final total = _totalPrice;
    double cashReceived = total;

    final textController = TextEditingController(
      text: total.toInt().toString(),
    );

    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final change = cashReceived - total;
            final isSufficient = change >= 0;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Pembayaran Kasir',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: isProcessing
                              ? null
                              : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Tagihan',
                          style: TextStyle(fontSize: 15),
                        ),
                        Flexible(
                          child: Text(
                            CurrencyFormatter.format(total),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      keyboardType: TextInputType.number,
                      enabled: !isProcessing,
                      decoration: const InputDecoration(
                        labelText: 'Uang Tunai Diterima',
                        prefixText: 'Rp ',
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          cashReceived = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _QuickAmountChip(
                          label: 'Uang Pas',
                          onTap: () {
                            if (isProcessing) return;
                            setModalState(() {
                              cashReceived = total;
                              textController.text =
                                  total.toInt().toString();
                            });
                          },
                        ),
                        _QuickAmountChip(
                          label: 'Rp 50.000',
                          onTap: () {
                            if (isProcessing) return;
                            setModalState(() {
                              cashReceived = 50000;
                              textController.text = '50000';
                            });
                          },
                        ),
                        _QuickAmountChip(
                          label: 'Rp 100.000',
                          onTap: () {
                            if (isProcessing) return;
                            setModalState(() {
                              cashReceived = 100000;
                              textController.text = '100000';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSufficient
                            ? AppColors.accent.withValues(alpha: 0.1)
                            : AppColors.ewsCritical.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSufficient ? 'Kembalian' : 'Uang Kurang',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSufficient
                                  ? AppColors.accentHover
                                  : AppColors.ewsCritical,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              CurrencyFormatter.format(change.abs()),
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSufficient
                                    ? AppColors.accentHover
                                    : AppColors.ewsCritical,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (isSufficient && !isProcessing)
                            ? () async {
                                setModalState(() {
                                  isProcessing = true;
                                });

                                final cartSnapshot =
                                    List<CartItemModel>.from(_cart);

                                final now = DateTime.now();

                                final strukId =
                                    'TRX-${DateFormat('yyyyMMdd').format(now)}-'
                                    '${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

                                final totalModal = cartSnapshot.fold(
                                  0.0,
                                  (sum, item) => sum + item.subtotalModal,
                                );

                                final totalLaba = total - totalModal;

                                final newTrx = TransactionModel(
                                  idTransaksi:
                                      'trx-${now.millisecondsSinceEpoch}',
                                  noStruk: strukId,
                                  kasirId: 'kasir-01',
                                  namaKasir: 'Siti Rahma',
                                  tanggalWaktu: now,
                                  subtotal: total,
                                  totalBayar: total,
                                  uangDiterima: cashReceived,
                                  uangKembalian: change,
                                  totalModal: totalModal,
                                  marginKeuntungan: totalLaba,
                                  status: 'completed',
                                  items: cartSnapshot,
                                );

                                try {
                                  await ref
                                      .read(
                                        transactionListProvider.notifier,
                                      )
                                      .recordTransaction(newTrx);

                                  if (!mounted || !ctx.mounted) return;

                                  Navigator.pop(ctx);

                                  setState(() {
                                    _cart.clear();
                                  });

                                  _showSuccessDialog(total, change);
                                } catch (e) {
                                  if (!mounted || !ctx.mounted) return;

                                  setModalState(() {
                                    isProcessing = false;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Transaksi gagal: ${e.toString()}',
                                      ),
                                      backgroundColor: AppColors.ewsCritical,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Selesaikan & Simpan Transaksi'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      textController.dispose();
    });
  }

  // =====================================================
  // DIALOG TRANSAKSI BERHASIL
  // =====================================================

  void _showSuccessDialog(double total, double change) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Transaksi Berhasil!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${CurrencyFormatter.format(total)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Kembalian: ${CurrencyFormatter.format(change)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Cetak Struk'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Mengirim struk ke printer Bluetooth...',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      child: const Text('Selesai'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =====================================================
  // WIDGET PENCARIAN DAN SCANNER
  // =====================================================

  Widget _buildSearchAndScanner({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 7 : 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: AppStrings.searchProductHint,
                prefixIcon: const Icon(Icons.search_rounded),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: compact ? 8 : 12,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: Size(
                compact ? 40 : 48,
                compact ? 40 : 48,
              ),
            ),
            tooltip: 'Buka Kamera Pemindai Barcode',
            onPressed: _openCameraScanner,
          ),
          const SizedBox(width: 3),
          IconButton.filled(
            icon: Icon(
              _isScannerActive
                  ? Icons.keyboard_hide_rounded
                  : Icons.keyboard_rounded,
            ),
            style: IconButton.styleFrom(
              backgroundColor: _isScannerActive
                  ? AppColors.ewsCritical
                  : AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: Size(
                compact ? 40 : 48,
                compact ? 40 : 48,
              ),
            ),
            tooltip: _isScannerActive
                ? 'Tutup Input Manual'
                : 'Input Barcode Manual / USB',
            onPressed: () {
              FocusScope.of(context).unfocus();

              setState(() {
                _isScannerActive = !_isScannerActive;
              });

              if (!_isScannerActive) {
                _manualBarcodeController.clear();
                _manualBarcodeFocusNode.unfocus();
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _isScannerActive) {
                    _manualBarcodeFocusNode.requestFocus();
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManualScanner({required bool compact}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 5 : 12,
      ),
      color: const Color(0xFF0F172A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact)
            Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Pemindai Barcode Kasir',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Buka Kamera',
                  icon: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.accent,
                  ),
                  onPressed: _openCameraScanner,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Tutup Scanner',
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    _manualBarcodeFocusNode.unfocus();
                    setState(() {
                      _isScannerActive = false;
                    });
                  },
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualBarcodeController,
                  focusNode: _manualBarcodeFocusNode,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ketik / scan barcode...',
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.barcode_reader,
                      color: AppColors.accent,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: compact ? 7 : 10,
                    ),
                  ),
                  onSubmitted: (val) {
                    _handleBarcodeScanned(val);
                    _manualBarcodeController.clear();

                    if (mounted && _isScannerActive) {
                      _manualBarcodeFocusNode.requestFocus();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: compact ? 42 : 48,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.add_shopping_cart_rounded,
                    size: 17,
                  ),
                  label: const Text('Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    _handleBarcodeScanned(
                      _manualBarcodeController.text,
                    );
                    _manualBarcodeController.clear();

                    if (mounted && _isScannerActive) {
                      _manualBarcodeFocusNode.requestFocus();
                    }
                  },
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text(
                    'Uji Barcode: ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  _buildTestBarcodeChip(
                    '99000001 (Beras Curah)',
                    '99000001',
                  ),
                  const SizedBox(width: 6),
                  _buildTestBarcodeChip(
                    '99000002 (Telur Curah)',
                    '99000002',
                  ),
                  const SizedBox(width: 6),
                  _buildTestBarcodeChip(
                    '899123456001 (Minyak)',
                    '899123456001',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTestBarcodeChip(String label, String code) {
    return ActionChip(
      backgroundColor: Colors.white.withValues(alpha: 0.15),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
        ),
      ),
      onPressed: () {
        _handleBarcodeScanned(code);
      },
    );
  }

  // =====================================================
  // KATALOG PRODUK
  // =====================================================

  Widget _buildProductCatalog(List<ProductModel> products) {
    if (products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 10),
            Text(
              'Produk tidak ditemukan',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 7),
      itemBuilder: (ctx, i) {
        final prod = products[i];

        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _addToCart(prod),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: prod.isCustomBarcode
                        ? Colors.purple.shade50
                        : AppColors.primary.withValues(alpha: 0.08),
                    child: Icon(
                      prod.isCustomBarcode
                          ? Icons.scale_rounded
                          : Icons.inventory_2_outlined,
                      color: prod.isCustomBarcode
                          ? Colors.purple
                          : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prod.namaProduk,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'SKU: ${prod.skuBarcode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Stok: ${prod.stokSaatIni}',
                          style: TextStyle(
                            fontSize: 11,
                            color: prod.stokSaatIni <= prod.reorderPoint
                                ? AppColors.ewsCritical
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(prod.hargaJual),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Tambah ke keranjang',
                    icon: const Icon(
                      Icons.add_shopping_cart_rounded,
                      size: 19,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                    onPressed: () => _addToCart(prod),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // PANEL KERANJANG
  // =====================================================

  Widget _buildCartPanel({
    required bool compact,
    required bool shortHeight,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: compact
            ? const Border(
                top: BorderSide(color: AppColors.border),
              )
            : const Border(
                left: BorderSide(color: AppColors.border),
              ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: shortHeight ? 5 : 10,
            ),
            color: AppColors.primary.withValues(alpha: 0.04),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Keranjang Belanja',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_totalQuantity Barang',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 30,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 5),
                        Text(
                          AppStrings.cartEmpty,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemCount: _cart.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                    ),
                    itemBuilder: (ctx, i) {
                      final item = _cart[i];

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: shortHeight ? 2 : 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.namaProduk,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${CurrencyFormatter.format(item.product.hargaJual)} x ${item.qty}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 3),
                            _QuantityButton(
                              icon: Icons.remove,
                              onTap: () => _updateQuantity(i, -1),
                            ),
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${item.qty}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            _QuantityButton(
                              icon: Icons.add,
                              onTap: () => _updateQuantity(i, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.all(shortHeight ? 7 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total Tagihan',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        CurrencyFormatter.format(_totalPrice),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: shortHeight ? 14 : 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: shortHeight ? 5 : 9),
                SizedBox(
                  width: double.infinity,
                  height: shortHeight ? 36 : 44,
                  child: ElevatedButton.icon(
                    onPressed: _cart.isEmpty ? null : _openCheckoutDialog,
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text('Bayar Sekarang'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // TAMPILAN UTAMA POS
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(productListProvider);

    final filteredCatalog = catalog.where((prod) {
      final query = _searchQuery.toLowerCase();

      return prod.namaProduk.toLowerCase().contains(query) ||
          prod.skuBarcode.toLowerCase().contains(query);
    }).toList();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWideScreen = screenWidth >= 800;

    final keyboardOpen =
        MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.point_of_sale_rounded,
              color: AppColors.accent,
              size: 22,
            ),
            SizedBox(width: 8),
            Text('Maftuhah POS'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Kelola Master Produk',
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductManagementScreen(),
                ),
              );
            },
          ),
          if (screenWidth >= 420)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _isOnline
                    ? AppColors.accent
                    : AppColors.ewsWarning,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                _isOnline ? Icons.wifi : Icons.wifi_off,
                color: _isOnline ? AppColors.accent : AppColors.ewsWarning,
                size: 20,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;

          final compactMode =
              keyboardOpen || availableHeight < 500;

          final shortHeight = availableHeight < 390;

          return Column(
            children: [
              _buildSearchAndScanner(compact: compactMode),

              if (_isScannerActive)
                _buildManualScanner(compact: compactMode),

              Expanded(
                child: isWideScreen
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildProductCatalog(filteredCatalog),
                          ),
                          SizedBox(
                            width: 330,
                            child: _buildCartPanel(
                              compact: false,
                              shortHeight: shortHeight,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            flex: keyboardOpen ? 3 : 5,
                            child: _buildProductCatalog(filteredCatalog),
                          ),
                          Expanded(
                            flex: keyboardOpen ? 2 : 4,
                            child: _buildCartPanel(
                              compact: true,
                              shortHeight: shortHeight,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =======================================================
// TOMBOL JUMLAH BARANG
// =======================================================

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(
        minWidth: 30,
        minHeight: 30,
      ),
      padding: EdgeInsets.zero,
      iconSize: 18,
      color: AppColors.primary,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}

// =======================================================
// KOMPONEN TOMBOL NOMINAL CEPAT
// =======================================================

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: onTap,
    );
  }
}
