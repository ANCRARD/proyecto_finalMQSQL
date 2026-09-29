# Proyecto de Base de Datos para un E-commerce

Este repositorio contiene la base de datos de una tienda en línea construida en MySQL 8. Guardamos el catálogo de productos, las categorías, los proveedores, los clientes, las ventas con su detalle y la información que rodea la compra, como carritos, promociones, visitas, reseñas, devoluciones y sucursales. Además, sobre ese esquema implementamos 20 consultas de análisis, 20 funciones, un esquema de seguridad con roles y usuarios, 20 triggers, 20 eventos programados y 20 procedimientos almacenados. Por otro lado, los datos de ejemplo simulan la operación de la tienda entre enero de 2025 y septiembre de 2026, de modo que todas las consultas devuelven resultados con sentido.

## Integrantes

- Frank David Cuesta Niño
- _________________________
- _________________________
- _________________________

## Requisitos

- MySQL Server 8.0 (lo probamos con 8.0.46). No usamos MariaDB porque la sintaxis de roles, CHECK y funciones de ventana es distinta.
- Docker con un contenedor de la imagen oficial `mysql:8.0` en ejecución.
- DBeaver o la consola `mysql` para ejecutar los scripts.

Si trabajan con la consola dentro del contenedor, conviene forzar el juego de caracteres para que las tildes y la ñ se guarden bien:

```bash
docker exec -i <nombre_contenedor> mysql -uroot -p --default-character-set=utf8mb4 < 01_Esquema_y_Datos.sql
```

Igualmente, todos los scripts empiezan con `SET NAMES utf8mb4;`, así que desde DBeaver no hay que configurar nada adicional.

## Orden de ejecución

En DBeaver cada archivo se abre en un editor SQL y se ejecuta completo con **Ejecutar script (Alt+X)**. Los scripts se deben correr en este orden:

| Paso | Archivo | Usuario de conexión | Qué hace |
|------|---------|---------------------|----------|
| 1 | `01_Esquema_y_Datos.sql` | `root` | Crea `ecommerce_db`, las 17 tablas de negocio y carga los datos de ejemplo |
| 2 | `02_Consultas_Avanzadas.sql` | `root` | Ejecuta las 20 consultas de análisis |
| 3 | `03_Funciones.sql` | `root` | Crea las 20 funciones |
| 4 | `04_Seguridad.sql` | `root` | Crea roles, usuarios, vistas de seguridad y elimina `root@'%'` |
| 5 | `05_Triggers.sql` | `admin_user` | Crea las tablas de auditoría y los 20 triggers |
| 6 | `06_Eventos.sql` | `admin_user` | Activa el programador de eventos, crea las tablas de reportes y los 20 eventos |
| 7 | `07_Procedimientos_Almacenados.sql` | `admin_user` | Crea los 20 procedimientos y da EXECUTE al rol de marketing |

### Advertencia importante sobre `root@'%'`

En la imagen de Docker, la conexión que hace DBeaver desde el equipo anfitrión entra como `root@'%'`. El requisito 16 pide que root no se pueda usar de forma remota, por eso la última línea de `04_Seguridad.sql` es `DROP USER IF EXISTS 'root'@'%';`.

Antes de esa línea el mismo script crea `admin_user` con todos los privilegios y `WITH GRANT OPTION`. Por lo tanto, **después de ejecutar el paso 4 hay que crear una nueva conexión en DBeaver** con estos datos y seguir con los pasos 5, 6 y 7 desde ella:

- Usuario: `admin_user`
- Contraseña: `Adm1n#Ecommerce26`
- Base de datos: `ecommerce_db`

La sesión abierta como root sigue funcionando hasta que se cierre, pero ya no se podrá volver a entrar con ella. Si en algún momento se necesita root, se puede entrar desde dentro del contenedor, porque `root@localhost` sigue existiendo:

```bash
docker exec -it <nombre_contenedor> mysql -uroot -p
```

Desde ahí también se puede desbloquear `admin_user` si se equivocan cinco veces con la contraseña: `ALTER USER 'admin_user'@'%' ACCOUNT UNLOCK;`.

Si quieren reconstruir todo desde cero más adelante, pueden ejecutar los siete scripts en el mismo orden conectados como `admin_user`. En ese caso `04_Seguridad.sql` no borra ni recrea a `admin_user`, solo actualiza su política, para que la sesión que está ejecutando el script no pierda sus permisos.

### Usuarios que crea el script de seguridad

| Usuario | Contraseña | Rol |
|---------|------------|-----|
| `admin_user` | `Adm1n#Ecommerce26` | Administrador_Sistema |
| `marketing_user` | `Mkt#Ventas2026` | Gerente_Marketing |
| `inventory_user` | `Inv#Bodega2026` | Empleado_Inventario |
| `support_user` | `Sop#Clientes2026` | Atencion_Cliente |
| `analyst_user` | `Ana#Datos2026x` | Analista_Datos (máximo 500 consultas por hora) |

## Modelos de la base de datos

En la carpeta `modelos/` están los tres diagramas en formato draw.io:

- `01_Modelo_Conceptual.drawio`: modelo entidad relación en notación Chen, con entidades, atributos, relaciones y cardinalidades. Los atributos derivados aparecen con borde punteado.
- `02_Modelo_Logico.drawio`: modelo relacional en notación pata de gallo, con las relaciones N:M ya resueltas en `detalle_venta` y `carrito_detalle`.
- `03_Modelo_Fisico.drawio`: todas las tablas del sistema con tipos de MySQL, restricciones, índices secundarios y acciones referenciales.

Para abrirlos basta con entrar a [app.diagrams.net](https://app.diagrams.net), elegir **Abrir diagrama existente** y seleccionar el archivo. También se pueden abrir con la aplicación de escritorio de draw.io o con la extensión de draw.io para VS Code.

## Ejemplos de prueba

Registrar una venta nueva. El procedimiento recibe los productos en JSON, valida el stock dentro de una transacción y congela el precio vigente:

```sql
CALL sp_RealizarNuevaVenta(3, 1, '[{"id_producto": 4, "cantidad": 2}, {"id_producto": 16, "cantidad": 1}]', @id_venta);
SELECT @id_venta;
SELECT * FROM detalle_venta WHERE id_venta = @id_venta;
```

Usar funciones sobre la venta recién creada:

```sql
SELECT fn_CalcularTotalVenta(@id_venta) AS total,
       fn_CalcularIVA(@id_venta) AS iva,
       fn_CalcularCostoEnvio(@id_venta) AS envio,
       fn_EstimarFechaEntrega(@id_venta) AS entrega_estimada,
       fn_DeterminarEstadoLealtad(3) AS nivel_cliente;
```

Disparar triggers con un cambio de precio y una baja de stock:

```sql
UPDATE productos SET precio = 239900 WHERE id_producto = 13;
SELECT * FROM log_cambios_precio;

UPDATE productos SET stock = 3 WHERE id_producto = 5;
SELECT * FROM alertas_stock;

UPDATE productos SET stock = -1 WHERE id_producto = 5;
```

La última sentencia debe fallar con el mensaje del trigger que impide el stock negativo.

Verificar que los eventos estén activos:

```sql
SHOW VARIABLES LIKE 'event_scheduler';
SELECT event_name, interval_value, interval_field, starts, status
FROM information_schema.events
WHERE event_schema = 'ecommerce_db';
```

Probar el filtro por sucursal conectándose como `support_user`, que solo ve las ventas de la sede de Cúcuta:

```sql
SELECT id_sucursal, COUNT(*) FROM v_ventas_sucursal GROUP BY id_sucursal;
```
