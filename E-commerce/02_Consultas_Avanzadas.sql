SET NAMES utf8mb4;
USE ecommerce_db;

-- 1. Top 10 productos más vendidos por ingresos
SELECT RANK() OVER (ORDER BY SUM(dv.subtotal) DESC) AS posicion,
       p.id_producto,
       p.nombre,
       cat.nombre AS categoria,
       SUM(dv.cantidad) AS unidades_vendidas,
       SUM(dv.subtotal) AS ingresos
FROM detalle_venta dv
JOIN ventas v ON v.id_venta = dv.id_venta
JOIN productos p ON p.id_producto = dv.id_producto
JOIN categorias cat ON cat.id_categoria = p.id_categoria
WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
GROUP BY p.id_producto, p.nombre, cat.nombre
ORDER BY ingresos DESC
LIMIT 10;

-- 2. Productos con bajas ventas (10 % inferior)
WITH ventas_producto AS (
    SELECT p.id_producto,
           p.nombre,
           p.stock,
           p.fecha_creacion,
           COALESCE(s.unidades, 0) AS unidades,
           COALESCE(s.ingresos, 0) AS ingresos
    FROM productos p
    LEFT JOIN (
        SELECT dv.id_producto,
               SUM(dv.cantidad) AS unidades,
               SUM(dv.subtotal) AS ingresos
        FROM detalle_venta dv
        JOIN ventas v ON v.id_venta = dv.id_venta
        WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
        GROUP BY dv.id_producto
    ) s ON s.id_producto = p.id_producto
    WHERE p.activo = TRUE
      AND p.eliminado_en IS NULL
),
clasificados AS (
    SELECT vp.*,
           NTILE(10) OVER (ORDER BY vp.ingresos, vp.unidades) AS decil,
           ROUND(PERCENT_RANK() OVER (ORDER BY vp.ingresos) * 100, 1) AS percentil
    FROM ventas_producto vp
)
SELECT id_producto,
       nombre,
       unidades,
       ingresos,
       stock,
       percentil,
       DATEDIFF(CURDATE(), fecha_creacion) AS dias_en_catalogo
FROM clasificados
WHERE decil = 1
ORDER BY ingresos, unidades;

-- 3. Clientes VIP: top 5 por valor de vida (LTV)
SELECT c.id_cliente,
       CONCAT(c.nombre, ' ', c.apellido) AS cliente,
       c.ciudad,
       COUNT(v.id_venta) AS compras,
       SUM(v.total) AS valor_de_vida,
       ROUND(AVG(v.total), 2) AS ticket_promedio,
       MIN(v.fecha_venta) AS primera_compra,
       MAX(v.fecha_venta) AS ultima_compra
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
GROUP BY c.id_cliente, c.nombre, c.apellido, c.ciudad
ORDER BY valor_de_vida DESC
LIMIT 5;

-- 4. Análisis de ventas mensuales
WITH mensual AS (
    SELECT YEAR(v.fecha_venta) AS anio,
           MONTH(v.fecha_venta) AS mes,
           COUNT(*) AS pedidos,
           SUM(v.total) AS ventas
    FROM ventas v
    WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    GROUP BY YEAR(v.fecha_venta), MONTH(v.fecha_venta)
)
SELECT anio,
       mes,
       pedidos,
       ventas,
       ROUND(ventas / pedidos, 2) AS ticket_promedio,
       ROUND(100 * (ventas - LAG(ventas) OVER (ORDER BY anio, mes)) / LAG(ventas) OVER (ORDER BY anio, mes), 1) AS variacion_mensual_pct
FROM mensual
ORDER BY anio, mes;

-- 5. Crecimiento de clientes por trimestre
SELECT YEAR(c.fecha_registro) AS anio,
       QUARTER(c.fecha_registro) AS trimestre,
       COUNT(*) AS clientes_nuevos,
       SUM(COUNT(*)) OVER (ORDER BY YEAR(c.fecha_registro), QUARTER(c.fecha_registro)) AS clientes_acumulados,
       COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY YEAR(c.fecha_registro), QUARTER(c.fecha_registro)) AS diferencia_vs_trimestre_anterior
