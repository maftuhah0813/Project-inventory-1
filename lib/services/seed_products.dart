import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/inventory/data/models/product_model.dart';

class SeedProducts {
  static Future<void> uploadInitialProducts(
    List<ProductModel> initialProducts,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final productsCollection = firestore.collection('products');

    // Jangan unggah ulang jika koleksi sudah berisi produk.
    final existingProducts = await productsCollection.limit(1).get();

    if (existingProducts.docs.isNotEmpty) {
      print('Koleksi products sudah berisi data.');
      return;
    }

    final batch = firestore.batch();

    for (final product in initialProducts) {
      final docRef = productsCollection.doc(product.idProduk);
      batch.set(docRef, product.toMap());
    }

    await batch.commit();

    print('Enam produk awal berhasil diunggah ke Firestore.');
  }
}
