
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/firestore_service.dart';
import '../../../inventory/data/models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/transaction_model.dart';

// Katalog produk referensi untuk seed transaksi
final _prodMinyak = ProductModel(
  idProduk: 'prod-001',
  skuBarcode: '899123456001',
  namaProduk: 'Minyak Goreng 2L',
  kategori: 'Sembako',
  hargaBeli: 28000,
  hargaJual: 34000,
  stokSaatIni: 24,
  reorderPoint: 10,
  updatedAt: DateTime.now(),
);

final _prodBeras = ProductModel(
  idProduk: 'prod-002',
  skuBarcode: '99000001',
  namaProduk: 'Beras Curah Rojo Lele (kg)',
  kategori: 'Curah',
  hargaBeli: 12500,
  hargaJual: 14500,
  stokSaatIni: 4,
  reorderPoint: 15,
  isCustomBarcode: true,
  updatedAt: DateTime.now(),
);

final _prodTelur = ProductModel(
  idProduk: 'prod-003',
  skuBarcode: '99000002',
  namaProduk: 'Telur Ayam Ras (kg)',
  kategori: 'Curah',
  hargaBeli: 24000,
  hargaJual: 28000,
  stokSaatIni: 8,
  reorderPoint: 12,
  isCustomBarcode: true,
  updatedAt: DateTime.now(),
);

final _prodGula = ProductModel(
  idProduk: 'prod-004',
  skuBarcode: '899999919012',
  namaProduk: 'Gula Pasir Kristal 1kg',
  kategori: 'Sembako',
  hargaBeli: 15000,
  hargaJual: 17500,
  stokSaatIni: 30,
  reorderPoint: 10,
  updatedAt: DateTime.now(),
);

final _prodMie = ProductModel(
  idProduk: 'prod-005',
  skuBarcode: '899886611001',
  namaProduk: 'Mie Instan Goreng',
  kategori: 'Makanan',
  hargaBeli: 2600,
  hargaJual: 3100,
  stokSaatIni: 60,
  reorderPoint: 20,
  updatedAt: DateTime.now(),
);

final _prodKecap = ProductModel(
  idProduk: 'prod-006',
  skuBarcode: '899275311022',
  namaProduk: 'Kecap Manis Refill 550ml',
  kategori: 'Bumbu',
  hargaBeli: 18000,
  hargaJual: 21500,
  stokSaatIni: 15,
  reorderPoint: 7,
  updatedAt: DateTime.now(),
);

