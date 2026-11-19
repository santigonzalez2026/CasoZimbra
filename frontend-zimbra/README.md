# Prototipo Inicial del Front-end – Caso Zimbra y LoopFuse OneView (Sesión 3)

Interfaz web desarrollada en **HTML5, CSS3 y JavaScript (Fetch API)** para la **Sesión 3 – Automatización y lógica avanzada** del curso *Sistemas Transaccionales de Bases de Datos* (UNIMINUTO).

## Módulos incluidos en el prototipo
1. **Formulario de Registro de Clientes / Prospectos (`POST /api/prospectos`):** Permite registrar nuevos prospectos asociándolos a un asesor comercial, una campaña de LoopFuse OneView y un producto ZCS de interés, visualizando la tabla actualizada en tiempo real.
2. **Formulario de Registro de Propuestas Comerciales (`POST /api/propuestas/procedimiento`):** Invoca el procedimiento almacenado `sp_registrar_propuesta_completa`, activa el trigger `trg_detalle_propuesta_after_insert_recalcular_total` y calcula el subtotal mediante la función UDF `fn_calcular_subtotal_propuesta`. Incluye además el formulario rápido de cierre de venta (`POST /api/ventas/cerrar`).
3. **Panel de Automatización SQL (Triggers, Procedimientos Almacenados y Funciones UDF):** Permite simular actividades en `visita_web` para disparar el trigger de *lead scoring* (`trg_visita_web_after_insert_scoring_y_alerta`), evaluar las 5 funciones UDF en tiempo real y ejecutar los procedimientos almacenados de reportes mensuales (`sp_reporte_mensual_ventas`), desempeño por asesor (`sp_reporte_desempeno_asesores`), rendimiento de campañas (`sp_reporte_rendimiento_campanas`) y verificación de vencimientos (`sp_actualizar_propuestas_vencidas_y_alertas`).

## Formas de ejecución
- **Conectado en vivo al Back-end y MySQL:** Inicie el servidor Spring Boot (`backend-zimbra/ejecutar_backend.bat`) y abra `http://localhost:8080/` en su navegador, o abra directamente `frontend-zimbra/index.html`.
- **Modo vista previa local:** Si abre `frontend-zimbra/index.html` sin haber iniciado el servidor en el puerto 8080, la aplicación activa automáticamente el modo de demostración local con datos simulados del caso Zimbra para probar todos los formularios y reportes.
- **Repositorio GitHub:** `https://github.com/santigonzalez2026/CasoZimbra.git`