FROM clientes c
GROUP BY YEAR(c.fecha_registro), QUARTER(c.fecha_registro)
ORDER BY anio, trimestre;

-- 6. Tasa de compra repetida
WITH compras AS (
    SELECT c.id_cliente,
           COUNT(v.id_venta) AS cantidad
    FROM clientes c
    LEFT JOIN ventas v ON v.id_cliente = c.id_cliente
                      AND v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    GROUP BY c.id_cliente
)
SELECT COUNT(*) AS clientes_registrados,
       SUM(cantidad >= 1) AS clientes_con_compra,
       SUM(cantidad > 1) AS clientes_recurrentes,
       ROUND(100 * SUM(cantidad > 1) / NULLIF(SUM(cantidad >= 1), 0), 2) AS tasa_compra_repetida_pct,
       ROUND(100 * SUM(cantidad > 1) / COUNT(*), 2) AS recurrentes_sobre_registrados_pct
FROM compras;

-- 7. Productos comprados juntos frecuentemente
SELECT a.id_producto AS id_producto_a,
       pa.nombre AS producto_a,
       b.id_producto AS id_producto_b,
       pb.nombre AS producto_b,
       COUNT(DISTINCT a.id_venta) AS veces_juntos
FROM detalle_venta a
JOIN detalle_venta b ON b.id_venta = a.id_venta
                    AND a.id_producto < b.id_producto
JOIN ventas v ON v.id_venta = a.id_venta
JOIN productos pa ON pa.id_producto = a.id_producto
JOIN productos pb ON pb.id_producto = b.id_producto
WHERE v.estado <> 'Cancelado'
GROUP BY a.id_producto, pa.nombre, b.id_producto, pb.nombre
HAVING COUNT(DISTINCT a.id_venta) >= 2
ORDER BY veces_juntos DESC, producto_a
LIMIT 15;

-- 8. Rotación de inventario por categoría (últimos 12 meses)
WITH costo_vendido AS (
    SELECT p.id_categoria,
           SUM((dv.cantidad - dv.cantidad_devuelta) * p.costo) AS costo_ventas,
           SUM(dv.cantidad - dv.cantidad_devuelta) AS unidades
    FROM detalle_venta dv
    JOIN ventas v ON v.id_venta = dv.id_venta
    JOIN productos p ON p.id_producto = dv.id_producto
    WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado', 'Devuelto')
      AND v.fecha_venta >= CURDATE() - INTERVAL 12 MONTH
    GROUP BY p.id_categoria
),
inventario AS (
    SELECT p.id_categoria,
           SUM(p.stock) AS unidades_en_stock,
           SUM(p.stock * p.costo) AS valor_inventario
    FROM productos p
    WHERE p.eliminado_en IS NULL
    GROUP BY p.id_categoria
)
SELECT cat.nombre AS categoria,
       COALESCE(cv.unidades, 0) AS unidades_vendidas_12m,
       i.unidades_en_stock,
       COALESCE(cv.costo_ventas, 0) AS costo_de_ventas,
       i.valor_inventario,
       ROUND(COALESCE(cv.costo_ventas, 0) / NULLIF(i.valor_inventario, 0), 2) AS rotacion,
       ROUND(365 / NULLIF(COALESCE(cv.costo_ventas, 0) / NULLIF(i.valor_inventario, 0), 0), 0) AS dias_de_inventario
FROM categorias cat
JOIN inventario i ON i.id_categoria = cat.id_categoria
LEFT JOIN costo_vendido cv ON cv.id_categoria = cat.id_categoria
ORDER BY rotacion DESC;

-- 9. Productos que necesitan reabastecimiento
SELECT p.id_producto,
       p.sku,
       p.nombre,
       p.stock,
       p.stock_minimo,
       p.stock_minimo - p.stock AS faltante,
       p.stock_minimo * 2 - p.stock AS pedido_sugerido,
       pr.nombre AS proveedor,
       pr.telefono_contacto,
       p.ubicacion
FROM productos p
JOIN proveedores pr ON pr.id_proveedor = p.id_proveedor
WHERE p.stock < p.stock_minimo
  AND p.activo = TRUE
  AND p.eliminado_en IS NULL
ORDER BY p.stock / NULLIF(p.stock_minimo, 0), faltante DESC;

