# DOKUMEN RENCANA KERJA PENGEMBANGAN SISTEM (WORK PLAN & PROJECT ROADMAP)
## "Sistem Kasir Mobile Berbasis Barcode Scanner dengan Fitur Visualisasi Data dan Peringatan Dini (Early Warning System) Persediaan Barang"

---

### INFORMASI PROYEK
- **Judul Proyek / Skripsi**: Sistem Kasir Mobile Berbasis Barcode Scanner dengan Fitur Visualisasi Data dan Peringatan Dini (*Early Warning System*) Persediaan Barang
- **Model Pengembangan**: *Agile / Evolutionary Prototyping* (Iteratif & Adaptif)
- **Platform Sasaran**: Mobile (*Cross-Platform*: Android & iOS)
- **Teknologi Utama**: Flutter (Dart), Firebase (Auth, Firestore, Cloud Messaging), Riverpod State Management
- **Pendekatan Arsitektur**: *Two-Sided Application* (*Role-Based Access Control* - Admin & Kasir) dengan kapabilitas *Offline-First Resilience*
- **Target Waktu**: 14 Minggu (3,5 Bulan)

---

## 1. PENDAHULUAN & LANDASAN PENGEMBANGAN

### 1.1. Latar Belakang & Urgensi
Berdasarkan kajian komparatif operasional ritel, proses pencatatan kasir dan audit stok konvensional memakan waktu rata-rata 15 detik per SKU dan rawan kesalahan (*human error*), serta memakan waktu hingga 25 menit untuk *stock opname* 100 barang. Integrasi pemindai barcode kamera gawai cerdas memangkas waktu proses hingga di bawah 3 detik (efisiensi >80%) dan mengeliminasi salah input harga.

Selain itu, pengelolaan inventaris ritel kerap menghadapi dua ancaman kritis: *overstocking* (dana beku) dan *stockout* (kehilangan penjualan & kepercayaan konsumen). Keberadaan modul *Early Warning System* (EWS) dengan kalkulasi *Reorder Point* (ROP) dan visualisasi data penjualan interaktif menjadi kebutuhan esensial untuk mentransformasi manajemen inventaris dari reaktif menjadi proaktif-prediktif.

### 1.2. Integrasi Penyelesaian Celah Penelitian (*Research Gaps*)
Rencana kerja ini mengintegrasikan secara eksplisit solusi atas 5 (*lima*) celah riset yang telah diidentifikasi:
1. **Analytic-Inventory Disconnect Mitigation**: Logika EWS tidak hanya menggunakan nilai ambang statis, melainkan menyediakan formulasi kalkulasi batas kritis (*Reorder Point* = *Average Usage* × *Lead Time* + *Safety Stock*) yang adaptif dengan pertimbangan sensitivitas biaya kelangkaan barang.
2. **Offline-First Resilience**: Mengimplementasikan *offline caching* dan *background sync queue* lokal agar aplikasi kasir tetap dapat memproses transaksi penjualan dan pencarian barcode meski koneksi internet terputus, serta melakukan sinkronisasi otomatis saat jaringan pulih tanpa tabrakan data (*data conflict*).
3. **Cognitive Load Reduction**: Dasbor analitik admin didesain dengan hierarki informasi yang ramah UMKM (*Mobile-First BI*), mengombinasikan visualisasi *fl_chart* dengan *Quick Insight Cards* (teks ringkas otomatis penjelas tren) agar mudah diinterpretasikan oleh pelaku usaha dengan literasi data terbatas.
4. **Financial Reporting Integrity**: Menyediakan audit trail transaksi per kasir/shift, perhitungan omzet akurat, dan ekspor dokumen laporan standar (PDF & Excel) untuk menunjang akuntabilitas pembukuan.
5. **Socio-Technical Adoption Barrier**: Fitur *Custom Barcode Generator* untuk barang curah/tanpa kemasan pabrik (beras kiloan, telur, dll.), antarmuka kamera smartphone tanpa perangkat scanner eksternal mahal, dan navigasi yang sangat sederhana untuk menekan kurva belajar (*learning curve*) kasir.

---

## 2. ARSITEKTUR SISTEM & SPESIFIKASI TEKNIS

