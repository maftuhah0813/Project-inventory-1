/// String konstanta dan teks label aplikasi Maftuhah Mobile POS
class AppStrings {
  static const String appName = 'Maftuhah POS';
  static const String appTagline = 'Smart Mobile POS & Inventory EWS';

  // Auth
  static const String loginTitle = 'Selamat Datang';
  static const String loginSubtitle = 'Silakan masuk untuk mengakses sistem kasir';
  static const String emailLabel = 'Alamat Email';
  static const String passwordLabel = 'Kata Sandi';
  static const String loginButton = 'Masuk ke Sistem';
  static const String logoutConfirm = 'Apakah Anda yakin ingin keluar dari sesi ini?';

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleKasir = 'kasir';

  // POS
  static const String posTitle = 'Kasir Pintar';
  static const String cartEmpty = 'Keranjang belanja masih kosong';
  static const String scanHint = 'Arahkan kamera ke barcode produk';
  static const String searchProductHint = 'Cari nama barang atau kode SKU...';
  static const String totalBelanja = 'Total Belanja';
  static const String bayarButton = 'Proses Pembayaran';
  static const String uangPas = 'Uang Pas';
  static const String kembalian = 'Kembalian';

  // EWS (Early Warning System)
  static const String ewsTitle = 'Peringatan Dini Stok';
  static const String ewsCriticalBadge = 'KRITIS';
  static const String ewsWarningBadge = 'WASPADA';
  static const String ewsSafeBadge = 'AMAN';
  static const String reorderPoint = 'Batas Kritis (ROP)';
  static const String restockAction = 'Konfirmasi Restock';

  // Analytics & Admin
  static const String dashboardTitle = 'Dasbor Manajemen';
  static const String topProducts = 'Top 5 Produk Terlaris';
  static const String salesTrend = 'Tren Penjualan';
  static const String quickInsights = 'Insight Cerdas Bisnis';
  static const String exportReport = 'Ekspor Laporan Finansial';
}