-- 10. Análisis de carrito abandonado (últimos 180 días)
WITH parametros AS (
    SELECT CURDATE() - INTERVAL 180 DAY AS desde,
           7 AS dias_para_comprar
),
carritos_periodo AS (
    SELECT ca.id_carrito,
           ca.id_cliente,
           ca.estado,
           ca.fecha_creacion,
           ca.fecha_actualizacion
    FROM carritos ca
    CROSS JOIN parametros pa
    WHERE ca.estado IN ('Activo', 'Abandonado')
      AND ca.fecha_creacion >= pa.desde
)
SELECT c.id_cliente,
       CONCAT(c.nombre, ' ', c.apellido) AS cliente,
       c.email,
       cp.id_carrito,
       cp.estado,
       cp.fecha_actualizacion AS ultima_actividad,
       COUNT(cd.id_carrito_detalle) AS productos_en_carrito,
       COALESCE(SUM(cd.cantidad * p.precio), 0) AS valor_estimado
FROM carritos_periodo cp
CROSS JOIN parametros pa
JOIN clientes c ON c.id_cliente = cp.id_cliente
LEFT JOIN carrito_detalle cd ON cd.id_carrito = cp.id_carrito
LEFT JOIN productos p ON p.id_producto = cd.id_producto
WHERE NOT EXISTS (
    SELECT 1
    FROM ventas v
    WHERE v.id_cliente = cp.id_cliente
      AND v.fecha_venta BETWEEN cp.fecha_creacion AND cp.fecha_actualizacion + INTERVAL pa.dias_para_comprar DAY
      AND v.estado <> 'Cancelado'
)
GROUP BY c.id_cliente, c.nombre, c.apellido, c.email, cp.id_carrito, cp.estado, cp.fecha_actualizacion
ORDER BY valor_estimado DESC;

-- 11. Rendimiento de proveedores
SELECT RANK() OVER (ORDER BY COALESCE(SUM(dv.subtotal), 0) DESC) AS posicion,
       pr.id_proveedor,
       pr.nombre AS proveedor,
       pr.ciudad,
       COUNT(DISTINCT p.id_producto) AS productos_en_catalogo,
       COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas,
       COALESCE(SUM(dv.subtotal), 0) AS ingresos,
       COALESCE(SUM(dv.cantidad * (dv.precio_unitario_congelado - p.costo)), 0) AS margen_bruto,
       ROUND(100 * COALESCE(SUM(dv.subtotal), 0) / SUM(SUM(dv.subtotal)) OVER (), 2) AS participacion_pct
FROM proveedores pr
LEFT JOIN productos p ON p.id_proveedor = pr.id_proveedor
LEFT JOIN (
    SELECT dv2.*
    FROM detalle_venta dv2
    JOIN ventas v ON v.id_venta = dv2.id_venta
    WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
) dv ON dv.id_producto = p.id_producto
GROUP BY pr.id_proveedor, pr.nombre, pr.ciudad
ORDER BY posicion;

-- 12. Análisis geográfico de ventas
SELECT CASE WHEN GROUPING(c.departamento) = 1 THEN 'TOTAL GENERAL' ELSE c.departamento END AS departamento,
       CASE WHEN GROUPING(c.ciudad) = 1 AND GROUPING(c.departamento) = 0 THEN 'Subtotal departamento' ELSE c.ciudad END AS ciudad,
       COUNT(DISTINCT v.id_cliente) AS clientes,
       COUNT(v.id_venta) AS pedidos,
       SUM(v.total) AS ventas,
       ROUND(AVG(v.total), 2) AS ticket_promedio
FROM ventas v
JOIN clientes c ON c.id_cliente = v.id_cliente
WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
GROUP BY c.departamento, c.ciudad WITH ROLLUP
ORDER BY GROUPING(c.departamento), c.departamento, GROUPING(c.ciudad), ventas DESC;

-- 13. Ventas por hora del día
SELECT HOUR(v.fecha_venta) AS hora,
       COUNT(*) AS pedidos,
       SUM(v.total) AS ventas,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS porcentaje_pedidos,
       DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS ranking,
       CASE
           WHEN DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) <= 3 THEN 'Hora pico'
           WHEN COUNT(*) < AVG(COUNT(*)) OVER () / 2 THEN 'Hora valle'
           ELSE 'Normal'
       END AS clasificacion
