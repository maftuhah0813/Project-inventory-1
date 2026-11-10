# MASTER DEVELOPMENT PLAN & TASK BREAKDOWN
## Sistem Kasir Mobile Berbasis Barcode Scanner dengan Visualisasi Data & Early Warning System (EWS)
**Nama Proyek**: Maftuhah Mobile POS  
**Platform**: Android & iOS (Flutter 3.x)  
**Target Penyelesaian**: 14 Minggu (6 Sprint)  
**Dokumen Acuan**: *Rencana Kerja Pengembangan Sistem* & *Gap Penelitian Sistem Kasir Mobile*

---

## 1. IKHTISAR TEKNIS & STANDAR ARSITEKTUR

### 1.1. Arsitektur Dua Sisi (Role-Based Access Control)
Aplikasi dibangun menggunakan satu basis kode (*single codebase*) dengan dua antarmuka terisolasi berdasarkan peran pengguna:
1. **Front-End Kasir (POS Mode)**:
   - Antarmuka pemindai barcode kamera resolusi adaptif (`mobile_scanner`).
   - Keranjang belanja dinamis dan perhitungan otomatis kembalian.
   - Fitur pencarian cepat ("Tap & Search") untuk barcode rusak / barang curah.
   - Eksekusi transaksi atomik (Firestore batch write) yang memotong stok secara aman.
   - Kapabilitas *Offline-First* (Firestore local cache persistence) & rekap shift harian.
2. **Back-Office Admin (Management & BI Mode)**:
   - Dashboard Visualisasi Data (`fl_chart`): Grafik batang Top 5 produk terlaris & grafik garis tren omzet.
   - *Quick Insight Cards*: Analitik ramah kognitif untuk pemilik usaha UMKM.
   - Pusat Peringatan Dini (*Early Warning System / EWS*): Deteksi stok kritis dan integrasi FCM (*Firebase Cloud Messaging*).
   - Master Produk & Formulasi Ambang Batas Stok (*Reorder Point* / ROP).
   - *Custom Barcode Generator* (`barcode_widget` Code128) untuk produk eceran/curah.
   - Ekspor Laporan Finansial (PDF & Excel/CSV).

### 1.2. Spesifikasi Lengkap Teknologi yang Digunakan (Comprehensive Tech Stack)

Aplikasi Maftuhah Mobile POS dirancang dengan arsitektur teknologi modern yang mengutamakan performa kompilasi native, responsivitas pemindaian berlatensi rendah, serta resiliensi operasional tanpa bergantung 100% pada koneksi internet (*Offline-First*).

#### A. Bahasa Pemrograman & Core Framework
- **Bahasa Pemrograman**: **Dart 3.x**
  - Mengadopsi fitur *Sound Null Safety*, *Pattern Matching*, *Records*, dan *Async/Await Streams* untuk menjamin keandalan kode serta meminimalkan potensi *runtime crash*.
- **Mobile Framework**: **Flutter SDK 3.47+ (Channel Stable)**
  - Menggunakan rendering engine performa tinggi (Skia/Impeller) yang mengompilasi kode sumber langsung menjadi *machine code* native ARM64/x86 untuk Android (APK/AAB) dan iOS (IPA), menghasilkan animasi 60 FPS konsisten pada antarmuka kasir.

#### B. State Management & Dependency Injection
- **Library**: `flutter_riverpod` (v2.x) & `riverpod_annotation`
- **Peran & Justifikasi Teknis**:
  - Menyediakan sistem manajemen status yang *compile-time safe*, decoupled (memisahkan logika bisnis dari UI), dan mudah diuji (*testable*).
  - Mengelola *reactive state* keranjang kasir (*Cart State*), sinkronisasi keranjang secara instan saat barcode dipindai tanpa membebani memori (*auto-dispose* saat layar ditutup).
  - Didukung `riverpod_generator` dan `build_runner` untuk pembuatan provider secara otomatis dan terstandarisasi.

