CREATE DATABASE praktikum_function_trigger;
USE praktikum_function_trigger;

CREATE TABLE produk (
    id_produk INT AUTO_INCREMENT PRIMARY KEY,
    nama_produk VARCHAR(100) NOT NULL,
    harga DECIMAL(12,2) NOT NULL,
    stok INT NOT NULL DEFAULT 0,
    CHECK (harga > 0),
    CHECK (stok >= 0)
) ENGINE = InnoDB;

    id_penjualan INT AUTO_INCREMENT PRIMARY KEY,
    id_produk INT NOT NULL,
    jumlah INT NOT NULL,
    harga_satuan DECIMAL(12,2) NOT NULL,
    total DECIMAL(14,2) NOT NULL DEFAULT 0,
    tanggal_transaksi TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_penjualan_produk
        FOREIGN KEY (id_produk)
        REFERENCES produk(id_produk),

    CHECK (jumlah > 0),
    CHECK (harga_satuan > 0),
    CHECK (total >= 0)
) ENGINE = InnoDB;

CREATE TABLE log_stok (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_produk INT NOT NULL,
    stok_awal INT NOT NULL,
    stok_akhir INT NOT NULL,
    keterangan VARCHAR(100) NOT NULL,
    waktu_log TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

INSERT INTO produk (nama_produk, harga, stok)
VALUES
    ('Laptop', 7500000, 10),
    ('Mouse', 150000, 25),
    ('Keyboard', 350000, 15),
    ('Monitor', 1800000, 8);
Verifikasi data:
SELECT * FROM produk;

DELIMITER //
CREATE FUNCTION hitung_total(
    p_harga DECIMAL(12,2),
    p_jumlah INT
)
RETURNS DECIMAL(14,2)
DETERMINISTIC
NO SQL
BEGIN
    RETURN p_harga * p_jumlah;
END //
DELIMITER ;

SELECT hitung_total(150000, 3) AS total_harga;

DELIMITER //
CREATE FUNCTION hitung_diskon(
    p_total DECIMAL(14,2)
)
RETURNS DECIMAL(14,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_total >= 1000000 THEN
        RETURN p_total * 0.10;
    ELSE
        RETURN 0;
    END IF;
END //
DELIMITER ;

SELECT
    1500000 AS total_transaksi,
    hitung_diskon(1500000) AS diskon,
    1500000 - hitung_diskon(1500000) AS total_bayar;

SELECT
    hitung_total(350000, 4) AS total_transaksi,
    hitung_diskon(hitung_total(350000, 4)) AS diskon,
    hitung_total(350000, 4)
      - hitung_diskon(hitung_total(350000, 4))
      AS total_bayar;

DELIMITER //
CREATE TRIGGER validasi_penjualan
BEFORE INSERT ON penjualan
FOR EACH ROW
BEGIN
    DECLARE v_stok INT DEFAULT NULL;
    DECLARE v_ada INT DEFAULT 0;

    IF NEW.jumlah <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Jumlah pembelian harus lebih dari nol';
    END IF;

    IF NEW.harga_satuan <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Harga satuan harus lebih dari nol';
    END IF;

    SELECT COUNT(*)
    INTO v_ada
    FROM produk
    WHERE id_produk = NEW.id_produk;

    IF v_ada = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Produk tidak ditemukan';
    END IF;

    SELECT stok
    INTO v_stok
    FROM produk
    WHERE id_produk = NEW.id_produk
    FOR UPDATE;

    IF NEW.jumlah > v_stok THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
            'Stok produk tidak mencukupi';
    END IF;
    SET NEW.total =
        hitung_total(NEW.harga_satuan, NEW.jumlah);
END //
DELIMITER ;

DELIMITER //

CREATE TRIGGER update_stok_penjualan
AFTER INSERT ON penjualan
FOR EACH ROW
BEGIN
    DECLARE v_stok_awal INT;
    DECLARE v_stok_akhir INT;

    SELECT stok
    INTO v_stok_awal
    FROM produk
    WHERE id_produk = NEW.id_produk;

    SET v_stok_akhir = v_stok_awal - NEW.jumlah;

    UPDATE produk
    SET stok = v_stok_akhir
    WHERE id_produk = NEW.id_produk;

    INSERT INTO log_stok (
        id_produk,
        stok_awal,
        stok_akhir,
        keterangan
    )
    VALUES (
        NEW.id_produk,
        v_stok_awal,
        v_stok_akhir,
        'Pengurangan stok karena penjualan'
    );
END //

DELIMITER ;

INSERT INTO penjualan (
    id_produk,
    jumlah,
    harga_satuan,
    total
)
VALUES (2, 2, 150000, 0);

SELECT * FROM penjualan;

SELECT nama_produk, stok
FROM produk
WHERE id_produk = 2;

SELECT * FROM log_stok;

SHOW FUNCTION STATUS
WHERE Db = 'praktikum_function_trigger';

SHOW TRIGGERS
FROM praktikum_function_trigger;

delimiter //
create function hitung_pajak (
	p_total decimal (14,2)
	)
returns decimal (14,2)
deterministic
no sql
begin
	return p_total * 0.11;
end //
delimiter ;

select 2000000 as total_transaksi, hitung_pajak (2000000) as pajak_diharapkan;
select 5000000 as total_transaksi, hitung_pajak (5000000) as pajak_diharapkan;

select
	hitung_total (5000000, 4) as total_transaksi,
	hitung_pajak(hitung_total(5000000,4)) as pajak,
	hitung_total (5000000, 4) + hitung_pajak (hitung_total(5000000,4)) as total_bayar;


delimiter //
create function hitung_total_akhir (
	p_total decimal (14,2),
	p_diskon decimal (5,2)
	)
returns decimal (14,2)
deterministic
no sql
begin
	return p_total * (1 - (p_diskon / 100));
end //
delimiter ;

select hitung_total_akhir(3000000, 15) AS total_akhir;

delimiter //
create trigger log_perubahan_stok_produk
after update on produk
for each row
begin
	if old.stok <> new.stok then
	insert into log_stok (
	id_produk,
	stok_awal,
	stok_akhir,
	keterangan
	)
	values (
	new.id_produk,
	old.stok,
	new.stok
	);
	end if;
end //
delimiter ;

update produk set stok = 25 where id_produk = 2;
select * from  log_stok where id_produk = 2 order by id_log desc;
SELECT * FROM log_stok WHERE id_produk = 2 ORDER BY id_log DESC;


delimiter //
create trigger validasi_harga_produk
before update on produk
for each row
begin
	if new.harga <= 0 then
	signal sqlstate '45000'
	set message_text = 'Harga produk harus lebih besar dari nol';
end if;
end //
delimiter ;

update produk set harga = 200000 where id_produk = 2;
update produk set harga = 0 where id_produk = 2;
