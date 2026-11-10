import 'cart_item_model.dart';

/// Model dokumen Transaksi Penjualan Kasir
class TransactionModel {
  final String idTransaksi;
  final String noStruk;
  final String kasirId;
  final String namaKasir;
  final DateTime tanggalWaktu;
  final double subtotal;
  final double totalBayar;
  final double uangDiterima;
  final double uangKembalian;
  final double totalModal;
  final double marginKeuntungan;
  final String status; // 'completed' atau 'pending_sync'
  final List<CartItemModel> items;

  const TransactionModel({
    required this.idTransaksi,
    required this.noStruk,
    required this.kasirId,
    required this.namaKasir,
    required this.tanggalWaktu,
    required this.subtotal,
    required this.totalBayar,
    required this.uangDiterima,
    required this.uangKembalian,
    required this.totalModal,
    required this.marginKeuntungan,
    this.status = 'completed',
    required this.items,
  });

  bool get isOfflinePending => status == 'pending_sync';

  Map<String, dynamic> toMap() {
    return {
      'id_transaksi': idTransaksi,
      'no_struk': noStruk,
      'kasir_id': kasirId,
      'nama_kasir': namaKasir,
      'tanggal_waktu': tanggalWaktu.toIso8601String(),
      'subtotal': subtotal,
      'total_bayar': totalBayar,
      'uang_diterima': uangDiterima,
      'uang_kembalian': uangKembalian,
      'total_modal': totalModal,
      'margin_keuntungan': marginKeuntungan,
      'status': status,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      idTransaksi: id,
      noStruk: map['no_struk'] as String? ?? '',
      kasirId: map['kasir_id'] as String? ?? '',
      namaKasir: map['nama_kasir'] as String? ?? 'Kasir',
      tanggalWaktu: map['tanggal_waktu'] != null
          ? DateTime.tryParse(map['tanggal_waktu'].toString()) ?? DateTime.now()
          : DateTime.now(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      totalBayar: (map['total_bayar'] as num?)?.toDouble() ?? 0.0,
      uangDiterima: (map['uang_diterima'] as num?)?.toDouble() ?? 0.0,
      uangKembalian: (map['uang_kembalian'] as num?)?.toDouble() ?? 0.0,
      totalModal: (map['total_modal'] as num?)?.toDouble() ?? 0.0,
      marginKeuntungan: (map['margin_keuntungan'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'completed',
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => CartItemModel.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