### 2.1. Arsitektur Dua Sisi (*Two-Sided RBAC Architecture*)
Aplikasi dikembangkan dalam satu basis kode (*single codebase*) dengan dua antarmuka terisolasi berdasarkan peran pengguna:
```
                               +-----------------------------+
                               |    Flutter Mobile Engine    |
                               +-----------------------------+
                                              |
                                   [Firebase Authentication]
                                              |
                       +----------------------+----------------------+
                       |                                             |
             [Role: "kasir"]                                [Role: "admin"]
                       |                                             |
        +--------------+--------------+               +--------------+--------------+
        | Front-End POS Operasional   |               | Back-Office & Business Intel|
        | - Kamera Barcode Scanner    |               | - Dashboard Visual fl_chart |
        | - Keranjang & Quick Checkout|               | - Penerima EWS Notification |
        | - Pencarian Manual Produk   |               | - Master Katalog & ROP Rule |
        | - Rekap Shift Harian        |               | - Custom Barcode Generator  |
        | - Offline Local Caching     |               | - Ekspor Laporan PDF/Excel  |
        +-----------------------------+               +-----------------------------+
                       \                                             /
                        \                                           /
                         +--------------------+--------------------+
                                              |
                                  [Cloud Firestore NoSQL]
                                  - users
                                  - products
                                  - transactions
                                              |
                                [Firebase Cloud Messaging]
                                (Push Notification Trigger)
```

### 2.2. Spesifikasi Tech Stack & Library
| Komponen | Teknologi Terpilih | Justifikasi & Peran |
| :--- | :--- | :--- |
| **Mobile Framework** | Flutter SDK (Dart) | Performa kompilasi *native*, multiplatform (Android/iOS), rendering UI konsisten |
| **State Management** | Riverpod | Pengelolaan *state* reaktif keranjang belanja (*cart*), sesi, dan sinkronisasi tanpa *lag* |
| **Database & Auth** | Firebase Cloud Firestore & Auth | Database NoSQL *real-time*, penyimpanan data offline otomatis (*persistence*), RBAC aman |
| **Push Notification** | Firebase Cloud Messaging (FCM) | Pengiriman notifikasi latar belakang instan untuk peringatan dini stok (*EWS*) ke ponsel admin |
| **Barcode Scanner** | `mobile_scanner` | Pemanfaatan kamera resolusi tinggi dengan latensi pemindaian rendah (sub-detik) |
| **Barcode Generator** | `barcode_widget` | Rendering grafis barcode Code128/EAN-13 untuk SKU barang curah di layar |
| **Data Analytics Chart** | `fl_chart` | Pembuatan grafik batang (*Bar Chart*) Top 5 terlaris & grafik garis (*Line Chart*) tren penjualan |
| **Export Reporting** | `pdf` & `printing` | Pembentukan dokumen laporan transaksi dan faktur yang siap unduh/cetak |

### 2.3. Struktur Basis Data (Cloud Firestore Collections)
1. **`users`**: `{ uid, nama_lengkap, role ('admin'|'kasir'), fcm_token, status_aktif, created_at }`
2. **`products`**: `{ id_produk, sku_barcode, nama_produk, harga_beli, harga_jual, stok_saat_ini, batas_kritis, is_custom_barcode, kategori, updated_at }`
3. **`transactions`**: `{ id_transaksi, tanggal_waktu, kasir_id, nama_kasir, total_harga, total_modal, margin_keuntungan, items: [{ id_produk, nama, qty, harga_satuan, subtotal }] }`

---

## 3. WORK BREAKDOWN STRUCTURE (WBS) & TAHAPAN KERJA

Proyek dibagi menjadi **6 Fase Utama** dengan pendekatan iteratif terukur:

```
[Fase 1: Inisiasi & Desain UI/UX] 
       ↓
[Fase 2: Infrastruktur Backend & Core Data Layer]
       ↓
[Fase 3: Pengembangan Modul Kasir (POS, Scanner & Offline Support)]
       ↓
[Fase 4: Pengembangan Modul Admin (Analytics, EWS & Barcode Generator)]
       ↓
[Fase 5: Pengujian Terpadu (Testing, QA & Validasi Resiliensi)]
       ↓
[Fase 6: Deployment, Pelatihan Pengguna & Finalisasi Dokumentasi]
```

---

### DETAIL AKTIVITAS SETIAP FASE