FROM ventas v
WHERE v.estado <> 'Cancelado'
GROUP BY HOUR(v.fecha_venta)
ORDER BY hora;

-- 14. Impacto de promociones: antes, durante y después
WITH promos AS (
    SELECT pm.id_promocion,
           pm.codigo,
           pm.id_producto,
           pm.porcentaje_descuento,
           pm.fecha_inicio,
           pm.fecha_fin,
           GREATEST(DATEDIFF(pm.fecha_fin, pm.fecha_inicio) + 1, 1) AS dias
    FROM promociones pm
    WHERE pm.id_producto IS NOT NULL
      AND pm.fecha_fin < NOW()
),
ventanas AS (
    SELECT id_promocion, codigo, id_producto, porcentaje_descuento, dias, 1 AS orden, 'Antes' AS periodo,
           fecha_inicio - INTERVAL dias DAY AS desde, fecha_inicio AS hasta
    FROM promos
    UNION ALL
    SELECT id_promocion, codigo, id_producto, porcentaje_descuento, dias, 2, 'Durante',
           fecha_inicio, fecha_fin
    FROM promos
    UNION ALL
    SELECT id_promocion, codigo, id_producto, porcentaje_descuento, dias, 3, 'Después',
           fecha_fin, fecha_fin + INTERVAL dias DAY
    FROM promos
)
SELECT w.codigo,
       p.nombre AS producto,
       w.porcentaje_descuento,
       w.periodo,
       DATE(w.desde) AS desde,
       DATE(w.hasta) AS hasta,
       COALESCE(SUM(dv.cantidad), 0) AS unidades,
       COALESCE(SUM(dv.subtotal), 0) AS ingresos,
       ROUND(COALESCE(SUM(dv.cantidad), 0) / w.dias, 2) AS unidades_por_dia
FROM ventanas w
JOIN productos p ON p.id_producto = w.id_producto
LEFT JOIN ventas v ON v.fecha_venta >= w.desde
                  AND v.fecha_venta < w.hasta
                  AND v.estado <> 'Cancelado'
LEFT JOIN detalle_venta dv ON dv.id_venta = v.id_venta
                          AND dv.id_producto = w.id_producto
GROUP BY w.id_promocion, w.codigo, p.nombre, w.porcentaje_descuento, w.orden, w.periodo, w.desde, w.hasta, w.dias
ORDER BY w.id_promocion, w.orden;

-- 15. Análisis de cohortes: retención mes a mes desde la primera compra
WITH compras AS (
    SELECT v.id_cliente,
           DATE_FORMAT(v.fecha_venta, '%Y-%m-01') AS mes_compra
    FROM ventas v
    WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    GROUP BY v.id_cliente, DATE_FORMAT(v.fecha_venta, '%Y-%m-01')
),
cohortes AS (
    SELECT id_cliente,
           MIN(mes_compra) AS mes_cohorte
    FROM compras
    GROUP BY id_cliente
),
actividad AS (
    SELECT co.mes_cohorte,
           TIMESTAMPDIFF(MONTH, co.mes_cohorte, cp.mes_compra) AS meses_transcurridos,
           COUNT(DISTINCT cp.id_cliente) AS clientes_activos
    FROM cohortes co
    JOIN compras cp ON cp.id_cliente = co.id_cliente
    GROUP BY co.mes_cohorte, TIMESTAMPDIFF(MONTH, co.mes_cohorte, cp.mes_compra)
)
SELECT DATE_FORMAT(a.mes_cohorte, '%Y-%m') AS cohorte,
       MAX(CASE WHEN a.meses_transcurridos = 0 THEN a.clientes_activos END) AS clientes_mes_0,
       ROUND(100 * MAX(CASE WHEN a.meses_transcurridos = 1 THEN a.clientes_activos END) / MAX(CASE WHEN a.meses_transcurridos = 0 THEN a.clientes_activos END), 1) AS mes_1_pct,
       ROUND(100 * MAX(CASE WHEN a.meses_transcurridos = 2 THEN a.clientes_activos END) / MAX(CASE WHEN a.meses_transcurridos = 0 THEN a.clientes_activos END), 1) AS mes_2_pct,
       ROUND(100 * MAX(CASE WHEN a.meses_transcurridos = 3 THEN a.clientes_activos END) / MAX(CASE WHEN a.meses_transcurridos = 0 THEN a.clientes_activos END), 1) AS mes_3_pct,
       ROUND(100 * MAX(CASE WHEN a.meses_transcurridos = 6 THEN a.clientes_activos END) / MAX(CASE WHEN a.meses_transcurridos = 0 THEN a.clientes_activos END), 1) AS mes_6_pct,
       ROUND(100 * MAX(CASE WHEN a.meses_transcurridos = 12 THEN a.clientes_activos END) / MAX(CASE WHEN a.meses_transcurridos = 0 THEN a.clientes_activos END), 1) AS mes_12_pct,
       SUM(CASE WHEN a.meses_transcurridos > 0 THEN a.clientes_activos ELSE 0 END) AS recompras_posteriores