/// Data transaksi demo untuk tampilan awal dashboard.
final List<TransactionModel> _initialTransactions = [
  TransactionModel(
    idTransaksi: 'trx-001',
    noStruk: 'TRX-20261102-0001',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(hours: 3, minutes: 15),
    ),
    subtotal: 68000,
    totalBayar: 68000,
    uangDiterima: 100000,
    uangKembalian: 32000,
    totalModal: 56000,
    marginKeuntungan: 12000,
    status: 'completed',
    items: [CartItemModel(product: _prodMinyak, qty: 2)],
  ),
  TransactionModel(
    idTransaksi: 'trx-002',
    noStruk: 'TRX-20261102-0002',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(hours: 2, minutes: 40),
    ),
    subtotal: 71500,
    totalBayar: 71500,
    uangDiterima: 100000,
    uangKembalian: 28500,
    totalModal: 60500,
    marginKeuntungan: 11000,
    status: 'completed',
    items: [
      CartItemModel(product: _prodBeras, qty: 3),
      CartItemModel(product: _prodTelur, qty: 1),
    ],
  ),
  TransactionModel(
    idTransaksi: 'trx-003',
    noStruk: 'TRX-20261102-0003',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(hours: 1, minutes: 10),
    ),
    subtotal: 35000,
    totalBayar: 35000,
    uangDiterima: 50000,
    uangKembalian: 15000,
    totalModal: 30000,
    marginKeuntungan: 5000,
    status: 'completed',
    items: [CartItemModel(product: _prodGula, qty: 2)],
  ),
  TransactionModel(
    idTransaksi: 'trx-004',
    noStruk: 'TRX-20261102-0004',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(minutes: 25),
    ),
    subtotal: 46200,
    totalBayar: 46200,
    uangDiterima: 50000,
    uangKembalian: 3800,
    totalModal: 39000,
    marginKeuntungan: 7200,
    status: 'completed',
    items: [
      CartItemModel(product: _prodMie, qty: 8),
      CartItemModel(product: _prodKecap, qty: 1),
    ],
  ),
  TransactionModel(
    idTransaksi: 'trx-005',
    noStruk: 'TRX-20261101-0001',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(days: 1, hours: 4),
    ),
    subtotal: 102000,
    totalBayar: 102000,
    uangDiterima: 120000,
    uangKembalian: 18000,
    totalModal: 84000,
    marginKeuntungan: 18000,
    status: 'completed',
    items: [CartItemModel(product: _prodMinyak, qty: 3)],
  ),
  TransactionModel(
    idTransaksi: 'trx-006',
    noStruk: 'TRX-20261101-0002',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(days: 1, hours: 2),
    ),
    subtotal: 52500,
    totalBayar: 52500,
    uangDiterima: 60000,
    uangKembalian: 7500,
    totalModal: 45000,
    marginKeuntungan: 7500,
    status: 'completed',
    items: [CartItemModel(product: _prodGula, qty: 3)],
  ),
  TransactionModel(
    idTransaksi: 'trx-007',
    noStruk: 'TRX-20261031-0001',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(days: 2, hours: 5),
    ),
    subtotal: 84000,
    totalBayar: 84000,
    uangDiterima: 100000,
    uangKembalian: 16000,
    totalModal: 72000,
    marginKeuntungan: 12000,
    status: 'completed',
    items: [CartItemModel(product: _prodTelur, qty: 3)],
  ),
  TransactionModel(
    idTransaksi: 'trx-008',
    noStruk: 'TRX-20261031-0002',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(days: 2, hours: 2),
    ),
    subtotal: 62000,
    totalBayar: 62000,
    uangDiterima: 70000,
    uangKembalian: 8000,
    totalModal: 52000,
    marginKeuntungan: 10000,
    status: 'completed',
    items: [CartItemModel(product: _prodMie, qty: 20)],
  ),
  TransactionModel(
    idTransaksi: 'trx-009',
    noStruk: 'TRX-20261030-0001',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(days: 3, hours: 4),
    ),
    subtotal: 116000,
    totalBayar: 116000,
    uangDiterima: 120000,
    uangKembalian: 4000,
    totalModal: 98000,
    marginKeuntungan: 18000,
    status: 'completed',
    items: [
      CartItemModel(product: _prodMinyak, qty: 2),
      CartItemModel(product: _prodTelur, qty: 1),
      CartItemModel(product: _prodKecap, qty: 1),
    ],
  ),
  TransactionModel(
    idTransaksi: 'trx-010',
    noStruk: 'TRX-20261029-0001',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(days: 4, hours: 6),
    ),
    subtotal: 145000,
    totalBayar: 145000,
    uangDiterima: 150000,
    uangKembalian: 5000,
    totalModal: 125000,
    marginKeuntungan: 20000,
    status: 'completed',
    items: [CartItemModel(product: _prodBeras, qty: 10)],
  ),
  TransactionModel(
    idTransaksi: 'trx-011',
    noStruk: 'TRX-20261029-0002',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(days: 4, hours: 3),
    ),
    subtotal: 34000,
    totalBayar: 34000,
    uangDiterima: 50000,
    uangKembalian: 16000,
    totalModal: 28000,
    marginKeuntungan: 6000,
    status: 'completed',
    items: [CartItemModel(product: _prodMinyak, qty: 1)],
  ),
  TransactionModel(
    idTransaksi: 'trx-012',
    noStruk: 'TRX-20261028-0001',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(days: 5, hours: 4),
    ),
    subtotal: 93000,
    totalBayar: 93000,
    uangDiterima: 100000,
    uangKembalian: 7000,
    totalModal: 78000,
    marginKeuntungan: 15000,
    status: 'completed',
    items: [
      CartItemModel(product: _prodMie, qty: 10),
      CartItemModel(product: _prodMinyak, qty: 1),
      CartItemModel(product: _prodTelur, qty: 1),
    ],
  ),
  TransactionModel(
    idTransaksi: 'trx-013',
    noStruk: 'TRX-20261027-0001',
    kasirId: 'kasir-01',
    namaKasir: 'Siti Rahma',
    tanggalWaktu: DateTime.now().subtract(
      const Duration(days: 6, hours: 5),
    ),
    subtotal: 104000,
    totalBayar: 104000,
    uangDiterima: 110000,
    uangKembalian: 6000,
    totalModal: 88500,
    marginKeuntungan: 15500,
    status: 'completed',
    items: [
      CartItemModel(product: _prodBeras, qty: 5),
      CartItemModel(product: _prodGula, qty: 1),
      CartItemModel(product: _prodKecap, qty: 1),
    ],
  ),
];

/// Mengelola histori transaksi dan checkout.
class TransactionListNotifier extends StateNotifier<List<TransactionModel>> {
  final FirestoreService _firestoreService;
  StreamSubscription<List<TransactionModel>>? _subscription;

  TransactionListNotifier(this._firestoreService)
      : super(_initialTransactions) {
    _subscription = _firestoreService.getTransactions().listen(
      (transactions) {
        // Pertahankan data demo selama belum ada transaksi nyata.
        if (transactions.isNotEmpty) {
          state = transactions;
        }
      },
      onError: (error) {
        print('Gagal membaca histori transaksi: $error');
      },
    );
  }

  /// Menyimpan transaksi sekaligus mengurangi stok secara atomik.
  Future<void> recordTransaction(TransactionModel transaction) async {
    final itemQuantities = <String, int>{};

    // Gabungkan kuantitas jika produk yang sama muncul lebih dari sekali.
    for (final item in transaction.items) {
      final idProduk = item.product.idProduk;

      itemQuantities.update(
        idProduk,
        (qty) => qty + item.qty,
        ifAbsent: () => item.qty,
      );
    }

    await _firestoreService.checkoutTransaction(
      idTransaksi: transaction.idTransaksi,
      transactionData: transaction.toMap(),
      itemQuantities: itemQuantities,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider utama transaksi penjualan.
final transactionListProvider =
    StateNotifierProvider<TransactionListNotifier, List<TransactionModel>>(
  (ref) {
    return TransactionListNotifier(FirestoreService());
  },
);

/// Total omzet penjualan.
final totalRevenueProvider = Provider<double>((ref) {
  final transactions = ref.watch(transactionListProvider);
  return transactions.fold(
    0.0,
    (sum, trx) => sum + trx.totalBayar,
  );
});

/// Total keuntungan.
final totalProfitProvider = Provider<double>((ref) {
  final transactions = ref.watch(transactionListProvider);
  return transactions.fold(
    0.0,
    (sum, trx) => sum + trx.marginKeuntungan,
  );
});

/// Total modal / HPP.
final totalCogsProvider = Provider<double>((ref) {
  final transactions = ref.watch(transactionListProvider);
  return transactions.fold(
    0.0,
    (sum, trx) => sum + trx.totalModal,
  );
});
