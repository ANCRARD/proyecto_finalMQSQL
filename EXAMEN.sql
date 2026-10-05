USE ecommerce_db;

WITH rfm_base AS (
    SELECT c.id_cliente,
           CONCAT(c.nombre, ' ', c.apellido) AS cliente,
           DATEDIFF(CURDATE(), MAX(v.fecha_venta)) AS recencia,
           COUNT(v.id_venta) AS frecuencia,
           SUM(v.total) AS monetario
    FROM clientes c
    JOIN ventas v ON v.id_cliente = c.id_cliente
    WHERE v.estado IN ('Pagado', 'Procesando', 'Enviado', 'Entregado')
    GROUP BY c.id_cliente, c.nombre, c.apellido
),
rfm_scores AS (
    SELECT id_cliente,
           cliente,
           recencia,
           frecuencia,
           monetario,
           NTILE(4) OVER (ORDER BY recencia DESC, monetario ASC) AS r_score,
           NTILE(4) OVER (ORDER BY frecuencia ASC, monetario ASC) AS f_score,
           NTILE(4) OVER (ORDER BY monetario ASC) AS m_score
    FROM rfm_base
)
SELECT id_cliente,
       cliente,
       recencia,
       frecuencia,
       monetario,
       r_score,
       f_score,
       m_score,
       CONCAT(r_score, f_score, m_score) AS puntuacion_rfm,
       CASE
           WHEN r_score = 4 AND f_score >= 3 AND m_score >= 3 THEN 'Campeones'
           WHEN r_score >= 3 AND f_score >= 3 THEN 'Leales'
           WHEN r_score <= 2 AND (f_score >= 3 OR m_score >= 3) THEN 'En Riesgo'
           WHEN r_score >= 3 AND f_score <= 2 THEN 'Prometedores'
           ELSE 'Otros'
       END AS segmento
FROM rfm_scores
ORDER BY r_score DESC, f_score DESC, m_score DESC, monetario DESC;

-- Segmentación de clientes RFM
--
-- Primero se calcula, para cada cliente:
--   Recencia   = hace cuántos días fue su última compra
--   Frecuencia = cuántas compras ha hecho
--   Monetario  = cuánto ha gastado en total
-- Solo se cuentan las compras que sí se pagaron (no las canceladas ni las devueltas).
--
-- Después se le pone a cada cliente una nota de 1 a 4 en cada dato.
-- El 4 es la mejor nota: compró hace poco, compra seguido o gasta mucho.
--
-- Por último, con esas tres notas se ubica a cada cliente en un grupo:
--   Campeones    = compraron hace poco, compran seguido y gastan mucho
--   Leales       = siguen comprando con frecuencia
--   En Riesgo    = eran buenos clientes, pero llevan tiempo sin comprar
--   Prometedores = compraron hace poco, pero todavía compran poco
--   Otros        = el resto de clientes