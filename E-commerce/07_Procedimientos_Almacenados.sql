SET NAMES utf8mb4;
USE ecommerce_db;

DROP PROCEDURE IF EXISTS sp_RealizarNuevaVenta;
DELIMITER $$
CREATE PROCEDURE sp_RealizarNuevaVenta(
    IN p_id_cliente INT UNSIGNED,
    IN p_id_sucursal INT UNSIGNED,
    IN p_productos JSON,
    OUT p_id_venta INT UNSIGNED
)
BEGIN
    DECLARE v_fin BOOLEAN DEFAULT FALSE;
    DECLARE v_id_producto INT UNSIGNED;
    DECLARE v_cantidad INT;
    DECLARE v_stock INT;
    DECLARE v_precio DECIMAL(12,2);
    DECLARE v_descuento DECIMAL(5,2);
    DECLARE v_direccion VARCHAR(200);
    DECLARE v_mensaje VARCHAR(128);
    DECLARE cur_items CURSOR FOR
        SELECT jt.id_producto, SUM(jt.cantidad)
        FROM JSON_TABLE(p_productos, '$[*]' COLUMNS (
            id_producto INT UNSIGNED PATH '$.id_producto' ERROR ON EMPTY,
            cantidad INT PATH '$.cantidad' ERROR ON EMPTY
        )) AS jt
        GROUP BY jt.id_producto;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_venta = NULL;
        RESIGNAL;
    END;
    IF p_productos IS NULL OR NOT JSON_VALID(p_productos) OR JSON_TYPE(p_productos) <> 'ARRAY' OR JSON_LENGTH(p_productos) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista de productos debe ser un arreglo JSON con al menos un elemento';
    END IF;
    SELECT c.direccion_envio
    INTO v_direccion
    FROM clientes c
    WHERE c.id_cliente = p_id_cliente
      AND c.activo = TRUE
      AND c.eliminado_en IS NULL;
    IF v_direccion IS NULL AND NOT EXISTS (SELECT 1 FROM clientes c WHERE c.id_cliente = p_id_cliente AND c.activo = TRUE AND c.eliminado_en IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe o está inactivo';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM sucursales s WHERE s.id_sucursal = p_id_sucursal AND s.activa = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La sucursal no existe o está inactiva';
    END IF;
    START TRANSACTION;
    INSERT INTO ventas (id_cliente, id_sucursal, estado, direccion_envio)
    VALUES (p_id_cliente, p_id_sucursal, 'Pendiente de Pago', v_direccion);
    SET p_id_venta = LAST_INSERT_ID();
    SET v_fin = FALSE;
    OPEN cur_items;
    lectura: LOOP
        FETCH cur_items INTO v_id_producto, v_cantidad;
        IF v_fin THEN
            LEAVE lectura;
        END IF;
        IF v_cantidad IS NULL OR v_cantidad <= 0 THEN
            SET v_mensaje = CONCAT('Cantidad inválida para el producto ', v_id_producto);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
        END IF;
        SET v_stock = NULL;
        SELECT p.stock, p.precio
        INTO v_stock, v_precio
        FROM productos p
        WHERE p.id_producto = v_id_producto
          AND p.activo = TRUE
          AND p.eliminado_en IS NULL
        FOR UPDATE;
        IF v_stock IS NULL THEN
            SET v_mensaje = CONCAT('El producto ', v_id_producto, ' no existe o no está a la venta');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
        END IF;
        IF v_stock < v_cantidad THEN
            SET v_mensaje = CONCAT('Stock insuficiente para el producto ', v_id_producto, ': disponible ', v_stock, ', solicitado ', v_cantidad);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
        END IF;
        SELECT MAX(pr.porcentaje_descuento)
        INTO v_descuento
        FROM promociones pr
        WHERE pr.id_producto = v_id_producto
          AND pr.activa = TRUE
          AND NOW() BETWEEN pr.fecha_inicio AND pr.fecha_fin;
        IF v_descuento IS NOT NULL THEN
            SET v_precio = fn_AplicarDescuento(v_precio, v_descuento);
        END IF;
        INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario_congelado)
        VALUES (p_id_venta, v_id_producto, v_cantidad, v_precio);
    END LOOP;
    CLOSE cur_items;
    UPDATE ventas
    SET total = fn_CalcularTotalVenta(p_id_venta)
    WHERE id_venta = p_id_venta;
    UPDATE carritos
    SET estado = 'Convertido',
        id_venta = p_id_venta,
        fecha_actualizacion = NOW()
    WHERE id_cliente = p_id_cliente
      AND estado = 'Activo';
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_AgregarNuevoProducto;
DELIMITER $$
CREATE PROCEDURE sp_AgregarNuevoProducto(
    IN p_nombre VARCHAR(150),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(12,2),
    IN p_costo DECIMAL(12,2),
    IN p_stock INT,
    IN p_stock_minimo INT,
    IN p_peso_kg DECIMAL(8,3),
    IN p_ubicacion VARCHAR(40),
    IN p_id_categoria INT UNSIGNED,
    IN p_id_proveedor INT UNSIGNED,
    OUT p_id_producto INT UNSIGNED
)
BEGIN
    DECLARE v_sku VARCHAR(20);
    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre del producto es obligatorio';
    END IF;
    IF EXISTS (SELECT 1 FROM productos p WHERE p.nombre = TRIM(p_nombre)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe un producto con ese nombre';
    END IF;
    IF p_precio IS NULL OR p_precio <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio debe ser mayor que cero';
    END IF;
    IF p_costo IS NULL OR p_costo < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El costo no puede ser negativo';
    END IF;
    IF p_costo >= p_precio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El costo debe ser menor que el precio de venta';
    END IF;
    IF COALESCE(p_stock, 0) < 0 OR COALESCE(p_stock_minimo, 0) < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El stock y el stock mínimo no pueden ser negativos';
    END IF;
    IF p_id_categoria IS NOT NULL AND NOT EXISTS (SELECT 1 FROM categorias cat WHERE cat.id_categoria = p_id_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría indicada no existe';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM proveedores pr WHERE pr.id_proveedor = p_id_proveedor AND pr.activo = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor indicado no existe o está inactivo';
    END IF;
    SET v_sku = fn_GenerarSKU(TRIM(p_nombre), COALESCE(p_id_categoria, (SELECT cat.id_categoria FROM categorias cat WHERE cat.nombre = 'General')));
    INSERT INTO productos (id_categoria, id_proveedor, nombre, descripcion, sku, precio, costo, stock, stock_minimo, peso_kg, ubicacion)
    VALUES (p_id_categoria, p_id_proveedor, TRIM(p_nombre), p_descripcion, v_sku,
            p_precio, p_costo, COALESCE(p_stock, 0), COALESCE(p_stock_minimo, 5), COALESCE(p_peso_kg, 0), p_ubicacion);
    SET p_id_producto = LAST_INSERT_ID();
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_ActualizarDireccionCliente;
DELIMITER $$
CREATE PROCEDURE sp_ActualizarDireccionCliente(
    IN p_id_cliente INT UNSIGNED,
    IN p_direccion VARCHAR(200),
    IN p_ciudad VARCHAR(60),
    IN p_departamento VARCHAR(60),
    OUT p_pedidos_actualizados INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF p_direccion IS NULL OR TRIM(p_direccion) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección no puede estar vacía';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM clientes c WHERE c.id_cliente = p_id_cliente AND c.eliminado_en IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe';
    END IF;
    START TRANSACTION;
    UPDATE clientes
    SET direccion_envio = TRIM(p_direccion),
        ciudad = COALESCE(p_ciudad, ciudad),
        departamento = COALESCE(p_departamento, departamento)
    WHERE id_cliente = p_id_cliente;
    UPDATE ventas
    SET direccion_envio = TRIM(p_direccion)
    WHERE id_cliente = p_id_cliente
      AND estado IN ('Pendiente de Pago', 'Pagado', 'Procesando');
    SET p_pedidos_actualizados = ROW_COUNT();
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_ProcesarDevolucion;
DELIMITER $$
CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta INT UNSIGNED,
    IN p_id_producto INT UNSIGNED,
    IN p_cantidad INT,
    IN p_motivo VARCHAR(200),
    OUT p_id_credito INT UNSIGNED
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_id_cliente INT UNSIGNED;
    DECLARE v_id_detalle INT UNSIGNED;
    DECLARE v_vendida INT;
    DECLARE v_devuelta INT;
    DECLARE v_precio DECIMAL(12,2);
    DECLARE v_pendientes INT;
    DECLARE v_mensaje VARCHAR(128);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_credito = NULL;
        RESIGNAL;
    END;
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad a devolver debe ser mayor que cero';
    END IF;
    START TRANSACTION;
    SELECT v.estado, v.id_cliente
    INTO v_estado, v_id_cliente
    FROM ventas v
    WHERE v.id_venta = p_id_venta
    FOR UPDATE;
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta no existe';
    END IF;
    IF v_estado NOT IN ('Enviado', 'Entregado') THEN
        SET v_mensaje = CONCAT('Solo se aceptan devoluciones de pedidos enviados o entregados. Estado actual: ', v_estado);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
    SELECT dv.id_detalle, dv.cantidad, dv.cantidad_devuelta, dv.precio_unitario_congelado
    INTO v_id_detalle, v_vendida, v_devuelta, v_precio
    FROM detalle_venta dv
    WHERE dv.id_venta = p_id_venta
      AND dv.id_producto = p_id_producto
    FOR UPDATE;
    IF v_id_detalle IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no hace parte de esta venta';
    END IF;
    IF v_devuelta + p_cantidad > v_vendida THEN
        SET v_mensaje = CONCAT('Solo se pueden devolver ', v_vendida - v_devuelta, ' unidades de este producto');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
    UPDATE detalle_venta
    SET cantidad_devuelta = cantidad_devuelta + p_cantidad
    WHERE id_detalle = v_id_detalle;
    UPDATE productos
    SET stock = stock + p_cantidad
    WHERE id_producto = p_id_producto;
    INSERT INTO creditos_cliente (id_cliente, id_venta, monto, motivo)
    VALUES (v_id_cliente, p_id_venta, p_cantidad * v_precio, COALESCE(NULLIF(TRIM(p_motivo), ''), 'Devolución de producto'));
    SET p_id_credito = LAST_INSERT_ID();
    SELECT COALESCE(SUM(dv.cantidad - dv.cantidad_devuelta), 0)
    INTO v_pendientes
    FROM detalle_venta dv
    WHERE dv.id_venta = p_id_venta;
    IF v_pendientes = 0 THEN
        UPDATE ventas
        SET estado = 'Devuelto'
        WHERE id_venta = p_id_venta;
    END IF;
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_ObtenerHistorialComprasCliente;
DELIMITER $$
CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(IN p_id_cliente INT UNSIGNED)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM clientes c WHERE c.id_cliente = p_id_cliente) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe';
    END IF;
    SELECT c.id_cliente,
           fn_FormatearNombreCompleto(c.nombre, c.apellido) AS cliente,
           c.email,
           c.nivel_lealtad,
           fn_ContarVentasCliente(c.id_cliente) AS compras_validas,
           c.total_gastado,
           fn_CalcularDiasDesdeUltimaCompra(c.id_cliente) AS dias_desde_ultima_compra
    FROM clientes c
    WHERE c.id_cliente = p_id_cliente;
    SELECT v.id_venta,
           v.fecha_venta,
           v.estado,
           s.nombre AS sucursal,
           p.nombre AS producto,
           dv.cantidad,
           dv.precio_unitario_congelado,
           dv.subtotal,
           dv.cantidad_devuelta,
           v.total AS total_venta
    FROM ventas v
    JOIN sucursales s ON s.id_sucursal = v.id_sucursal
    JOIN detalle_venta dv ON dv.id_venta = v.id_venta
    JOIN productos p ON p.id_producto = dv.id_producto
    WHERE v.id_cliente = p_id_cliente
    ORDER BY v.fecha_venta DESC, p.nombre;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_AjustarNivelStock;
DELIMITER $$
CREATE PROCEDURE sp_AjustarNivelStock(
    IN p_id_producto INT UNSIGNED,
    IN p_nuevo_stock INT,
    IN p_motivo VARCHAR(200)
)
BEGIN
    DECLARE v_stock_actual INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF p_nuevo_stock IS NULL OR p_nuevo_stock < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nuevo stock debe ser un número mayor o igual a cero';
    END IF;
    IF p_motivo IS NULL OR CHAR_LENGTH(TRIM(p_motivo)) < 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Debe indicar un motivo claro para el ajuste';
    END IF;
    START TRANSACTION;
    SELECT p.stock
    INTO v_stock_actual
    FROM productos p
    WHERE p.id_producto = p_id_producto
    FOR UPDATE;
    IF v_stock_actual IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no existe';
    END IF;
    INSERT INTO ajustes_stock (id_producto, stock_anterior, stock_nuevo, motivo, usuario)
    VALUES (p_id_producto, v_stock_actual, p_nuevo_stock, TRIM(p_motivo), USER());
    UPDATE productos
    SET stock = p_nuevo_stock
    WHERE id_producto = p_id_producto;
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_EliminarClienteDeFormaSegura;
DELIMITER $$
CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(IN p_id_cliente INT UNSIGNED)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF NOT EXISTS (SELECT 1 FROM clientes c WHERE c.id_cliente = p_id_cliente AND c.eliminado_en IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no existe o ya fue eliminado';
    END IF;
    IF EXISTS (SELECT 1 FROM ventas v WHERE v.id_cliente = p_id_cliente AND v.estado IN ('Pendiente de Pago', 'Pagado', 'Procesando', 'Enviado')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente tiene pedidos en curso y no se puede eliminar todavía';
    END IF;
    START TRANSACTION;
    UPDATE clientes
    SET nombre = 'Cliente',
        apellido = 'Anonimizado',
        email = CONCAT('anonimo_', p_id_cliente, '@eliminado.local'),
        contrasena_hash = SHA2(UUID(), 256),
        salt = LEFT(MD5(RAND()), 16),
        telefono = NULL,
        fecha_nacimiento = NULL,
        direccion_envio = NULL,
        activo = FALSE,
        eliminado_en = NOW()
    WHERE id_cliente = p_id_cliente;
    UPDATE ventas
    SET direccion_envio = NULL
    WHERE id_cliente = p_id_cliente;
    UPDATE carritos
    SET estado = 'Abandonado',
        fecha_actualizacion = NOW()
    WHERE id_cliente = p_id_cliente
      AND estado = 'Activo';
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_AplicarDescuentoPorCategoria;
DELIMITER $$
CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(
    IN p_id_categoria INT UNSIGNED,
    IN p_porcentaje DECIMAL(5,2),
    OUT p_productos_actualizados INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF p_porcentaje IS NULL OR p_porcentaje <= 0 OR p_porcentaje >= 90 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El porcentaje de descuento debe ser mayor que 0 y menor que 90';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM categorias cat WHERE cat.id_categoria = p_id_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría no existe';
    END IF;
    IF EXISTS (SELECT 1 FROM productos p WHERE p.id_categoria = p_id_categoria AND p.eliminado_en IS NULL AND fn_AplicarDescuento(p.precio, p_porcentaje) <= p.costo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El descuento dejaría al menos un producto por debajo de su costo';
    END IF;
    START TRANSACTION;
    UPDATE productos
    SET precio = fn_AplicarDescuento(precio, p_porcentaje)
    WHERE id_categoria = p_id_categoria
      AND eliminado_en IS NULL;
    SET p_productos_actualizados = ROW_COUNT();
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_GenerarReporteMensualVentas;
DELIMITER $$
CREATE PROCEDURE sp_GenerarReporteMensualVentas(IN p_anio SMALLINT, IN p_mes TINYINT)
BEGIN
    DECLARE v_inicio DATE;
    DECLARE v_fin DATE;
    IF p_mes IS NULL OR p_mes NOT BETWEEN 1 AND 12 OR p_anio IS NULL OR p_anio < 2000 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Debe indicar un año y un mes válidos';
    END IF;
    SET v_inicio = MAKEDATE(p_anio, 1) + INTERVAL (p_mes - 1) MONTH;
    SET v_fin = v_inicio + INTERVAL 1 MONTH;
    SELECT DATE_FORMAT(v_inicio, '%Y-%m') AS periodo,
           COUNT(*) AS pedidos,
           SUM(v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')) AS pedidos_validos,
           SUM(v.estado = 'Cancelado') AS cancelados,
           SUM(v.estado = 'Devuelto') AS devueltos,
           COALESCE(SUM(CASE WHEN v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado') THEN v.total END), 0) AS ventas_totales,
           COALESCE(ROUND(AVG(CASE WHEN v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado') THEN v.total END), 2), 0) AS ticket_promedio,
           COUNT(DISTINCT v.id_cliente) AS clientes
    FROM ventas v
    WHERE v.fecha_venta >= v_inicio
      AND v.fecha_venta < v_fin;
    SELECT cat.nombre AS categoria,
           SUM(dv.cantidad) AS unidades,
           SUM(dv.subtotal) AS ingresos,
           SUM(dv.cantidad * (dv.precio_unitario_congelado - p.costo)) AS margen
    FROM ventas v
    JOIN detalle_venta dv ON dv.id_venta = v.id_venta
    JOIN productos p ON p.id_producto = dv.id_producto
    JOIN categorias cat ON cat.id_categoria = p.id_categoria
    WHERE v.fecha_venta >= v_inicio
      AND v.fecha_venta < v_fin
      AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    GROUP BY cat.nombre
    ORDER BY ingresos DESC;
    SELECT s.nombre AS sucursal,
           COUNT(*) AS pedidos,
           SUM(v.total) AS ventas
    FROM ventas v
    JOIN sucursales s ON s.id_sucursal = v.id_sucursal
    WHERE v.fecha_venta >= v_inicio
      AND v.fecha_venta < v_fin
      AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    GROUP BY s.nombre
    ORDER BY ventas DESC;
    SELECT p.nombre AS producto,
           SUM(dv.cantidad) AS unidades,
           SUM(dv.subtotal) AS ingresos
    FROM ventas v
    JOIN detalle_venta dv ON dv.id_venta = v.id_venta
    JOIN productos p ON p.id_producto = dv.id_producto
    WHERE v.fecha_venta >= v_inicio
      AND v.fecha_venta < v_fin
      AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    GROUP BY p.nombre
    ORDER BY ingresos DESC
    LIMIT 5;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_CambiarEstadoPedido;
DELIMITER $$
CREATE PROCEDURE sp_CambiarEstadoPedido(
    IN p_id_venta INT UNSIGNED,
    IN p_nuevo_estado VARCHAR(20)
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_valido BOOLEAN DEFAULT FALSE;
    DECLARE v_mensaje VARCHAR(128);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    SELECT v.estado
    INTO v_estado
    FROM ventas v
    WHERE v.id_venta = p_id_venta
    FOR UPDATE;
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta no existe';
    END IF;
    SET v_valido = CASE
        WHEN v_estado = 'Pendiente de Pago' AND p_nuevo_estado IN ('Pagado', 'Cancelado') THEN TRUE
        WHEN v_estado = 'Pagado' AND p_nuevo_estado IN ('Procesando', 'Cancelado') THEN TRUE
        WHEN v_estado = 'Procesando' AND p_nuevo_estado IN ('Enviado', 'Cancelado') THEN TRUE
        WHEN v_estado = 'Enviado' AND p_nuevo_estado IN ('Entregado', 'Devuelto') THEN TRUE
        WHEN v_estado = 'Entregado' AND p_nuevo_estado = 'Devuelto' THEN TRUE
        ELSE FALSE
    END;
    IF NOT v_valido THEN
        SET v_mensaje = CONCAT('No se permite pasar de "', v_estado, '" a "', COALESCE(p_nuevo_estado, 'NULL'), '"');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
    UPDATE ventas
    SET estado = p_nuevo_estado,
        fecha_pago = IF(p_nuevo_estado = 'Pagado', COALESCE(fecha_pago, NOW()), fecha_pago)
    WHERE id_venta = p_id_venta;
    IF p_nuevo_estado = 'Cancelado' THEN
        UPDATE productos p
        JOIN detalle_venta dv ON dv.id_producto = p.id_producto
        SET p.stock = p.stock + dv.cantidad - dv.cantidad_devuelta
        WHERE dv.id_venta = p_id_venta;
    END IF;
    IF p_nuevo_estado = 'Devuelto' THEN
        UPDATE productos p
        JOIN detalle_venta dv ON dv.id_producto = p.id_producto
        SET p.stock = p.stock + dv.cantidad - dv.cantidad_devuelta
        WHERE dv.id_venta = p_id_venta;
        INSERT INTO creditos_cliente (id_cliente, id_venta, monto, motivo)
        SELECT v.id_cliente, v.id_venta, SUM((dv.cantidad - dv.cantidad_devuelta) * dv.precio_unitario_congelado), 'Devolución total del pedido'
        FROM ventas v
        JOIN detalle_venta dv ON dv.id_venta = v.id_venta
        WHERE v.id_venta = p_id_venta
        GROUP BY v.id_cliente, v.id_venta
        HAVING SUM(dv.cantidad - dv.cantidad_devuelta) > 0;
        UPDATE detalle_venta
        SET cantidad_devuelta = cantidad
        WHERE id_venta = p_id_venta;
    END IF;
    INSERT INTO notificaciones (id_venta, canal, mensaje)
    VALUES (p_id_venta, 'Email', CONCAT('Tu pedido #', p_id_venta, ' cambió de estado: ', v_estado, ' a ', p_nuevo_estado)),
           (p_id_venta, 'Webhook', CONCAT('{"id_venta":', p_id_venta, ',"estado":"', p_nuevo_estado, '"}'));
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_RegistrarNuevoCliente;
DELIMITER $$
CREATE PROCEDURE sp_RegistrarNuevoCliente(
    IN p_nombre VARCHAR(60),
    IN p_apellido VARCHAR(60),
    IN p_email VARCHAR(120),
    IN p_contrasena VARCHAR(100),
    IN p_telefono VARCHAR(20),
    IN p_fecha_nacimiento DATE,
    IN p_direccion VARCHAR(200),
    IN p_ciudad VARCHAR(60),
    IN p_departamento VARCHAR(60),
    IN p_id_referido_por INT UNSIGNED,
    OUT p_id_cliente INT UNSIGNED
)
BEGIN
    DECLARE v_salt CHAR(16);
    IF p_nombre IS NULL OR TRIM(p_nombre) = '' OR p_apellido IS NULL OR TRIM(p_apellido) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre y el apellido son obligatorios';
    END IF;
    IF NOT fn_ValidarFormatoEmail(TRIM(p_email)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El correo electrónico no tiene un formato válido';
    END IF;
    IF EXISTS (SELECT 1 FROM clientes c WHERE c.email = LOWER(TRIM(p_email))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe un cliente registrado con ese correo';
    END IF;
    IF NOT fn_ValidarComplejidadContrasena(p_contrasena) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La contraseña debe tener mínimo 10 caracteres, mayúscula, minúscula, número y símbolo';
    END IF;
    IF p_fecha_nacimiento IS NOT NULL AND p_fecha_nacimiento > CURDATE() - INTERVAL 14 YEAR THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente debe tener al menos 14 años';
    END IF;
    IF p_id_referido_por IS NOT NULL AND NOT EXISTS (SELECT 1 FROM clientes c WHERE c.id_cliente = p_id_referido_por AND c.eliminado_en IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente que refiere no existe';
    END IF;
    SET v_salt = LEFT(SHA2(UUID(), 256), 16);
    INSERT INTO clientes (nombre, apellido, email, contrasena_hash, salt, telefono, fecha_nacimiento, direccion_envio, ciudad, departamento, id_referido_por)
    VALUES (p_nombre, p_apellido, p_email, SHA2(CONCAT(v_salt, p_contrasena), 256), v_salt, p_telefono, p_fecha_nacimiento, p_direccion, p_ciudad, p_departamento, p_id_referido_por);
    SET p_id_cliente = LAST_INSERT_ID();
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_ObtenerDetallesProductoCompleto;
DELIMITER $$
CREATE PROCEDURE sp_ObtenerDetallesProductoCompleto(IN p_id_producto INT UNSIGNED)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM productos p WHERE p.id_producto = p_id_producto) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no existe';
    END IF;
    SELECT p.id_producto,
           p.sku,
           p.nombre,
           p.descripcion,
           p.precio,
           p.costo,
           ROUND(100 * (p.precio - p.costo) / p.precio, 2) AS margen_porcentaje,
           p.stock,
           p.stock_minimo,
           p.peso_kg,
           p.ubicacion,
           p.activo,
           cat.id_categoria,
           cat.nombre AS categoria,
           pr.id_proveedor,
           pr.nombre AS proveedor,
           pr.nit,
           pr.email_contacto,
           pr.telefono_contacto,
           pr.ciudad AS ciudad_proveedor,
           (SELECT ROUND(AVG(r.calificacion), 1) FROM resenas_producto r WHERE r.id_producto = p.id_producto) AS calificacion_promedio,
           (SELECT COUNT(*) FROM resenas_producto r WHERE r.id_producto = p.id_producto) AS cantidad_resenas,
           (SELECT pm.codigo
            FROM promociones pm
            WHERE pm.id_producto = p.id_producto
              AND pm.activa = TRUE
              AND NOW() BETWEEN pm.fecha_inicio AND pm.fecha_fin
            ORDER BY pm.porcentaje_descuento DESC
            LIMIT 1) AS promocion_vigente
    FROM productos p
    JOIN categorias cat ON cat.id_categoria = p.id_categoria
    JOIN proveedores pr ON pr.id_proveedor = p.id_proveedor
    WHERE p.id_producto = p_id_producto;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_FusionarCuentasCliente;
DELIMITER $$
CREATE PROCEDURE sp_FusionarCuentasCliente(
    IN p_id_principal INT UNSIGNED,
    IN p_id_duplicado INT UNSIGNED
)
BEGIN
    DECLARE v_bloqueadas INT;
    DECLARE v_registro_duplicado DATETIME;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF p_id_principal = p_id_duplicado THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Las dos cuentas a fusionar deben ser diferentes';
    END IF;
    IF (SELECT COUNT(*) FROM clientes c WHERE c.id_cliente IN (p_id_principal, p_id_duplicado) AND c.eliminado_en IS NULL) < 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Alguna de las cuentas no existe o ya fue eliminada';
    END IF;
    START TRANSACTION;
    SELECT COUNT(*)
    INTO v_bloqueadas
    FROM clientes c
    WHERE c.id_cliente IN (p_id_principal, p_id_duplicado)
    FOR UPDATE;
    SELECT c.fecha_registro
    INTO v_registro_duplicado
    FROM clientes c
    WHERE c.id_cliente = p_id_duplicado;
    UPDATE ventas SET id_cliente = p_id_principal WHERE id_cliente = p_id_duplicado;
    UPDATE carritos SET id_cliente = p_id_principal WHERE id_cliente = p_id_duplicado;
    UPDATE visitas_producto SET id_cliente = p_id_principal WHERE id_cliente = p_id_duplicado;
    UPDATE creditos_cliente SET id_cliente = p_id_principal WHERE id_cliente = p_id_duplicado;
    DELETE r
    FROM resenas_producto r
    JOIN resenas_producto rp ON rp.id_producto = r.id_producto
                            AND rp.id_cliente = p_id_principal
    WHERE r.id_cliente = p_id_duplicado;
    UPDATE resenas_producto SET id_cliente = p_id_principal WHERE id_cliente = p_id_duplicado;
    UPDATE clientes
    SET id_referido_por = NULL
    WHERE id_cliente = p_id_principal
      AND id_referido_por = p_id_duplicado;
    UPDATE clientes
    SET id_referido_por = p_id_principal
    WHERE id_referido_por = p_id_duplicado
      AND id_cliente <> p_id_principal;
    UPDATE clientes c
    SET c.total_gastado = (
            SELECT COALESCE(SUM(v.total), 0)
            FROM ventas v
            WHERE v.id_cliente = p_id_principal
              AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
        ),
        c.fecha_ultimo_pedido = (SELECT MAX(v.fecha_venta) FROM ventas v WHERE v.id_cliente = p_id_principal),
        c.nivel_lealtad = fn_DeterminarEstadoLealtad(p_id_principal),
        c.fecha_registro = LEAST(c.fecha_registro, v_registro_duplicado)
    WHERE c.id_cliente = p_id_principal;
    UPDATE clientes
    SET nombre = 'Cuenta',
        apellido = 'Fusionada',
        email = CONCAT('fusionado_', p_id_duplicado, '@eliminado.local'),
        telefono = NULL,
        direccion_envio = NULL,
        total_gastado = 0,
        fecha_ultimo_pedido = NULL,
        activo = FALSE,
        eliminado_en = NOW()
    WHERE id_cliente = p_id_duplicado;
    COMMIT;
    SELECT p_id_principal AS cuenta_resultante,
           (SELECT COUNT(*) FROM ventas v WHERE v.id_cliente = p_id_principal) AS ventas_totales;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_AsignarProductoAProveedor;
DELIMITER $$
CREATE PROCEDURE sp_AsignarProductoAProveedor(
    IN p_id_producto INT UNSIGNED,
    IN p_id_proveedor INT UNSIGNED
)
BEGIN
    DECLARE v_actual INT UNSIGNED;
    SELECT p.id_proveedor
    INTO v_actual
    FROM productos p
    WHERE p.id_producto = p_id_producto;
    IF v_actual IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no existe';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM proveedores pr WHERE pr.id_proveedor = p_id_proveedor AND pr.activo = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe o está inactivo';
    END IF;
    IF v_actual = p_id_proveedor THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto ya está asignado a ese proveedor';
    END IF;
    UPDATE productos
    SET id_proveedor = p_id_proveedor
    WHERE id_producto = p_id_producto;
    SELECT p.id_producto, p.nombre, pr.nombre AS proveedor_nuevo
    FROM productos p
    JOIN proveedores pr ON pr.id_proveedor = p.id_proveedor
    WHERE p.id_producto = p_id_producto;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_BuscarProductos;
DELIMITER $$
CREATE PROCEDURE sp_BuscarProductos(
    IN p_texto VARCHAR(100),
    IN p_id_categoria INT UNSIGNED,
    IN p_precio_min DECIMAL(12,2),
    IN p_precio_max DECIMAL(12,2),
    IN p_solo_disponibles BOOLEAN,
    IN p_orden VARCHAR(20)
)
BEGIN
    IF p_precio_min IS NOT NULL AND p_precio_max IS NOT NULL AND p_precio_min > p_precio_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio mínimo no puede ser mayor que el máximo';
    END IF;
    SELECT p.id_producto,
           p.sku,
           p.nombre,
           cat.nombre AS categoria,
           p.precio,
           p.stock,
           (SELECT ROUND(AVG(r.calificacion), 1) FROM resenas_producto r WHERE r.id_producto = p.id_producto) AS calificacion
    FROM productos p
    JOIN categorias cat ON cat.id_categoria = p.id_categoria
    WHERE p.activo = TRUE
      AND p.eliminado_en IS NULL
      AND (p_texto IS NULL OR p.nombre LIKE CONCAT('%', p_texto, '%') OR p.descripcion LIKE CONCAT('%', p_texto, '%'))
      AND (p_id_categoria IS NULL OR p.id_categoria = p_id_categoria)
      AND (p_precio_min IS NULL OR p.precio >= p_precio_min)
      AND (p_precio_max IS NULL OR p.precio <= p_precio_max)
      AND (COALESCE(p_solo_disponibles, FALSE) = FALSE OR p.stock > 0)
    ORDER BY
        CASE WHEN p_orden = 'precio_asc' THEN p.precio END ASC,
        CASE WHEN p_orden = 'precio_desc' THEN p.precio END DESC,
        CASE WHEN p_orden = 'calificacion' THEN (SELECT AVG(r.calificacion) FROM resenas_producto r WHERE r.id_producto = p.id_producto) END DESC,
        p.nombre ASC;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_ObtenerDashboardAdmin;
DELIMITER $$
CREATE PROCEDURE sp_ObtenerDashboardAdmin()
BEGIN
    SELECT (SELECT COALESCE(SUM(v.total), 0)
            FROM ventas v
            WHERE v.fecha_venta >= CURDATE()
              AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')) AS ventas_hoy,
           (SELECT COUNT(*) FROM ventas v WHERE v.fecha_venta >= CURDATE()) AS pedidos_hoy,
           (SELECT COUNT(*) FROM clientes c WHERE c.fecha_registro >= CURDATE()) AS clientes_nuevos_hoy,
           (SELECT COUNT(*) FROM clientes c WHERE c.fecha_registro >= CURDATE() - INTERVAL 7 DAY) AS clientes_nuevos_7_dias,
           (SELECT COALESCE(SUM(v.total), 0)
            FROM ventas v
            WHERE v.fecha_venta >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
              AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')) AS ventas_mes_actual,
           (SELECT COALESCE(SUM(v.total), 0)
            FROM ventas v
            WHERE v.fecha_venta >= DATE_FORMAT(CURDATE() - INTERVAL 1 MONTH, '%Y-%m-01')
              AND v.fecha_venta < DATE_FORMAT(CURDATE(), '%Y-%m-01')
              AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')) AS ventas_mes_anterior,
           (SELECT COUNT(*) FROM ventas v WHERE v.estado = 'Pendiente de Pago') AS pendientes_de_pago,
           (SELECT COUNT(*) FROM ventas v WHERE v.estado IN ('Pagado', 'Procesando')) AS por_despachar,
           (SELECT COUNT(*) FROM productos p WHERE p.stock < p.stock_minimo AND p.activo = TRUE) AS productos_bajo_minimo,
           (SELECT COUNT(*) FROM carritos ca WHERE ca.estado = 'Activo') AS carritos_activos;
    SELECT p.nombre AS producto,
           SUM(dv.cantidad) AS unidades_7_dias
    FROM detalle_venta dv
    JOIN ventas v ON v.id_venta = dv.id_venta
    JOIN productos p ON p.id_producto = dv.id_producto
    WHERE v.fecha_venta >= CURDATE() - INTERVAL 7 DAY
      AND v.estado <> 'Cancelado'
    GROUP BY p.nombre
    ORDER BY unidades_7_dias DESC
    LIMIT 5;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_ProcesarPago;
DELIMITER $$
CREATE PROCEDURE sp_ProcesarPago(
    IN p_id_venta INT UNSIGNED,
    IN p_metodo_pago VARCHAR(30),
    IN p_monto DECIMAL(12,2)
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_total DECIMAL(12,2);
    DECLARE v_mensaje VARCHAR(128);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF p_metodo_pago NOT IN ('Tarjeta de credito', 'Tarjeta debito', 'PSE', 'Nequi', 'Contraentrega') OR p_metodo_pago IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Método de pago no válido';
    END IF;
    START TRANSACTION;
    SELECT v.estado, v.total
    INTO v_estado, v_total
    FROM ventas v
    WHERE v.id_venta = p_id_venta
    FOR UPDATE;
    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta no existe';
    END IF;
    IF v_estado <> 'Pendiente de Pago' THEN
        SET v_mensaje = CONCAT('La venta no está pendiente de pago. Estado actual: ', v_estado);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
    IF p_monto IS NULL OR p_monto <> v_total THEN
        SET v_mensaje = CONCAT('El monto recibido (', COALESCE(p_monto, 0), ') no coincide con el total de la venta (', v_total, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
    UPDATE ventas
    SET estado = 'Pagado',
        metodo_pago = p_metodo_pago,
        fecha_pago = NOW()
    WHERE id_venta = p_id_venta;
    INSERT INTO notificaciones (id_venta, canal, mensaje)
    VALUES (p_id_venta, 'SMS', CONCAT('Recibimos el pago de tu pedido #', p_id_venta, ' por $', FORMAT(v_total, 0, 'es_CO')));
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_AnadirResenaProducto;
DELIMITER $$
CREATE PROCEDURE sp_AnadirResenaProducto(
    IN p_id_cliente INT UNSIGNED,
    IN p_id_producto INT UNSIGNED,
    IN p_calificacion TINYINT,
    IN p_comentario TEXT,
    OUT p_id_resena INT UNSIGNED
)
BEGIN
    IF p_calificacion IS NULL OR p_calificacion NOT BETWEEN 1 AND 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La calificación debe estar entre 1 y 5';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM ventas v
        JOIN detalle_venta dv ON dv.id_venta = v.id_venta
        WHERE v.id_cliente = p_id_cliente
          AND dv.id_producto = p_id_producto
          AND v.estado IN ('Entregado', 'Devuelto')
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo puede reseñar productos que ya compró y recibió';
    END IF;
    IF EXISTS (SELECT 1 FROM resenas_producto r WHERE r.id_cliente = p_id_cliente AND r.id_producto = p_id_producto) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente ya publicó una reseña para este producto';
    END IF;
    INSERT INTO resenas_producto (id_producto, id_cliente, calificacion, comentario)
    VALUES (p_id_producto, p_id_cliente, p_calificacion, NULLIF(TRIM(p_comentario), ''));
    SET p_id_resena = LAST_INSERT_ID();
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_ObtenerProductosRelacionados;
DELIMITER $$
CREATE PROCEDURE sp_ObtenerProductosRelacionados(
    IN p_id_producto INT UNSIGNED,
    IN p_limite INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM productos p WHERE p.id_producto = p_id_producto) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto no existe';
    END IF;
    SELECT p.id_producto,
           p.nombre,
           p.precio,
           COUNT(DISTINCT b.id_venta) AS veces_comprados_juntos,
           COUNT(DISTINCT v.id_cliente) AS clientes_distintos
    FROM detalle_venta a
    JOIN detalle_venta b ON b.id_venta = a.id_venta
                        AND b.id_producto <> a.id_producto
    JOIN ventas v ON v.id_venta = a.id_venta
    JOIN productos p ON p.id_producto = b.id_producto
    WHERE a.id_producto = p_id_producto
      AND v.estado <> 'Cancelado'
      AND p.activo = TRUE
      AND p.eliminado_en IS NULL
    GROUP BY p.id_producto, p.nombre, p.precio
    ORDER BY veces_comprados_juntos DESC, clientes_distintos DESC
    LIMIT p_limite;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_MoverProductosEntreCategorias;
DELIMITER $$
CREATE PROCEDURE sp_MoverProductosEntreCategorias(
    IN p_id_categoria_origen INT UNSIGNED,
    IN p_id_categoria_destino INT UNSIGNED,
    IN p_ids_productos JSON,
    OUT p_productos_movidos INT
)
BEGIN
    DECLARE v_bloqueadas INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF p_id_categoria_origen = p_id_categoria_destino THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría de origen y la de destino deben ser diferentes';
    END IF;
    IF (SELECT COUNT(*) FROM categorias cat WHERE cat.id_categoria IN (p_id_categoria_origen, p_id_categoria_destino)) < 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Alguna de las categorías no existe';
    END IF;
    IF p_ids_productos IS NOT NULL AND (NOT JSON_VALID(p_ids_productos) OR JSON_TYPE(p_ids_productos) <> 'ARRAY') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista de productos debe ser un arreglo JSON, por ejemplo [3, 7]';
    END IF;
    START TRANSACTION;
    SELECT COUNT(*)
    INTO v_bloqueadas
    FROM categorias cat
    WHERE cat.id_categoria IN (p_id_categoria_origen, p_id_categoria_destino)
    FOR UPDATE;
    UPDATE productos p
    SET p.id_categoria = p_id_categoria_destino
    WHERE p.id_categoria = p_id_categoria_origen
      AND (p_ids_productos IS NULL OR p.id_producto IN (
          SELECT jt.id
          FROM JSON_TABLE(p_ids_productos, '$[*]' COLUMNS (id INT UNSIGNED PATH '$')) AS jt
      ));
    SET p_productos_movidos = ROW_COUNT();
    IF p_ids_productos IS NOT NULL AND p_productos_movidos < JSON_LENGTH(p_ids_productos) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uno o más productos no pertenecen a la categoría de origen';
    END IF;
    UPDATE categorias cat
    SET cat.cantidad_productos = (
        SELECT COUNT(*)
        FROM productos p
        WHERE p.id_categoria = cat.id_categoria
    )
    WHERE cat.id_categoria IN (p_id_categoria_origen, p_id_categoria_destino);
    COMMIT;
END$$
DELIMITER ;

GRANT EXECUTE ON PROCEDURE ecommerce_db.sp_GenerarReporteMensualVentas TO Gerente_Marketing;
GRANT EXECUTE ON PROCEDURE ecommerce_db.sp_ObtenerHistorialComprasCliente TO Gerente_Marketing;
GRANT EXECUTE ON PROCEDURE ecommerce_db.sp_ObtenerProductosRelacionados TO Gerente_Marketing;
GRANT EXECUTE ON PROCEDURE ecommerce_db.sp_BuscarProductos TO Gerente_Marketing;