#### C. Backend as a Service (BaaS) & Cloud Persistence
- **Platform Cloud**: **Google Firebase Ecosystem**
  - **Firebase Authentication**: Manajemen sesi pengguna kasir & admin berbasis Email/Password dengan token JWT terenkripsi dan mekanisme *auto-login* persisten.
  - **Cloud Firestore (NoSQL Document Store)**:
    - Penyimpanan dokumen JSON-like realtime dengan *snapshot listener* untuk sinkronisasi katalog dan transaksi instan antar gawai.
    - **Firestore Offline Persistence**: Fitur cache lokal bawaan yang otomatis menyimpan operasi data di memori internal perangkat saat internet terputus, dan mengeksekusi antrean sinkronisasi (*sync queue*) saat gawai kembali online tanpa *data conflict*.
    - **Firestore Atomic Transactions & Batch Writes**: Menjamin proses *multi-document write* (pencatatan struk transaksi sekaligus pemotongan stok barang) berjalan atomik tanpa risiko data parsial (*race condition*).
  - **Firebase Cloud Messaging (FCM)**:
    - Pengiriman notifikasi peringatan dini stok (*Early Warning System*) berprioritas tinggi (`priority: high`) langsung ke perangkat Android/iOS pemilik toko (Admin), bahkan ketika aplikasi sedang ditutup (*background/terminated*).
  - **Local Notifications**: `flutter_local_notifications`
    - Menampilkan banner pop-up notifikasi darurat pada saat aplikasi sedang aktif dibuka (*foreground notification handler*).

#### D. Hardware Integration & Vision Processing (Barcode Scanner)
- **Library**: `mobile_scanner` (v5.x+)
- **Engine**: Google ML Kit Vision Barcode Scanning API
- **Spesifikasi & Kapabilitas**:
  - Pemindaian kamera berlatensi sangat rendah (**sub-detik < 0,8 detik per SKU**).
  - Mendukung berbagai format standar barcode ritel 1D (*Code 128, EAN-13, EAN-8, Code 39, UPC-A*) serta kode matriks 2D (*QR Code*).
  - Mendukung kontrol native perangkat: *Torch/Flashlight toggle* (lampu kilat untuk toko berpencahayaan redup), *Camera switcher* (kamera belakang/depan), dan *Custom Viewfinder Overlay* (pembatasan area deteksi hanya pada jendela tengah layar agar tidak salah membaca barcode barang di sebelahnya).

#### E. Barcode Generator & Printing Engine (Solusi Barang Curah)
- **Barcode Generator**: `barcode_widget`
  - Algoritma generator visual barcode berbasis vektor SVG/Canvas untuk mencetak kode batang kustom (misal awalan `9900xxxx`) bagi produk curah/kiloan (beras curah, telur, gula pasir) yang tidak memiliki kemasan pabrik.
- **Thermal & Document Printing Engine**: `pdf` & `printing`
  - Integrasi driver pencetakan struk kasir format standar POS: kertas termal lebar 58mm dan 80mm via koneksi Bluetooth ESC/POS maupun Wi-Fi printer.
  - Pembuatan dokumen cetak laporan penjualan berkala ukuran A4 (PDF) yang siap dibagikan via WhatsApp atau email.

#### F. Data Visualization & Business Intelligence (BI)
- **Library**: `fl_chart`
  - **Grafik Batang (BarChart)**: Visualisasi interaktif Top 5 Produk Terlaris (*Fast-Moving Items*) dengan tooltip informasi detail kuantitas terjual.
  - **Grafik Garis (LineChart)**: Visualisasi kurva tren pendapatan omzet harian dan mingguan dengan gradien warna modern yang mudah dibaca pelaku usaha UMKM.
  - Dirancang khusus untuk arsitektur *Mobile-First BI* guna mengurangi beban kognitif pemilik usaha (*Low Cognitive Load*).

#### G. Utility, Format Mata Uang, & Jaringan
- **Format Rupiah & Tanggal**: `intl`
  - Format mata uang baku Indonesia: `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)`.
  - Format tanggal transaksi lokal (WIB/WITA/WIT).
- **Network Resilience Detector**: `connectivity_plus`
  - Memonitor status konektivitas jaringan (Wi-Fi, Seluler, None) secara realtime untuk mengubah indikator visual status online/offline di header kasir.
