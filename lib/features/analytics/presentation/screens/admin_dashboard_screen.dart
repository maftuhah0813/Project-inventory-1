import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../inventory/data/models/product_model.dart';
import '../../../inventory/data/providers/product_provider.dart';
import '../../../inventory/presentation/screens/product_management_screen.dart';
import '../../../inventory/presentation/screens/barcode_generator_screen.dart';
import '../../../pos/data/providers/transaction_provider.dart';
import 'sales_report_screen.dart';
import '../../../../services/seed_products.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  void _showQuickRestockModal(BuildContext context, WidgetRef ref, ProductModel product) {
    final qtyController = TextEditingController(text: '10');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.add_shopping_cart_rounded, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('Restok Cepat Barang', style: TextStyle(fontSize: 18)),
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
                'Stok saat ini: ${product.stokSaatIni} unit (Batas ROP: ${product.reorderPoint})',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Tambahan Stok (Unit)',
                  prefixIcon: Icon(Icons.exposure_plus_1_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final qty = int.tryParse(qtyController.text) ?? 0;
                if (qty > 0) {
                  ref.read(productListProvider.notifier).adjustStock(product.idProduk, qty);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Berhasil menambah $qty unit stok untuk "${product.namaProduk}"'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
              child: const Text('Konfirmasi Tambah'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProducts = ref.watch(productListProvider);
    final criticalProducts = ref.watch(criticalProductsProvider);
    final warningProducts = ref.watch(warningProductsProvider);
    final totalAlertCount = criticalProducts.length + warningProducts.length;

    // Metrik Transaksi Finansial Realtime
    final transactions = ref.watch(transactionListProvider);
    final totalOmzet = transactions.fold(0.0, (sum, t) => sum + t.totalBayar);
    final totalLaba = transactions.fold(0.0, (sum, t) => sum + t.marginKeuntungan);
    final avgTrx = transactions.isNotEmpty ? (totalOmzet / transactions.length) : 0.0;
    final marginPercent = totalOmzet > 0 ? (totalLaba / totalOmzet * 100) : 0.0;

    // Ambil produk bermasalah untuk ditampilkan di EWS widget (maksimal 3 item)
    final ewsItems = [...criticalProducts, ...warningProducts].take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: AppColors.accent, size: 22),
            SizedBox(width: 8),
            Text(AppStrings.dashboardTitle),
          ],
        ),
        actions: [
                    // Tombol sementara untuk mengunggah produk awal ke Firestore
          IconButton(
            icon: const Icon(Icons.cloud_upload_rounded),
            tooltip: 'Unggah Produk Awal ke Firestore',
            onPressed: () async {
              try {
                await SeedProducts.uploadInitialProducts(
                  initialProductsForSeed,
                );

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Proses unggah produk awal selesai. Periksa koleksi products di Firestore.',
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal mengunggah produk: $e'),
                  ),
                );
              }
            },
          ),
          // EWS Critical Alert Badge Icon
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_active_rounded),
                tooltip: 'Pusat Peringatan EWS',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductManagementScreen(initialFilter: 'kritis'),
                    ),
                  );
                },
              ),
              if (totalAlertCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.ewsCritical,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$totalAlertCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, Pemilik Toko (Admin)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Ringkasan performa bisnis ritel & status inventaris hari ini',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Financial Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Omzet Hari Ini',
                    value: CurrencyFormatter.format(totalOmzet),
                    subtitle: '${transactions.length} Transaksi Tercatat',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    title: 'Total Transaksi',
                    value: '${transactions.length} TRX',
                    subtitle: 'Rata-rata ${CurrencyFormatter.format(avgTrx)}',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    title: 'Estimasi Laba Bersih',
                    value: CurrencyFormatter.format(totalLaba),
                    subtitle: 'Margin ${marginPercent.toStringAsFixed(1)}%',
                    icon: Icons.monetization_on_outlined,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Insight Card (Cognitive Load Reduction for UMKM)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Insight Cerdas Bisnis (Mobile BI)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          criticalProducts.isNotEmpty
                              ? 'Perhatian: Ada ${criticalProducts.length} produk dalam status STOK KRITIS (${criticalProducts.map((p) => p.namaProduk).take(2).join(', ')}). Segera lakukan restock sebelum akhir pekan!'
                              : 'Kondisi inventaris dalam status baik. Semua barang memenuhi ambang batas aman (ROP).',
                          style: TextStyle(fontSize: 13, color: Colors.brown.shade800, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Early Warning System (EWS) Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.ewsCritical, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Peringatan Dini Stok (EWS)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: totalAlertCount > 0 ? AppColors.ewsCritical : AppColors.ewsSafe,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalAlertCount Perlu Perhatian',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProductManagementScreen(initialFilter: 'kritis'),
                      ),
                    );
                  },
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dynamic EWS Item Cards from State
            if (ewsItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppColors.accent, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Semua stok berada dalam batas aman! Tidak ada stok kritis.',
                      style: TextStyle(color: AppColors.accentHover, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else
              ...ewsItems.map((prod) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _EwsAlertCard(
                    namaProduk: prod.namaProduk,
                    sku: '${prod.skuBarcode} ${prod.isCustomBarcode ? "(Curah)" : ""}',
                    stokSaatIni: prod.stokSaatIni,
                    reorderPoint: prod.reorderPoint,
                    level: prod.isCritical ? 'critical' : 'warning',
                    onRestock: () => _showQuickRestockModal(context, ref, prod),
                  ),
                );
              }),
            const SizedBox(height: 24),

            // Quick Actions Navigation Grid
            const Text(
              'Aksi Cepat Manajemen',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionShortcutCard(
                    title: 'Master Produk',
                    subtitle: '${allProducts.length} Produk Terdaftar',
                    icon: Icons.inventory_2_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProductManagementScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionShortcutCard(
                    title: 'Cetak Barcode Curah',
                    subtitle: 'SKU Barang Kiloan/Ecer',
                    icon: Icons.qr_code_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BarcodeGeneratorScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionShortcutCard(
                    title: 'Laporan PDF & Excel',
                    subtitle: 'Rekap Finansial & Audit',
                    icon: Icons.picture_as_pdf_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SalesReportScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _EwsAlertCard extends StatelessWidget {
  final String namaProduk;
  final String sku;
  final int stokSaatIni;
  final int reorderPoint;
  final String level;
  final VoidCallback onRestock;

  const _EwsAlertCard({
    required this.namaProduk,
    required this.sku,
    required this.stokSaatIni,
    required this.reorderPoint,
    required this.level,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    final isCritical = level == 'critical';
    final badgeColor = isCritical ? AppColors.ewsCritical : AppColors.ewsWarning;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: badgeColor.withValues(alpha: 0.12),
          child: Icon(Icons.warning_rounded, color: badgeColor, size: 22),
        ),
        title: Text(namaProduk, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: $sku', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCritical ? 'KRITIS' : 'WASPADA',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Stok: $stokSaatIni unit (Batas ROP: $reorderPoint unit)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(90, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: onRestock,
          child: const Text('Restock', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

class _ActionShortcutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
