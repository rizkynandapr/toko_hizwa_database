/* =====================================================
   DATABASE  : toko_hizwa  
   ===================================================== */
CREATE DATABASE toko_hizwa;
USE toko_hizwa;

/* =====================================================
   1. MASTER DATA : barang
   ===================================================== */
CREATE TABLE barang (
    id_barang    INT AUTO_INCREMENT PRIMARY KEY,
    nama_barang  VARCHAR(55)  NOT NULL UNIQUE,
    harga_beli   DECIMAL(12,2) NOT NULL DEFAULT 0,
    harga_jual   DECIMAL(12,2) NOT NULL DEFAULT 0
);

/* =====================================================
   2. OPERASIONAL : barang_masuk
   ===================================================== */
CREATE TABLE barang_masuk (
    id_masuk     INT AUTO_INCREMENT PRIMARY KEY,
    tanggal      DATE         NOT NULL DEFAULT CURRENT_DATE,
    id_barang    INT          NOT NULL,
    jumlah_masuk INT          NOT NULL CHECK (jumlah_masuk > 0),
    FOREIGN KEY (id_barang) REFERENCES barang(id_barang) ON DELETE CASCADE
);

/* =====================================================
   3. REKAP STOK : katalog_barang
   ===================================================== */
CREATE TABLE katalog_barang (
    id_barang  INT PRIMARY KEY,
    stok_akhir INT NOT NULL DEFAULT 0,
    FOREIGN KEY (id_barang) REFERENCES barang(id_barang) ON DELETE CASCADE
);

/* =====================================================
   4. HEADER JUAL : barang_terjual
   ===================================================== */
CREATE TABLE barang_terjual (
    id_transaksi    INT AUTO_INCREMENT PRIMARY KEY,
    tanggal         DATE          NOT NULL DEFAULT CURRENT_DATE,
    total_transaksi DECIMAL(14,2) NOT NULL DEFAULT 0
);

/* =====================================================
   5. DETAIL JUAL : rinci_barang_terjual
   ===================================================== */
CREATE TABLE rinci_barang_terjual (
    id_rinci     INT AUTO_INCREMENT PRIMARY KEY,
    id_transaksi INT NOT NULL,
    id_barang    INT NOT NULL,
    jumlah       INT NOT NULL CHECK (jumlah > 0),
    kas_masuk    DECIMAL(14,2) NOT NULL,
    profit       DECIMAL(14,2) NOT NULL,
    FOREIGN KEY (id_transaksi) REFERENCES barang_terjual(id_transaksi) ON DELETE CASCADE,
    FOREIGN KEY (id_barang)    REFERENCES barang(id_barang)            ON DELETE RESTRICT
);

/* =====================================================
   6. KAS HARIAN  : buku_kas_harian
   ===================================================== */
CREATE TABLE buku_kas_harian (
    id_kas        INT AUTO_INCREMENT PRIMARY KEY,
    tanggal       DATE NOT NULL,
    uraian        VARCHAR(55) NOT NULL,
    tipe_transaksi ENUM('MASUK','KELUAR') NOT NULL,
    jumlah        DECIMAL(14,2) NOT NULL CHECK (jumlah >= 0),
    id_transaksi  INT,
    FOREIGN KEY (id_transaksi) REFERENCES barang_terjual(id_transaksi) ON DELETE SET NULL
);

/* =====================================================
   7. TRIGGER  — otomatisasi stok & kas
   ===================================================== */
DELIMITER //

/* ---------- BARANG MASUK ---------- */
CREATE TRIGGER after_barang_masuk_insert
AFTER INSERT ON barang_masuk
FOR EACH ROW
BEGIN
  INSERT INTO katalog_barang (id_barang, stok_akhir)
  VALUES (NEW.id_barang, NEW.jumlah_masuk)
  ON DUPLICATE KEY UPDATE stok_akhir = stok_akhir + NEW.jumlah_masuk;
END//

CREATE TRIGGER after_barang_masuk_update
AFTER UPDATE ON barang_masuk
FOR EACH ROW
BEGIN
  UPDATE katalog_barang
    SET stok_akhir = stok_akhir + (NEW.jumlah_masuk - OLD.jumlah_masuk)
  WHERE id_barang = NEW.id_barang;
