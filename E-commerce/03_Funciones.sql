SET NAMES utf8mb4;
USE ecommerce_db;

DROP FUNCTION IF EXISTS fn_CalcularTotalVenta;
DELIMITER $$
CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT UNSIGNED)
RETURNS DECIMAL(12,2)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT COALESCE(SUM(dv.subtotal), 0)
    INTO v_total
    FROM detalle_venta dv
    WHERE dv.id_venta = p_id_venta;
    RETURN v_total;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_VerificarDisponibilidadStock;
DELIMITER $$
CREATE FUNCTION fn_VerificarDisponibilidadStock(p_id_producto INT UNSIGNED, p_cantidad INT)
RETURNS BOOLEAN
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_stock INT;
    DECLARE v_activo BOOLEAN;
    SELECT p.stock, (p.activo AND p.eliminado_en IS NULL)
    INTO v_stock, v_activo
    FROM productos p
    WHERE p.id_producto = p_id_producto;
    IF v_stock IS NULL OR p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RETURN FALSE;
    END IF;
    RETURN v_activo AND v_stock >= p_cantidad;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_ObtenerPrecioProducto;
DELIMITER $$
CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT UNSIGNED)
RETURNS DECIMAL(12,2)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_precio DECIMAL(12,2);
    SELECT p.precio
    INTO v_precio
    FROM productos p
    WHERE p.id_producto = p_id_producto;
    RETURN v_precio;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_CalcularEdadCliente;
DELIMITER $$
CREATE FUNCTION fn_CalcularEdadCliente(p_id_cliente INT UNSIGNED)
RETURNS INT
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_nacimiento DATE;
    SELECT c.fecha_nacimiento
    INTO v_nacimiento
    FROM clientes c
    WHERE c.id_cliente = p_id_cliente;
    IF v_nacimiento IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN TIMESTAMPDIFF(YEAR, v_nacimiento, CURDATE());
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_FormatearNombreCompleto;
DELIMITER $$
CREATE FUNCTION fn_FormatearNombreCompleto(p_nombre VARCHAR(60), p_apellido VARCHAR(60))
RETURNS VARCHAR(130)
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
    DECLARE v_texto VARCHAR(130);
    DECLARE v_resultado VARCHAR(130) DEFAULT '';
    DECLARE v_palabra VARCHAR(130);
    SET v_texto = TRIM(REGEXP_REPLACE(CONCAT(COALESCE(p_nombre, ''), ' ', COALESCE(p_apellido, '')), '[[:space:]]+', ' '));
    WHILE v_texto <> '' DO
        SET v_palabra = SUBSTRING_INDEX(v_texto, ' ', 1);
        SET v_resultado = CONCAT(v_resultado, IF(v_resultado = '', '', ' '), UPPER(LEFT(v_palabra, 1)), LOWER(SUBSTRING(v_palabra, 2)));
        IF LOCATE(' ', v_texto) = 0 THEN
            SET v_texto = '';
        ELSE
            SET v_texto = SUBSTRING(v_texto, LOCATE(' ', v_texto) + 1);
        END IF;
    END WHILE;
    RETURN v_resultado;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_EsClienteNuevo;
DELIMITER $$
CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT UNSIGNED)
RETURNS BOOLEAN
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_primera DATETIME;
    SELECT MIN(v.fecha_venta)
    INTO v_primera
    FROM ventas v
    WHERE v.id_cliente = p_id_cliente
      AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado');
    RETURN v_primera IS NOT NULL AND v_primera >= NOW() - INTERVAL 30 DAY;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_CalcularCostoEnvio;
DELIMITER $$
CREATE FUNCTION fn_CalcularCostoEnvio(p_id_venta INT UNSIGNED)
RETURNS DECIMAL(12,2)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_peso DECIMAL(10,3);
    SELECT COALESCE(SUM(dv.cantidad * p.peso_kg), 0)
    INTO v_peso
    FROM detalle_venta dv
    JOIN productos p ON p.id_producto = dv.id_producto
    WHERE dv.id_venta = p_id_venta;
    RETURN CASE
        WHEN v_peso = 0 THEN 0
        WHEN v_peso <= 1 THEN 9900
        WHEN v_peso <= 5 THEN 14900
        WHEN v_peso <= 10 THEN 22900
        WHEN v_peso <= 20 THEN 34900
        ELSE 34900 + CEIL(v_peso - 20) * 1500
    END;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_AplicarDescuento;
