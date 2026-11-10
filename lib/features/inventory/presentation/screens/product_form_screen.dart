import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/product_model.dart';
import '../../data/providers/product_provider.dart';
import '../../../pos/presentation/screens/barcode_scanner_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final ProductModel? initialProduct;

  const ProductFormScreen({super.key, this.initialProduct});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _namaController;
  late TextEditingController _skuController;
  late TextEditingController _kategoriController;
  late TextEditingController _hargaBeliController;
  late TextEditingController _hargaJualController;
  late TextEditingController _stokController;

  // EWS / ROP Parameters
  late TextEditingController _avgDailySalesController;
  late TextEditingController _leadTimeController;
  late TextEditingController _safetyStockController;
  late TextEditingController _reorderPointController;

  bool _isCustomBarcode = false;
  bool _autoCalculateROP = true;

  bool get _isEditMode => widget.initialProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;

    _namaController = TextEditingController(text: p?.namaProduk ?? '');
    _skuController = TextEditingController(text: p?.skuBarcode ?? '');
    _kategoriController = TextEditingController(text: p?.kategori ?? 'Sembako');
    _hargaBeliController = TextEditingController(text: p != null ? p.hargaBeli.toInt().toString() : '');
    _hargaJualController = TextEditingController(text: p != null ? p.hargaJual.toInt().toString() : '');
    _stokController = TextEditingController(text: p != null ? p.stokSaatIni.toString() : '10');

    _avgDailySalesController = TextEditingController(text: p != null ? p.avgDailySales.toString() : '3.0');
    _leadTimeController = TextEditingController(text: p != null ? p.leadTimeDays.toString() : '2');
    _safetyStockController = TextEditingController(text: p != null ? p.safetyStock.toString() : '5');
    _reorderPointController = TextEditingController(text: p != null ? p.reorderPoint.toString() : '11');

    _isCustomBarcode = p?.isCustomBarcode ?? false;

    // Recalculate ROP when inputs change
    _avgDailySalesController.addListener(_recalcROP);
    _leadTimeController.addListener(_recalcROP);
    _safetyStockController.addListener(_recalcROP);
  }

  void _recalcROP() {
    if (!_autoCalculateROP) return;

    final d = double.tryParse(_avgDailySalesController.text) ?? 0.0;
    final l = int.tryParse(_leadTimeController.text) ?? 0;
    final ss = int.tryParse(_safetyStockController.text) ?? 0;

    final calculated = ProductModel.calculateROP(
      avgDailySales: d,
      leadTimeDays: l,
      safetyStock: ss,
    );

    setState(() {
      _reorderPointController.text = calculated.toString();
    });
  }

  @override
  void dispose() {
    _namaController.dispose();
    _skuController.dispose();
    _kategoriController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    _stokController.dispose();
    _avgDailySalesController.dispose();
    _leadTimeController.dispose();
    _safetyStockController.dispose();
    _reorderPointController.dispose();
    super.dispose();
  }

  void _generateSku({bool isCurah = false}) {
    final rand = Random();
    if (isCurah) {
      final code = '9900${rand.nextInt(9000) + 1000}';
      setState(() {
        _skuController.text = code;
        _isCustomBarcode = true;
      });
    } else {
      final code = '899${rand.nextInt(900000000) + 100000000}';
      setState(() {
        _skuController.text = code;
        _isCustomBarcode = false;
      });
    }
  }

  Future<void> _handleSave() async {
  if (!_formKey.currentState!.validate()) return;

  final nama = _namaController.text.trim();
  final sku = _skuController.text.trim();
  final kategori = _kategoriController.text.trim().isEmpty
      ? 'Umum'
      : _kategoriController.text.trim();
  final hargaBeli =
      double.tryParse(_hargaBeliController.text.replaceAll('.', '')) ?? 0.0;
  final hargaJual =
      double.tryParse(_hargaJualController.text.replaceAll('.', '')) ?? 0.0;
  final stok = int.tryParse(_stokController.text) ?? 0;

  final avgDaily =
      double.tryParse(_avgDailySalesController.text) ?? 2.0;
  final leadTime = int.tryParse(_leadTimeController.text) ?? 2;
  final safety = int.tryParse(_safetyStockController.text) ?? 5;
  final rop = int.tryParse(_reorderPointController.text) ?? 10;

  try {
    if (_isEditMode) {
      final updated = widget.initialProduct!.copyWith(
        namaProduk: nama,
        skuBarcode: sku,
        kategori: kategori,
        hargaBeli: hargaBeli,
        hargaJual: hargaJual,
        stokSaatIni: stok,
        avgDailySales: avgDaily,
        leadTimeDays: leadTime,
        safetyStock: safety,
        reorderPoint: rop,
        isCustomBarcode: _isCustomBarcode,
        updatedAt: DateTime.now(),
      );

      await ref.read(productListProvider.notifier).updateProduct(updated);
    } else {
      final newProduct = ProductModel(
        idProduk: 'prod-${DateTime.now().millisecondsSinceEpoch}',
        skuBarcode: sku,
        namaProduk: nama,
        kategori: kategori,
        hargaBeli: hargaBeli,
        hargaJual: hargaJual,
        stokSaatIni: stok,
        avgDailySales: avgDaily,
        leadTimeDays: leadTime,
        safetyStock: safety,
        reorderPoint: rop,
        isCustomBarcode: _isCustomBarcode,
        updatedAt: DateTime.now(),
      );

      await ref.read(productListProvider.notifier).addProduct(newProduct);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditMode
              ? 'Produk "$nama" berhasil diperbarui'
              : 'Produk "$nama" berhasil ditambahkan',
        ),
        backgroundColor: AppColors.accent,
      ),
    );

    Navigator.pop(context);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal menyimpan produk: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    final beli = double.tryParse(_hargaBeliController.text.replaceAll('.', '')) ?? 0.0;
    final jual = double.tryParse(_hargaJualController.text.replaceAll('.', '')) ?? 0.0;
    final margin = jual - beli;
    final marginPercent = beli > 0 ? (margin / beli * 100) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Master Produk' : 'Tambah Produk Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.accent),
            tooltip: 'Simpan',
            onPressed: _handleSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Identitas Produk Card
              _buildSectionCard(
                title: 'Informasi Produk',
                icon: Icons.info_outline_rounded,
                children: [
                  TextFormField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Produk *',
                      hintText: 'Contoh: Beras Rojo Lele 5kg',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Nama produk wajib diisi';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _skuController,
                          decoration: const InputDecoration(
                            labelText: 'Kode SKU / Barcode *',
                            hintText: '899xxx atau 9900xxx',
                            prefixIcon: Icon(Icons.qr_code_rounded),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Kode barcode wajib diisi';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tombol Scan Barcode Kamera
                      Tooltip(
                        message: 'Pindai Barcode Fisik dari Kamera',
                        child: InkWell(
                          onTap: () async {
                            final scanned = await BarcodeScannerScreen.scanSingleBarcode(context);
                            if (scanned != null && scanned.isNotEmpty) {
                              setState(() {
                                _skuController.text = scanned;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Berhasil memindai barcode: $scanned'),
                                    backgroundColor: AppColors.accent,
                                  ),
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        tooltip: 'Generate Barcode Otomatis',
                        icon: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_fix_high_rounded, color: AppColors.primary),
                        ),
                        onSelected: (val) {
                          if (val == 'curah') {
                            _generateSku(isCurah: true);
                          } else {
                            _generateSku(isCurah: false);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'pabrik',
                            child: Row(
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Barcode Pabrik (EAN-13)'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'curah',
                            child: Row(
                              children: [
                                Icon(Icons.scale_rounded, size: 20, color: Colors.purple),
                                SizedBox(width: 8),
                                Text('Barcode Curah (9900xxxx)'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _kategoriController,
                    decoration: const InputDecoration(
                      labelText: 'Kategori Produk',
                      hintText: 'Sembako, Curah, Makanan, Minuman, Bumbu...',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Kategori Cepat Chip
                  Wrap(
                    spacing: 8,
                    children: ['Sembako', 'Curah', 'Makanan', 'Minuman', 'Bumbu', 'Kebersihan'].map((cat) {
                      return ActionChip(
                        label: Text(cat, style: const TextStyle(fontSize: 12)),
                        onPressed: () => setState(() => _kategoriController.text = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Produk Curah / Kiloan (Custom Barcode)'),
                    subtitle: const Text('Gunakan untuk barang eceran yang tidak memiliki label pabrik'),
                    value: _isCustomBarcode,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) => setState(() => _isCustomBarcode = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Finansial & Harga Card
              _buildSectionCard(
                title: 'Harga & Margin Keuntungan',
                icon: Icons.monetization_on_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _hargaBeliController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga Beli (Modal) *',
                            prefixText: 'Rp ',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _hargaJualController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga Jual *',
                            prefixText: 'Rp ',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Margin Preview Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: margin >= 0 ? AppColors.accent.withValues(alpha: 0.1) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: margin >= 0 ? AppColors.accent.withValues(alpha: 0.3) : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estimasi Margin per Satuan:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: margin >= 0 ? AppColors.accentHover : Colors.red.shade800,
                          ),
                        ),
                        Text(
                          '${CurrencyFormatter.format(margin)} (${marginPercent.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: margin >= 0 ? AppColors.accentHover : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Parameter Inventaris & Early Warning System (EWS / ROP) Card
              _buildSectionCard(
                title: 'Stok & Formulasi Reorder Point (ROP)',
                icon: Icons.warning_amber_rounded,
                children: [
                  TextFormField(
                    controller: _stokController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kuantitas Stok Saat Ini *',
                      suffixText: 'Unit / Kg',
                      prefixIcon: Icon(Icons.warehouse_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Stok wajib diisi';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kalkulasi Otomatis ROP',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Rumus: ROP = (d × L) + SS',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Switch(
                        value: _autoCalculateROP,
                        activeThumbColor: AppColors.accent,
                        onChanged: (val) {
                          setState(() => _autoCalculateROP = val);
                          if (val) _recalcROP();
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _avgDailySalesController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Rata-rata Harian (d)',
                            helperText: 'Laku per hari',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _leadTimeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Lead Time (L)',
                            helperText: 'Hari antar suplier',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _safetyStockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Safety Stock (SS)',
                            helperText: 'Cadangan aman',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _reorderPointController,
                    readOnly: _autoCalculateROP,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Batas Minimum Reorder Point (ROP) *',
                      helperText: 'Saat stok di bawah angka ini, EWS akan memicu alarm peringatan',
                      prefixIcon: const Icon(Icons.notification_important_outlined, color: AppColors.ewsCritical),
                      filled: _autoCalculateROP,
                      fillColor: _autoCalculateROP ? Colors.grey.shade100 : Colors.white,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'ROP wajib diisi';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tombol Simpan
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  _isEditMode ? 'Simpan Perubahan Produk' : 'Simpan Produk ke Katalog',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleSave,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}
