# 💼 Toko Hizwa Database — Sistem Kasir Otomatis MySQL

**Toko Hizwa** adalah rancangan basis data MySQL untuk mendukung operasional **kasir toko retail** dengan fitur **otomatisasi stok dan kas harian**. Database ini cocok untuk pembelajaran, tugas akhir, maupun implementasi usaha skala UMKM.

---

## 📂 Struktur Tabel

| Tabel                  | Deskripsi                                                                 |
|------------------------|---------------------------------------------------------------------------|
| **barang**             | Master data barang: nama, harga beli, harga jual.                        |
| **barang_masuk**       | Catatan penerimaan stok barang masuk.                                     |
| **katalog_barang**     | Rekap stok akhir setiap barang.                                           |
| **barang_terjual**     | Header transaksi penjualan.                                               |
| **rinci_barang_terjual** | Rincian transaksi penjualan (detail barang terjual).                     |
| **buku_kas_harian**    | Pencatatan arus kas harian (penjualan & HPP otomatis).                    |

---

## ⚙️ Fitur Utama

✅ **Trigger otomatis** — update stok, hitung laba, dan catat kas tanpa input manual.  
✅ **View siap pakai** — laporan barang, transaksi, rekap kas harian, laba bersih.  
✅ **Relasi tertata** — foreign key & constraint jelas untuk menjaga integritas data.

---

## 🚀 Cara Menggunakan

1. Import file `toko_hizwa.sql` ke server MySQL Anda (via phpMyAdmin, DBeaver, atau MySQL CLI).  
2. Jalankan dan uji tabel, trigger, dan view menggunakan query test.  
3. Sesuaikan data barang, harga, atau laporan sesuai kebutuhan toko Anda.

---

## 📜 Lisensi

Skrip database ini bebas digunakan untuk keperluan edukasi, riset, dan pengembangan internal. Mohon cantumkan atribusi jika di-*publish* ulang.

---

**Created with ❤️ by rizkynandapr**  
[GitHub](https://github.com/rizkynandapr)

