import '../../../inventory/data/models/product_model.dart';

/// Model item keranjang belanja kasir
class CartItemModel {
  final ProductModel product;
  final int qty;

  const CartItemModel({
    required this.product,
    required this.qty,
  });

  double get subtotal => product.hargaJual * qty;
  double get subtotalModal => product.hargaBeli * qty;
  double get profitMargin => subtotal - subtotalModal;

  CartItemModel copyWith({
    ProductModel? product,
    int? qty,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      qty: qty ?? this.qty,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_produk': product.idProduk,
      'sku_barcode': product.skuBarcode,
      'nama_produk': product.namaProduk,
      'harga_beli': product.hargaBeli,
      'harga_jual': product.hargaJual,
      'qty': qty,
      'subtotal': subtotal,
      'subtotal_modal': subtotalModal,
      'profit_margin': profitMargin,
    };
  }

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      product: ProductModel(
        idProduk: map['id_produk'] as String? ?? '',
        skuBarcode: map['sku_barcode'] as String? ?? '',
        namaProduk: map['nama_produk'] as String? ?? '',
        kategori: '',
        hargaBeli: (map['harga_beli'] as num?)?.toDouble() ?? 0.0,
        hargaJual: (map['harga_jual'] as num?)?.toDouble() ?? 0.0,
        stokSaatIni: 0,
        reorderPoint: 0,
        updatedAt: DateTime.now(),
      ),
      qty: (map['qty'] as num?)?.toInt() ?? 1,
    );
  }
}
