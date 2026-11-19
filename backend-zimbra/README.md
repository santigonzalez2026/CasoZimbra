# Back-end Transaccional Zimbra y LoopFuse OneView (Sesiones 2 y 3)

Proyecto del **Back-end en Java 17 con Spring Boot 3.4.3** conectado a **MySQL (`zimbra_transaccional`)**, desarrollado para la **Sesión 2 (Base de datos y transacciones)** y la **Sesión 3 (Automatización y lógica avanzada)** del curso *Sistemas Transaccionales de Bases de Datos* (UNIMINUTO).

## 1. Requisitos previos
1. Ejecutar en MySQL 8.0+ o MariaDB el script consolidado `../Script_SQL_Completo_Sesion_2_y_3_Zimbra.sql` (o en orden `../Sesion_2_Zimbra_BD_y_Transacciones.sql` y `../Sesion_3_Zimbra_Triggers_Procedimientos_y_Funciones.sql`).
2. Verificar usuario y contraseña de MySQL en `src/main/resources/application.properties` (`root` / `12345`).
3. Ejecutar `ejecutar_backend.bat` o `mvn spring-boot:run`.
4. Abrir el prototipo del Front-end en el navegador en **`http://localhost:8080/`** (o abrir `../frontend-zimbra/index.html`).
5. Repositorio GitHub del proyecto: `https://github.com/santigonzalez2026/CasoZimbra.git`.

## 2. Endpoints REST de la Sesión 2 (Conexión y Transacciones ACID)

| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/health` | Verifica la conexión activa con MySQL y retorna el conteo de las 13 tablas. |
| `GET` | `/api/vendedores` | Lista los 30 asesores comerciales de Zimbra. |
| `GET` | `/api/productos` | Consulta el catálogo de ediciones y licencias de ZCS. |
| `GET` | `/api/campanas` | Lista las campañas de marketing de LoopFuse OneView. |
| `GET` | `/api/prospectos` | Lista los prospectos con su asesor, campaña y puntaje de interés. |
| `POST` | `/api/prospectos` | **Transacción ACID:** Registra prospecto, asignación de asesor y alerta inicial. |
| `GET` | `/api/propuestas` | Lista las propuestas comerciales registradas. |
| `POST` | `/api/propuestas` | **Transacción ACID con `SAVEPOINT`:** Crea propuesta con líneas base y opcionales. |
| `GET` | `/api/ventas` | Consulta las ventas registradas y facturadas. |
| `POST` | `/api/ventas/cerrar` | **Transacción ACID + Trigger:** Cierra venta, acepta propuesta y convierte prospecto. |
| `GET` | `/api/alertas` | Lista las alertas automáticas generadas para los asesores comerciales. |
| `GET` | `/api/bitacora-errores` | Consulta la tabla `bitacora_errores_transaccion`. |

## 3. Endpoints REST de la Sesión 3 (Triggers, Procedimientos Almacenados y Funciones UDF)

| Método | Endpoint | Objeto SQL invocado | Descripción |
|---|---|---|---|
| `GET` | `/api/reportes/mensual?anio=2026&mes=10` | `CALL sp_reporte_mensual_ventas(?, ?)` | Genera el reporte mensual de ventas por vendedor, producto y campaña (RF-15, RF-28). |
| `GET` | `/api/reportes/desempeno-asesores` | `CALL sp_reporte_desempeno_asesores()` + `fn_tasa_conversion_vendedor` | Calcula los indicadores de desempeño comercial de los 30 asesores (Tabla 20, RF-26). |
| `GET` | `/api/reportes/rendimiento-campanas` | `CALL sp_reporte_rendimiento_campanas()` | Calcula el ROI, conversión y costo por venta de cada campaña LoopFuse (RF-16, RF-31). |
| `POST` | `/api/automatizacion/verificar-vencimientos` | `CALL sp_actualizar_propuestas_vencidas_y_alertas(OUT, OUT)` | Marca propuestas expiradas como `'Vencida'` y genera alertas preventivas (RF-11, RF-24). |
| `POST` | `/api/propuestas/procedimiento` | `CALL sp_registrar_propuesta_completa(...)` + Trigger + UDF | Crea propuesta y detalle invocando procedimiento almacenado, trigger y UDF (RF-09, RF-10). |
| `GET` | `/api/funciones/prospecto/{id}/indicadores` | `fn_calcular_puntaje_compromiso_prospecto` + `fn_clasificar_habito_cliente` | Evalúa el puntaje de compromiso y clasifica el hábito de compra del cliente (RF-05, RF-27). |
| `GET` | `/api/funciones/propuesta/{id}/indicadores` | `fn_calcular_subtotal_propuesta` + `fn_dias_restantes_vigencia_propuesta` | Calcula el subtotal acumulado y los días restantes de vigencia de una propuesta. |
| `GET` | `/api/funciones/vendedor/{id}/conversion` | `fn_tasa_conversion_vendedor` | Retorna el porcentaje de conversión comercial de un vendedor. |
| `POST` | `/api/visitas-web` | `trg_visita_web_after_insert_scoring_y_alerta` | Registra una actividad web y dispara el trigger de Lead Scoring y alertas automáticas. |
