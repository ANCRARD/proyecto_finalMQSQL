SET NAMES utf8mb4;
USE ecommerce_db;

DROP PROCEDURE IF EXISTS sp_instalar_validate_password;
DELIMITER $$
CREATE PROCEDURE sp_instalar_validate_password()
BEGIN
    IF (SELECT COUNT(*) FROM mysql.component WHERE component_urn = 'file://component_validate_password') = 0 THEN
        INSTALL COMPONENT 'file://component_validate_password';
    END IF;
END$$
DELIMITER ;
CALL sp_instalar_validate_password();
DROP PROCEDURE IF EXISTS sp_instalar_validate_password;

SET PERSIST validate_password.policy = 'MEDIUM';
SET PERSIST validate_password.length = 10;
SET PERSIST validate_password.mixed_case_count = 1;
SET PERSIST validate_password.number_count = 1;
SET PERSIST validate_password.special_char_count = 1;
SET PERSIST validate_password.check_user_name = ON;
SET PERSIST default_password_lifetime = 90;
SET PERSIST password_history = 5;
SET PERSIST log_error_verbosity = 3;

DROP ROLE IF EXISTS Administrador_Sistema, Gerente_Marketing, Analista_Datos, Empleado_Inventario, Atencion_Cliente, Auditor_Financiero, Visitante;
CREATE ROLE Administrador_Sistema, Gerente_Marketing, Analista_Datos, Empleado_Inventario, Atencion_Cliente, Auditor_Financiero, Visitante;

GRANT ALL PRIVILEGES ON ecommerce_db.* TO Administrador_Sistema WITH GRANT OPTION;

GRANT SELECT ON ecommerce_db.ventas TO Gerente_Marketing;
GRANT SELECT ON ecommerce_db.detalle_venta TO Gerente_Marketing;
GRANT SELECT (id_cliente, nombre, apellido, email, telefono, fecha_nacimiento, direccion_envio, ciudad, departamento, id_referido_por, total_gastado, fecha_ultimo_pedido, nivel_lealtad, fecha_registro, activo, eliminado_en) ON ecommerce_db.clientes TO Gerente_Marketing;

GRANT SELECT ON ecommerce_db.categorias TO Analista_Datos;
GRANT SELECT ON ecommerce_db.proveedores TO Analista_Datos;
GRANT SELECT ON ecommerce_db.sucursales TO Analista_Datos;
GRANT SELECT ON ecommerce_db.productos TO Analista_Datos;
GRANT SELECT (id_cliente, nombre, apellido, email, telefono, fecha_nacimiento, direccion_envio, ciudad, departamento, id_referido_por, total_gastado, fecha_ultimo_pedido, nivel_lealtad, fecha_registro, activo, eliminado_en) ON ecommerce_db.clientes TO Analista_Datos;
GRANT SELECT ON ecommerce_db.ventas TO Analista_Datos;
GRANT SELECT ON ecommerce_db.detalle_venta TO Analista_Datos;
GRANT SELECT ON ecommerce_db.carritos TO Analista_Datos;
GRANT SELECT ON ecommerce_db.carrito_detalle TO Analista_Datos;
GRANT SELECT ON ecommerce_db.promociones TO Analista_Datos;
GRANT SELECT ON ecommerce_db.visitas_producto TO Analista_Datos;
GRANT SELECT ON ecommerce_db.resenas_producto TO Analista_Datos;
GRANT SELECT ON ecommerce_db.creditos_cliente TO Analista_Datos;
GRANT SELECT ON ecommerce_db.ajustes_stock TO Analista_Datos;
GRANT SELECT ON ecommerce_db.notificaciones TO Analista_Datos;

GRANT SELECT ON ecommerce_db.productos TO Empleado_Inventario;
GRANT SELECT ON ecommerce_db.categorias TO Empleado_Inventario;
GRANT SELECT ON ecommerce_db.proveedores TO Empleado_Inventario;
GRANT UPDATE (stock, ubicacion, precio) ON ecommerce_db.productos TO Empleado_Inventario;

GRANT SELECT ON ecommerce_db.productos TO Atencion_Cliente;

GRANT SELECT ON ecommerce_db.ventas TO Auditor_Financiero;
GRANT SELECT ON ecommerce_db.detalle_venta TO Auditor_Financiero;
GRANT SELECT ON ecommerce_db.productos TO Auditor_Financiero;

GRANT SELECT ON ecommerce_db.productos TO Visitante;

DROP USER IF EXISTS 'marketing_user'@'%', 'inventory_user'@'%', 'support_user'@'%', 'analyst_user'@'%';

CREATE USER IF NOT EXISTS 'admin_user'@'%' IDENTIFIED BY 'Adm1n#Ecommerce26';
ALTER USER 'admin_user'@'%'
    PASSWORD EXPIRE INTERVAL 180 DAY
    PASSWORD HISTORY 5
    FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;