#### FASE 1: Inisiasi, Analisis Kebutuhan, & Desain Antarmuka (Minggu 1 – 2)
- **1.1. Finalisasi Spesifikasi Kebutuhan Perangkat Lunak (SKPL/SRS)**:
  - Penegasan batasan hak akses (Admin vs Kasir).
  - Penentuan format SKU barang curah (*custom barcode*).
  - Standarisasi formula batas kritis (*Reorder Point* / EWS).
- **1.2. Desain Arsitektur & Wireframing**:
  - Penyusunan *User Flow* transaksi kasir dan navigasi dasbor admin.
  - Perancangan *Wireframe* & *High-Fidelity Mockup* (Figma) dengan prinsip *Low Cognitive Load* (warna bersih, kontras tinggi, tombol aksi besar untuk lingkungan toko).
- **1.3. Setup Repository & Standar Kode**:
  - Konfigurasi Git repository, branch strategy (`main`, `develop`, `feature/*`).
  - Inisialisasi proyek Flutter & struktur direktori *feature-driven clean architecture*.

#### FASE 2: Infrastruktur Backend, Skema Data & Autentikasi (Minggu 3 – 4)
- **2.1. Konfigurasi Proyek Firebase**:
  - Setup Firebase Project, integrasi SHA-1 / SHA-256 Android, dan konfigurasi iOS Bundle ID.
  - Implementasi *Firebase Authentication* (Email/Password).
- **2.2. Firestore Data Modeling & Security Rules**:
  - Pembuatan skema koleksi: `users`, `products`, `transactions`.
  - Konfigurasi *Firestore Security Rules* berbasis *Role*:
    - Hanya Admin yang dapat menulis/mengubah koleksi `products` dan membaca `harga_beli`.
    - Kasir hanya diizinkan membaca `products` dan membuat dokumen baru di `transactions`.
- **2.3. Autentikasi & Routing RBAC**:
  - Implementasi Splash Screen yang mendeteksi sesi aktif dan hak akses (*role-based navigation*).
  - Modul Manajemen Profil Pengguna.

#### FASE 3: Modul Operasional Kasir (Front-End POS) (Minggu 5 – 7)
- **3.1. Integrasi Barcode Scanner Kamera**:
  - Implementasi `mobile_scanner` dengan kontrol lampu kilat (*torch*), peralihan kamera, dan pembatasan area bidik (*scanning overlay*).
  - Optimasi pemrosesan frame gambar untuk respon instan (<0,8 detik).
- **3.2. Keranjang Belanja (*Cart Engine*) & Quick Search**:
  - Pengelolaan *state* keranjang dinamis menggunakan Riverpod (tambah, kurangi kuantitas, hapus, hitung total subtotal dan kembalian).
  - Fitur "Tap & Search" (katalog visual dan *search bar* responsif) untuk antisipasi kode batang rusak.
- **3.3. Transaksi Checkout Atomik & Pengurangan Stok**:
  - Eksekusi transaksi multi-dokumen (*Firestore Batch Write / Transaction*): mencatat struk penjualan sekaligus memotong `stok_saat_ini` secara konsisten tanpa risiko *race condition*.
- **3.4. Implementasi Offline-First Caching**:
  - Pengaktifan *Firestore Offline Persistence* dan *local queue mechanism* agar transaksi kasir tidak terhenti saat internet terputus.
- **3.5. Rekap Shift & Riwayat Transaksi Kasir**:
  - Halaman riwayat penjualan harian berstatus *read-only* per akun kasir untuk rekonsiliasi uang fisik di laci kasir (*cash drawer tallying*).

#### FASE 4: Modul Admin, Analytics & Early Warning System (Minggu 8 – 10)
- **4.1. Manajemen Master Produk & ROP Rule**:
  - Form CRUD Produk (nama, SKU, harga beli, harga jual, stok awal, batas kritis/ROP).
  - Pengaturan ambang batas stok dinamis per barang.
- **4.2. Custom Barcode Generator (Solusi Barang Curah)**:
  - Generator SKU unik terstruktur untuk barang eceran/kiloan (misal: awalan "9900xxxx").
  - Rendering visual barcode Code128 menggunakan `barcode_widget` dan fitur cetak/simpan visual untuk ditempel pada wadah/plastik kemasan.
