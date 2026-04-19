-- 1. Apa saja nama cabang dan nama kota yang memiliki data transaksi penjualan di minimart?
SELECT 
	mc.nama_cabang, 
	mk.nama_kota 
FROM ms_cabang mc
JOIN ms_kota mk ON  mc.kode_kota = mk.kode_kota 
WHERE mc.kode_cabang IN (SELECT kode_cabang FROM tr_penjualan)



-- 2. Apa saja nama cabang dan nama kota yang tidak memiliki data transaksi penjualan di kota 
-- di mana cabang lain memiliki data transaksi penjualan?
SELECT mc.nama_cabang, mk.nama_kota
FROM ms_cabang mc
JOIN ms_kota mk ON mc.kode_kota = mk.kode_kota
WHERE mc.kode_cabang 
 NOT IN (
     SELECT DISTINCT tp.kode_cabang
     FROM tr_penjualan tp
 ) 
 AND mk.kode_kota IN (
     SELECT DISTINCT mc2.kode_kota
     FROM ms_cabang mc2
     JOIN tr_penjualan tp2 ON mc2.kode_cabang = tp2.kode_cabang
 )
ORDER BY 1, 2;



-- 3. Provinsi mana yang memiliki jumlah cabang terbanyak saat ini? Sebutkan 5 provinsi teratas!
SELECT
	mp.nama_propinsi,
	COUNT(DISTINCT mc.kode_cabang) AS jumlah_cabang
FROM ms_cabang mc 
JOIN ms_kota mk ON mk.kode_kota = mc.kode_kota 
JOIN ms_propinsi mp ON mp.kode_propinsi  = mk.kode_propinsi 
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;



-- 4. Berapa profit per kuartal dan pada tanggal berapa profit tertinggi terjadi di setiap kuartal, 
-- serta berapa total profit di tahun 2008?
WITH quarterly_profit AS (
    SELECT
        CASE
            WHEN MONTH(tp.tgl_transaksi) IN (1, 2, 3) THEN 'Q1'
            WHEN MONTH(tp.tgl_transaksi) IN (4, 5, 6) THEN 'Q2'
            WHEN MONTH(tp.tgl_transaksi) IN (7, 8, 9) THEN 'Q3'
            ELSE 'Q4'
        END AS kuartal,
        SUM(tp.jumlah_pembelian * (mhh.harga_berlaku_cabang - mhh.modal_cabang - mhh.biaya_cabang)) AS total_profit
    FROM tr_penjualan tp
    JOIN ms_harga_harian mhh ON tp.kode_produk = mhh.kode_produk
        AND mhh.kode_cabang = tp.kode_cabang
        AND DATE(mhh.tgl_berlaku) = DATE(tp.tgl_transaksi)
    WHERE YEAR(tp.tgl_transaksi) = 2008
    GROUP BY 1
),
highest_profit_date AS (
    SELECT
        CASE
            WHEN MONTH(tp.tgl_transaksi) IN (1, 2, 3) THEN 'Q1'
            WHEN MONTH(tp.tgl_transaksi) IN (4, 5, 6) THEN 'Q2'
            WHEN MONTH(tp.tgl_transaksi) IN (7, 8, 9) THEN 'Q3'
            ELSE 'Q4'
        END AS kuartal,
        tp.tgl_transaksi,
        SUM(tp.jumlah_pembelian * (mhh.harga_berlaku_cabang - mhh.modal_cabang - mhh.biaya_cabang)) AS profit_harian
    FROM tr_penjualan tp
    JOIN ms_harga_harian mhh ON tp.kode_produk = mhh.kode_produk
        AND mhh.kode_cabang = tp.kode_cabang
        AND DATE(mhh.tgl_berlaku) = DATE(tp.tgl_transaksi)
    WHERE YEAR(tp.tgl_transaksi) = 2008
    GROUP BY 1, 2
),
total_yearly_profit AS (
    SELECT
        SUM(tp.jumlah_pembelian * (mhh.harga_berlaku_cabang - mhh.modal_cabang - mhh.biaya_cabang)) AS total_profit_tahun_2008
    FROM tr_penjualan tp
    JOIN ms_harga_harian mhh ON tp.kode_produk = mhh.kode_produk
        AND mhh.kode_cabang = tp.kode_cabang
        AND DATE(mhh.tgl_berlaku) = DATE(tp.tgl_transaksi)
    WHERE YEAR(tp.tgl_transaksi) = 2008
),
max_profit_dates AS (
    SELECT 
        kuartal, 
        tgl_transaksi AS tanggal_profit_tertinggi
    FROM (
        SELECT 
            kuartal, 
            tgl_transaksi, 
            profit_harian,
            ROW_NUMBER() OVER (PARTITION BY kuartal ORDER BY profit_harian DESC) AS rn
        FROM highest_profit_date
    ) sub
    WHERE rn = 1
)
SELECT
    qp.kuartal,
    qp.total_profit AS profit_per_kuartal,
    mpd.tanggal_profit_tertinggi,
    (SELECT total_profit_tahun_2008 FROM total_yearly_profit) AS total_profit_tahun_2008