CREATE USER 'marketing_user'@'%' IDENTIFIED BY 'Mkt#Ventas2026'
    PASSWORD EXPIRE INTERVAL 90 DAY
    PASSWORD HISTORY 5
    FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 2;
CREATE USER 'inventory_user'@'%' IDENTIFIED BY 'Inv#Bodega2026'
    PASSWORD EXPIRE INTERVAL 90 DAY
    PASSWORD HISTORY 5
    FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 2;
CREATE USER 'support_user'@'%' IDENTIFIED BY 'Sop#Clientes2026'
    PASSWORD EXPIRE INTERVAL 90 DAY
    PASSWORD HISTORY 5
    FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 2;
CREATE USER 'analyst_user'@'%' IDENTIFIED BY 'Ana#Datos2026x'
    PASSWORD EXPIRE INTERVAL 90 DAY
    PASSWORD HISTORY 5
    FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 2;

GRANT ALL PRIVILEGES ON *.* TO 'admin_user'@'%' WITH GRANT OPTION;
GRANT Administrador_Sistema TO 'admin_user'@'%' WITH ADMIN OPTION;
GRANT Gerente_Marketing TO 'marketing_user'@'%';
GRANT Empleado_Inventario TO 'inventory_user'@'%';
GRANT Atencion_Cliente TO 'support_user'@'%';
GRANT Analista_Datos TO 'analyst_user'@'%';

SET DEFAULT ROLE ALL TO 'admin_user'@'%', 'marketing_user'@'%', 'inventory_user'@'%', 'support_user'@'%', 'analyst_user'@'%';

ALTER USER 'analyst_user'@'%' WITH MAX_QUERIES_PER_HOUR 500 MAX_CONNECTIONS_PER_HOUR 60;

CREATE OR REPLACE
    DEFINER = 'admin_user'@'%'
    SQL SECURITY DEFINER
VIEW v_info_clientes_basica AS
SELECT c.id_cliente,
       c.nombre,
       c.apellido,
       c.email,
       CONCAT(REPEAT('*', GREATEST(CHAR_LENGTH(c.telefono) - 3, 0)), RIGHT(c.telefono, 3)) AS telefono,
       c.ciudad,
       c.departamento,
       c.nivel_lealtad,
       c.fecha_registro,
       c.fecha_ultimo_pedido,
       c.activo
FROM clientes c
WHERE c.eliminado_en IS NULL;

CREATE OR REPLACE
    DEFINER = 'admin_user'@'%'
    SQL SECURITY DEFINER
VIEW v_ventas_sucursal AS
SELECT v.id_venta,
       v.id_cliente,
       v.id_sucursal,
       s.nombre AS sucursal,
       v.fecha_venta,
       v.estado,
       v.total,
       v.metodo_pago,
       v.fecha_pago
FROM ventas v
JOIN sucursales s ON s.id_sucursal = v.id_sucursal
JOIN usuarios_sucursal us ON us.id_sucursal = v.id_sucursal
WHERE us.usuario_mysql = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE
    DEFINER = 'admin_user'@'%'
    SQL SECURITY DEFINER
VIEW v_intentos_login_fallidos AS
SELECT el.LOGGED AS fecha,
       el.ERROR_CODE AS codigo,
       el.DATA AS detalle
FROM performance_schema.error_log el
WHERE el.DATA LIKE 'Access denied for user%';

CREATE OR REPLACE
    DEFINER = 'admin_user'@'%'
    SQL SECURITY DEFINER
VIEW v_errores_autenticacion_host AS
SELECT hc.IP AS ip,
       hc.HOST AS host,
       hc.COUNT_AUTHENTICATION_ERRORS AS errores_autenticacion,
       hc.COUNT_HANDSHAKE_ERRORS AS errores_handshake,
       hc.FIRST_ERROR_SEEN AS primer_error,
       hc.LAST_ERROR_SEEN AS ultimo_error
FROM performance_schema.host_cache hc
WHERE hc.COUNT_AUTHENTICATION_ERRORS > 0
   OR hc.COUNT_HANDSHAKE_ERRORS > 0;

GRANT SELECT ON ecommerce_db.v_info_clientes_basica TO Atencion_Cliente;
GRANT SELECT ON ecommerce_db.v_ventas_sucursal TO Atencion_Cliente;
GRANT SELECT ON ecommerce_db.v_ventas_sucursal TO Empleado_Inventario;
GRANT SELECT ON ecommerce_db.v_intentos_login_fallidos TO Auditor_Financiero;
GRANT SELECT ON ecommerce_db.v_errores_autenticacion_host TO Auditor_Financiero;

REVOKE UPDATE (precio) ON ecommerce_db.productos FROM Empleado_Inventario;

SHOW GRANTS FOR Analista_Datos;
SHOW GRANTS FOR Empleado_Inventario;
SHOW GRANTS FOR 'analyst_user'@'%' USING Analista_Datos;

DROP USER IF EXISTS 'root'@'%';