FROM actividad a
GROUP BY a.mes_cohorte
ORDER BY a.mes_cohorte;

-- 16. Margen de beneficio por producto
SELECT p.id_producto,
       p.nombre,
       p.precio,
       p.costo,
       p.precio - p.costo AS margen_unitario,
       ROUND(100 * (p.precio - p.costo) / p.precio, 2) AS margen_pct,
       COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas,
       COALESCE(SUM(dv.cantidad * (dv.precio_unitario_congelado - p.costo)), 0) AS margen_realizado,
       RANK() OVER (ORDER BY (p.precio - p.costo) / p.precio DESC) AS ranking_margen
FROM productos p
LEFT JOIN (
    SELECT dv2.id_producto, dv2.cantidad, dv2.precio_unitario_congelado
    FROM detalle_venta dv2
    JOIN ventas v ON v.id_venta = dv2.id_venta
    WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
) dv ON dv.id_producto = p.id_producto
WHERE p.eliminado_en IS NULL
GROUP BY p.id_producto, p.nombre, p.precio, p.costo
ORDER BY margen_pct DESC;

-- 17. Tiempo promedio entre compras
WITH compras AS (
    SELECT v.id_cliente,
           v.fecha_venta,
           DATEDIFF(v.fecha_venta, LAG(v.fecha_venta) OVER (PARTITION BY v.id_cliente ORDER BY v.fecha_venta)) AS dias_desde_anterior
    FROM ventas v
    WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
),
por_cliente AS (
    SELECT c.id_cliente,
           CONCAT(c.nombre, ' ', c.apellido) AS cliente,
           COUNT(*) AS compras,
           ROUND(AVG(co.dias_desde_anterior), 1) AS promedio_dias
    FROM compras co
    JOIN clientes c ON c.id_cliente = co.id_cliente
    GROUP BY c.id_cliente, c.nombre, c.apellido
    HAVING COUNT(*) > 1
)
SELECT id_cliente,
       cliente,
       compras,
       promedio_dias,
       ROUND(AVG(promedio_dias) OVER (), 1) AS promedio_general_dias
FROM por_cliente
ORDER BY promedio_dias;

-- 18. Productos más vistos vs. más comprados
WITH vistas AS (
    SELECT vp.id_producto,
           COUNT(*) AS visitas,
           COUNT(DISTINCT vp.id_cliente) AS visitantes_identificados
    FROM visitas_producto vp
    GROUP BY vp.id_producto
),
compras AS (
    SELECT dv.id_producto,
           SUM(dv.cantidad) AS unidades,
           COUNT(DISTINCT dv.id_venta) AS pedidos
    FROM detalle_venta dv
    JOIN ventas v ON v.id_venta = dv.id_venta
    WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    GROUP BY dv.id_producto
)
SELECT p.id_producto,
       p.nombre,
       COALESCE(vi.visitas, 0) AS visitas,
       RANK() OVER (ORDER BY COALESCE(vi.visitas, 0) DESC) AS ranking_visitas,
       COALESCE(co.pedidos, 0) AS pedidos,
       COALESCE(co.unidades, 0) AS unidades,
       RANK() OVER (ORDER BY COALESCE(co.pedidos, 0) DESC) AS ranking_compras,
       ROUND(100 * COALESCE(co.pedidos, 0) / NULLIF(vi.visitas, 0), 2) AS tasa_conversion_pct
