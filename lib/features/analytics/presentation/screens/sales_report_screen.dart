
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../pos/data/models/transaction_model.dart';
import '../../../pos/data/providers/transaction_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HELPER TYPES
// ─────────────────────────────────────────────────────────────────────────────

class _TopProduct {
  final String namaProduk;
  final int totalQty;
  final double totalOmzet;

  _TopProduct({
    required this.namaProduk,
    required this.totalQty,
    required this.totalOmzet,
  });
}

class _DailySales {
  final DateTime date;
  final double omzet;
  final double laba;

  _DailySales({
    required this.date,
    required this.omzet,
    required this.laba,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SALES REPORT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() =>
      _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen>
    with SingleTickerProviderStateMixin {
  String _selectedPeriod = '7 Hari';
  DateTimeRange? _customRange;

  late TabController _tabController;

  int _touchedBarIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTER TRANSAKSI
  // ─────────────────────────────────────────────────────────────────────────

  List<TransactionModel> _filterTransactions(
    List<TransactionModel> all,
  ) {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Hari Ini':
        return all.where((t) {
          return t.tanggalWaktu.year == now.year &&
              t.tanggalWaktu.month == now.month &&
              t.tanggalWaktu.day == now.day;
        }).toList();

      case '7 Hari':
        final weekAgo = now.subtract(const Duration(days: 7));

        return all
            .where((t) => !t.tanggalWaktu.isBefore(weekAgo))
            .toList();

      case 'Bulan Ini':
        return all.where((t) {
          return t.tanggalWaktu.year == now.year &&
              t.tanggalWaktu.month == now.month;
        }).toList();

      case 'Kustom':
        if (_customRange == null) return all;

        final start = DateTime(
          _customRange!.start.year,
          _customRange!.start.month,
          _customRange!.start.day,
        );

        final end = DateTime(
          _customRange!.end.year,
          _customRange!.end.month,
          _customRange!.end.day,
        ).add(const Duration(days: 1));

        return all.where((t) {
          return !t.tanggalWaktu.isBefore(start) &&
              t.tanggalWaktu.isBefore(end);
        }).toList();

      default:
        return all;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HITUNG PRODUK TERLARIS
  // ─────────────────────────────────────────────────────────────────────────

  List<_TopProduct> _computeTopProducts(
    List<TransactionModel> trxList,
  ) {
    final Map<String, _TopProduct> map = {};

    for (final trx in trxList) {
      for (final item in trx.items) {
        final name = item.product.namaProduk;
        final existing = map[name];

        if (existing == null) {
          map[name] = _TopProduct(
            namaProduk: name,
            totalQty: item.qty,
            totalOmzet: item.subtotal,
          );
        } else {
          map[name] = _TopProduct(
            namaProduk: name,
            totalQty: existing.totalQty + item.qty,
            totalOmzet: existing.totalOmzet + item.subtotal,
          );
        }
      }
    }

    final list = map.values.toList();

    list.sort(
      (a, b) => b.totalOmzet.compareTo(a.totalOmzet),
    );

    return list.take(7).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HITUNG PENJUALAN HARIAN
  // ─────────────────────────────────────────────────────────────────────────

  List<_DailySales> _computeDailySales(
    List<TransactionModel> trxList,
  ) {
    final Map<String, _DailySales> map = {};

    for (final trx in trxList) {
      final dayKey = DateFormat('yyyy-MM-dd').format(
        trx.tanggalWaktu,
      );

      final existing = map[dayKey];

      if (existing == null) {
        map[dayKey] = _DailySales(
          date: DateTime(
            trx.tanggalWaktu.year,
            trx.tanggalWaktu.month,
            trx.tanggalWaktu.day,
          ),
          omzet: trx.totalBayar,
          laba: trx.marginKeuntungan,
        );
      } else {
        map[dayKey] = _DailySales(
          date: existing.date,
          omzet: existing.omzet + trx.totalBayar,
          laba: existing.laba + trx.marginKeuntungan,
        );
      }
    }

    final list = map.values.toList();

    list.sort((a, b) => a.date.compareTo(b.date));

    return list;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PILIH PERIODE KUSTOM
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(
        const Duration(days: 1),
      ),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(
              const Duration(days: 30),
            ),
            end: DateTime.now(),
          ),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _customRange = picked;
        _selectedPeriod = 'Kustom';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PENANGANAN ERROR EKSPOR PDF
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleExportPdf(
    List<TransactionModel> filteredTrx,
    List<_TopProduct> topProducts,
  ) async {
    try {
      await _exportPdfReport(filteredTrx, topProducts);
    } catch (e, stackTrace) {
      debugPrint('Gagal mengekspor PDF: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EKSPOR PDF
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _exportPdfReport(
    List<TransactionModel> filteredTrx,
    List<_TopProduct> topProducts,
  ) async {
    final pdf = pw.Document();

    final nowFormatted = DateFormat(
      'dd MMMM yyyy HH:mm',
      'id_ID',
    ).format(DateTime.now());

    final totalOmzet = filteredTrx.fold(
      0.0,
      (sum, t) => sum + t.totalBayar,
    );

    final totalModal = filteredTrx.fold(
      0.0,
      (sum, t) => sum + t.totalModal,
    );

    final totalLaba = filteredTrx.fold(
      0.0,
      (sum, t) => sum + t.marginKeuntungan,
    );

    final marginPercent = totalOmzet > 0
        ? (totalLaba / totalOmzet * 100)
        : 0.0;

    final aov = filteredTrx.isNotEmpty
        ? totalOmzet / filteredTrx.length
        : 0.0;

    String periodeLabel = _selectedPeriod;

    if (_selectedPeriod == 'Kustom' && _customRange != null) {
      periodeLabel =
          '${DateFormat('dd/MM/yyyy').format(_customRange!.start)} – '
          '${DateFormat('dd/MM/yyyy').format(_customRange!.end)}';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _buildPdfHeader(ctx),
        build: (ctx) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Laporan Rekapitulasi Penjualan & Margin',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.Text(
                      'Periode: $periodeLabel',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Tanggal Cetak: $nowFormatted',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Dicetak Oleh: Administrator Sistem',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 14),

            // RINGKASAN KEUANGAN
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(
                  color: PdfColors.grey400,
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfStatItem(
                    'Total Omzet',
                    CurrencyFormatter.format(totalOmzet),
                  ),
                  _buildPdfStatItem(
                    'Total Modal (HPP)',
                    CurrencyFormatter.format(totalModal),
                  ),
                  _buildPdfStatItem(
                    'Laba Bersih',
                    CurrencyFormatter.format(totalLaba),
                  ),
                  _buildPdfStatItem(
                    'Margin',
                    '${marginPercent.toStringAsFixed(1)}%',
                  ),
                  _buildPdfStatItem(
                    'Rata-rata Nota',
                    CurrencyFormatter.format(aov),
                  ),
                  _buildPdfStatItem(
                    'Total Transaksi',
                    '${filteredTrx.length} Nota',
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 18),

            // PRODUK TERLARIS
            if (topProducts.isNotEmpty) ...[
              pw.Text(
                'Top Produk Terlaris (Berdasarkan Omzet)',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),

              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(3.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(2.0),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.teal800,
                    ),
                    children: [
                      _buildPdfHeaderCell('#'),
                      _buildPdfHeaderCell('Nama Produk'),
                      _buildPdfHeaderCell('Total Terjual'),
                      _buildPdfHeaderCell('Omzet (Rp)'),
                    ],
                  ),
                  ...topProducts.asMap().entries.map((e) {
                    final tp = e.value;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: e.key.isEven
                            ? PdfColors.white
                            : PdfColors.grey50,
                      ),
                      children: [
                        _buildPdfDataCell(
                          '${e.key + 1}',
                          align: pw.TextAlign.center,
                        ),
                        _buildPdfDataCell(tp.namaProduk),
                        _buildPdfDataCell(
                          '${tp.totalQty} unit',
                          align: pw.TextAlign.center,
                        ),
                        _buildPdfDataCell(
                          CurrencyFormatter.format(tp.totalOmzet),
                          align: pw.TextAlign.right,
                          isBold: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 18),
            ],

            // RINCIAN TRANSAKSI
            pw.Text(
              'Rincian Transaksi Penjualan',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),

            pw.SizedBox(height: 6),

            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.6),
                1: const pw.FlexColumnWidth(2.2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(3.0),
                4: const pw.FlexColumnWidth(1.8),
                5: const pw.FlexColumnWidth(1.6),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                  ),
                  children: [
                    _buildPdfHeaderCell('No.'),
                    _buildPdfHeaderCell('No. Struk'),
                    _buildPdfHeaderCell('Waktu'),
                    _buildPdfHeaderCell('Item Belanja'),
                    _buildPdfHeaderCell('Total (Rp)'),
                    _buildPdfHeaderCell('Laba (Rp)'),
                  ],
                ),
                ...filteredTrx.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final t = entry.value;

                  final timeStr = DateFormat(
                    'dd/MM HH:mm',
                  ).format(t.tanggalWaktu);

                  final itemsSummary = t.items
                      .map(
                        (i) =>
                            '${i.product.namaProduk} (${i.qty}x)',
                      )
                      .join(', ');

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: idx.isEven
                          ? PdfColors.grey50
                          : PdfColors.white,
                    ),
                    children: [
                      _buildPdfDataCell(
                        '$idx',
                        align: pw.TextAlign.center,
                      ),
                      _buildPdfDataCell(t.noStruk),
                      _buildPdfDataCell(timeStr),
                      _buildPdfDataCell(itemsSummary),
                      _buildPdfDataCell(
                        CurrencyFormatter.format(t.totalBayar),
                        align: pw.TextAlign.right,
                        isBold: true,
                      ),
                      _buildPdfDataCell(
                        CurrencyFormatter.format(
                          t.marginKeuntungan,
                        ),
                        align: pw.TextAlign.right,
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 32),

            // TANDA TANGAN
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Kasir / Petugas Operasional,',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 48),
                    pw.Text(
                      '( ......................................... )',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Pemilik Toko (Owner / Admin),',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 48),
                    pw.Text(
                      '( Maftuhah / Administrator )',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    // BUKA DIALOG CETAK / SIMPAN PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return pdf.save();
      },
      name:
          'Laporan_Penjualan_${periodeLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PDF HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  pw.Widget _buildPdfHeader(pw.Context ctx) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TOKO MAFTUHAH POS MART',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Sistem Manajemen Kasir & Inventaris Ritel Terpadu',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(
                  color: PdfColors.teal700,
                  width: 0.8,
                ),
              ),
              child: pw.Text(
                'LAPORAN RESMI',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
            ),
          ],
        ),
        pw.Divider(
          thickness: 1.5,
          color: PdfColors.blueGrey800,
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _buildPdfStatItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 9,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPdfDataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DETAIL TRANSAKSI
  // ─────────────────────────────────────────────────────────────────────────

  void _showTransactionDetails(TransactionModel trx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            trx.noStruk,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),

                  const Divider(),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kasir: ${trx.namaKasir}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(
                          trx.tanggalWaktu,
                        ),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Rincian Belanja:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 6),

                  ...trx.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.product.namaProduk} (${item.qty}x)',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(item.subtotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 20),

                  _detailRow(
                    'Total Tagihan',
                    CurrencyFormatter.format(trx.totalBayar),
                    isBold: true,
                    valueColor: AppColors.primary,
                    fontSize: 16,
                  ),

                  _detailRow(
                    'Uang Diterima',
                    CurrencyFormatter.format(trx.uangDiterima),
                  ),

                  _detailRow(
                    'Kembalian',
                    CurrencyFormatter.format(trx.uangKembalian),
                    valueColor: AppColors.accent,
                  ),

                  _detailRow(
                    'Est. Keuntungan Bersih',
                    CurrencyFormatter.format(trx.marginKeuntungan),
                    valueColor: Colors.purple,
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.print_rounded),
                    label: const Text(
                      'Cetak Ulang Struk Transaksi',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Mengirim perintah cetak struk ke printer thermal...',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    double fontSize = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight:
                  isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allTransactions = ref.watch(transactionListProvider);

    final filtered = _filterTransactions(allTransactions);
    final topProducts = _computeTopProducts(filtered);
    final dailySales = _computeDailySales(filtered);

    final totalOmzet = filtered.fold(
      0.0,
      (sum, t) => sum + t.totalBayar,
    );

    final totalModal = filtered.fold(
      0.0,
      (sum, t) => sum + t.totalModal,
    );

    final totalLaba = filtered.fold(
      0.0,
      (sum, t) => sum + t.marginKeuntungan,
    );

    final aov = filtered.isNotEmpty
        ? totalOmzet / filtered.length
        : 0.0;

    final marginPercent = totalOmzet > 0
        ? (totalLaba / totalOmzet * 100)
        : 0.0;

    String periodeLabel = _selectedPeriod;

    if (_selectedPeriod == 'Kustom' && _customRange != null) {
      periodeLabel =
          '${DateFormat('dd/MM').format(_customRange!.start)} – '
          '${DateFormat('dd/MM/yyyy').format(_customRange!.end)}';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Laporan Finansial & Penjualan',
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard_rounded),
              text: 'Ringkasan & Grafik',
            ),
            Tab(
              icon: Icon(Icons.bar_chart_rounded),
              text: 'Analisis Mendalam',
            ),
            Tab(
              icon: Icon(Icons.receipt_long_rounded),
              text: 'Daftar Nota',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppColors.accent,
            ),
            tooltip: 'Ekspor Laporan PDF (A4)',
            onPressed: () {
              _handleExportPdf(filtered, topProducts);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRingkasanTab(
                  filtered,
                  totalOmzet,
                  totalModal,
                  totalLaba,
                  aov,
                  marginPercent,
                  topProducts,
                  dailySales,
                  periodeLabel,
                ),
                _buildGrafikTab(
                  dailySales,
                  topProducts,
                ),
                _buildTransaksiTab(filtered),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTER PERIODE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPeriodFilterBar() {
    const periods = [
      'Hari Ini',
      '7 Hari',
      'Bulan Ini',
      'Semua',
      'Kustom',
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...periods.map((period) {
              final isSelected = _selectedPeriod == period;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(period),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.grey.shade100,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) {
                    if (period == 'Kustom') {
                      _pickCustomRange();
                    } else {
                      setState(() {
                        _selectedPeriod = period;
                      });
                    }
                  },
                ),
              );
            }),

            if (_selectedPeriod == 'Kustom' &&
                _customRange != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: TextButton.icon(
                  onPressed: _pickCustomRange,
                  icon: const Icon(
                    Icons.edit_calendar_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  label: Text(
                    '${DateFormat('dd/MM').format(_customRange!.start)} – '
                    '${DateFormat('dd/MM/yy').format(_customRange!.end)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: RINGKASAN & GRAFIK
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRingkasanTab(
    List<TransactionModel> filtered,
    double totalOmzet,
    double totalModal,
    double totalLaba,
    double aov,
    double marginPercent,
    List<_TopProduct> topProducts,
    List<_DailySales> dailySales,
    String periodeLabel,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KARTU RINGKASAN
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Omzet Penjualan',
                  value: CurrencyFormatter.format(totalOmzet),
                  subtitle: '${filtered.length} Transaksi',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Laba Bersih',
                  value: CurrencyFormatter.format(totalLaba),
                  subtitle:
                      'Margin: ${marginPercent.toStringAsFixed(1)}%',
                  icon: Icons.monetization_on_outlined,
                  color: Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Total Modal (HPP)',
                  value: CurrencyFormatter.format(totalModal),
                  subtitle: 'Harga Pokok Barang',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Rata-rata Nota (AOV)',
                  value: CurrencyFormatter.format(aov),
                  subtitle: 'Per Transaksi',
                  icon: Icons.shopping_basket_outlined,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // GRAFIK PENJUALAN
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _SectionHeader(
                  icon: Icons.auto_graph_rounded,
                  title: 'Grafik Penjualan Harian ($periodeLabel)',
                ),
              ),
              Text(
                '${dailySales.length} Hari Aktif',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (dailySales.isEmpty)
            _EmptyCard(
              message:
                  'Belum ada transaksi di periode $periodeLabel',
            )
          else
            _buildDailySalesBarChart(dailySales),

          const SizedBox(height: 20),

          // BANNER EKSPOR PDF - LAYOUT DIPERBAIKI
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // INFORMASI BANNER
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ekspor Laporan PDF (A4)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Neraca, Top Produk, Rincian Nota & Tanda Tangan',
                            style: TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // TOMBOL PDF DENGAN UKURAN TERBATAS
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 120,
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        fixedSize: const Size(120, 42),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        _handleExportPdf(filtered, topProducts);
                      },
                      child: const Text(
                        'Unduh PDF',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // TOP PRODUK TERLARIS
          if (topProducts.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Top Produk Terlaris ($periodeLabel)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            ...topProducts.take(5).toList().asMap().entries.map((e) {
              return _TopProductCard(
                rank: e.key + 1,
                product: e.value,
              );
            }),

            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: ANALISIS MENDALAM
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGrafikTab(
    List<_DailySales> dailySales,
    List<_TopProduct> topProducts,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Visualisasi Penjualan Harian',
          ),

          const SizedBox(height: 12),

          if (dailySales.isEmpty)
            const _EmptyCard(
              message: 'Tidak ada data grafik untuk periode ini',
            )
          else
            _buildDailySalesBarChart(dailySales),

          const SizedBox(height: 24),

          if (topProducts.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.leaderboard_rounded,
              title: 'Ranking Omzet Seluruh Produk',
            ),

            const SizedBox(height: 12),

            _buildTopProductsHorizontalBar(topProducts),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GRAFIK BATANG PENJUALAN
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDailySalesBarChart(
    List<_DailySales> dailySales,
  ) {
    final maxOmzet = dailySales
        .map((d) => d.omzet)
        .fold(0.0, (a, b) => a > b ? a : b);

    final barGroups = dailySales.asMap().entries.map((e) {
      final i = e.key;
      final d = e.value;

      final isSelected = _touchedBarIndex == i;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: d.omzet,
            color: isSelected
                ? AppColors.accent
                : AppColors.primary,
            width: dailySales.length <= 7 ? 22 : 14,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxOmzet * 1.15,
              color: Colors.grey.shade100,
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              const SizedBox(width: 6),

              const Text(
                'Omzet Harian (Rp)',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              const Text(
                'Sentuh bar untuk detail',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxOmzet > 0
                    ? maxOmzet * 1.15
                    : 100000,

                barTouchData: BarTouchData(
                  touchCallback: (
                    FlTouchEvent event,
                    BarTouchResponse? response,
                  ) {
                    setState(() {
                      if (response == null ||
                          response.spot == null ||
                          event is FlTapUpEvent ||
                          event is FlPanEndEvent) {
                        _touchedBarIndex = -1;
                      } else {
                        _touchedBarIndex =
                            response.spot!.touchedBarGroupIndex;
                      }
                    });
                  },

                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primaryLight,
                    getTooltipItem: (
                      group,
                      groupIndex,
                      rod,
                      rodIndex,
                    ) {
                      final d = dailySales[group.x];

                      return BarTooltipItem(
                        '${DateFormat('dd MMM').format(d.date)}\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text:
                                'Omzet: ${CurrencyFormatter.format(d.omzet)}\n',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text:
                                'Laba: +${CurrencyFormatter.format(d.laba)}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                titlesData: FlTitlesData(
                  show: true,

                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),

                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),

                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();

                        if (i < 0 || i >= dailySales.length) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('dd/MM').format(
                              dailySales[i].date,
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return const SizedBox.shrink();
                        }

                        return Text(
                          _shortCurrency(value),
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),

                borderData: FlBorderData(show: false),

                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortCurrency(double val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}jt';
    }

    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)}rb';
    }

    return val.toStringAsFixed(0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GRAFIK PRODUK TERLARIS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopProductsHorizontalBar(
    List<_TopProduct> topProducts,
  ) {
    final maxOmzet = topProducts.first.totalOmzet;

    final colors = [
      AppColors.accent,
      AppColors.secondary,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: topProducts.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;

          final ratio = maxOmzet > 0
              ? p.totalOmzet / maxOmzet
              : 0.0;

          final barColor = colors[i % colors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${i + 1}. ${p.namaProduk}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Text(
                      CurrencyFormatter.format(p.totalOmzet),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: barColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      barColor,
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '${p.totalQty} unit terjual',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3: DAFTAR NOTA
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTransaksiTab(
    List<TransactionModel> filtered,
  ) {
    if (filtered.isEmpty) {
      return const Center(
        child: _EmptyCard(
          message: 'Belum ada transaksi di periode ini',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final trx = filtered[i];

        final timeStr = DateFormat(
          'dd/MM/yyyy HH:mm',
        ).format(trx.tanggalWaktu);

        final totalItems = trx.items.fold(
          0,
          (sum, item) => sum + item.qty,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),

            leading: CircleAvatar(
              backgroundColor: AppColors.accent.withValues(
                alpha: 0.1,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 22,
              ),
            ),

            title: Row(
              children: [
                Expanded(
                  child: Text(
                    trx.noStruk,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(width: 8),

                Flexible(
                  child: Text(
                    CurrencyFormatter.format(trx.totalBayar),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),

            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),

                Text(
                  '$timeStr • ${trx.namaKasir} • $totalItems barang',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 4),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Laba: +${CurrencyFormatter.format(trx.marginKeuntungan)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
              ],
            ),

            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
            ),

            onTap: () => _showTransactionDetails(trx),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 20,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 32),
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 12),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              Icon(
                icon,
                color: color,
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductCard extends StatelessWidget {
  final int rank;
  final _TopProduct product;

  const _TopProductCard({
    required this.rank,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final medalColors = [
      Colors.amber.shade600,
      Colors.blueGrey.shade400,
      Colors.brown.shade400,
    ];

    final medalIcons = [
      Icons.emoji_events_rounded,
      Icons.military_tech_rounded,
      Icons.star_rounded,
    ];

    final isMedal = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMedal
              ? medalColors[rank - 1].withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isMedal
                  ? medalColors[rank - 1].withValues(alpha: 0.12)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isMedal
                  ? Icon(
                      medalIcons[rank - 1],
                      color: medalColors[rank - 1],
                      size: 20,
                    )
                  : Text(
                      '$rank',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.namaProduk,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),

                Text(
                  '${product.totalQty} unit terjual',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(product.totalOmzet),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),

              const Text(
                'omzet',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