END//

CREATE TRIGGER after_barang_masuk_delete
AFTER DELETE ON barang_masuk
FOR EACH ROW
BEGIN
  UPDATE katalog_barang
    SET stok_akhir = stok_akhir - OLD.jumlah_masuk
  WHERE id_barang = OLD.id_barang;
END//

/* ---------- DETAIL PENJUALAN : BEFORE/AFTER INSERT ---------- */
CREATE TRIGGER rbt_before_insert
BEFORE INSERT ON rinci_barang_terjual
FOR EACH ROW
BEGIN
  DECLARE hj, hb DECIMAL(12,2);
  SELECT harga_jual, harga_beli INTO hj, hb
  FROM barang WHERE id_barang = NEW.id_barang;

  SET NEW.kas_masuk = NEW.jumlah * hj;
  SET NEW.profit    = NEW.kas_masuk - (hb * NEW.jumlah);
END//

CREATE TRIGGER rbt_after_insert
AFTER INSERT ON rinci_barang_terjual
FOR EACH ROW
BEGIN
  DECLARE hb DECIMAL(12,2);
  DECLARE tgl DATE;

  SELECT harga_beli INTO hb FROM barang WHERE id_barang = NEW.id_barang;
  SELECT tanggal   INTO tgl FROM barang_terjual WHERE id_transaksi = NEW.id_transaksi;

  /* 1. Total header */
  UPDATE barang_terjual
    SET total_transaksi = ( SELECT SUM(kas_masuk)
                            FROM rinci_barang_terjual
                            WHERE id_transaksi = NEW.id_transaksi )
  WHERE id_transaksi = NEW.id_transaksi;

  /* 2. Kurangi stok */
  UPDATE katalog_barang
    SET stok_akhir = stok_akhir - NEW.jumlah
  WHERE id_barang = NEW.id_barang;

  /* 3. Kas: masuk & HPP */
  INSERT INTO buku_kas_harian (tanggal, uraian, tipe_transaksi, jumlah, id_transaksi)
  VALUES
    (tgl, CONCAT('Penjualan #',NEW.id_transaksi),'MASUK', NEW.kas_masuk, NEW.id_transaksi),
    (tgl, CONCAT('HPP #',NEW.id_transaksi),      'KELUAR', hb*NEW.jumlah, NEW.id_transaksi);
END//

/* ---------- DETAIL PENJUALAN : BEFORE/AFTER UPDATE ---------- */
CREATE TRIGGER rbt_before_update
BEFORE UPDATE ON rinci_barang_terjual
FOR EACH ROW
BEGIN
  DECLARE hj, hb DECIMAL(12,2);
  SELECT harga_jual, harga_beli INTO hj, hb
  FROM barang WHERE id_barang = NEW.id_barang;

  SET NEW.kas_masuk = NEW.jumlah * hj;
  SET NEW.profit    = NEW.kas_masuk - (hb * NEW.jumlah);
END//

CREATE TRIGGER rbt_after_update
AFTER UPDATE ON rinci_barang_terjual
FOR EACH ROW
BEGIN
  DECLARE hb DECIMAL(12,2);
  DECLARE tgl DATE;
  DECLARE diff_qty INT;

  SELECT harga_beli INTO hb FROM barang WHERE id_barang = NEW.id_barang;
  SELECT tanggal   INTO tgl FROM barang_terjual WHERE id_transaksi = NEW.id_transaksi;

  SET diff_qty = NEW.jumlah - OLD.jumlah;   -- positif: stok berkurang

  /* 1. Sesuaikan stok */
  UPDATE katalog_barang
    SET stok_akhir = stok_akhir - diff_qty
  WHERE id_barang = NEW.id_barang;

  /* 2. Refresh total header */
  UPDATE barang_terjual
    SET total_transaksi = ( SELECT SUM(kas_masuk)
                            FROM rinci_barang_terjual
                            WHERE id_transaksi = NEW.id_transaksi )
  WHERE id_transaksi = NEW.id_transaksi;

  /* 3. Tandai entri lama sebagai batal */
  UPDATE buku_kas_harian
    SET uraian = CONCAT('[BATAL] ', uraian)
  WHERE id_transaksi = NEW.id_transaksi
    AND uraian NOT LIKE '[BATAL]%';

  /* 4. Catat penyesuaian */
  INSERT INTO buku_kas_harian (tanggal, uraian, tipe_transaksi, jumlah, id_transaksi)
  VALUES
    (tgl, CONCAT('Penjualan #',NEW.id_transaksi,' (ADJ)'),
         IF(diff_qty>=0,'MASUK','KELUAR'),
         ABS(NEW.kas_masuk - OLD.kas_masuk),
         NEW.id_transaksi),

    (tgl, CONCAT('HPP #',NEW.id_transaksi,' (ADJ)'),
         IF(diff_qty>=0,'KELUAR','MASUK'),
         ABS((hb*NEW.jumlah) - (hb*OLD.jumlah)),
         NEW.id_transaksi);