FROM productos p
LEFT JOIN vistas vi ON vi.id_producto = p.id_producto
LEFT JOIN compras co ON co.id_producto = p.id_producto
WHERE p.eliminado_en IS NULL
ORDER BY ranking_visitas;

-- 19. Segmentación de clientes RFM
WITH base AS (
    SELECT c.id_cliente,
           CONCAT(c.nombre, ' ', c.apellido) AS cliente,
           DATEDIFF(CURDATE(), MAX(v.fecha_venta)) AS recencia_dias,
           COUNT(v.id_venta) AS frecuencia,
           SUM(v.total) AS monetario
    FROM clientes c
    JOIN ventas v ON v.id_cliente = c.id_cliente
    WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    GROUP BY c.id_cliente, c.nombre, c.apellido
),
puntajes AS (
    SELECT b.*,
           NTILE(5) OVER (ORDER BY b.recencia_dias DESC) AS r,
           NTILE(5) OVER (ORDER BY b.frecuencia, b.monetario) AS f,
           NTILE(5) OVER (ORDER BY b.monetario) AS m
    FROM base b
)
SELECT id_cliente,
       cliente,
       recencia_dias,
       frecuencia,
       monetario,
       r,
       f,
       m,
       CONCAT(r, f, m) AS codigo_rfm,
       CASE
           WHEN r >= 4 AND f >= 4 AND m >= 4 THEN 'Campeones'
           WHEN r >= 3 AND f >= 3 THEN 'Leales'
           WHEN r >= 4 AND f <= 2 THEN 'Nuevos prometedores'
           WHEN r <= 2 AND f >= 3 THEN 'En riesgo'
           WHEN r = 3 AND f <= 2 THEN 'Necesitan atención'
           ELSE 'Perdidos'
       END AS segmento
FROM puntajes
ORDER BY r DESC, f DESC, m DESC;

-- 20. Predicción de demanda simple para la categoría Celulares y Accesorios
WITH RECURSIVE meses AS (
    SELECT DATE_FORMAT(CURDATE() - INTERVAL 11 MONTH, '%Y-%m-01') AS mes
    UNION ALL
    SELECT mes + INTERVAL 1 MONTH
    FROM meses
    WHERE mes < DATE_FORMAT(CURDATE(), '%Y-%m-01')
),
ventas_mes AS (
    SELECT DATE_FORMAT(v.fecha_venta, '%Y-%m-01') AS mes,
           SUM(dv.cantidad) AS unidades,
           SUM(dv.subtotal) AS ingresos
    FROM ventas v
    JOIN detalle_venta dv ON dv.id_venta = v.id_venta
    JOIN productos p ON p.id_producto = dv.id_producto
    JOIN categorias cat ON cat.id_categoria = p.id_categoria
    WHERE cat.nombre = 'Celulares y Accesorios'
      AND v.estado <> 'Cancelado'
    GROUP BY DATE_FORMAT(v.fecha_venta, '%Y-%m-01')
),
serie AS (
    SELECT m.mes,
           COALESCE(vm.unidades, 0) AS unidades,
           COALESCE(vm.ingresos, 0) AS ingresos,
           ROUND(AVG(COALESCE(vm.unidades, 0)) OVER (ORDER BY m.mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS promedio_movil_3m,
           ROUND(AVG(COALESCE(vm.ingresos, 0)) OVER (ORDER BY m.mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS ingresos_movil_3m
    FROM meses m
    LEFT JOIN ventas_mes vm ON vm.mes = m.mes
)
SELECT DATE_FORMAT(mes, '%Y-%m') AS mes,
       'Real' AS tipo,
       unidades,
       ingresos,
       promedio_movil_3m
FROM serie
UNION ALL
SELECT DATE_FORMAT(mes + INTERVAL 1 MONTH, '%Y-%m'),
       'Proyección',
       ROUND(promedio_movil_3m),
       ingresos_movil_3m,
       promedio_movil_3m
FROM serie
WHERE mes = (SELECT MAX(mes) FROM serie)
ORDER BY mes;
