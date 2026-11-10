/// Model data representasi Master Produk & Parameter Inventaris (ROP/EWS)
class ProductModel {
  final String idProduk;
  final String skuBarcode;
  final String namaProduk;
  final String kategori;
  final double hargaBeli;
  final double hargaJual;
  final int stokSaatIni;
  final int safetyStock;
  final int leadTimeDays;
  final double avgDailySales;
  final int reorderPoint;
  final bool isCustomBarcode;
  final DateTime updatedAt;

  const ProductModel({
    required this.idProduk,
    required this.skuBarcode,
    required this.namaProduk,
    required this.kategori,
    required this.hargaBeli,
    required this.hargaJual,
    required this.stokSaatIni,
    this.safetyStock = 5,
    this.leadTimeDays = 2,
    this.avgDailySales = 2.0,
    required this.reorderPoint,
    this.isCustomBarcode = false,
    required this.updatedAt,
  });

  /// Status Level Peringatan Dini (EWS)
  bool get isCritical => stokSaatIni <= (reorderPoint * 0.5);
  bool get isWarning => stokSaatIni <= reorderPoint && !isCritical;
  bool get isSafe => stokSaatIni > reorderPoint;

  String get ewsStatusLabel {
    if (isCritical) return 'KRITIS';
    if (isWarning) return 'WASPADA';
    return 'AMAN';
  }

  /// Kalkulasi batas kritis Reorder Point: ROP = (d x L) + SS
  static int calculateROP({
    required double avgDailySales,
    required int leadTimeDays,
    required int safetyStock,
  }) {
    return ((avgDailySales * leadTimeDays) + safetyStock).ceil();
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      idProduk: id,
      skuBarcode: map['sku_barcode'] as String? ?? '',
      namaProduk: map['nama_produk'] as String? ?? '',
      kategori: map['kategori'] as String? ?? 'Umum',
      hargaBeli: (map['harga_beli'] as num?)?.toDouble() ?? 0.0,
      hargaJual: (map['harga_jual'] as num?)?.toDouble() ?? 0.0,
      stokSaatIni: (map['stok_saat_ini'] as num?)?.toInt() ?? 0,
      safetyStock: (map['safety_stock'] as num?)?.toInt() ?? 5,
      leadTimeDays: (map['lead_time_days'] as num?)?.toInt() ?? 2,
      avgDailySales: (map['avg_daily_sales'] as num?)?.toDouble() ?? 2.0,
      reorderPoint: (map['reorder_point'] as num?)?.toInt() ?? 10,
      isCustomBarcode: map['is_custom_barcode'] as bool? ?? false,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_produk': idProduk,
      'sku_barcode': skuBarcode,
      'nama_produk': namaProduk,
      'kategori': kategori,
      'harga_beli': hargaBeli,
      'harga_jual': hargaJual,
      'stok_saat_ini': stokSaatIni,
      'safety_stock': safetyStock,
      'lead_time_days': leadTimeDays,
      'avg_daily_sales': avgDailySales,
      'reorder_point': reorderPoint,
      'is_custom_barcode': isCustomBarcode,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? idProduk,
    String? skuBarcode,
    String? namaProduk,
    String? kategori,
    double? hargaBeli,
    double? hargaJual,
    int? stokSaatIni,
    int? safetyStock,
    int? leadTimeDays,
    double? avgDailySales,
    int? reorderPoint,
    bool? isCustomBarcode,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      idProduk: idProduk ?? this.idProduk,
      skuBarcode: skuBarcode ?? this.skuBarcode,
      namaProduk: namaProduk ?? this.namaProduk,
      kategori: kategori ?? this.kategori,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      hargaJual: hargaJual ?? this.hargaJual,
      stokSaatIni: stokSaatIni ?? this.stokSaatIni,
      safetyStock: safetyStock ?? this.safetyStock,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      avgDailySales: avgDailySales ?? this.avgDailySales,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      isCustomBarcode: isCustomBarcode ?? this.isCustomBarcode,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          idProduk == other.idProduk;

  @override
  int get hashCode => idProduk.hashCode;
}