- **4.3. Implementasi Early Warning System (EWS) & Cloud Messaging**:
  - Logika verifikasi ambang batas: *Trigger* otomatis ketika `stok_saat_ini <= batas_kritis`.
  - Integrasi Firebase Cloud Messaging (FCM): pengiriman notifikasi instan berlatar belakang (*Background/Foreground Notification*) ke token perangkat Admin.
  - Halaman Pusat Notifikasi Peringatan Stok di aplikasi Admin dengan tanda status prioritas (*Kritis*, *Waspada*, *Aman*).
- **4.4. Dashboard Business Intelligence & fl_chart**:
  - Widget Agregasi Metrik Finansial: Total Omzet, Estimasi Laba Bersih, Jumlah Transaksi Bulan Berjalan.
  - *Bar Chart* Top 5 Produk Terlaris (*Fast-Moving Items*).
  - *Line Chart* Tren Penjualan Harian/Mingguan.
  - Kartu Rekomendasi Cerdas (*Insight Card* berbasis teks singkat untuk kemudahan kognisi UMKM).
- **4.5. Modul Ekspor Laporan Finansial**:
  - Generator laporan penjualan periode kustom (harian, mingguan, bulanan).
  - Format output dokumen PDF terstruktur (siap cetak via Bluetooth/WiFi printer) dan file spreadsheet (CSV/Excel).

#### FASE 5: Pengujian Kualitas, Resiliensi & Optimasi (Minggu 11 – 12)
- **5.1. Pengujian Fungsional (Black Box & White Box Testing)**:
  - Validasi semua skenario kasus uji: pemindaian berbagai kondisi pencahayaan, kalkulasi keranjang belanja, pembagian hak akses pengguna.
- **5.2. Pengujian Resiliensi Jaringan (Offline-to-Online Sync)**:
  - Simulasi pemutusan koneksi saat kasir memproses 10+ transaksi berturut-turut, kemudian pemulihan jaringan untuk memverifikasi akurasi sinkronisasi stok dan integritas data cloud.
- **5.3. Pengujian Latensi Scanner & Akurasi EWS**:
  - Tolok ukur kecepatan deteksi barcode kamera (<1 detik).
  - Uji ketepatan waktu pengiriman notifikasi FCM EWS saat stok menembus batas kritis (<5 detik).
- **5.4. User Acceptance Testing (UAT)**:
  - Uji keterpakaian langsung bersama pemilik toko (Admin) dan staf kasir.
  - Pengukuran skor kegunaan (*System Usability Scale* / SUS).

#### FASE 6: Deployment, Pelatihan & Finalisasi Pelaporan (Minggu 13 – 14)
- **6.1. Build & Release Preparation**:
  - Optimasi ukuran bundle aplikasi (Flutter APK / App Bundle / IPA).
  - Konfigurasi penandatanganan aplikasi (*Release KeyStore signing*).
- **6.2. Penyusunan Buku Panduan & Pelatihan Staf**:
  - Pembuatan *User Manual Guide* (Panduan Praktis Pengoperasian Kasir & Admin).
  - Sesi demonstrasi dan pendampingan implementasi di toko ritel.
- **6.3. Finalisasi Laporan Ilmiah / Skripsi**:
  - Penyusunan Bab 4 (Hasil Implementasi & Pembahasan Analisis Data).
  - Penyusunan Bab 5 (Kesimpulan, Batasan, dan Saran Pengembangan Lanjutan).
  - Pengemasan dokumentasi teknis dan arsip kode sumber (*source code*).

---

## 4. JADWAL KERJA & TIMELINE (GANTT CHART)