DELIMITER $$
CREATE FUNCTION fn_AplicarDescuento(p_monto DECIMAL(12,2), p_porcentaje DECIMAL(5,2))
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
    IF p_porcentaje IS NULL OR p_porcentaje < 0 OR p_porcentaje > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El porcentaje de descuento debe estar entre 0 y 100';
    END IF;
    RETURN ROUND(p_monto * (1 - p_porcentaje / 100), 2);
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_ObtenerUltimaFechaCompra;
DELIMITER $$
CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT UNSIGNED)
RETURNS DATETIME
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_fecha DATETIME;
    SELECT MAX(v.fecha_venta)
    INTO v_fecha
    FROM ventas v
    WHERE v.id_cliente = p_id_cliente
      AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado');
    RETURN v_fecha;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_ValidarFormatoEmail;
DELIMITER $$
CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
    IF p_email IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$');
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_ObtenerNombreCategoria;
DELIMITER $$
CREATE FUNCTION fn_ObtenerNombreCategoria(p_id_producto INT UNSIGNED)
RETURNS VARCHAR(80)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_nombre VARCHAR(80);
    SELECT cat.nombre
    INTO v_nombre
    FROM productos p
    JOIN categorias cat ON cat.id_categoria = p.id_categoria
    WHERE p.id_producto = p_id_producto;
    RETURN v_nombre;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_ContarVentasCliente;
DELIMITER $$
CREATE FUNCTION fn_ContarVentasCliente(p_id_cliente INT UNSIGNED)
RETURNS INT
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_total INT;
    SELECT COUNT(*)
    INTO v_total
    FROM ventas v
    WHERE v.id_cliente = p_id_cliente
      AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado');
    RETURN v_total;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_CalcularDiasDesdeUltimaCompra;
DELIMITER $$
CREATE FUNCTION fn_CalcularDiasDesdeUltimaCompra(p_id_cliente INT UNSIGNED)
RETURNS INT
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_ultima DATETIME;
    SET v_ultima = fn_ObtenerUltimaFechaCompra(p_id_cliente);
    IF v_ultima IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN DATEDIFF(CURDATE(), v_ultima);
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_DeterminarEstadoLealtad;
DELIMITER $$
CREATE FUNCTION fn_DeterminarEstadoLealtad(p_id_cliente INT UNSIGNED)
RETURNS VARCHAR(10)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_gastado DECIMAL(12,2);
    SELECT COALESCE(SUM(v.total), 0)
    INTO v_gastado
    FROM ventas v
    WHERE v.id_cliente = p_id_cliente
      AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado');
    RETURN CASE
        WHEN v_gastado >= 5000000 THEN 'Oro'
        WHEN v_gastado >= 1500000 THEN 'Plata'
        ELSE 'Bronce'
    END;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_GenerarSKU;
DELIMITER $$
CREATE FUNCTION fn_GenerarSKU(p_nombre VARCHAR(150), p_id_categoria INT UNSIGNED)
RETURNS VARCHAR(20)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_categoria VARCHAR(80);
    DECLARE v_pref_cat VARCHAR(3);
    DECLARE v_pref_nom VARCHAR(3);
    DECLARE v_base VARCHAR(10);
    DECLARE v_consecutivo INT;
    DECLARE v_sku VARCHAR(20);
    SELECT cat.nombre
    INTO v_categoria
    FROM categorias cat
    WHERE cat.id_categoria = p_id_categoria;
    IF v_categoria IS NULL THEN
        SET v_categoria = 'General';
    END IF;
    SET v_pref_cat = LEFT(REGEXP_REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(v_categoria), 'Á', 'A'), 'É', 'E'), 'Í', 'I'), 'Ó', 'O'), 'Ú', 'U'), 'Ñ', 'N'), 'Ü', 'U'), '[^A-Z0-9]', ''), 3);
    SET v_pref_nom = LEFT(REGEXP_REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(p_nombre), 'Á', 'A'), 'É', 'E'), 'Í', 'I'), 'Ó', 'O'), 'Ú', 'U'), 'Ñ', 'N'), 'Ü', 'U'), '[^A-Z0-9]', ''), 3);
    SET v_base = CONCAT(v_pref_cat, '-', v_pref_nom);
    SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(p.sku, '-', -1) AS UNSIGNED)), 0) + 1
    INTO v_consecutivo
    FROM productos p
    WHERE p.sku LIKE CONCAT(v_base, '-%');
    SET v_sku = CONCAT(v_base, '-', LPAD(v_consecutivo, 4, '0'));
    WHILE EXISTS (SELECT 1 FROM productos p WHERE p.sku = v_sku) DO
        SET v_consecutivo = v_consecutivo + 1;
        SET v_sku = CONCAT(v_base, '-', LPAD(v_consecutivo, 4, '0'));
    END WHILE;
    RETURN v_sku;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_CalcularIVA;