- **Penyimpanan Lokal Ringan**: `shared_preferences`
  - Menyimpan konfigurasi ID printer bluetooth default, nama toko, alamat, dan preferensi kasir aktif.
- **Ekspor Dokumen Lembar Kerja**: `excel` / `csv`
  - Mengonversi kumpulan riwayat transaksi menjadi file `.xlsx` / `.csv` untuk pembukuan audit eksternal.
- **Desain Tipografi & Ikon**: `google_fonts` (Inter / Outfit) & `lucide_icons`
  - Memberikan tampilan visual modern, kontras tinggi, dan ramah lingkungan kerja kasir ritel.

#### H. Matriks Dependensi `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management & DI
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Firebase Ecosystem
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  firebase_messaging: ^15.1.3
  flutter_local_notifications: ^17.2.3

  # Hardware & Barcode Processing
  mobile_scanner: ^5.2.3
  barcode_widget: ^2.0.4

  # Data Visualization & BI
  fl_chart: ^0.69.0

  # Printing & Report Export
  pdf: ^3.11.1
  printing: ^5.13.2
  excel: ^4.0.6
  path_provider: ^2.1.4

  # Utility, Formatter & UI
  intl: ^0.19.0
  connectivity_plus: ^6.0.5
  shared_preferences: ^2.3.2
  google_fonts: ^6.2.1
  lucide_icons: ^0.257.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  riverpod_generator: ^2.4.2
  build_runner: ^2.4.12