FROM quarterly_profit qp
JOIN max_profit_dates mpd ON qp.kuartal = mpd.kuartal;



-- 5. Cabang mana yang memiliki total penjualan dan profit tertinggi pada tahun 2008? Tampilkan 
-- daftar masing-masing cabang beserta jumlah penjualan, profit, persentase kontribusi terhadap 
-- total penjualan, dan urutkan berdasarkan jumlah penjualan!
WITH total_profit_penjualan AS (
    SELECT 
        tp.kode_cabang,
        SUM(tp.jumlah_pembelian * (mhh.harga_berlaku_cabang - mhh.modal_cabang - mhh.biaya_cabang)) AS total_profit,
        SUM(tp.jumlah_pembelian) AS jumlah_penjualan_per_cabang
    FROM tr_penjualan tp
    JOIN ms_harga_harian mhh ON tp.kode_produk = mhh.kode_produk 
                            AND tp.kode_cabang = mhh.kode_cabang 
                            AND tp.tgl_transaksi = mhh.tgl_berlaku
    WHERE YEAR(tp.tgl_transaksi) = 2008
    GROUP BY 1
)
SELECT 
    mc.nama_cabang,
    tpp.jumlah_penjualan_per_cabang,
    tpp.total_profit AS total_profit,
    ROUND((tpp.jumlah_penjualan_per_cabang / (SELECT SUM(jumlah_penjualan_per_cabang) FROM total_profit_penjualan)) * 100, 3) AS persentase_penjualan,
    RANK() OVER (ORDER BY tpp.jumlah_penjualan_per_cabang DESC) AS urutan
FROM ms_cabang mc
JOIN total_profit_penjualan tpp ON mc.kode_cabang = tpp.kode_cabang
ORDER BY 3 DESC;



-- 6. Pada bulan apa saja jumlah transaksi penjualan di atas rata-rata jumlah transaksi penjualan di tahun 2008?
SELECT 
    MONTH(tgl_transaksi) AS bulan,
    COUNT(*) AS jumlah_transaksi,
    CASE 
        WHEN COUNT(*) > 
        	(SELECT AVG(jumlah_transaksi) 
        	FROM (SELECT 
        		MONTH(tgl_transaksi) AS bulan, 
        		COUNT(*) AS jumlah_transaksi 
        	FROM tr_penjualan 
        	WHERE YEAR(tgl_transaksi) = 2008 
        	GROUP BY bulan) AS avg_trans_per_month) 
        THEN 'Di atas rata-rata'
        ELSE 'Di bawah rata-rata'
    END AS keterangan
FROM tr_penjualan
WHERE YEAR(tgl_transaksi) = 2008
GROUP BY 1
ORDER BY 1;



