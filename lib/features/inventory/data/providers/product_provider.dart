import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/firestore_service.dart';
import '../models/product_model.dart';

/// Initial seed data untuk katalog produk Maftuhah Mobile POS
final List<ProductModel> initialProductsForSeed = [
  ProductModel(
    idProduk: 'prod-001',
    skuBarcode: '899123456001',
    namaProduk: 'Minyak Goreng 2L',
    kategori: 'Sembako',
    hargaBeli: 28000,
    hargaJual: 34000,
    stokSaatIni: 24,
    safetyStock: 5,
    leadTimeDays: 2,
    avgDailySales: 3.0,
    reorderPoint: 11,
    isCustomBarcode: false,
    updatedAt: DateTime.now(),
  ),
  ProductModel(
    idProduk: 'prod-002',
    skuBarcode: '99000001',
    namaProduk: 'Beras Curah Rojo Lele (kg)',
    kategori: 'Curah',
    hargaBeli: 12500,
    hargaJual: 14500,
    stokSaatIni: 4, // Kritis! (<= 50% ROP)
    safetyStock: 5,
    leadTimeDays: 2,
    avgDailySales: 5.0,
    reorderPoint: 15,
    isCustomBarcode: true,
    updatedAt: DateTime.now(),
  ),
  ProductModel(
    idProduk: 'prod-003',
    skuBarcode: '99000002',
    namaProduk: 'Telur Ayam Ras (kg)',
    kategori: 'Curah',
    hargaBeli: 24000,
    hargaJual: 28000,
    stokSaatIni: 8, // Waspada! (<= ROP)
    safetyStock: 4,
    leadTimeDays: 2,
    avgDailySales: 4.0,
    reorderPoint: 12,
    isCustomBarcode: true,
    updatedAt: DateTime.now(),
  ),
  ProductModel(
    idProduk: 'prod-004',
    skuBarcode: '899999919012',
    namaProduk: 'Gula Pasir Kristal 1kg',
    kategori: 'Sembako',
    hargaBeli: 15000,
    hargaJual: 17500,
    stokSaatIni: 30,
    safetyStock: 4,
    leadTimeDays: 3,
    avgDailySales: 2.0,
    reorderPoint: 10,
    isCustomBarcode: false,
    updatedAt: DateTime.now(),
  ),
  ProductModel(
    idProduk: 'prod-005',
    skuBarcode: '899886611001',
    namaProduk: 'Mie Instan Goreng',
    kategori: 'Makanan',
    hargaBeli: 2600,
    hargaJual: 3100,
    stokSaatIni: 60,
    safetyStock: 10,
    leadTimeDays: 2,
    avgDailySales: 8.0,
    reorderPoint: 26,
    isCustomBarcode: false,
    updatedAt: DateTime.now(),
  ),
  ProductModel(
    idProduk: 'prod-006',
    skuBarcode: '899275311022',
    namaProduk: 'Kecap Manis Refill 550ml',
    kategori: 'Bumbu',
    hargaBeli: 18000,
    hargaJual: 21500,
    stokSaatIni: 15,
    safetyStock: 3,
    leadTimeDays: 2,
    avgDailySales: 2.0,
    reorderPoint: 7,
    isCustomBarcode: false,
    updatedAt: DateTime.now(),
  ),
];

/// State Notifier untuk mengelola inventaris / Master Produk
class ProductListNotifier extends StateNotifier<List<ProductModel>> {
  final FirestoreService _firestoreService;
  StreamSubscription<List<ProductModel>>? _subscription;

  ProductListNotifier(this._firestoreService) : super(initialProductsForSeed) {
    _subscription = _firestoreService.getProducts().listen(
      (products) {
        if (products.isNotEmpty) {
          state = products;
        }
      },
      onError: (error) {
        print('Gagal membaca produk dari Firestore: $error (menggunakan data katalog awal)');
      },
    );
  }

  /// Tambah produk ke Firestore
  Future<void> addProduct(ProductModel product) async {
    await _firestoreService.addProduct(product);
  }

  /// Perbarui produk di Firestore
  Future<void> updateProduct(ProductModel updated) async {
    await _firestoreService.updateProduct(updated);
  }

  /// Hapus produk dari Firestore
  Future<void> deleteProduct(String idProduk) async {
    await _firestoreService.deleteProduct(idProduk);
  }

  /// Tambah atau kurangi stok
  Future<void> adjustStock(String idProduk, int qtyDelta) async {
    final index = state.indexWhere((item) => item.idProduk == idProduk);

    if (index == -1) {
      throw Exception('Produk tidak ditemukan: $idProduk');
    }

    final product = state[index];
    final newStock = (product.stokSaatIni + qtyDelta).clamp(0, 999999);

    await _firestoreService.updateStock(
      idProduk: idProduk,
      stokBaru: newStock,
    );
  }

  /// Tetapkan stok produk
  Future<void> setStock(String idProduk, int newStock) async {
    final index = state.indexWhere((item) => item.idProduk == idProduk);

    if (index == -1) {
      throw Exception('Produk tidak ditemukan: $idProduk');
    }

    await _firestoreService.updateStock(
      idProduk: idProduk,
      stokBaru: newStock < 0 ? 0 : newStock,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider Utama Master Produk
final productListProvider =
    StateNotifierProvider<ProductListNotifier, List<ProductModel>>((ref) {
  return ProductListNotifier(FirestoreService());
});

/// Filter Provider: Daftar Produk Kritis EWS (Stok <= 50% ROP)
final criticalProductsProvider = Provider<List<ProductModel>>((ref) {
  final products = ref.watch(productListProvider);
  return products.where((p) => p.isCritical).toList();
});

/// Filter Provider: Daftar Produk Waspada EWS (Stok <= ROP & > 50% ROP)
final warningProductsProvider = Provider<List<ProductModel>>((ref) {
  final products = ref.watch(productListProvider);
  return products.where((p) => p.isWarning).toList();
});

/// Provider Daftar Kategori Unik
final productCategoriesProvider = Provider<List<String>>((ref) {
  final products = ref.watch(productListProvider);
  final categories = products.map((p) => p.kategori).toSet().toList();
  categories.sort();
  return ['Semua', ...categories];
});