DELIMITER $$
CREATE FUNCTION fn_CalcularIVA(p_id_venta INT UNSIGNED)
RETURNS DECIMAL(12,2)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    RETURN ROUND(fn_CalcularTotalVenta(p_id_venta) * 0.19, 2);
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_ObtenerStockTotalPorCategoria;
DELIMITER $$
CREATE FUNCTION fn_ObtenerStockTotalPorCategoria(p_id_categoria INT UNSIGNED)
RETURNS INT
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_total INT;
    SELECT COALESCE(SUM(p.stock), 0)
    INTO v_total
    FROM productos p
    WHERE p.id_categoria = p_id_categoria
      AND p.eliminado_en IS NULL;
    RETURN v_total;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_EstimarFechaEntrega;
DELIMITER $$
CREATE FUNCTION fn_EstimarFechaEntrega(p_id_venta INT UNSIGNED)
RETURNS DATE
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_fecha DATE;
    DECLARE v_ciudad VARCHAR(60);
    DECLARE v_dias INT;
    SELECT DATE(v.fecha_venta), c.ciudad
    INTO v_fecha, v_ciudad
    FROM ventas v
    JOIN clientes c ON c.id_cliente = v.id_cliente
    WHERE v.id_venta = p_id_venta;
    IF v_fecha IS NULL THEN
        RETURN NULL;
    END IF;
    SET v_dias = CASE
        WHEN v_ciudad = 'Cúcuta' THEN 1
        WHEN v_ciudad IN ('Villa del Rosario', 'Los Patios') THEN 2
        WHEN v_ciudad IN ('Pamplona', 'Bucaramanga', 'Bogotá') THEN 3
        WHEN v_ciudad IN ('Medellín', 'Barranquilla') THEN 4
        WHEN v_ciudad = 'Cali' THEN 5
        ELSE 7
    END;
    WHILE v_dias > 0 DO
        SET v_fecha = v_fecha + INTERVAL 1 DAY;
        IF DAYOFWEEK(v_fecha) <> 1 THEN
            SET v_dias = v_dias - 1;
        END IF;
    END WHILE;
    RETURN v_fecha;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_ConvertirMoneda;
DELIMITER $$
CREATE FUNCTION fn_ConvertirMoneda(p_monto DECIMAL(14,2), p_moneda CHAR(3))
RETURNS DECIMAL(14,2)
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
    DECLARE v_tasa DECIMAL(10,2);
    SET v_tasa = CASE UPPER(p_moneda)
        WHEN 'COP' THEN 1
        WHEN 'USD' THEN 4000
        WHEN 'EUR' THEN 4400
        WHEN 'MXN' THEN 215
        ELSE NULL
    END;
    IF v_tasa IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Moneda no soportada. Use COP, USD, EUR o MXN';
    END IF;
    RETURN ROUND(p_monto / v_tasa, 2);
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_ValidarComplejidadContrasena;
DELIMITER $$
CREATE FUNCTION fn_ValidarComplejidadContrasena(p_contrasena VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
    IF p_contrasena IS NULL OR CHAR_LENGTH(p_contrasena) < 10 THEN
        RETURN FALSE;
    END IF;
    RETURN REGEXP_LIKE(p_contrasena, '[A-Z]', 'c')
        AND REGEXP_LIKE(p_contrasena, '[a-z]', 'c')
        AND REGEXP_LIKE(p_contrasena, '[0-9]')
        AND REGEXP_LIKE(p_contrasena, '[^A-Za-z0-9]', 'c')
        AND NOT REGEXP_LIKE(p_contrasena, '[[:space:]]');
END$$
DELIMITER ;
