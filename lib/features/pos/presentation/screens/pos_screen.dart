
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

  String _searchQuery = '';
  bool _isScannerActive = false;
  final bool _isOnline = true;

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    super.dispose();
  }

  // =====================================================
  // BARCODE SCANNER
  // =====================================================

  void _handleBarcodeScanned(String rawBarcode) {
    final code = rawBarcode.trim();

    if (code.isEmpty) return;

    final catalog = ref.read(productListProvider);

    final matchIndex = catalog.indexWhere(
      (product) => product.skuBarcode == code,
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
                child: Text(
                  'Berhasil scan: ${product.namaProduk}',
                ),
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

  void _openCameraScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          mode: ScannerMode.continuousKasir,
          initialCartCount: _cart.fold(
            0,
            (sum, item) => sum + item.qty,
          ),
          initialCartTotal: _totalPrice,
          onProductScanned: (product) {
            _addToCart(product);
          },
        ),
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

  void _addToCart(ProductModel product) {
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
  // CHECKOUT DAN PEMBAYARAN FIRESTORE
  // =====================================================

  void _openCheckoutDialog() {
    if (_cart.isEmpty) return;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Pembayaran
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pembayaran Kasir',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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

                  // Total Tagihan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Tagihan',
                        style: TextStyle(fontSize: 15),
                      ),
                      Text(
                        CurrencyFormatter.format(total),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Input Uang Tunai
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

                  // Tombol Nominal Cepat
                  Wrap(
                    spacing: 8,
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

                  // Informasi Kembalian
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
                          isSufficient
                              ? 'Kembalian'
                              : 'Uang Kurang',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSufficient
                                ? AppColors.accentHover
                                : AppColors.ewsCritical,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(change.abs()),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSufficient
                                ? AppColors.accentHover
                                : AppColors.ewsCritical,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tombol Checkout
                  ElevatedButton(
                    onPressed: (isSufficient && !isProcessing)
                        ? () async {
                            // Mencegah checkout berulang.
                            setModalState(() {
                              isProcessing = true;
                            });

                            // Salin keranjang sebelum proses async.
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

                            // Membuat objek transaksi.
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
                              // Menyimpan transaksi dan mengurangi
                              // stok melalui Firestore secara atomik.
                              await ref
                                  .read(
                                    transactionListProvider.notifier,
                                  )
                                  .recordTransaction(newTrx);

                              if (!mounted || !ctx.mounted) return;

                              // Tutup dialog pembayaran.
                              Navigator.pop(ctx);

                              // Kosongkan keranjang setelah berhasil.
                              setState(() {
                                _cart.clear();
                              });

                              // Tampilkan dialog keberhasilan.
                              _showSuccessDialog(total, change);
                            } catch (e) {
                              if (!mounted || !ctx.mounted) return;

                              // Aktifkan kembali tombol checkout.
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
                        : const Text(
                            'Selesaikan & Simpan Transaksi',
                          ),
                  ),
                ],
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
  // TAMPILAN UTAMA POS
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(productListProvider);

    final filteredCatalog = catalog.where((prod) {
      final query = _searchQuery.toLowerCase();

      return prod.namaProduk.toLowerCase().contains(query) ||
          prod.skuBarcode.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,

      // =================================================
      // APP BAR
      // =================================================

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
          // Navigasi ke Master Produk
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Kelola Master Produk',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductManagementScreen(),
                ),
              );
            },
          ),

          // Indikator jaringan
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
                  _isOnline ? 'Online' : 'Offline Mode',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Logout
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
              );
            },
          ),
        ],
      ),

      // =================================================
      // BODY
      // =================================================

      body: Column(
        children: [
          // =============================================
          // SEARCH DAN SCANNER
          // =============================================

          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: AppStrings.searchProductHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
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

                const SizedBox(width: 8),

                // Scanner Kamera
                IconButton.filled(
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Buka Kamera Pemindai Barcode',
                  onPressed: _openCameraScanner,
                ),

                const SizedBox(width: 6),

                // Input Barcode Manual
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
                  ),
                  tooltip: _isScannerActive
                      ? 'Tutup Input Manual'
                      : 'Input Barcode Manual / USB',
                  onPressed: () {
                    setState(() {
                      _isScannerActive = !_isScannerActive;
                    });
                  },
                ),
              ],
            ),
          ),

          // =============================================
          // INPUT BARCODE MANUAL
          // =============================================

          if (_isScannerActive)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              color: const Color(0xFF0F172A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),

                      const SizedBox(width: 8),

                      const Text(
                        'Pemindai Barcode Kasir',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),

                      const Spacer(),

                      TextButton.icon(
                        icon: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        label: const Text(
                          'Buka Kamera',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: _openCameraScanner,
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 20,
                        ),
                        tooltip: 'Tutup Scanner',
                        onPressed: () {
                          setState(() {
                            _isScannerActive = false;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Input Barcode Manual / USB
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualBarcodeController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Ketik / scan barcode (contoh: 99000001)...',
                            hintStyle: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.barcode_reader,
                              color: AppColors.accent,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(
                              alpha: 0.1,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (val) {
                            _handleBarcodeScanned(val);
                            _manualBarcodeController.clear();
                          },
                        ),
                      ),

                      const SizedBox(width: 10),

                      ElevatedButton.icon(
                        icon: const Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 18,
                        ),
                        label: const Text('Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          _handleBarcodeScanned(
                            _manualBarcodeController.text,
                          );

                          _manualBarcodeController.clear();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Quick Test Scans
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

                        ActionChip(
                          backgroundColor: Colors.white.withValues(
                            alpha: 0.15,
                          ),
                          label: const Text(
                            '99000001 (Beras Curah)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          onPressed: () {
                            _handleBarcodeScanned('99000001');
                          },
                        ),

                        const SizedBox(width: 6),

                        ActionChip(
                          backgroundColor: Colors.white.withValues(
                            alpha: 0.15,
                          ),
                          label: const Text(
                            '99000002 (Telur Curah)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          onPressed: () {
                            _handleBarcodeScanned('99000002');
                          },
                        ),

                        const SizedBox(width: 6),

                        ActionChip(
                          backgroundColor: Colors.white.withValues(
                            alpha: 0.15,
                          ),
                          label: const Text(
                            '899123456001 (Minyak)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          onPressed: () {
                            _handleBarcodeScanned('899123456001');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // =============================================
          // KATALOG PRODUK DAN KERANJANG
          // =============================================

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // =======================================
                // KATALOG PRODUK
                // =======================================

                Expanded(
                  flex: 3,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredCatalog.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final prod = filteredCatalog[i];

                      return Card(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),

                          leading: CircleAvatar(
                            backgroundColor: prod.isCustomBarcode
                                ? Colors.purple.shade50
                                : AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
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

                          title: Text(
                            prod.namaProduk,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),

                          subtitle: Text(
                            'SKU: ${prod.skuBarcode} • Stok: ${prod.stokSaatIni}',
                            style: TextStyle(
                              fontSize: 12,
                              color: prod.stokSaatIni <=
                                      prod.reorderPoint
                                  ? AppColors.ewsCritical
                                  : AppColors.textSecondary,
                            ),
                          ),

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                CurrencyFormatter.format(
                                  prod.hargaJual,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),

                              const SizedBox(width: 8),

                              IconButton(
                                icon: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  color: AppColors.accent,
                                ),
                                onPressed: () {
                                  _addToCart(prod);
                                },
                              ),
                            ],
                          ),

                          onTap: () {
                            _addToCart(prod);
                          },
                        ),
                      );
                    },
                  ),
                ),

                // =======================================
                // PANEL KERANJANG
                // =======================================

                Container(
                  width: 320,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: BorderSide(
                        color: AppColors.border,
                      ),
                    ),
                  ),

                  child: Column(
                    children: [
                      // Header Keranjang
                      Container(
                        padding: const EdgeInsets.all(14),
                        color: AppColors.primary.withValues(
                          alpha: 0.04,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Keranjang Belanja',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),

                            Text(
                              '${_cart.length} Item',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Daftar Keranjang
                      Expanded(
                        child: _cart.isEmpty
                            ? const Center(
                                child: Text(
                                  AppStrings.cartEmpty,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _cart.length,
                                itemBuilder: (ctx, i) {
                                  final item = _cart[i];

                                  return ListTile(
                                    dense: true,

                                    title: Text(
                                      item.product.namaProduk,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    subtitle: Text(
                                      '${CurrencyFormatter.format(item.product.hargaJual)} x ${item.qty}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                      ),
                                    ),

                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _updateQuantity(i, -1);
                                          },
                                        ),

                                        Text(
                                          '${item.qty}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _updateQuantity(i, 1);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),

                      // =================================
                      // FOOTER CHECKOUT
                      // =================================

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.05,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),

                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Tagihan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),

                                Text(
                                  CurrencyFormatter.format(
                                    _totalPrice,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            ElevatedButton(
                              onPressed: _cart.isEmpty
                                  ? null
                                  : _openCheckoutDialog,
                              child: const Text(
                                'Bayar Sekarang',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