-- 7. Lakukan monitoring performa setiap cabang dengan membandingkan performa bulanannya selama tahun 2008. 
-- Pada bulan apa saja di setiap cabang yang memiliki persentase jumlah transaksi terendah dan tertinggi?
WITH per_cabang AS (
    SELECT 
        MONTH(tp.tgl_transaksi) AS bulan,
        tp.kode_cabang,
        COUNT(tp.kode_transaksi) AS current_jumlah_transaksi
    FROM tr_penjualan tp
    WHERE YEAR(tp.tgl_transaksi) = 2008
    GROUP BY 1, 2
)
SELECT 
    bulan,
    kode_cabang,
    LAG(current_jumlah_transaksi, 1) 
        OVER (PARTITION BY kode_cabang ORDER BY bulan) AS previous_jumlah_transaksi,
    current_jumlah_transaksi,
    CASE 
        WHEN LAG(current_jumlah_transaksi, 1) 
            OVER (PARTITION BY kode_cabang ORDER BY bulan) IS NULL THEN 'No Data'
        WHEN LAG(current_jumlah_transaksi, 1) 
            OVER (PARTITION BY kode_cabang ORDER BY bulan) = 0 THEN '0%'
        ELSE CONCAT(ROUND(((current_jumlah_transaksi - LAG(current_jumlah_transaksi, 1) 
            OVER (PARTITION BY kode_cabang ORDER BY bulan)) / LAG(current_jumlah_transaksi, 1) 
            OVER (PARTITION BY kode_cabang ORDER BY bulan)) * 100, 2), '%')
    END AS persentase,
    CASE 
        WHEN LAG(current_jumlah_transaksi, 1) 
            OVER (PARTITION BY kode_cabang ORDER BY bulan) IS NULL THEN 'No Data'
        WHEN ((current_jumlah_transaksi - LAG(current_jumlah_transaksi, 1) 
            OVER (PARTITION BY kode_cabang ORDER BY bulan)) / LAG(current_jumlah_transaksi, 1) 
            OVER (PARTITION BY kode_cabang ORDER BY bulan)) < 0 THEN 'Negatif'
        WHEN ((current_jumlah_transaksi - LAG(current_jumlah_transaksi, 1) 
            OVER (PARTITION BY kode_cabang ORDER BY bulan)) / LAG(current_jumlah_transaksi, 1) 
            OVER (PARTITION BY kode_cabang ORDER BY bulan)) > 0 THEN 'Positif'
        ELSE 'Stabil'
    END AS keterangan
FROM per_cabang;



-- 8. Berapa jumlah produk unik yang terjual di setiap cabang berdasarkan data transaksi yang ada?
SELECT 
    mc.nama_cabang,
    COUNT(DISTINCT tp.kode_produk) AS jumlah_produk_unik_terjual
FROM ms_cabang AS mc
JOIN tr_penjualan AS tp ON mc.kode_cabang = tp.kode_cabang
GROUP BY 1
ORDER BY 2 DESC;


-- 9. Produk apa saja yang memiliki jumlah penjualan tertinggi? Sebutkan lima produk teratas!
SELECT 
 mp.nama_produk,
 SUM(tp.jumlah_pembelian) AS jumlah_penjualan
FROM tr_penjualan tp 
JOIN ms_produk mp ON mp.kode_produk = tp.kode_produk 
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;

-- 10. Produk apa yang paling banyak terjual pada masing-masing kategori?
WITH produk_per_kategori AS (
  SELECT
    mp.kode_kategori,
    mp.nama_produk,
    SUM(tp.jumlah_pembelian) AS total_terjual
  FROM tr_penjualan tp
  JOIN ms_produk mp ON tp.kode_produk = mp.kode_produk
  GROUP BY 1,2
),
max_terjual_per_kategori AS (
  SELECT
    kode_kategori,
    MAX(total_terjual) AS max_terjual
  FROM produk_per_kategori
  GROUP BY 1
)
SELECT
  mk.nama_kategori,
  ppk.nama_produk,
  ppk.total_terjual
FROM produk_per_kategori ppk
JOIN max_terjual_per_kategori mtpk ON ppk.kode_kategori = mtpk.kode_kategori
                                    AND ppk.total_terjual= mtpk.max_terjual
JOIN ms_kategori mk ON ppk.kode_kategori = mk.kode_kategori
ORDER BY 1;