| ID | Aktivitas / Tahapan Kerja | M1 | M2 | M3 | M4 | M5 | M6 | M7 | M8 | M9 | M10 | M11 | M12 | M13 | M14 | Deliverables Utama |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **1.1** | Analisis Kebutuhan & SRS | █ | | | | | | | | | | | | | | Dokumen Spesifikasi SRS |
| **1.2** | Perancangan UI/UX & Prototipe Figma | █ | █ | | | | | | | | | | | | | Prototipe UI Mockup Figma |
| **1.3** | Setup Repository & Clean Architecture | | █ | | | | | | | | | | | | | Baseline Flutter Project |
| **2.1** | Konfigurasi Firebase Auth & Service | | | █ | | | | | | | | | | | | Firebase Config & Keys |
| **2.2** | Desain Database Firestore & Rules | | | █ | █ | | | | | | | | | | | Schema Collections & Rules |
| **2.3** | Implementasi Sesi & Routing RBAC | | | | █ | | | | | | | | | | | Modul Login & Auth Guard |
| **3.1** | Modul Barcode Scanner Kamera | | | | | █ | █ | | | | | | | | | Fitur Scanner `mobile_scanner` |
| **3.2** | State Keranjang & Manual Search | | | | | █ | █ | | | | | | | | | Modul Cart & Tap Search |
| **3.3** | Batch Checkout & Pemotongan Stok | | | | | | | █ | | | | | | | | Checkout Engine & Transaksi |
| **3.4** | Implementasi Offline Persistence | | | | | | | █ | | | | | | | | Offline Caching Support |
| **3.5** | Rekap Shift Kasir (Read-Only) | | | | | | | █ | | | | | | | | Halaman Shift Harian |
| **4.1** | Master Produk & Konfigurasi ROP | | | | | | | | █ | | | | | | | CRUD Katalog & Batas Kritis |
| **4.2** | Generator Barcode Barang Curah | | | | | | | | █ | █ | | | | | | Fitur Cetak SKU Curah |
| **4.3** | Early Warning System (EWS) & FCM | | | | | | | | | █ | █ | | | | | Push Notification Stok Kritis |
| **4.4** | Dashboard Visualisasi Data fl_chart| | | | | | | | | █ | █ | | | | | Grafik Omzet & Top 5 Item |
| **4.5** | Ekspor Laporan Finansial (PDF/XLS)| | | | | | | | | | █ | | | | | Modul Export PDF/Excel |
| **5.1** | Pengujian Black Box & Validasi | | | | | | | | | | | █ | | | | Laporan Hasil Pengujian |
| **5.2** | Uji Resiliensi Jaringan (Offline Sync)| | | | | | | | | | | █ | █ | | | Matriks Uji Konektivitas |
| **5.3** | UAT Bersama Mitra Pengguna | | | | | | | | | | | | █ | | | Dokumen Evaluasi UAT / SUS |
| **6.1** | Build APK/Bundle Rilis | | | | | | | | | | | | | █ | | File Installer APK / IPA |
| **6.2** | Pelatihan & Serah Terima Sistem | | | | | | | | | | | | | █ | █ | Panduan Pengguna (User Manual)|
| **6.3** | Penyusunan Laporan Skripsi Lengkap | | | | | | | | | | | | | █ | █ | Dokumen Naskah Skripsi Bab 1-5|

---

## 5. MATRIKS TANGGUNG JAWAB (RACI MATRIX)

Keterangan:
- **R (Responsible)**: Pelaksana yang mengerjakan tugas langsung.
- **A (Accountable)**: Penanggung jawab utama keberhasilan hasil tugas.
- **C (Consulted)**: Pihak yang dimintai konsultasi/masukan teknis/akademis.
- **I (Informed)**: Pihak yang diberi laporan hasil perkembangan.

| Aktivitas Pengembangan | Pengembang Aplikasi (Lead Dev) | Dosen Pembimbing / Advisor | Mitra Pemilik Toko (Admin) | Staf Kasir (End-User) |
| :--- | :---: | :---: | :---: | :---: |
| Analisis Gap & Desain Solusi | **R / A** | **C** | **C** | **I** |
| Perancangan UI/UX & Alur Kerja | **R** | **C** | **A** | **C** |
| Setup Firebase & Keamanan Data | **R / A** | **C** | **I** | **I** |
| Coding Modul Kasir & Pemindai | **R / A** | **I** | **I** | **C** |
| Coding Modul EWS & Dashboard | **R / A** | **C** | **C** | **I** |
| Pengujian Resiliensi & Skenario Offline | **R / A** | **C** | **I** | **I** |
| User Acceptance Testing (UAT) | **R** | **I** | **A** | **A** |
| Penulisan Naskah Laporan/Skripsi | **R / A** | **A / C** | **I** | **I** |

---

## 6. RENCANA PENGUJIAN DAN PENJAMINAN MUTU (QA PLAN)

