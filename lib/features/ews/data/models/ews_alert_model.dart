/// Model data representasi Peringatan Dini Stok Kritis (Early Warning System)
class EwsAlertModel {
  final String idAlert;
  final String idProduk;
  final String namaProduk;
  final String skuBarcode;
  final int stokSaatIni;
  final int reorderPoint;
  final String level; // 'critical' atau 'warning'
  final String status; // 'unread' atau 'acknowledged'
  final DateTime createdAt;

  const EwsAlertModel({
    required this.idAlert,
    required this.idProduk,
    required this.namaProduk,
    required this.skuBarcode,
    required this.stokSaatIni,
    required this.reorderPoint,
    required this.level,
    this.status = 'unread',
    required this.createdAt,
  });

  bool get isCritical => level == 'critical';
  bool get isUnread => status == 'unread';

  Map<String, dynamic> toMap() {
    return {
      'id_alert': idAlert,
      'id_produk': idProduk,
      'nama_produk': namaProduk,
      'sku_barcode': skuBarcode,
      'stok_saat_ini': stokSaatIni,
      'reorder_point': reorderPoint,
      'level': level,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory EwsAlertModel.fromMap(Map<String, dynamic> map, String id) {
    return EwsAlertModel(
      idAlert: id,
      idProduk: map['id_produk'] as String? ?? '',
      namaProduk: map['nama_produk'] as String? ?? '',
      skuBarcode: map['sku_barcode'] as String? ?? '',
      stokSaatIni: (map['stok_saat_ini'] as num?)?.toInt() ?? 0,
      reorderPoint: (map['reorder_point'] as num?)?.toInt() ?? 0,
      level: map['level'] as String? ?? 'warning',
      status: map['status'] as String? ?? 'unread',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
