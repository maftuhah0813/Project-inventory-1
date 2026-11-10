import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/product_model.dart';
import '../../data/providers/product_provider.dart';
import 'barcode_generator_screen.dart';
import 'product_form_screen.dart';
import '../../../pos/presentation/screens/barcode_scanner_screen.dart';

class ProductManagementScreen extends ConsumerStatefulWidget {
  final String? initialFilter; // 'all', 'kritis', 'waspada'

  const ProductManagementScreen({super.key, this.initialFilter});

  @override
  ConsumerState<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState
    extends ConsumerState<ProductManagementScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  String _selectedEwsStatus = 'Semua';

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter == 'kritis') {
      _selectedEwsStatus = 'KRITIS';
    } else if (widget.initialFilter == 'waspada') {
      _selectedEwsStatus = 'WASPADA';
    }
  }

  void _showQuickRestockDialog(ProductModel product) {
    final qtyController = TextEditingController(text: '10');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_shopping_cart_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Restok Cepat Barang', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.namaProduk,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Stok saat ini: ${product.stokSaatIni} unit '
              '(Batas ROP: ${product.reorderPoint})',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Jumlah Tambahan Stok (Unit)',
                hintText: 'Contoh: 10',
                prefixIcon: Icon(Icons.exposure_plus_1_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final qty = int.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Masukkan jumlah lebih dari 0.')),
                );
                return;
              }

              ref
                  .read(productListProvider.notifier)
                  .adjustStock(product.idProduk, qty);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Berhasil menambah $qty unit stok untuk '
                    '"${product.namaProduk}"',
                  ),
                  backgroundColor: AppColors.accent,
                ),
              );
            },
            child: const Text('Konfirmasi Tambah'),
          ),
        ],
      ),
    ).whenComplete(qtyController.dispose);
  }

  void _confirmDelete(ProductModel product) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.ewsCritical),
            SizedBox(width: 8),
            Text('Hapus Produk?'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${product.namaProduk}" '
          'dari katalog master produk?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ewsCritical,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref
                  .read(productListProvider.notifier)
                  .deleteProduct(product.idProduk);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Permintaan hapus "${product.namaProduk}" dikirim.'),
                ),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = ref.watch(productListProvider);
    final categories = ref.watch(productCategoriesProvider);

    final criticalCount = allProducts.where((p) => p.isCritical).length;
    final warningCount = allProducts.where((p) => p.isWarning).length;

    final query = _searchQuery.toLowerCase().trim();
    final filtered = allProducts.where((product) {
      final matchesQuery =
          product.namaProduk.toLowerCase().contains(query) ||
          product.skuBarcode.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == 'Semua' ||
          product.kategori == _selectedCategory;
      final matchesStatus =
          _selectedEwsStatus == 'Semua' ||
          product.ewsStatusLabel == _selectedEwsStatus;
      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Master Produk & Inventaris'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'Cetak Barcode Curah',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BarcodeGeneratorScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Produk',
            onPressed: _openAddProduct,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Produk'),
        onPressed: _openAddProduct,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryBadge(
                    label: 'Total Produk',
                    count: '${allProducts.length}',
                    color: AppColors.primary,
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryBadge(
                    label: 'Stok Kritis',
                    count: '$criticalCount',
                    color: AppColors.ewsCritical,
                    icon: Icons.error_outline_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryBadge(
                    label: 'Stok Waspada',
                    count: '$warningCount',
                    color: AppColors.ewsWarning,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk atau kode barcode...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Scan Barcode untuk Cari',
                  onPressed: () async {
                    final scanned = await BarcodeScannerScreen.scanSingleBarcode(context);
                    if (scanned != null && scanned.isNotEmpty) {
                      setState(() => _searchQuery = scanned);
                    }
                  },
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Status: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildFilterChip(
                        label: 'Semua Status',
                        isSelected: _selectedEwsStatus == 'Semua',
                        onSelected: () =>
                            setState(() => _selectedEwsStatus = 'Semua'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: 'Kritis ($criticalCount)',
                        color: AppColors.ewsCritical,
                        isSelected: _selectedEwsStatus == 'KRITIS',
                        onSelected: () =>
                            setState(() => _selectedEwsStatus = 'KRITIS'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: 'Waspada ($warningCount)',
                        color: AppColors.ewsWarning,
                        isSelected: _selectedEwsStatus == 'WASPADA',
                        onSelected: () =>
                            setState(() => _selectedEwsStatus = 'WASPADA'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: 'Aman',
                        color: AppColors.ewsSafe,
                        isSelected: _selectedEwsStatus == 'AMAN',
                        onSelected: () =>
                            setState(() => _selectedEwsStatus = 'AMAN'),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        'Kategori: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...categories.map((category) {
                        final selected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              category,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: selected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.background,
                            onSelected: (_) => setState(
                              () => _selectedCategory = category,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tidak ada produk yang cocok',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Coba ganti kata kunci pencarian atau filter status',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildProductCard(filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  void _openAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
  }

  Widget _buildSummaryBadge({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    final activeColor = color ?? AppColors.primary;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : activeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? activeColor
                : activeColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : activeColor,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final Color badgeColor;
    if (product.isCritical) {
      badgeColor = AppColors.ewsCritical;
    } else if (product.isWarning) {
      badgeColor = AppColors.ewsWarning;
    } else {
      badgeColor = AppColors.ewsSafe;
    }

    final margin = product.hargaJual - product.hargaBeli;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: product.isCritical
              ? AppColors.ewsCritical.withValues(alpha: 0.4)
              : AppColors.border,
          width: product.isCritical ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: product.isCustomBarcode
                      ? Colors.purple.shade50
                      : AppColors.primary.withValues(alpha: 0.08),
                  child: Icon(
                    product.isCustomBarcode
                        ? Icons.scale_rounded
                        : Icons.inventory_2_outlined,
                    color: product.isCustomBarcode
                        ? Colors.purple
                        : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.namaProduk,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'STOK ${product.ewsStatusLabel}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.kategori,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.qr_code_rounded,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          Text(
                            product.skuBarcode,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Harga Jual',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(product.hargaJual),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'Modal: ${CurrencyFormatter.format(product.hargaBeli)} '
                        '(+${CurrencyFormatter.format(margin)})',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 36, width: 1, color: AppColors.border),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Stok Saat Ini',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${product.stokSaatIni}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Unit',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Batas ROP: ${product.reorderPoint} unit',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                    label: const Text('Restok', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showQuickRestockDialog(product),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductFormScreen(
                            initialProduct: product,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.qr_code_2_rounded,
                    color: product.isCustomBarcode
                        ? Colors.purple
                        : AppColors.primary,
                    size: 20,
                  ),
                  tooltip: 'Cetak Barcode Stiker',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BarcodeGeneratorScreen(
                          preselectedProduct: product,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.ewsCritical,
                    size: 20,
                  ),
                  tooltip: 'Hapus Produk',
                  onPressed: () => _confirmDelete(product),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