END//

/* ---------- DETAIL PENJUALAN : AFTER DELETE ---------- */
CREATE TRIGGER rbt_after_delete
AFTER DELETE ON rinci_barang_terjual
FOR EACH ROW
BEGIN
  DECLARE hb DECIMAL(12,2);
  DECLARE tgl DATE;

  SELECT harga_beli INTO hb FROM barang WHERE id_barang = OLD.id_barang;
  SELECT tanggal   INTO tgl FROM barang_terjual WHERE id_transaksi = OLD.id_transaksi;

  /* 1. Kembalikan stok */
  UPDATE katalog_barang
    SET stok_akhir = stok_akhir + OLD.jumlah
  WHERE id_barang = OLD.id_barang;

  /* 2. Perbarui total header */
  UPDATE barang_terjual
    SET total_transaksi = ( SELECT COALESCE(SUM(kas_masuk),0)
                            FROM rinci_barang_terjual
                            WHERE id_transaksi = OLD.id_transaksi )
  WHERE id_transaksi = OLD.id_transaksi;

  /* 3. Batalkan entri kas */
  UPDATE buku_kas_harian
    SET uraian = CONCAT('[BATAL] ', uraian)
  WHERE id_transaksi = OLD.id_transaksi
    AND uraian NOT LIKE '[BATAL]%';

  /* 4. Tulis VOID */
  INSERT INTO buku_kas_harian (tanggal, uraian, tipe_transaksi, jumlah, id_transaksi)
  VALUES
    (tgl, CONCAT('VOID Penjualan #',OLD.id_transaksi),'KELUAR', OLD.kas_masuk,  OLD.id_transaksi),
    (tgl, CONCAT('VOID HPP #',OLD.id_transaksi),      'MASUK',  hb*OLD.jumlah,  OLD.id_transaksi);
END//

DELIMITER ;

/* =====================================================
   8. VIEW — laporan siap pakai
   ===================================================== */
CREATE VIEW view_barang AS
  SELECT id_barang, nama_barang, harga_beli, harga_jual
  FROM barang;

CREATE VIEW view_barang_masuk AS
  SELECT bm.id_masuk, bm.tanggal, b.nama_barang, bm.jumlah_masuk
  FROM barang_masuk bm
  JOIN barang b ON bm.id_barang = b.id_barang;

CREATE VIEW view_katalog_barang AS
  SELECT kb.id_barang, b.nama_barang, kb.stok_akhir
  FROM katalog_barang kb
  JOIN barang b ON kb.id_barang = b.id_barang;

CREATE VIEW view_barang_terjual AS
  SELECT id_transaksi, tanggal, total_transaksi
  FROM barang_terjual;

CREATE VIEW view_rinci_barang_terjual AS
  SELECT r.id_rinci, r.id_transaksi, b.nama_barang,
         r.jumlah, r.kas_masuk, r.profit
  FROM rinci_barang_terjual r
  JOIN barang b ON r.id_barang = b.id_barang;

CREATE VIEW view_buku_kas_harian AS
  SELECT *
  FROM buku_kas_harian
  ORDER BY tanggal, id_kas;

CREATE VIEW view_laba_bersih AS
  SELECT tanggal,
         SUM(CASE WHEN tipe_transaksi='MASUK'  THEN jumlah
                  WHEN tipe_transaksi='KELUAR' THEN -jumlah END) AS laba_bersih
  FROM buku_kas_harian
  GROUP BY tanggal
  ORDER BY tanggal;