SET NAMES utf8mb4;
USE ecommerce_db;
SET GLOBAL event_scheduler = ON;

CREATE TABLE IF NOT EXISTS reporte_ventas_semanales (
    id_reporte INT UNSIGNED NOT NULL AUTO_INCREMENT,
    semana_inicio DATE NOT NULL,
    semana_fin DATE NOT NULL,
    cantidad_ventas INT NOT NULL,
    unidades_vendidas INT NOT NULL,
    total_ventas DECIMAL(14,2) NOT NULL,
    ticket_promedio DECIMAL(12,2) NOT NULL,
    clientes_distintos INT NOT NULL,
    generado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_reporte_ventas_semanales PRIMARY KEY (id_reporte),
    CONSTRAINT uq_reporte_ventas_semanales_semana_inicio UNIQUE (semana_inicio)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS resumen_ventas_diarias (
    fecha DATE NOT NULL,
    id_sucursal INT UNSIGNED NOT NULL,
    cantidad_ventas INT NOT NULL,
    unidades_vendidas INT NOT NULL,
    total_ventas DECIMAL(14,2) NOT NULL,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_resumen_ventas_diarias PRIMARY KEY (fecha, id_sucursal)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS ranking_productos (
    id_producto INT UNSIGNED NOT NULL,
    posicion INT NOT NULL,
    unidades_vendidas INT NOT NULL,
    ingresos DECIMAL(14,2) NOT NULL,
    visitas INT NOT NULL,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_ranking_productos PRIMARY KEY (id_producto),
    INDEX idx_ranking_posicion (posicion)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS kpis_mensuales (
    anio SMALLINT NOT NULL,
    mes TINYINT NOT NULL,
    total_ventas DECIMAL(14,2) NOT NULL,
    cantidad_pedidos INT NOT NULL,
    ticket_promedio DECIMAL(12,2) NOT NULL,
    clientes_nuevos INT NOT NULL,
    clientes_activos INT NOT NULL,
    tasa_cancelacion DECIMAL(5,2) NOT NULL,
    margen_bruto DECIMAL(14,2) NOT NULL,
    calculado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_kpis_mensuales PRIMARY KEY (anio, mes)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS tamano_bd_log (
    id_registro INT UNSIGNED NOT NULL AUTO_INCREMENT,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cantidad_tablas INT NOT NULL,
    tamano_datos_mb DECIMAL(10,2) NOT NULL,
    tamano_indices_mb DECIMAL(10,2) NOT NULL,
    tamano_total_mb DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_tamano_bd_log PRIMARY KEY (id_registro)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS reporte_proveedores_mensual (
    anio SMALLINT NOT NULL,
    mes TINYINT NOT NULL,
    id_proveedor INT UNSIGNED NOT NULL,
    posicion INT NOT NULL,
    unidades_vendidas INT NOT NULL,
    ingresos DECIMAL(14,2) NOT NULL,
    margen DECIMAL(14,2) NOT NULL,
    generado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_reporte_proveedores_mensual PRIMARY KEY (anio, mes, id_proveedor)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS lista_reabastecimiento (
    id_item INT UNSIGNED NOT NULL AUTO_INCREMENT,
    fecha_lista DATE NOT NULL,
    id_producto INT UNSIGNED NOT NULL,
    id_proveedor INT UNSIGNED NOT NULL,
    stock_actual INT NOT NULL,
    stock_minimo INT NOT NULL,
    cantidad_sugerida INT NOT NULL,
    CONSTRAINT pk_lista_reabastecimiento PRIMARY KEY (id_item),
    CONSTRAINT uq_reabastecimiento_fecha_producto UNIQUE (fecha_lista, id_producto)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS cupones_cumpleanos (
    id_cupon INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_cliente INT UNSIGNED NOT NULL,
    codigo VARCHAR(30) NOT NULL,
    porcentaje_descuento DECIMAL(5,2) NOT NULL,
    fecha_generacion DATE NOT NULL,
    fecha_vencimiento DATE NOT NULL,
    usado BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_cupones_cumpleanos PRIMARY KEY (id_cupon),
    CONSTRAINT uq_cupones_cumpleanos_codigo UNIQUE (codigo),
    CONSTRAINT uq_cupones_cliente_fecha UNIQUE (id_cliente, fecha_generacion)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS actividad_sospechosa (
    id_registro INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_cliente INT UNSIGNED NOT NULL,
    tipo VARCHAR(60) NOT NULL,
    detalle VARCHAR(255) NOT NULL,
    cantidad_eventos INT NOT NULL,
    revisado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_deteccion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_actividad_sospechosa PRIMARY KEY (id_registro),
    INDEX idx_actividad_cliente_tipo (id_cliente, tipo, fecha_deteccion)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS inconsistencias_datos (
    id_registro INT UNSIGNED NOT NULL AUTO_INCREMENT,
    tipo VARCHAR(60) NOT NULL,
    tabla VARCHAR(64) NOT NULL,
    id_afectado INT UNSIGNED NOT NULL,
    detalle VARCHAR(255) NOT NULL,
    fecha_deteccion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_inconsistencias_datos PRIMARY KEY (id_registro)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS mv_ventas_categoria_mensual (
    anio SMALLINT NOT NULL,
    mes TINYINT NOT NULL,
    id_categoria INT UNSIGNED NOT NULL,
    categoria VARCHAR(80) NOT NULL,
    cantidad_pedidos INT NOT NULL,
    unidades_vendidas INT NOT NULL,
    ingresos DECIMAL(14,2) NOT NULL,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_mv_ventas_categoria_mensual PRIMARY KEY (anio, mes, id_categoria)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS mv_resumen_clientes (
    id_cliente INT UNSIGNED NOT NULL,
    nombre_completo VARCHAR(130) NOT NULL,
    ciudad VARCHAR(60),
    cantidad_compras INT NOT NULL,
    total_gastado DECIMAL(12,2) NOT NULL,
    ticket_promedio DECIMAL(12,2) NOT NULL,
    primera_compra DATETIME,
    ultima_compra DATETIME,
    nivel_lealtad VARCHAR(10) NOT NULL,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_mv_resumen_clientes PRIMARY KEY (id_cliente)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS log_cambios_precio_historico (
    id_log INT UNSIGNED NOT NULL,
    id_producto INT UNSIGNED NOT NULL,
    precio_anterior DECIMAL(12,2) NOT NULL,
    precio_nuevo DECIMAL(12,2) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_cambio DATETIME NOT NULL,
    fecha_archivado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_log_cambios_precio_historico PRIMARY KEY (id_log)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS auditoria_clientes_historico (
    id_auditoria INT UNSIGNED NOT NULL,
    id_cliente INT UNSIGNED NOT NULL,
    accion VARCHAR(20) NOT NULL,
    email VARCHAR(120) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha DATETIME NOT NULL,
    fecha_archivado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_auditoria_clientes_historico PRIMARY KEY (id_auditoria)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS log_estado_pedido_historico (
    id_log INT UNSIGNED NOT NULL,
    id_venta INT UNSIGNED NOT NULL,
    estado_anterior VARCHAR(20) NOT NULL,
    estado_nuevo VARCHAR(20) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_cambio DATETIME NOT NULL,
    fecha_archivado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_log_estado_pedido_historico PRIMARY KEY (id_log)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS log_permisos_historico (
    id_log INT UNSIGNED NOT NULL,
    id_permiso INT UNSIGNED NOT NULL,
    usuario_mysql VARCHAR(32) NOT NULL,
    rol_anterior VARCHAR(40) NOT NULL,
    rol_nuevo VARCHAR(40) NOT NULL,
    activo_anterior BOOLEAN NOT NULL,
    activo_nuevo BOOLEAN NOT NULL,
    accion VARCHAR(20) NOT NULL,
    ejecutado_por VARCHAR(100) NOT NULL,
    fecha DATETIME NOT NULL,
    fecha_archivado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_log_permisos_historico PRIMARY KEY (id_log)
) ENGINE = InnoDB;

DROP PROCEDURE IF EXISTS sp_evt_limpiar_tablas_tmp;
DELIMITER $$
CREATE PROCEDURE sp_evt_limpiar_tablas_tmp()
BEGIN
    DECLARE v_fin BOOLEAN DEFAULT FALSE;
    DECLARE v_tabla VARCHAR(64);
    DECLARE cur_tablas CURSOR FOR
        SELECT t.table_name
        FROM information_schema.tables t
        WHERE t.table_schema = DATABASE()
          AND t.table_name LIKE 'tmp\_%';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = TRUE;
    OPEN cur_tablas;
    lectura: LOOP
        FETCH cur_tablas INTO v_tabla;
        IF v_fin THEN
            LEAVE lectura;
        END IF;
        SET @v_sql = CONCAT('DROP TABLE IF EXISTS `', v_tabla, '`');
        PREPARE stmt FROM @v_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;
    CLOSE cur_tablas;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_evt_backup_tablas_criticas;
DELIMITER $$
CREATE PROCEDURE sp_evt_backup_tablas_criticas()
BEGIN
    DECLARE v_fin BOOLEAN DEFAULT FALSE;
    DECLARE v_tabla VARCHAR(64);
    DECLARE v_sufijo CHAR(8);
    DECLARE cur_viejas CURSOR FOR
        SELECT t.table_name
        FROM information_schema.tables t
        WHERE t.table_schema = DATABASE()
          AND t.table_name REGEXP '^bk_[a-z_]+_[0-9]{8}$'
          AND STR_TO_DATE(RIGHT(t.table_name, 8), '%Y%m%d') < CURDATE() - INTERVAL 7 DAY;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = TRUE;
    SET v_sufijo = DATE_FORMAT(CURDATE(), '%Y%m%d');
    SET @v_i = 1;
    WHILE @v_i <= 4 DO
        SET v_tabla = ELT(@v_i, 'clientes', 'productos', 'ventas', 'detalle_venta');
        SET @v_sql = CONCAT('DROP TABLE IF EXISTS `bk_', v_tabla, '_', v_sufijo, '`');
        PREPARE stmt FROM @v_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        SET @v_sql = CONCAT('CREATE TABLE `bk_', v_tabla, '_', v_sufijo, '` AS SELECT * FROM `', v_tabla, '`');
        PREPARE stmt FROM @v_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        SET @v_i = @v_i + 1;
    END WHILE;
    OPEN cur_viejas;
    lectura: LOOP
        FETCH cur_viejas INTO v_tabla;
        IF v_fin THEN
            LEAVE lectura;
        END IF;
        SET @v_sql = CONCAT('DROP TABLE IF EXISTS `', v_tabla, '`');
        PREPARE stmt FROM @v_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;
    CLOSE cur_viejas;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_evt_reconstruir_indices;
DELIMITER $$
CREATE PROCEDURE sp_evt_reconstruir_indices()
BEGIN
    DECLARE v_i INT DEFAULT 1;
    DECLARE v_tabla VARCHAR(64);
    WHILE v_i <= 6 DO
        SET v_tabla = ELT(v_i, 'productos', 'clientes', 'ventas', 'detalle_venta', 'visitas_producto', 'carrito_detalle');
        SET @v_sql = CONCAT('ALTER TABLE `', v_tabla, '` ENGINE = InnoDB');
        PREPARE stmt FROM @v_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        SET v_i = v_i + 1;
    END WHILE;
END$$
DELIMITER ;

DROP EVENT IF EXISTS evt_generate_weekly_sales_report;
DELIMITER $$
CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK
STARTS (CURRENT_DATE + INTERVAL (7 - WEEKDAY(CURRENT_DATE)) DAY + INTERVAL 1 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_inicio DATE;
    DECLARE v_fin DATE;
    SET v_inicio = CURDATE() - INTERVAL WEEKDAY(CURDATE()) DAY - INTERVAL 7 DAY;
    SET v_fin = v_inicio + INTERVAL 6 DAY;
    INSERT INTO reporte_ventas_semanales (semana_inicio, semana_fin, cantidad_ventas, unidades_vendidas, total_ventas, ticket_promedio, clientes_distintos)
    SELECT *
    FROM (
        SELECT v_inicio AS semana_inicio,
               v_fin AS semana_fin,
               COUNT(*) AS cantidad_ventas,
               COALESCE((SELECT SUM(dv.cantidad)
                         FROM detalle_venta dv
                         JOIN ventas v2 ON v2.id_venta = dv.id_venta
                         WHERE v2.fecha_venta >= v_inicio
                           AND v2.fecha_venta < v_fin + INTERVAL 1 DAY
                           AND v2.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')), 0) AS unidades_vendidas,
               COALESCE(SUM(v.total), 0) AS total_ventas,
               COALESCE(ROUND(AVG(v.total), 2), 0) AS ticket_promedio,
               COUNT(DISTINCT v.id_cliente) AS clientes_distintos
        FROM ventas v
        WHERE v.fecha_venta >= v_inicio
          AND v.fecha_venta < v_fin + INTERVAL 1 DAY
          AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    ) AS nuevo
    ON DUPLICATE KEY UPDATE cantidad_ventas = nuevo.cantidad_ventas,
                            unidades_vendidas = nuevo.unidades_vendidas,
                            total_ventas = nuevo.total_ventas,
                            ticket_promedio = nuevo.ticket_promedio,
                            clientes_distintos = nuevo.clientes_distintos,
                            generado_en = NOW();
END$$
DELIMITER ;

DROP EVENT IF EXISTS evt_cleanup_temp_tables_daily;
CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 3 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO CALL sp_evt_limpiar_tablas_tmp();

DROP EVENT IF EXISTS evt_archive_old_logs_monthly;
DELIMITER $$
CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS (LAST_DAY(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 4 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_limite DATETIME;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    SET v_limite = NOW() - INTERVAL 6 MONTH;
    START TRANSACTION;
    INSERT IGNORE INTO log_cambios_precio_historico (id_log, id_producto, precio_anterior, precio_nuevo, usuario, fecha_cambio)
    SELECT id_log, id_producto, precio_anterior, precio_nuevo, usuario, fecha_cambio
    FROM log_cambios_precio
    WHERE fecha_cambio < v_limite;
    DELETE FROM log_cambios_precio WHERE fecha_cambio < v_limite;
    INSERT IGNORE INTO auditoria_clientes_historico (id_auditoria, id_cliente, accion, email, usuario, fecha)
    SELECT id_auditoria, id_cliente, accion, email, usuario, fecha
    FROM auditoria_clientes
    WHERE fecha < v_limite;
    DELETE FROM auditoria_clientes WHERE fecha < v_limite;
    INSERT IGNORE INTO log_estado_pedido_historico (id_log, id_venta, estado_anterior, estado_nuevo, usuario, fecha_cambio)
    SELECT id_log, id_venta, estado_anterior, estado_nuevo, usuario, fecha_cambio
    FROM log_estado_pedido
    WHERE fecha_cambio < v_limite;
    DELETE FROM log_estado_pedido WHERE fecha_cambio < v_limite;
    INSERT IGNORE INTO log_permisos_historico (id_log, id_permiso, usuario_mysql, rol_anterior, rol_nuevo, activo_anterior, activo_nuevo, accion, ejecutado_por, fecha)
    SELECT id_log, id_permiso, usuario_mysql, rol_anterior, rol_nuevo, activo_anterior, activo_nuevo, accion, ejecutado_por, fecha
    FROM log_permisos
    WHERE fecha < v_limite;
    DELETE FROM log_permisos WHERE fecha < v_limite;
    COMMIT;
END$$
DELIMITER ;

DROP EVENT IF EXISTS evt_deactivate_expired_promotions_hourly;
CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS (CURRENT_TIMESTAMP + INTERVAL 5 MINUTE)
ON COMPLETION PRESERVE
ENABLE
DO
    UPDATE promociones
    SET activa = FALSE
    WHERE activa = TRUE
      AND fecha_fin < NOW();

DROP EVENT IF EXISTS evt_recalculate_customer_loyalty_tiers_nightly;
CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO
    UPDATE clientes
    SET nivel_lealtad = fn_DeterminarEstadoLealtad(id_cliente)
    WHERE eliminado_en IS NULL;

DROP EVENT IF EXISTS evt_generate_reorder_list_daily;
CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 6 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO
    INSERT INTO lista_reabastecimiento (fecha_lista, id_producto, id_proveedor, stock_actual, stock_minimo, cantidad_sugerida)
    SELECT *
    FROM (
        SELECT CURDATE() AS fecha_lista,
               p.id_producto,
               p.id_proveedor,
               p.stock AS stock_actual,
               p.stock_minimo,
               p.stock_minimo * 2 - p.stock AS cantidad_sugerida
        FROM productos p
        WHERE p.activo = TRUE
          AND p.eliminado_en IS NULL
          AND p.stock < p.stock_minimo
    ) AS nuevo
    ON DUPLICATE KEY UPDATE stock_actual = nuevo.stock_actual,
                            cantidad_sugerida = nuevo.cantidad_sugerida;

DROP EVENT IF EXISTS evt_rebuild_indexes_weekly;
CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS (CURRENT_DATE + INTERVAL (6 - WEEKDAY(CURRENT_DATE)) DAY + INTERVAL 3 HOUR + INTERVAL 30 MINUTE)
ON COMPLETION PRESERVE
ENABLE
DO CALL sp_evt_reconstruir_indices();

DROP EVENT IF EXISTS evt_suspend_inactive_accounts_quarterly;
CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 1 QUARTER
STARTS (MAKEDATE(YEAR(CURRENT_DATE), 1) + INTERVAL QUARTER(CURRENT_DATE) QUARTER + INTERVAL 5 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO
    UPDATE clientes
    SET activo = FALSE
    WHERE activo = TRUE
      AND eliminado_en IS NULL
      AND COALESCE(fecha_ultimo_pedido, fecha_registro) < NOW() - INTERVAL 1 YEAR;

DROP EVENT IF EXISTS evt_aggregate_daily_sales_data;
CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 15 MINUTE)
ON COMPLETION PRESERVE
ENABLE
DO
    INSERT INTO resumen_ventas_diarias (fecha, id_sucursal, cantidad_ventas, unidades_vendidas, total_ventas)
    SELECT *
    FROM (
        SELECT DATE(v.fecha_venta) AS fecha,
               v.id_sucursal,
               COUNT(DISTINCT v.id_venta) AS cantidad_ventas,
               SUM(dv.cantidad) AS unidades_vendidas,
               SUM(dv.subtotal) AS total_ventas
        FROM ventas v
        JOIN detalle_venta dv ON dv.id_venta = v.id_venta
        WHERE v.fecha_venta >= CURDATE() - INTERVAL 1 DAY
          AND v.fecha_venta < CURDATE()
          AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
        GROUP BY DATE(v.fecha_venta), v.id_sucursal
    ) AS nuevo
    ON DUPLICATE KEY UPDATE cantidad_ventas = nuevo.cantidad_ventas,
                            unidades_vendidas = nuevo.unidades_vendidas,
                            total_ventas = nuevo.total_ventas,
                            actualizado_en = NOW();

DROP EVENT IF EXISTS evt_check_data_consistency_nightly;
DELIMITER $$
CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR + INTERVAL 30 MINUTE)
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO inconsistencias_datos (tipo, tabla, id_afectado, detalle)
    SELECT 'Venta sin detalles', 'ventas', v.id_venta, CONCAT('La venta del ', v.fecha_venta, ' no tiene productos')
    FROM ventas v
    WHERE v.fecha_venta < NOW() - INTERVAL 1 HOUR
      AND NOT EXISTS (SELECT 1 FROM detalle_venta dv WHERE dv.id_venta = v.id_venta);
    INSERT INTO inconsistencias_datos (tipo, tabla, id_afectado, detalle)
    SELECT 'Total de venta descuadrado', 'ventas', v.id_venta, CONCAT('Total registrado ', v.total, ' y suma de detalles ', t.suma)
    FROM ventas v
    JOIN (
        SELECT id_venta, SUM(subtotal) AS suma
        FROM detalle_venta
        GROUP BY id_venta
    ) t ON t.id_venta = v.id_venta
    WHERE v.total <> t.suma;
    INSERT INTO inconsistencias_datos (tipo, tabla, id_afectado, detalle)
    SELECT 'Total gastado descuadrado', 'clientes', c.id_cliente, CONCAT('Registrado ', c.total_gastado, ' y calculado ', COALESCE(t.suma, 0))
    FROM clientes c
    LEFT JOIN (
        SELECT id_cliente, SUM(total) AS suma
        FROM ventas
        WHERE estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
        GROUP BY id_cliente
    ) t ON t.id_cliente = c.id_cliente
    WHERE c.total_gastado <> COALESCE(t.suma, 0);
    INSERT INTO inconsistencias_datos (tipo, tabla, id_afectado, detalle)
    SELECT 'Contador de productos descuadrado', 'categorias', cat.id_categoria, CONCAT('Registrado ', cat.cantidad_productos, ' y real ', COUNT(p.id_producto))
    FROM categorias cat
    LEFT JOIN productos p ON p.id_categoria = cat.id_categoria
    GROUP BY cat.id_categoria, cat.cantidad_productos
    HAVING cat.cantidad_productos <> COUNT(p.id_producto);
END$$
DELIMITER ;

DROP EVENT IF EXISTS evt_send_birthday_greetings_daily;
CREATE EVENT evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 7 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO
    INSERT IGNORE INTO cupones_cumpleanos (id_cliente, codigo, porcentaje_descuento, fecha_generacion, fecha_vencimiento)
    SELECT c.id_cliente,
           CONCAT('CUMPLE', DATE_FORMAT(CURDATE(), '%Y'), '-', LPAD(c.id_cliente, 5, '0')),
           15,
           CURDATE(),
           CURDATE() + INTERVAL 30 DAY
    FROM clientes c
    WHERE c.activo = TRUE
      AND c.eliminado_en IS NULL
      AND MONTH(c.fecha_nacimiento) = MONTH(CURDATE())
      AND DAY(c.fecha_nacimiento) = DAY(CURDATE());

DROP EVENT IF EXISTS evt_update_product_rankings_hourly;
DELIMITER $$
CREATE EVENT evt_update_product_rankings_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS (CURRENT_TIMESTAMP + INTERVAL 10 MINUTE)
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    DELETE FROM ranking_productos;
    INSERT INTO ranking_productos (id_producto, posicion, unidades_vendidas, ingresos, visitas)
    SELECT t.id_producto,
           RANK() OVER (ORDER BY t.unidades DESC, t.ingresos DESC),
           t.unidades,
           t.ingresos,
           t.visitas
    FROM (
        SELECT p.id_producto,
               COALESCE(vt.unidades, 0) AS unidades,
               COALESCE(vt.ingresos, 0) AS ingresos,
               (SELECT COUNT(*)
                FROM visitas_producto vp
                WHERE vp.id_producto = p.id_producto
                  AND vp.fecha_visita >= NOW() - INTERVAL 90 DAY) AS visitas
        FROM productos p
        LEFT JOIN (
            SELECT dv.id_producto, SUM(dv.cantidad) AS unidades, SUM(dv.subtotal) AS ingresos
            FROM detalle_venta dv
            JOIN ventas v ON v.id_venta = dv.id_venta
            WHERE v.fecha_venta >= NOW() - INTERVAL 90 DAY
              AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
            GROUP BY dv.id_producto
        ) vt ON vt.id_producto = p.id_producto
        WHERE p.eliminado_en IS NULL
    ) t;
    COMMIT;
END$$
DELIMITER ;

DROP EVENT IF EXISTS evt_backup_critical_tables_daily;
CREATE EVENT evt_backup_critical_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 HOUR + INTERVAL 30 MINUTE)
ON COMPLETION PRESERVE
ENABLE
DO CALL sp_evt_backup_tablas_criticas();

DROP EVENT IF EXISTS evt_clear_abandoned_carts_daily;
DELIMITER $$
CREATE EVENT evt_clear_abandoned_carts_daily
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 4 HOUR + INTERVAL 30 MINUTE)
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_limite DATETIME;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    SET v_limite = NOW() - INTERVAL 72 HOUR;
    START TRANSACTION;
    DELETE cd
    FROM carrito_detalle cd
    JOIN carritos c ON c.id_carrito = cd.id_carrito
    WHERE c.estado = 'Activo'
      AND c.fecha_actualizacion < v_limite;
    UPDATE carritos
    SET estado = 'Abandonado'
    WHERE estado = 'Activo'
      AND fecha_actualizacion < v_limite;
    COMMIT;
END$$
DELIMITER ;

DROP EVENT IF EXISTS evt_calculate_monthly_kpis;
DELIMITER $$
CREATE EVENT evt_calculate_monthly_kpis
ON SCHEDULE EVERY 1 MONTH
STARTS (LAST_DAY(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 2 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_inicio DATE;
    DECLARE v_fin DATE;
    SET v_inicio = DATE_FORMAT(CURDATE() - INTERVAL 1 MONTH, '%Y-%m-01');
    SET v_fin = v_inicio + INTERVAL 1 MONTH;
    INSERT INTO kpis_mensuales (anio, mes, total_ventas, cantidad_pedidos, ticket_promedio, clientes_nuevos, clientes_activos, tasa_cancelacion, margen_bruto)
    SELECT *
    FROM (
        SELECT YEAR(v_inicio) AS anio,
               MONTH(v_inicio) AS mes,
               COALESCE(SUM(CASE WHEN v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado') THEN v.total END), 0) AS total_ventas,
               COUNT(*) AS cantidad_pedidos,
               COALESCE(ROUND(AVG(CASE WHEN v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado') THEN v.total END), 2), 0) AS ticket_promedio,
               (SELECT COUNT(*) FROM clientes c WHERE c.fecha_registro >= v_inicio AND c.fecha_registro < v_fin) AS clientes_nuevos,
               COUNT(DISTINCT v.id_cliente) AS clientes_activos,
               COALESCE(ROUND(100 * SUM(v.estado = 'Cancelado') / NULLIF(COUNT(*), 0), 2), 0) AS tasa_cancelacion,
               COALESCE((SELECT SUM(dv.cantidad * (dv.precio_unitario_congelado - p.costo))
                         FROM detalle_venta dv
                         JOIN ventas v2 ON v2.id_venta = dv.id_venta
                         JOIN productos p ON p.id_producto = dv.id_producto
                         WHERE v2.fecha_venta >= v_inicio
                           AND v2.fecha_venta < v_fin
                           AND v2.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')), 0) AS margen_bruto
        FROM ventas v
        WHERE v.fecha_venta >= v_inicio
          AND v.fecha_venta < v_fin
    ) AS nuevo
    ON DUPLICATE KEY UPDATE total_ventas = nuevo.total_ventas,
                            cantidad_pedidos = nuevo.cantidad_pedidos,
                            ticket_promedio = nuevo.ticket_promedio,
                            clientes_nuevos = nuevo.clientes_nuevos,
                            clientes_activos = nuevo.clientes_activos,
                            tasa_cancelacion = nuevo.tasa_cancelacion,
                            margen_bruto = nuevo.margen_bruto,
                            calculado_en = NOW();
END$$
DELIMITER ;

DROP EVENT IF EXISTS evt_refresh_materialized_views_nightly;
DELIMITER $$
CREATE EVENT evt_refresh_materialized_views_nightly
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 3 HOUR + INTERVAL 15 MINUTE)
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    DELETE FROM mv_ventas_categoria_mensual;
    INSERT INTO mv_ventas_categoria_mensual (anio, mes, id_categoria, categoria, cantidad_pedidos, unidades_vendidas, ingresos)
    SELECT YEAR(v.fecha_venta), MONTH(v.fecha_venta), cat.id_categoria, cat.nombre,
           COUNT(DISTINCT v.id_venta), SUM(dv.cantidad), SUM(dv.subtotal)
    FROM ventas v
    JOIN detalle_venta dv ON dv.id_venta = v.id_venta
    JOIN productos p ON p.id_producto = dv.id_producto
    JOIN categorias cat ON cat.id_categoria = p.id_categoria
    WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    GROUP BY YEAR(v.fecha_venta), MONTH(v.fecha_venta), cat.id_categoria, cat.nombre;
    DELETE FROM mv_resumen_clientes;
    INSERT INTO mv_resumen_clientes (id_cliente, nombre_completo, ciudad, cantidad_compras, total_gastado, ticket_promedio, primera_compra, ultima_compra, nivel_lealtad)
    SELECT c.id_cliente,
           fn_FormatearNombreCompleto(c.nombre, c.apellido),
           c.ciudad,
           COUNT(v.id_venta),
           COALESCE(SUM(v.total), 0),
           COALESCE(ROUND(AVG(v.total), 2), 0),
           MIN(v.fecha_venta),
           MAX(v.fecha_venta),
           c.nivel_lealtad
    FROM clientes c
    LEFT JOIN ventas v ON v.id_cliente = c.id_cliente
                      AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    WHERE c.eliminado_en IS NULL
    GROUP BY c.id_cliente, c.nombre, c.apellido, c.ciudad, c.nivel_lealtad;
    COMMIT;
END$$
DELIMITER ;

DROP EVENT IF EXISTS evt_log_database_size_weekly;
CREATE EVENT evt_log_database_size_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS (CURRENT_DATE + INTERVAL (6 - WEEKDAY(CURRENT_DATE)) DAY + INTERVAL 23 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO
    INSERT INTO tamano_bd_log (cantidad_tablas, tamano_datos_mb, tamano_indices_mb, tamano_total_mb)
    SELECT COUNT(*),
           ROUND(SUM(t.data_length) / 1048576, 2),
           ROUND(SUM(t.index_length) / 1048576, 2),
           ROUND(SUM(t.data_length + t.index_length) / 1048576, 2)
    FROM information_schema.tables t
    WHERE t.table_schema = DATABASE()
      AND t.table_type = 'BASE TABLE';

DROP EVENT IF EXISTS evt_detect_fraudulent_activity_hourly;
DELIMITER $$
CREATE EVENT evt_detect_fraudulent_activity_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS (CURRENT_TIMESTAMP + INTERVAL 15 MINUTE)
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO actividad_sospechosa (id_cliente, tipo, detalle, cantidad_eventos)
    SELECT v.id_cliente,
           'Pedidos cancelados repetidos',
           CONCAT(COUNT(*), ' pedidos cancelados en las últimas 24 horas'),
           COUNT(*)
    FROM ventas v
    WHERE v.estado = 'Cancelado'
      AND v.fecha_venta >= NOW() - INTERVAL 24 HOUR
      AND NOT EXISTS (
          SELECT 1
          FROM actividad_sospechosa a
          WHERE a.id_cliente = v.id_cliente
            AND a.tipo = 'Pedidos cancelados repetidos'
            AND a.fecha_deteccion >= NOW() - INTERVAL 24 HOUR
      )
    GROUP BY v.id_cliente
    HAVING COUNT(*) >= 3;
    INSERT INTO actividad_sospechosa (id_cliente, tipo, detalle, cantidad_eventos)
    SELECT v.id_cliente,
           'Pedidos masivos en una hora',
           CONCAT(COUNT(*), ' pedidos creados en la última hora'),
           COUNT(*)
    FROM ventas v
    WHERE v.fecha_venta >= NOW() - INTERVAL 1 HOUR
      AND NOT EXISTS (
          SELECT 1
          FROM actividad_sospechosa a
          WHERE a.id_cliente = v.id_cliente
            AND a.tipo = 'Pedidos masivos en una hora'
            AND a.fecha_deteccion >= NOW() - INTERVAL 1 HOUR
      )
    GROUP BY v.id_cliente
    HAVING COUNT(*) >= 5;
    INSERT INTO actividad_sospechosa (id_cliente, tipo, detalle, cantidad_eventos)
    SELECT v.id_cliente,
           'Pagos pendientes acumulados',
           CONCAT(COUNT(*), ' pedidos sin pagar en las últimas 24 horas'),
           COUNT(*)
    FROM ventas v
    WHERE v.estado = 'Pendiente de Pago'
      AND v.fecha_venta >= NOW() - INTERVAL 24 HOUR
      AND NOT EXISTS (
          SELECT 1
          FROM actividad_sospechosa a
          WHERE a.id_cliente = v.id_cliente
            AND a.tipo = 'Pagos pendientes acumulados'
            AND a.fecha_deteccion >= NOW() - INTERVAL 24 HOUR
      )
    GROUP BY v.id_cliente
    HAVING COUNT(*) >= 4;
END$$
DELIMITER ;

DROP EVENT IF EXISTS evt_generate_supplier_performance_report_monthly;
DELIMITER $$
CREATE EVENT evt_generate_supplier_performance_report_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS (LAST_DAY(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 3 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_inicio DATE;
    DECLARE v_fin DATE;
    SET v_inicio = DATE_FORMAT(CURDATE() - INTERVAL 1 MONTH, '%Y-%m-01');
    SET v_fin = v_inicio + INTERVAL 1 MONTH;
    DELETE FROM reporte_proveedores_mensual
    WHERE anio = YEAR(v_inicio)
      AND mes = MONTH(v_inicio);
    INSERT INTO reporte_proveedores_mensual (anio, mes, id_proveedor, posicion, unidades_vendidas, ingresos, margen)
    SELECT YEAR(v_inicio),
           MONTH(v_inicio),
           t.id_proveedor,
           RANK() OVER (ORDER BY t.ingresos DESC),
           t.unidades,
           t.ingresos,
           t.margen
    FROM (
        SELECT pr.id_proveedor,
               COALESCE(SUM(x.cantidad), 0) AS unidades,
               COALESCE(SUM(x.subtotal), 0) AS ingresos,
               COALESCE(SUM(x.cantidad * (x.precio_unitario_congelado - x.costo)), 0) AS margen
        FROM proveedores pr
        LEFT JOIN (
            SELECT p.id_proveedor, dv.cantidad, dv.subtotal, dv.precio_unitario_congelado, p.costo
            FROM detalle_venta dv
            JOIN ventas v ON v.id_venta = dv.id_venta
            JOIN productos p ON p.id_producto = dv.id_producto
            WHERE v.fecha_venta >= v_inicio
              AND v.fecha_venta < v_fin
              AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
        ) x ON x.id_proveedor = pr.id_proveedor
        GROUP BY pr.id_proveedor
    ) t;
END$$
DELIMITER ;

DROP EVENT IF EXISTS evt_purge_soft_deleted_records_weekly;
DELIMITER $$
CREATE EVENT evt_purge_soft_deleted_records_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS (CURRENT_DATE + INTERVAL (6 - WEEKDAY(CURRENT_DATE)) DAY + INTERVAL 4 HOUR)
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DECLARE v_limite DATETIME;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    SET v_limite = NOW() - INTERVAL 30 DAY;
    START TRANSACTION;
    DELETE c
    FROM clientes c
    WHERE c.eliminado_en IS NOT NULL
      AND c.eliminado_en < v_limite
      AND NOT EXISTS (SELECT 1 FROM ventas v WHERE v.id_cliente = c.id_cliente)
      AND NOT EXISTS (SELECT 1 FROM creditos_cliente cc WHERE cc.id_cliente = c.id_cliente);
    DELETE p
    FROM productos p
    WHERE p.eliminado_en IS NOT NULL
      AND p.eliminado_en < v_limite
      AND NOT EXISTS (SELECT 1 FROM detalle_venta dv WHERE dv.id_producto = p.id_producto);
    UPDATE categorias cat
    SET cat.cantidad_productos = (
        SELECT COUNT(*)
        FROM productos p
        WHERE p.id_categoria = cat.id_categoria
    );
    COMMIT;
END$$
DELIMITER ;

GRANT SELECT ON ecommerce_db.reporte_ventas_semanales TO Analista_Datos;
GRANT SELECT ON ecommerce_db.resumen_ventas_diarias TO Analista_Datos;
GRANT SELECT ON ecommerce_db.ranking_productos TO Analista_Datos;
GRANT SELECT ON ecommerce_db.kpis_mensuales TO Analista_Datos;
GRANT SELECT ON ecommerce_db.reporte_proveedores_mensual TO Analista_Datos;
GRANT SELECT ON ecommerce_db.lista_reabastecimiento TO Analista_Datos;
GRANT SELECT ON ecommerce_db.mv_ventas_categoria_mensual TO Analista_Datos;
GRANT SELECT ON ecommerce_db.mv_resumen_clientes TO Analista_Datos;