```

#### I. Spesifikasi Kebutuhan Sistem Minimum
- **Perangkat Kasir & Admin (Android)**:
  - Versi OS: Android 7.0 (Nougat, API 24) hingga Android 14+ (API 34+).
  - Memori RAM: Minimal 2 GB (Disarankan 3 GB atau lebih tinggi).
  - Kamera: 8 Megapixel dengan fitur Auto-Focus dan Flash LED.
  - Penyimpanan Bebas: Minimal 250 MB untuk instalasi aplikasi dan cache transaksi offline.
- **Perangkat Admin (iOS - Opsional)**:
  - Versi OS: iOS 13.0 ke atas.
- **Lingkungan Pengembang (Developer Workstation)**:
  - Flutter SDK: 3.47.7 (Channel Stable)
  - Dart SDK: 3.13.5
  - Android SDK: Platform API 34/36, Build-Tools, Command-line tools
  - Java Development Kit: OpenJDK 17

### 1.3. Struktur Direktori Bersih (Feature-Driven Clean Architecture)
```
lib/
├── app.dart                        # MaterialApp, theme configuration, router
├── core/
│   ├── constants/                  # app_colors.dart, app_strings.dart, app_sizes.dart
│   ├── network/                    # connectivity_service.dart (offline detector)
│   ├── theme/                      # app_theme.dart (High contrast, touch-friendly UI)
│   └── utils/                      # currency_formatter.dart, date_formatter.dart, sound_helper.dart
├── features/
│   ├── auth/                       # Splash, Login, RBAC Auth Guard, Profile
│   │   ├── data/                   # auth_repository.dart, user_model.dart
│   │   ├── presentation/           # login_screen.dart, splash_screen.dart
│   │   └── providers/              # auth_provider.dart
│   ├── pos/                        # Kasir Front-End, Scanner, Cart & Checkout
│   │   ├── data/                   # transaction_repository.dart, cart_item_model.dart
│   │   ├── presentation/           # pos_screen.dart, scanner_view.dart, cart_sheet.dart, receipt_dialog.dart
│   │   └── providers/              # cart_provider.dart, checkout_provider.dart
│   ├── inventory/                  # Master Produk, ROP Rule, Custom Barcode
│   │   ├── data/                   # product_repository.dart, product_model.dart
│   │   ├── presentation/           # product_list_screen.dart, product_form_screen.dart, barcode_gen_screen.dart
│   │   └── providers/              # product_provider.dart
│   ├── ews/                        # Early Warning System & Alerts
│   │   ├── data/                   # ews_repository.dart, alert_model.dart
│   │   ├── presentation/           # alert_center_screen.dart, alert_badge_widget.dart
│   │   ├── providers/              # ews_provider.dart
│   │   └── services/               # fcm_service.dart, rop_calculator.dart
│   ├── analytics/                  # BI Dashboard, fl_chart, Quick Insights
│   │   ├── presentation/           # admin_dashboard_screen.dart, widgets/ (charts, insight cards)
│   │   └── providers/              # analytics_provider.dart
│   └── reports/                    # Shift Recap, Audit Trail, Export PDF
│       ├── presentation/           # shift_summary_screen.dart, report_export_screen.dart
│       └── services/               # pdf_generator_service.dart, excel_export_service.dart
└── main.dart                       # Entry point, Firebase.initializeApp()
```

### 1.4. Skema Basis Data Cloud Firestore
1. **`users`**
   - `uid` (string): Firebase Auth UID
   - `nama_lengkap` (string)
   - `email` (string)
   - `role` (string: `'admin'` | `'kasir'`)
   - `fcm_token` (string)
   - `status_aktif` (bool)
   - `created_at` (timestamp)

2. **`products`**
   - `id_produk` (string, auto-id)
   - `sku_barcode` (string, unique indexed)
   - `nama_produk` (string)
   - `kategori` (string)
   - `harga_beli` (number)
   - `harga_jual` (number)
   - `stok_saat_ini` (int)
   - `safety_stock` (int)
   - `lead_time_days` (int)
   - `avg_daily_sales` (number)
   - `reorder_point` (int): Formulasi $(d \times L) + SS$
   - `is_custom_barcode` (bool)
   - `updated_at` (timestamp)

3. **`transactions`**
   - `id_transaksi` (string)
   - `no_struk` (string, e.g. `TRX-20261019-001`)
   - `kasir_id` (string)
   - `nama_kasir` (string)
   - `tanggal_waktu` (timestamp)
   - `subtotal` (number)
   - `total_bayar` (number)
   - `uang_diterima` (number)
   - `uang_kembalian` (number)
   - `total_modal` (number)
   - `margin_keuntungan` (number)
   - `status` (string: `'completed'` | `'pending_sync'`)
   - `items` (array of objects):
     - `id_produk`, `sku_barcode`, `nama_produk`, `harga_beli`, `harga_jual`, `qty`, `subtotal`

4. **`ews_alerts`**
   - `id_alert` (string)
   - `id_produk` (string)
   - `nama_produk` (string)
   - `stok_saat_ini` (int)
   - `reorder_point` (int)
   - `level` (string: `'critical'` jika $\le 0.5 \times ROP$, `'warning'` jika $\le ROP$)
   - `status` (string: `'unread'` | `'acknowledged'`)
   - `created_at` (timestamp)

---

## 2. DETAIL WORK BREAKDOWN & SPRINT TICKETS

---

### SPRINT 0: Setup Lingkungan, Inisialisasi Proyek & Pondasi Dasar (Minggu 1 - 2)
**Tujuan Sprint**: Menyiapkan fondasi Flutter, struktur folder Clean Architecture, tema UI yang ramah ritel, dan integrasi dasar Firebase.

| Task ID | Nama Task | Prioritas | Estimasi | Deskripsi & Langkah Implementasi | Kriteria Selesai (*Definition of Done*) |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **TASK-001** | Inisialisasi Proyek Flutter & Konfigurasi Build | P0 | 1 Hari | Jalankan `flutter create` dengan package name `com.maftuhah.mobile_pos`, atur target SDK Android (minSdk 21, compileSdk 34+). | **[SELESAI]** Proyek berhasil diinisialisasi dan di-build. |
| **TASK-002** | Setup Library & Dependencies di `pubspec.yaml` | P0 | 0.5 Hari | Tambahkan library: `flutter_riverpod`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `mobile_scanner`, `barcode_widget`, `fl_chart`, `pdf`, `printing`, `intl`. | **[SELESAI]** `flutter pub get` berhasil dieksekusi tanpa error. |
| **TASK-003** | Implementasi Struktur Direktori Clean Architecture | P0 | 0.5 Hari | Buat folder `core/` (constants, theme, utils) dan `features/` (auth, pos, inventory, ews, analytics, reports). | **[SELESAI]** Direktori dan model data (`UserModel`, `ProductModel`, dll.) lengkap. |
| **TASK-004** | Desain Sistem Tema Ritel (High-Contrast & Large Touch Targets) | P1 | 1 Hari | Konfigurasi `AppTheme` dengan warna primer profesional (Navy/Emerald), tombol besar (min-height 52px), tipografi Google Fonts, format Rupiah (`Rp xxx.xxx`). | **[SELESAI]** `AppTheme`, `AppColors`, dan `CurrencyFormatter` siap pakai. |
| **TASK-005** | Konfigurasi Firebase Project & Firebase CLI | P0 | 1 Hari | Buat project Firebase di Google Cloud Console, daftarkan SHA-1 & SHA-256 Android, unduh `google-services.json`, dan inisialisasi `Firebase.initializeApp()`. | Menunggu pendaftaran project Firebase oleh pengguna. |

---

### SPRINT 1: Autentikasi, Role-Based Access Control & Manajemen Sesi (Minggu 3 - 4)
**Tujuan Sprint**: Pengguna dapat login dan diarahkan ke antarmuka yang tepat sesuai hak akses (Admin vs Kasir) dengan Firestore Security Rules yang ketat.

| Task ID | Nama Task | Prioritas | Estimasi | Deskripsi & Langkah Implementasi | Kriteria Selesai (*Definition of Done*) |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **TASK-101** | Antarmuka Layar Login & Validasi Form | P0 | 1 Hari | Buat UI Login dengan input Email & Password, validasi input, status loading, dan penanganan pesan error yang informatif. | Form login responsif, validasi mencegah input kosong/format salah. |
| **TASK-102** | Service Autentikasi Firebase & State Riverpod | P0 | 1.5 Hari | Implementasi `AuthRepository` menggunakan `firebase_auth`, sinkronkan profil pengguna dari koleksi Firestore `users`, ekspos via `authStateProvider`. | Status login persisten saat aplikasi ditutup dan dibuka kembali. |
| **TASK-103** | Dynamic Splash Screen & Role-Based Routing Guard | P0 | 1 Hari | Splash screen memeriksa status login: Jika belum login $\rightarrow$ `LoginScreen`, jika Role `kasir` $\rightarrow$ `PosScreen`, jika Role `admin` $\rightarrow$ `AdminDashboardScreen`. | Pengguna otomatis diarahkan ke layar sesuai role tanpa *flashing screen*. |
| **TASK-104** | Aturan Keamanan Firestore (*Security Rules*) | P0 | 1 Hari | Buat rules Firestore: hanya admin yang dapat mengubah katalog `products` dan membaca `harga_beli`; kasir hanya bisa membaca `products` dan menulis ke `transactions`. | Pengujian simulator rules Firestore berhasil menolak akses ilegal. |
| **TASK-105** | Sesi Shift Kasir & Tombol Logout Aman | P1 | 1 Hari | Simpan waktu mulai shift kasir, catat identitas kasir yang aktif, serta konfirmasi modal dialog saat logout. | Kasir dapat logout dengan aman dan sesi shift tercatat. |

---

### SPRINT 2: Front-End POS, Kamera Barcode Scanner & Transaksi Kasir (Minggu 5 - 7)
**Tujuan Sprint**: Kasir dapat memindai barcode fisik, menambah item ke keranjang, mencari barang manual, dan memproses transaksi checkout secara atomik beserta dukungan offline.

| Task ID | Nama Task | Prioritas | Estimasi | Deskripsi & Langkah Implementasi | Kriteria Selesai (*Definition of Done*) |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **TASK-201** | Integrasi Viewfinder Barcode Scanner (`mobile_scanner`) | P0 | 2 Hari | Implementasi pemindai kamera dengan kotak overlay bidik (*scanning window*), tombol senter (*torch*), peralihan kamera depan/belakang, dan suara "bip" saat sukses. | **[SELESAI]** `BarcodeScannerScreen` terintegrasi dengan mode continuous & single scan, overlay laser, haptic/sound, fallback error. |
| **TASK-202** | Engine Keranjang Belanja Dinamis (*Cart State*) | P0 | 2 Hari | State Riverpod untuk keranjang: tambah item dari scan/search, ubah kuantitas, hapus item, hitung otomatis subtotal, diskon, dan kembalian tunai. | Perhitungan keranjang akurat, reaktif tanpa re-render berlebih. |
| **TASK-203** | Fitur Pencarian Cepat ("Tap & Search") | P0 | 1.5 Hari | Katalog visual dengan search bar instan (filter nama / SKU) dan grid item untuk antisipasi jika barcode fisik tergores/rusak. | Kasir dapat memilih produk dalam 2 sentuhan saat scanner tidak digunakan. |
| **TASK-204** | Eksekusi Checkout Atomik (Firestore Batch Write) | P0 | 2 Hari | Proses checkout multi-item: simpan dokumen `transactions` baru dan potong `stok_saat_ini` pada masing-masing dokumen `products` secara atomik (*Batch/Transaction*). | Transaksi tercatat lengkap dan stok terpotong tanpa risiko *race condition*. |
| **TASK-205** | Dialog Pembayaran & Tampilan Struk Digital | P1 | 1.5 Hari | Modal dialog pembayaran tunai dengan tombol cepat nominal uang (Rp 20.000, 50.000, 100.000, Uang Pas), hitung kembalian, dan modal struk selesai. | Kembalian dihitung otomatis dan tombol uang pas mempermudah kasir. |
| **TASK-206** | Kapabilitas Offline-First & Antrean Sinkronisasi | P0 | 2 Hari | Aktifkan Firestore *offline persistence*. Tandai transaksi offline dengan `status: 'pending_sync'`, sinkronisasi otomatis saat terhubung kembali ke internet. | Transaksi tetap berjalan saat mode pesawat aktif, lalu tersinkronisasi saat online. |
| **TASK-207** | Rekap Shift Harian Kasir (*Cash Drawer Tally*) | P1 | 1.5 Hari | Layar *read-only* riwayat transaksi per kasir per shift, total omzet tunai shift berjalan untuk pencocokan fisik laci kasir. | Kasir dapat melihat rekapitulasi penjualan shift harian sebelum tutup buku. |

---

### SPRINT 3: Master Produk, Logika Reorder Point & Custom Barcode Generator (Minggu 8 - 9)
**Tujuan Sprint**: Admin dapat mengelola katalog master produk, menghitung ambang batas batas kritis (ROP), dan mencetak barcode kustom untuk barang curah.

| Task ID | Nama Task | Prioritas | Estimasi | Deskripsi & Langkah Implementasi | Kriteria Selesai (*Definition of Done*) |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **TASK-301** | CRUD Master Produk & Kategori | P0 | 2 Hari | Layar daftar produk dengan pencarian & filter, form tambah/edit produk (nama, kategori, harga beli, harga jual, stok awal). | Admin dapat menambah, mengedit, dan menghapus produk dengan validasi form. |
| **TASK-302** | Formulasi & Konfigurasi Ambang Batas ROP | P0 | 1.5 Hari | Form input parameter inventaris: *Safety Stock* ($SS$), *Lead Time* ($L$), dan rata-rata konsumsi ($d$). Kalkulator otomatis: $ROP = (d \times L) + SS$. | Nilai `reorder_point` otomatis terkalkulasi dan tersimpan di produk. |
| **TASK-303** | Generator Barcode Barang Curah (`barcode_widget`) | P0 | 2 Hari | Pembuatan SKU otomatis berawalan khusus (misal: `9900xxxx`) untuk barang tanpa kemasan pabrik (beras, telur, minyak curah), rendering grafis Code128. | Barcode kustom muncul di layar dan dapat dipindai oleh modul kasir. |
| **TASK-304** | Fitur Cetak / Simpan Label Barcode Kustom | P1 | 1.5 Hari | Integrasi paket `printing` untuk membuat dokumen siap cetak ukuran label stiker (misal 50x30mm) atau simpan sebagai gambar ke galeri. | Label barcode dapat dicetak ke printer termal / printer stiker. |

---

### SPRINT 4: Early Warning System (EWS) & Cloud Messaging FCM (Minggu 9 - 10)
**Tujuan Sprint**: Sistem secara otomatis mendeteksi ketika stok menembus batas kritis dan mengirimkan notifikasi *high-priority* ke perangkat Admin.

| Task ID | Nama Task | Prioritas | Estimasi | Deskripsi & Langkah Implementasi | Kriteria Selesai (*Definition of Done*) |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **TASK-401** | Logika Trigger Peringatan Dini (EWS Evaluator) | P0 | 1.5 Hari | Logika evaluasi saat transaksi terjadi: jika `stok_saat_ini <= reorder_point`, buat entri dokumen baru di koleksi `ews_alerts` dengan status `critical` atau `warning`. | Dokumen alert otomatis terbuat saat stok melewati ambang batas. |
| **TASK-402** | Integrasi Firebase Cloud Messaging (FCM High Priority) | P0 | 2 Hari | Konfigurasi registrasi FCM token perangkat Admin, pengiriman notifikasi latar belakang (*background message*) dengan payload `priority: high` saat alert terbentuk. | Notifikasi muncul di status bar HP Admin dalam waktu <5 detik setelah checkout. |
| **TASK-403** | Pusat Notifikasi Peringatan Stok (*Alert Center*) | P0 | 1.5 Hari | Layar di aplikasi Admin berisi daftar produk dengan stok kritis, indikator visual warna (Merah = Kritis, Kuning = Waspada), dan tombol *Restock Acknowledged*. | Admin dapat memantau seluruh barang yang wajib dipesan ulang dalam 1 layar. |
| **TASK-404** | Badge Counter Peringatan Dini pada Navigation Bar | P1 | 0.5 Hari | Stream listener Firestore untuk menghitung jumlah alert `unread` dan menampilkannya sebagai badge merah pada icon notifikasi. | Badge angka ter-update secara *real-time* saat terjadi penurunan stok kritis. |

---

### SPRINT 5: Dasbor Analitik Business Intelligence & Ekspor Laporan (Minggu 10 - 11)
**Tujuan Sprint**: Menyajikan visualisasi data penjualan yang mudah dipahami pelaku UMKM (*Mobile BI*) dan menyediakan fitur ekspor laporan audit finansial.

| Task ID | Nama Task | Prioritas | Estimasi | Deskripsi & Langkah Implementasi | Kriteria Selesai (*Definition of Done*) |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **TASK-501** | Widget Agregasi Metrik Finansial Utama | P0 | 1.5 Hari | Ringkasan kartu metrik: Total Omzet Hari Ini/Bulan Ini, Estimasi Laba Bersih, Jumlah Transaksi, dan Rata-rata Nilai Belanja (*Basket Size*). | Angka teragregasi secara tepat dari data transaksi Firestore. |
| **TASK-502** | Grafik Batang Top 5 Produk Terlaris (`fl_chart`) | P0 | 1.5 Hari | Komponen Bar Chart interaktif yang menampilkan 5 produk dengan kuantitas penjualan tertinggi dalam periode terpilih, dilengkapi label dan tooltip. | Grafik batang ter-render halus dengan data dinamis. |
| **TASK-503** | Grafik Garis Tren Penjualan Harian/Mingguan (`fl_chart`) | P0 | 1.5 Hari | Komponen Line Chart kurva tren omzet dengan gradien warna elegan, pemilih rentang waktu (7 Hari Terakhir, 30 Hari Terakhir). | Kurva tren penjualan tersaji informatif dan interaktif. |
| **TASK-504** | Kartu Rekomendasi Cerdas (*Quick Insight Cards*) | P1 | 1 Hari | Modul pembuat kalimat ringkas otomatis penjelas tren (contoh: *"Penjualan Beras meningkat 25% minggu ini. Pertimbangkan restock sebelum Jumat"*). | Rekomendasi teks otomatis muncul untuk membantu kognisi pengusaha UMKM. |
| **TASK-505** | Generator Laporan PDF & Ekspor Excel/CSV | P0 | 2 Hari | Fitur ekspor laporan transaksi berkala (harian/bulanan), layout struk/faktur PDF formal siap cetak dan file CSV/Excel untuk pembukuan akuntansi. | File PDF rapi dan spreadsheet dapat diunduh serta dibuka di aplikasi pembaca file. |

---

### SPRINT 6: Pengujian Kualitas, Resiliensi, UAT & Release (Minggu 12 - 14)
**Tujuan Sprint**: Memvalidasi seluruh fungsionalitas, menguji resiliensi offline, mengukur latensi scanner & EWS, serta menyiapkan file rilis final.

| Task ID | Nama Task | Prioritas | Estimasi | Deskripsi & Langkah Implementasi | Kriteria Selesai (*Definition of Done*) |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **TASK-601** | Pengujian Fungsional Black Box Terstruktur | P0 | 2 Hari | Menjalankan seluruh skenario uji kasus: kalkulasi keranjang, validasi form, hak akses RBAC, dan integritas pemotongan stok. | 100% *test case* utama lolos (*passed*) tanpa blocker. |
| **TASK-602** | Uji Resiliensi Jaringan (Offline-to-Online Sync Test) | P0 | 1.5 Hari | Simulasi kasir memproses 10 transaksi berturut-turut pada mode pesawat, lalu menyambungkan kembali koneksi internet. | Semua transaksi offline tersinkronisasi ke Cloud tanpa duplikasi data. |
| **TASK-603** | Uji Benchmark Latensi Scanner & Notifikasi EWS | P0 | 1.5 Hari | Pengukuran latensi pemindaian kamera (<1,0 detik) dan kecepatan tiba notifikasi FCM (<5,0 detik) menggunakan logging timestamp presisi. | Hasil pengujian memenuhi kriteria performa yang diajukan di skripsi/proposal. |
| **TASK-604** | User Acceptance Testing (UAT) & Evaluasi SUS | P1 | 2 Hari | Uji coba langsung bersama pemilik toko ritel dan staf kasir, pengisian kuesioner *System Usability Scale* (SUS). | Skor SUS $\ge 75$ (kategori *Good / Excellent*). |
| **TASK-605** | Build Release APK/AAB & Penandatanganan Aplikasi | P0 | 1 Hari | Konfigurasi release build di `build.gradle`, optimasi proguard / code shrinking, pembuatan release keystore, dan compile APK. | File installer APK siap pasang dan bebas dari *debug banner*. |
| **TASK-606** | Penyusunan User Manual Guide & Dokumentasi Teknis | P1 | 2 Hari | Pembuatan buku panduan operasional bergambar untuk kasir dan admin, serta penyelesaian dokumen laporan Bab 4 & 5. | User manual dan dokumentasi arsitektur selesai lengkap. |

---

## 3. CHECKLIST EKSEKUSI HARI PERTAMA (KICKSTART SPRINT 0)

Berikut adalah langkah praktis yang dapat langsung dieksekusi bersama untuk memulai basis kode:

1. [x] **Inisialisasi Project Flutter**:
   Berhasil dibuat menggunakan Flutter 3.47.7 di root direktori proyek (`maftuhah_mobile`).
2. [x] **Tambahkan Dependencies Utama**:
   Semua dependensi (`flutter_riverpod`, `mobile_scanner`, `fl_chart`, `pdf`, `printing`, `firebase_core`, dll.) berhasil diunduh dan diverifikasi via `pubspec.yaml`.
3. [x] **Bangun Struktur Folder Clean Architecture**:
   Folder `core/` dan `features/` (auth, pos, inventory, ews, analytics, reports) beserta model data (`user_model`, `product_model`, `cart_item_model`, `transaction_model`, `ews_alert_model`) telah diimplementasikan.
4. [x] **Buat File Konfigurasi Tema & Konstanta Dasar**:
   Telah dibuat `app_colors.dart`, `app_strings.dart`, `app_sizes.dart`, `app_theme.dart` (Material 3 retail design), dan `currency_formatter.dart` (Format Rupiah mandiri).
5. [ ] **Hubungkan Firebase**:
   Mengonfigurasi `firebase_options.dart` atau menambahkan `google-services.json` ke folder `android/app/`.
