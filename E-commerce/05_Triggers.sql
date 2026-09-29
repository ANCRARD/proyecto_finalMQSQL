SET NAMES utf8mb4;
USE ecommerce_db;

CREATE TABLE IF NOT EXISTS log_cambios_precio (
    id_log INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_producto INT UNSIGNED NOT NULL,
    precio_anterior DECIMAL(12,2) NOT NULL,
    precio_nuevo DECIMAL(12,2) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_log_cambios_precio PRIMARY KEY (id_log),
    INDEX idx_log_precio_producto (id_producto),
    INDEX idx_log_precio_fecha (fecha_cambio)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS auditoria_clientes (
    id_auditoria INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_cliente INT UNSIGNED NOT NULL,
    accion VARCHAR(20) NOT NULL,
    email VARCHAR(120) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_auditoria_clientes PRIMARY KEY (id_auditoria),
    INDEX idx_auditoria_clientes_fecha (fecha)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS log_estado_pedido (
    id_log INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_venta INT UNSIGNED NOT NULL,
    estado_anterior VARCHAR(20) NOT NULL,
    estado_nuevo VARCHAR(20) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_log_estado_pedido PRIMARY KEY (id_log),
    INDEX idx_log_estado_venta (id_venta),
    INDEX idx_log_estado_fecha (fecha_cambio)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS alertas_stock (
    id_alerta INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_producto INT UNSIGNED NOT NULL,
    stock_actual INT NOT NULL,
    stock_minimo INT NOT NULL,
    atendida BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_alerta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_alertas_stock PRIMARY KEY (id_alerta),
    INDEX idx_alertas_producto (id_producto, atendida)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS ventas_archivo (
    id_venta INT UNSIGNED NOT NULL,
    id_cliente INT UNSIGNED NOT NULL,
    id_sucursal INT UNSIGNED NOT NULL,
    fecha_venta DATETIME NOT NULL,
    estado VARCHAR(20) NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    metodo_pago VARCHAR(30),
    fecha_pago DATETIME,
    direccion_envio VARCHAR(200),
    archivado_por VARCHAR(100) NOT NULL,
    fecha_archivo DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_ventas_archivo PRIMARY KEY (id_venta)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS detalle_venta_archivo (
    id_detalle INT UNSIGNED NOT NULL,
    id_venta INT UNSIGNED NOT NULL,
    id_producto INT UNSIGNED NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario_congelado DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    cantidad_devuelta INT NOT NULL,
    fecha_archivo DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_detalle_venta_archivo PRIMARY KEY (id_detalle),
    INDEX idx_detalle_archivo_venta (id_venta)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS log_permisos (
    id_log INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_permiso INT UNSIGNED NOT NULL,
    usuario_mysql VARCHAR(32) NOT NULL,
    rol_anterior VARCHAR(40) NOT NULL,
    rol_nuevo VARCHAR(40) NOT NULL,
    activo_anterior BOOLEAN NOT NULL,
    activo_nuevo BOOLEAN NOT NULL,
    accion VARCHAR(20) NOT NULL,
    ejecutado_por VARCHAR(100) NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_log_permisos PRIMARY KEY (id_log),
    INDEX idx_log_permisos_usuario (usuario_mysql)
) ENGINE = InnoDB;

DROP TRIGGER IF EXISTS trg_audit_precio_producto_after_update;
DELIMITER $$
CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <> OLD.precio THEN
        INSERT INTO log_cambios_precio (id_producto, precio_anterior, precio_nuevo, usuario)
        VALUES (NEW.id_producto, OLD.precio, NEW.precio, USER());
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_check_stock_before_insert_venta;
DELIMITER $$
CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON detalle_venta
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    DECLARE v_activo BOOLEAN;
    DECLARE v_mensaje VARCHAR(128);
    SELECT p.stock, (p.activo AND p.eliminado_en IS NULL)
    INTO v_stock, v_activo
    FROM productos p
    WHERE p.id_producto = NEW.id_producto;
    IF v_stock IS NULL THEN
        SET v_mensaje = CONCAT('El producto ', NEW.id_producto, ' no existe');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
    IF NOT v_activo THEN
        SET v_mensaje = CONCAT('El producto ', NEW.id_producto, ' no está disponible para la venta');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
    IF v_stock < NEW.cantidad THEN
        SET v_mensaje = CONCAT('Stock insuficiente para el producto ', NEW.id_producto, ': disponible ', v_stock, ', solicitado ', NEW.cantidad);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_update_stock_after_insert_venta;
DELIMITER $$
CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_venta
FOR EACH ROW
BEGIN
    UPDATE productos
    SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.id_producto;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_prevent_delete_categoria_with_products;
DELIMITER $$
CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    DECLARE v_mensaje VARCHAR(128);
    IF EXISTS (SELECT 1 FROM productos p WHERE p.id_categoria = OLD.id_categoria) THEN
        SET v_mensaje = CONCAT('No se puede eliminar la categoría "', OLD.nombre, '" porque tiene productos asociados');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert;
DELIMITER $$
CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_clientes (id_cliente, accion, email, usuario)
    VALUES (NEW.id_cliente, 'ALTA', NEW.email, USER());
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_log_order_status_change;
DELIMITER $$
CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF NEW.estado <> OLD.estado THEN
        INSERT INTO log_estado_pedido (id_venta, estado_anterior, estado_nuevo, usuario)
        VALUES (NEW.id_venta, OLD.estado, NEW.estado, USER());
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_update_total_gastado_cliente;
DELIMITER $$
CREATE TRIGGER trg_update_total_gastado_cliente
AFTER UPDATE ON ventas
FOR EACH ROW
FOLLOWS trg_log_order_status_change
BEGIN
    IF NEW.estado <> OLD.estado OR NEW.total <> OLD.total OR NEW.id_cliente <> OLD.id_cliente THEN
        UPDATE clientes c
        SET c.total_gastado = (
            SELECT COALESCE(SUM(v.total), 0)
            FROM ventas v
            WHERE v.id_cliente = NEW.id_cliente
              AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
        )
        WHERE c.id_cliente = NEW.id_cliente;
        IF NEW.id_cliente <> OLD.id_cliente THEN
            UPDATE clientes c
            SET c.total_gastado = (
                SELECT COALESCE(SUM(v.total), 0)
                FROM ventas v
                WHERE v.id_cliente = OLD.id_cliente
                  AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
            )
            WHERE c.id_cliente = OLD.id_cliente;
        END IF;
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_prevent_negative_stock;
DELIMITER $$
CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    DECLARE v_mensaje VARCHAR(128);
    IF NEW.stock < 0 THEN
        SET v_mensaje = CONCAT('El stock del producto ', OLD.id_producto, ' no puede quedar negativo (valor calculado: ', NEW.stock, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_prevent_price_zero_or_less;
DELIMITER $$
CREATE TRIGGER trg_prevent_price_zero_or_less
BEFORE UPDATE ON productos
FOR EACH ROW
FOLLOWS trg_prevent_negative_stock
BEGIN
    IF NEW.precio IS NULL OR NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio del producto debe ser mayor que cero';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_set_fecha_modificacion_producto;
DELIMITER $$
CREATE TRIGGER trg_set_fecha_modificacion_producto
BEFORE UPDATE ON productos
FOR EACH ROW
FOLLOWS trg_prevent_price_zero_or_less
BEGIN
    SET NEW.fecha_modificacion = NOW();
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_capitalize_nombre_cliente;
DELIMITER $$
CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    DECLARE v_texto VARCHAR(60);
    DECLARE v_resultado VARCHAR(60);
    DECLARE v_palabra VARCHAR(60);
    DECLARE v_campo INT DEFAULT 1;
    WHILE v_campo <= 2 DO
        SET v_texto = TRIM(REGEXP_REPLACE(IF(v_campo = 1, NEW.nombre, NEW.apellido), '[[:space:]]+', ' '));
        SET v_resultado = '';
        WHILE v_texto <> '' DO
            SET v_palabra = SUBSTRING_INDEX(v_texto, ' ', 1);
            SET v_resultado = CONCAT(v_resultado, IF(v_resultado = '', '', ' '), UPPER(LEFT(v_palabra, 1)), LOWER(SUBSTRING(v_palabra, 2)));
            IF LOCATE(' ', v_texto) = 0 THEN
                SET v_texto = '';
            ELSE
                SET v_texto = SUBSTRING(v_texto, LOCATE(' ', v_texto) + 1);
            END IF;
        END WHILE;
        IF v_campo = 1 THEN
            SET NEW.nombre = v_resultado;
        ELSE
            SET NEW.apellido = v_resultado;
        END IF;
        SET v_campo = v_campo + 1;
    END WHILE;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_recalculate_total_venta_on_detalle_change;
DELIMITER $$
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_change
AFTER UPDATE ON detalle_venta
FOR EACH ROW
BEGIN
    UPDATE ventas v
    SET v.total = (
        SELECT COALESCE(SUM(dv.subtotal), 0)
        FROM detalle_venta dv
        WHERE dv.id_venta = NEW.id_venta
    )
    WHERE v.id_venta = NEW.id_venta;
    IF NEW.id_venta <> OLD.id_venta THEN
        UPDATE ventas v
        SET v.total = (
            SELECT COALESCE(SUM(dv.subtotal), 0)
            FROM detalle_venta dv
            WHERE dv.id_venta = OLD.id_venta
        )
        WHERE v.id_venta = OLD.id_venta;
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_send_stock_alert_on_low_stock;
DELIMITER $$
CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
FOLLOWS trg_audit_precio_producto_after_update
BEGIN
    IF NEW.stock < NEW.stock_minimo AND NEW.stock < OLD.stock
       AND NOT EXISTS (SELECT 1 FROM alertas_stock a WHERE a.id_producto = NEW.id_producto AND a.atendida = FALSE) THEN
        INSERT INTO alertas_stock (id_producto, stock_actual, stock_minimo)
        VALUES (NEW.id_producto, NEW.stock, NEW.stock_minimo);
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_archive_deleted_venta;
DELIMITER $$
CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO ventas_archivo (id_venta, id_cliente, id_sucursal, fecha_venta, estado, total, metodo_pago, fecha_pago, direccion_envio, archivado_por)
    VALUES (OLD.id_venta, OLD.id_cliente, OLD.id_sucursal, OLD.fecha_venta, OLD.estado, OLD.total, OLD.metodo_pago, OLD.fecha_pago, OLD.direccion_envio, USER())
    ON DUPLICATE KEY UPDATE estado = OLD.estado, total = OLD.total, archivado_por = USER(), fecha_archivo = NOW();
    INSERT INTO detalle_venta_archivo (id_detalle, id_venta, id_producto, cantidad, precio_unitario_congelado, subtotal, cantidad_devuelta)
    SELECT dv.id_detalle, dv.id_venta, dv.id_producto, dv.cantidad, dv.precio_unitario_congelado, dv.subtotal, dv.cantidad_devuelta
    FROM detalle_venta dv
    WHERE dv.id_venta = OLD.id_venta
    ON DUPLICATE KEY UPDATE fecha_archivo = NOW();
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer;
DELIMITER $$
CREATE TRIGGER trg_validate_email_format_on_customer
BEFORE INSERT ON clientes
FOR EACH ROW
FOLLOWS trg_capitalize_nombre_cliente
BEGIN
    DECLARE v_mensaje VARCHAR(128);
    SET NEW.email = LOWER(TRIM(NEW.email));
    IF NOT fn_ValidarFormatoEmail(NEW.email) THEN
        SET v_mensaje = CONCAT('El correo "', LEFT(NEW.email, 60), '" no tiene un formato válido');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_update_last_order_date_customer;
DELIMITER $$
CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    UPDATE clientes c
    SET c.fecha_ultimo_pedido = GREATEST(COALESCE(c.fecha_ultimo_pedido, NEW.fecha_venta), NEW.fecha_venta)
    WHERE c.id_cliente = NEW.id_cliente;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_prevent_self_referral;
DELIMITER $$
CREATE TRIGGER trg_prevent_self_referral
BEFORE UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF NEW.id_referido_por IS NOT NULL AND NEW.id_referido_por = NEW.id_cliente THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede registrarse como su propio referido';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_log_permission_changes;
DELIMITER $$
CREATE TRIGGER trg_log_permission_changes
AFTER UPDATE ON permisos_usuario
FOR EACH ROW
BEGIN
    DECLARE v_accion VARCHAR(20);
    IF OLD.activo AND NOT NEW.activo THEN
        SET v_accion = 'REVOCADO';
    ELSEIF NOT OLD.activo AND NEW.activo THEN
        SET v_accion = 'REACTIVADO';
    ELSEIF NEW.rol <> OLD.rol THEN
        SET v_accion = 'CAMBIO_ROL';
    ELSE
        SET v_accion = 'MODIFICADO';
    END IF;
    INSERT INTO log_permisos (id_permiso, usuario_mysql, rol_anterior, rol_nuevo, activo_anterior, activo_nuevo, accion, ejecutado_por)
    VALUES (NEW.id_permiso, NEW.usuario_mysql, OLD.rol, NEW.rol, OLD.activo, NEW.activo, v_accion, USER());
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_assign_default_category_on_null;
DELIMITER $$
CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN
        SET NEW.id_categoria = (SELECT cat.id_categoria FROM categorias cat WHERE cat.nombre = 'General');
        IF NEW.id_categoria IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No existe la categoría General para asignar por defecto';
        END IF;
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_update_producto_count_in_categoria;
DELIMITER $$
CREATE TRIGGER trg_update_producto_count_in_categoria
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias
    SET cantidad_productos = cantidad_productos + 1
    WHERE id_categoria = NEW.id_categoria;
END$$
DELIMITER ;

GRANT SELECT ON ecommerce_db.log_cambios_precio TO Auditor_Financiero;
GRANT SELECT ON ecommerce_db.alertas_stock TO Empleado_Inventario;
