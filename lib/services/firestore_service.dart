
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/inventory/data/models/product_model.dart';
import '../features/pos/data/models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Referensi koleksi produk
  CollectionReference<Map<String, dynamic>> get products =>
      _firestore.collection('products');

  // Referensi koleksi transaksi
  CollectionReference<Map<String, dynamic>> get transactions =>
      _firestore.collection('transactions');

  // Mengambil semua produk secara real-time
  Stream<List<ProductModel>> getProducts() {
    return products.orderBy('nama_produk').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProductModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
  // Mengambil histori transaksi secara real-time
Stream<List<TransactionModel>> getTransactions() {
  return transactions
      .orderBy('tanggal_waktu', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      return TransactionModel.fromMap(doc.data(), doc.id);
    }).toList();
  });
  }
  // Menambahkan produk
  Future<void> addProduct(ProductModel product) async {
    final docRef = products.doc(product.idProduk);

    print('MULAI SIMPAN PRODUK');
    print('Project Firebase: ${_firestore.app.options.projectId}');
    print('ID dokumen: ${docRef.id}');
    print('Data produk: ${product.toMap()}');

    try {
      await docRef.set(product.toMap());

      print('BERHASIL SIMPAN PRODUK: ${docRef.id}');

      final savedDoc = await docRef.get();

      print('Dokumen ditemukan setelah simpan: ${savedDoc.exists}');
      print('Data dari Firestore: ${savedDoc.data()}');
    } catch (e, stackTrace) {
      print('GAGAL SIMPAN PRODUK: $e');
      print(stackTrace);
      rethrow;
    }
  }

  // Memperbarui produk
  Future<void> updateProduct(ProductModel product) async {
    await products.doc(product.idProduk).update(product.toMap());
  }

  // Menghapus produk
  Future<void> deleteProduct(String idProduk) async {
    await products.doc(idProduk).delete();
  }

  // Mengatur stok produk
  Future<void> updateStock({
    required String idProduk,
    required int stokBaru,
  }) async {
    await products.doc(idProduk).update({
      'stok_saat_ini': stokBaru,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Checkout atomik:
  /// 1. Memvalidasi stok terbaru dari Firestore.
  /// 2. Menyimpan transaksi.
  /// 3. Mengurangi stok semua produk.
  ///
  /// Jika salah satu operasi gagal, seluruh perubahan dibatalkan.
  Future<void> checkoutTransaction({
    required String idTransaksi,
    required Map<String, dynamic> transactionData,
    required Map<String, int> itemQuantities,
  }) async {
    if (itemQuantities.isEmpty) {
      throw Exception('Keranjang belanja kosong.');
    }

    for (final entry in itemQuantities.entries) {
      if (entry.value <= 0) {
        throw Exception('Jumlah pembelian produk tidak valid.');
      }
    }

    final transactionRef = transactions.doc(idTransaksi);

    // Siapkan referensi dokumen produk
    final productRefs = itemQuantities.keys.map(
      (idProduk) => products.doc(idProduk),
    ).toList();

    await _firestore.runTransaction((transaction) async {
      // Semua pembacaan harus dilakukan sebelum penulisan.
      final productSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final productRef in productRefs) {
        final snapshot = await transaction.get(productRef);
        productSnapshots.add(snapshot);
      }

      // Validasi seluruh stok terbaru.
      final stockUpdates = <String, int>{};

      for (var i = 0; i < productSnapshots.length; i++) {
        final snapshot = productSnapshots[i];
        final idProduk = itemQuantities.keys.elementAt(i);
        final qtyDibeli = itemQuantities[idProduk]!;

        if (!snapshot.exists) {
          throw Exception('Produk $idProduk tidak ditemukan di Firestore.');
        }

        final data = snapshot.data()!;
        final stokSekarang = (data['stok_saat_ini'] as num?)?.toInt();

        if (stokSekarang == null) {
          throw Exception('Data stok produk $idProduk tidak valid.');
        }

        if (stokSekarang < qtyDibeli) {
          final namaProduk = data['nama_produk'] ?? idProduk;

          throw Exception(
            'Stok $namaProduk tidak mencukupi. '
            'Stok tersedia: $stokSekarang, '
            'jumlah pembelian: $qtyDibeli.',
          );
        }

        stockUpdates[idProduk] = stokSekarang - qtyDibeli;
      }

      // Semua validasi berhasil. Mulai penulisan.
      for (final entry in stockUpdates.entries) {
        transaction.update(products.doc(entry.key), {
          'stok_saat_ini': entry.value,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Simpan transaksi dengan ID yang sudah dibuat.
      transaction.set(transactionRef, transactionData);
    });
  }
}
