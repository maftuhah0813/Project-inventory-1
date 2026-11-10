
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/product_model.dart';
import '../../data/providers/product_provider.dart';

class BarcodeGeneratorScreen extends ConsumerStatefulWidget {
  final ProductModel? preselectedProduct;

  const BarcodeGeneratorScreen({
    super.key,
    this.preselectedProduct,
  });

  @override
  ConsumerState<BarcodeGeneratorScreen> createState() =>
      _BarcodeGeneratorScreenState();
}

class _BarcodeGeneratorScreenState
    extends ConsumerState<BarcodeGeneratorScreen> {
  ProductModel? _selectedProduct;

  late TextEditingController _productNameController;
  late TextEditingController _skuController;
  late TextEditingController _priceController;
  late TextEditingController _copiesController;

  String _barcodeType = 'Code 128';

  bool _includeShopName = true;
  bool _includePrice = true;
  bool _includeDate = true;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();

    _selectedProduct = widget.preselectedProduct;

    _productNameController = TextEditingController(
      text: _selectedProduct?.namaProduk ??
          'Beras Curah Rojo Lele (kg)',
    );

    _skuController = TextEditingController(
      text: _selectedProduct?.skuBarcode ?? '99000001',
    );

    _priceController = TextEditingController(
      text: _selectedProduct != null
          ? _selectedProduct!.hargaJual.toInt().toString()
          : '14500',
    );

    _copiesController = TextEditingController(text: '3');
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _copiesController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onProductSelected(ProductModel? product) {
    if (product == null) return;

    setState(() {
      _selectedProduct = product;

      _productNameController.text = product.namaProduk;
      _skuController.text = product.skuBarcode;
      _priceController.text = product.hargaJual.toInt().toString();
    });
  }

  void _generateRandomCurahCode() {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final uniqueSuffix = now.substring(now.length - 4);

    setState(() {
      _skuController.text = '9900$uniqueSuffix';
    });
  }

  bw.Barcode _getBarcodeObject() {
    final sku = _skuController.text.trim();

    switch (_barcodeType) {
      case 'QR Code':
        return bw.Barcode.qrCode();

      case 'EAN-13':
        final digits = sku.replaceAll(RegExp(r'\D'), '');

        if (digits.length == 12 || digits.length == 13) {
          return bw.Barcode.ean13();
        }

        return bw.Barcode.code128();

      default:
        return bw.Barcode.code128();
    }
  }

  pw.Barcode _getPdfBarcodeObject() {
    final sku = _skuController.text.trim();

    switch (_barcodeType) {
      case 'QR Code':
        return pw.Barcode.qrCode();

      case 'EAN-13':
        final digits = sku.replaceAll(RegExp(r'\D'), '');

        if (digits.length == 12 || digits.length == 13) {
          return pw.Barcode.ean13();
        }

        return pw.Barcode.code128();

      default:
        return pw.Barcode.code128();
    }
  }

  Future<void> _printOrExportPdf() async {
    if (_isPrinting) return;

    final name = _productNameController.text.trim();
    final sku = _skuController.text.trim();

    final price = double.tryParse(
          _priceController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0.0;

    final copies = int.tryParse(_copiesController.text.trim()) ?? 0;

    if (name.isEmpty) {
      _showMessage('Nama produk tidak boleh kosong.');
      return;
    }

    if (sku.isEmpty) {
      _showMessage('Kode SKU barcode tidak boleh kosong.');
      return;
    }

    if (price < 0) {
      _showMessage('Harga produk tidak valid.');
      return;
    }

    if (copies < 1 || copies > 500) {
      _showMessage('Jumlah cetak harus antara 1 sampai 500.');
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final pdf = pw.Document();

      final pdfBarcode = _getPdfBarcodeObject();

      final now = DateTime.now();

      final nowFormatted =
          '${now.day}/${now.month}/${now.year}';

      const pageFormat = PdfPageFormat(
        58 * PdfPageFormat.mm,
        40 * PdfPageFormat.mm,
        marginAll: 2 * PdfPageFormat.mm,
      );

      for (int i = 0; i < copies; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (pw.Context ctx) {
              return pw.Container(
                padding: const pw.EdgeInsets.all(3),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (_includeShopName)
                      pw.Text(
                        'MAFTUHAH POS MART',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 7.5,
                          color: PdfColors.blueGrey800,
                        ),
                      ),

                    pw.SizedBox(height: 2),

                    pw.Text(
                      name,
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8.5,
                      ),
                    ),

                    pw.SizedBox(height: 3),

                    pw.Expanded(
                      child: pw.BarcodeWidget(
                        barcode: pdfBarcode,
                        data: sku,
                        drawText: _barcodeType != 'QR Code',
                        textStyle: const pw.TextStyle(
                          fontSize: 6.5,
                        ),
                      ),
                    ),

                    pw.SizedBox(height: 2),

                    pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      children: [
                        if (_includePrice)
                          pw.Text(
                            CurrencyFormatter.format(price),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7.5,
                              color: PdfColors.black,
                            ),
                          ),

                        if (_includeDate)
                          pw.Text(
                            'Tgl: $nowFormatted',
                            style: const pw.TextStyle(
                              fontSize: 6,
                              color: PdfColors.grey700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Stiker_Barcode_${sku}_x$copies.pdf',
      );
    } catch (e, stackTrace) {
      debugPrint('Gagal mencetak barcode: $e');
      debugPrintStack(stackTrace: stackTrace);

      _showMessage('Gagal membuat PDF barcode: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  Widget _buildBarcodePreview({
    required String currentSku,
  }) {
    if (currentSku.isEmpty) {
      return Container(
        height: 75,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const Text(
          'Masukkan SKU Barcode',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      );
    }

    try {
      return SizedBox(
        width: 220,
        height: 75,
        child: bw.BarcodeWidget(
          barcode: _getBarcodeObject(),
          data: currentSku,
          width: 220,
          height: 75,
          drawText: _barcodeType != 'QR Code',
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
          ),
          errorBuilder: (context, error) {
            return Center(
              child: Text(
                'Format tidak valid untuk $_barcodeType',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      return Container(
        height: 60,
        color: Colors.red.shade50,
        alignment: Alignment.center,
        child: Text(
          'Format tidak valid: $e',
          style: const TextStyle(
            fontSize: 10,
            color: Colors.red,
          ),
        ),
      );
    }
  }

  Widget _buildPreviewCard({
    required String currentName,
    required String currentSku,
    required double currentPrice,
  }) {
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Pratinjau Stiker Barcode',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _barcodeType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final stickerWidth =
                  constraints.maxWidth < 280
                      ? constraints.maxWidth
                      : 260.0;

              return Center(
                child: Container(
                  width: stickerWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade400,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_includeShopName) ...[
                        const Text(
                          'MAFTUHAH POS MART',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],

                      Text(
                        currentName.isEmpty
                            ? 'Nama Barang Curah'
                            : currentName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 10),

                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildBarcodePreview(
                          currentSku: currentSku,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          if (_includePrice)
                            Flexible(
                              child: Text(
                                CurrencyFormatter.format(currentPrice),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),

                          if (_includeDate)
                            Text(
                              '${now.day}/${now.month}/${now.year}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          const Text(
            'Siap dicetak ke kertas termal stiker atau printer kasir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(List<ProductModel> allProducts) {
    final curahProducts = allProducts
        .where(
          (p) =>
              p.isCustomBarcode ||
              p.kategori.toLowerCase() == 'curah',
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pilih Produk Curah yang Tersedia',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            key: ValueKey(_selectedProduct?.idProduk),
            initialValue: _selectedProduct != null &&
                    allProducts.any(
                      (p) =>
                          p.idProduk ==
                          _selectedProduct!.idProduk,
                    )
                ? _selectedProduct!.idProduk
                : null,
            decoration: const InputDecoration(
              labelText: 'Pilih dari Katalog Master',
              prefixIcon: Icon(
                Icons.arrow_drop_down_circle_outlined,
              ),
            ),
            isExpanded: true,
            items: allProducts.map((p) {
              final isCurah = p.isCustomBarcode ||
                  p.kategori.toLowerCase() == 'curah';

              return DropdownMenuItem<String>(
                value: p.idProduk,
                child: Text(
                  '${p.namaProduk} (${p.skuBarcode}) '
                  '${isCurah ? "[Curah]" : ""}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isCurah
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isCurah
                        ? Colors.purple.shade700
                        : AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            onChanged: (id) {
              if (id == null) return;

              final match = allProducts.firstWhere(
                (p) => p.idProduk == id,
              );

              _onProductSelected(match);
            },
          ),

          if (curahProducts.isNotEmpty) ...[
            const SizedBox(height: 10),

            const Text(
              'Rekomendasi Barang Curah / Kiloan:',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 6),

            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: curahProducts.map((p) {
                return ActionChip(
                  avatar: const Icon(
                    Icons.scale_rounded,
                    size: 16,
                    color: Colors.purple,
                  ),
                  label: Text(
                    '${p.namaProduk} (${p.skuBarcode})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _onProductSelected(p),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Parameter & Konfigurasi Label',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 20),

          TextFormField(
            controller: _productNameController,
            decoration: const InputDecoration(
              labelText: 'Nama Barang di Stiker',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 400;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'Kode SKU / Barcode',
                        prefixIcon: Icon(Icons.qr_code_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),

                  const SizedBox(width: 8),

                  SizedBox(
                    width: compact ? 104 : 120,
                    height: 56,
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.auto_fix_high_rounded,
                        size: 18,
                      ),
                      label: Text(
                        compact ? 'Acak' : 'Acak SKU',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade50,
                        foregroundColor: Colors.purple.shade700,
                        elevation: 0,
                        minimumSize: Size(
                          compact ? 104 : 120,
                          56,
                        ),
                        maximumSize: Size(
                          compact ? 104 : 120,
                          56,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                      ),
                      onPressed: _generateRandomCurahCode,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 350;

              if (compact) {
                return Column(
                  children: [
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga Jual',
                        prefixText: 'Rp ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _copiesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Salinan Cetak',
                        suffixText: 'Lembar',
                        prefixIcon: Icon(Icons.copy_rounded),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga Jual',
                        prefixText: 'Rp ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextFormField(
                      controller: _copiesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Salinan Cetak',
                        suffixText: 'Lembar',
                        prefixIcon: Icon(Icons.copy_rounded),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          const Text(
            'Tipe Simbologi Barcode:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Code 128', 'QR Code', 'EAN-13'].map((type) {
              final isSelected = _barcodeType == type;

              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.background,
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
                  setState(() {
                    _barcodeType = type;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          Material(
            color: Colors.transparent,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Cantumkan Nama Toko ("Maftuhah POS Mart")',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: _includeShopName,
                  activeThumbColor: AppColors.accent,
                  onChanged: (val) {
                    setState(() {
                      _includeShopName = val;
                    });
                  },
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Cantumkan Harga Produk',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: _includePrice,
                  activeThumbColor: AppColors.accent,
                  onChanged: (val) {
                    setState(() {
                      _includePrice = val;
                    });
                  },
                ),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Cantumkan Tanggal Cetak / Kemas',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: _includeDate,
                  activeThumbColor: AppColors.accent,
                  onChanged: (val) {
                    setState(() {
                      _includeDate = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = ref.watch(productListProvider);

    final currentSku = _skuController.text.trim();
    final currentName = _productNameController.text.trim();

    final currentPrice = double.tryParse(
          _priceController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0.0;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Cetak Barcode Produk Curah'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.print_rounded,
              color: AppColors.accent,
            ),
            tooltip: 'Cetak / Ekspor Stiker Barcode',
            onPressed: _isPrinting ? null : _printOrExportPdf,
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPreviewCard(
                currentName: currentName,
                currentSku: currentSku,
                currentPrice: currentPrice,
              ),

              const SizedBox(height: 16),

              _buildProductCard(allProducts),

              const SizedBox(height: 16),

              _buildConfigurationCard(),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.print_rounded,
                          size: 22,
                        ),

                  label: Text(
                    _isPrinting
                        ? 'Menyiapkan PDF...'
                        : 'Cetak Stiker Barcode Sekarang',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  onPressed:
                      _isPrinting ? null : _printOrExportPdf,
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