-- 11. Produk mana saja yang termasuk dalam kelompok dengan profit terendah dibandingkan 
-- dengan keseluruhan produk? Bagi produk menjadi empat kelompok besar, dan tampilkan produk 
-- yang termasuk dalam dua kelompok terbawah (profit terendah)!
WITH profit AS (
    SELECT 
        mhh.kode_cabang,
        mhh.kode_produk,
        mhh.tgl_berlaku,
        mp.nama_produk,
        mp.kode_kategori,
        SUM(mhh.harga_berlaku_cabang - mhh.modal_cabang - mhh.biaya_cabang) AS profit
    FROM ms_harga_harian mhh 
    JOIN ms_produk mp ON mp.kode_produk = mhh.kode_produk
    GROUP BY 1, 2, 3, 4, 5
),
total_profit AS (
    SELECT 
        pp.kode_cabang,
        pp.nama_produk,
        pp.kode_kategori,
        SUM(tp.jumlah_pembelian * pp.profit) AS total_profit
    FROM profit pp
    JOIN tr_penjualan tp ON pp.kode_cabang = tp.kode_cabang 
                        AND pp.kode_produk = tp.kode_produk 
                        AND pp.tgl_berlaku = tp.tgl_transaksi 
    GROUP BY 1, 2, 3
    ORDER BY total_profit DESC
),
grouped_product AS (
    SELECT 
        kode_cabang,
        nama_produk,
        kode_kategori,
        total_profit,
        NTILE(4) OVER (ORDER BY total_profit DESC) AS kelompok
    FROM total_profit
)
SELECT 
    gp.kode_cabang,
    gp.nama_produk,
    mk.nama_kategori,
    gp.total_profit AS profit_per_produk,
    CASE 
        WHEN gp.kelompok IN (1) THEN 1
        WHEN gp.kelompok IN (2) THEN 2
        WHEN gp.kelompok IN (3) THEN 3
        ELSE 4
    END AS group_product
FROM grouped_product gp 
JOIN ms_kategori mk ON gp.kode_kategori = mk.kode_kategori
WHERE gp.kelompok IN (3,4)
ORDER BY 4 DESC;



-- 12. Siapakah karyawan terbaik yang memiliki persentase kontribusi transaksi tertinggi 
-- di setiap cabang pada tahun 2008?
WITH total_transaksi_per_kasir AS (
  SELECT
    kode_kasir,
    kode_cabang,
    COUNT(*) AS total_transaksi_per_kasir
  FROM tr_penjualan
  WHERE YEAR(tgl_transaksi) = 2008
  GROUP BY kode_kasir, kode_cabang
),
total_transaksi_per_cabang AS (
  SELECT
    kode_cabang,
    COUNT(*) AS total_transaksi_per_cabang
  FROM tr_penjualan
  WHERE YEAR(tgl_transaksi) = 2008
  GROUP BY kode_cabang
),
kasir_persen AS (
  SELECT
    tk.kode_kasir,
    tk.kode_cabang,
    CONCAT(mk.nama_depan, ' ', mk.nama_belakang) AS nama,
    tk.total_transaksi_per_kasir,
    tc.total_transaksi_per_cabang,
    ROUND((tk.total_transaksi_per_kasir / tc.total_transaksi_per_cabang) * 100, 2) AS persentase_kontribusi_terhadap_cabang,
    ROW_NUMBER() OVER (PARTITION BY tk.kode_cabang ORDER BY tk.total_transaksi_per_kasir DESC) AS rn
  FROM total_transaksi_per_kasir tk
  JOIN ms_karyawan mk ON tk.kode_kasir = mk.kode_karyawan
  JOIN total_transaksi_per_cabang tc ON tk.kode_cabang = tc.kode_cabang
)
SELECT 
  kp.kode_kasir, 
  kp.nama, 
  mc.nama_cabang AS nama_cabang, 
  kp.total_transaksi_per_kasir, 
  kp.total_transaksi_per_cabang, 
  kp.persentase_kontribusi_terhadap_cabang
FROM kasir_persen kp
JOIN ms_cabang mc ON kp.kode_cabang = mc.kode_cabang
WHERE kp.rn = 1
ORDER BY 6 DESC;

 
-- Project Minimart
-- by: Bintang Ary Pradana
  