| Kategori Pengujian | Objek Pengujian | Metode & Alat | Kriteria Keberhasilan (*Pass Criteria*) |
| :--- | :--- | :--- | :--- |
| **Barcode Scanner Responsiveness** | Kamera HP membaca berbagai jenis barcode fisik & custom | Pengujian empiris dengan pencahayaan rendah & normal | Kecepatan pembacaan <1,0 detik per item, akurasi decoding 100% |
| **Data Integrity on Checkout** | Pemotongan stok multi-item secara simultan | *Batch write stress test* (simulasi 50 transaksi berturut-turut) | Tidak terjadi *negative stock*, seluruh data item tercatat persis di koleksi transaksi |
| **EWS Trigger Latency** | Pengurangan stok menembus `batas_kritis` | Simulasi checkout barang hingga stok = ambang batas | Notifikasi FCM muncul di ponsel Admin dalam waktu <5 detik |
| **Network Resilience (Offline)** | Transaksi saat mode pesawat aktif (*airplane mode*) | Pengujian pemutusan sinyal internet saat checkout | Transaksi tersimpan di cache lokal; otomatis sinkron ke server saat online kembali |
| **Data Visualization Accuracy** | Agregasi total omzet dan Top 5 produk terlaris | Verifikasi silang antara grafik `fl_chart` dengan database | Nilai pada grafik 100% identik dengan hasil perhitungan manual di lembar kerja |
| **Role-Based Security** | Upaya akses modul Admin menggunakan akun Kasir | *Penetration/Access control test* via modifikasi rute aplikasi | Kasir ditolak mengakses menu katalog produk dan dashboard analytics |

---

## 7. MANAJEMEN RISIKO DAN RENCANA MITIGASI

| No | Risiko Potensial | Tingkat Dampak | Probabilitas | Rencana Mitigasi (*Action Plan*) |
| :---: | :--- | :---: | :---: | :--- |
| **1** | **Kamera HP berspesifikasi rendah sulit membaca barcode kecil/rusak** | Tinggi | Sedang | Menyediakan opsi input manual instan ("Tap & Search"), pembatasan resolusi adaptif, dan fitur lampu kilat terintegrasi. |
| **2** | **Koneksi internet toko tidak stabil (*Digital Divide*)** | Tinggi | Tinggi | Mengimplementasikan kapabilitas *Offline-First* penuh dengan Firestore *persistence cache* dan antrean sinkronisasi latar belakang. |
| **3** | **Notifikasi FCM tertahan oleh mekanisme hemat baterai Android (*Doze Mode*)** | Sedang | Sedang | Mengonfigurasi prioritas payload FCM ke `priority: high`, melengkapi dengan *badge* alarm visual di dalam aplikasi saat dibuka. |
| **4** | **Staf kasir enggan/lambat beradaptasi dengan aplikasi (*Adoption Barrier*)** | Sedang | Rendah | Mendesain antarmuka sesederhana mungkin (*Numpad layout*, tombol checkout kontras tinggi), dan menyediakan buku panduan bergambar. |
| **5** | **Banyak barang lokal tidak memiliki barcode pabrik** | Tinggi | Tinggi | Mengimplementasikan fitur *Custom Barcode Generator* langsung di aplikasi Admin untuk mencetak SKU lokal barang kiloan. |

---

## 8. INDIKATOR KEBERHASILAN & DELIVERABLES PROYEK

### 8.1. Luaran Produk (Product Deliverables)
1. **Paket Aplikasi Mobile (.apk / .aab)** yang siap dipasang pada perangkat Android staf dan pemilik toko.
2. **Repositori Kode Sumber Terstruktur**: Basis kode Flutter dengan arsitektur bersih, bebas *lint warning*, terdokumentasi rapi.
3. **Konfigurasi Cloud Backend**: Proyek Firebase aktif dengan aturan keamanan teruji (*Security Rules*) dan indeks database optimal.

### 8.2. Luaran Akademik & Dokumentasi (Academic Deliverables)
1. **Naskah Laporan Skripsi/Penelitian Komprehensif (Bab 1 s.d. Bab 5)** yang memvalidasi efisiensi operasional dan penjawab celah riset.
2. **Dokumen Hasil Pengujian Sistem**: Lembar kerja evaluasi *Black Box*, uji latensi barcode, uji resiliensi sinkronisasi luring, dan kuesioner UAT/SUS.
3. **Buku Panduan Pengguna (*User Manual & Operation SOP*)**: Panduan tata cara instalasi, operasional kasir, pendaftaran barang curah, dan penanganan notifikasi peringatan dini.
