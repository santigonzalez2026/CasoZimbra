-- =====================================================================================
-- CORPORACIÓN UNIVERSITARIA MINUTO DE DIOS - UNIMINUTO
-- Curso: Sistemas Transaccionales de Bases de Datos
-- Caso de Estudio: Zimbra y LoopFuse OneView
-- Entregable: Sesión 3 - Automatización y lógica avanzada (Triggers, Procedimientos y Funciones UDF)
-- Autores:
--   Maria Fernanda Chacón Criales - ID 1103928
--   Sergio Alberto Quiroga Gomez  - ID 798170
--   Santiago Gonzalez Gamboa      - ID 1017544
-- Docente: Ladi Paola Ballen Carrasco
-- Motor: MySQL 8.0+ / MariaDB 10.5+ (Motor transaccional InnoDB)
-- =====================================================================================

USE zimbra_transaccional;

-- Nota: Todas las funciones UDF están declaradas como DETERMINISTIC y READS SQL DATA
-- para compatibilidad directa con MySQL 8.0+ y MariaDB 10.5+ con binlog activo.

-- =====================================================================================
-- LIMPIEZA PREVIA DE OBJETOS DE LA SESIÓN 3 (IDEMPOTENCIA DEL SCRIPT)
-- =====================================================================================
DROP TRIGGER IF EXISTS trg_venta_after_insert_actualizar_propuesta;
DROP TRIGGER IF EXISTS trg_detalle_propuesta_after_insert_recalcular_total;
DROP TRIGGER IF EXISTS trg_detalle_propuesta_after_update_recalcular_total;
DROP TRIGGER IF EXISTS trg_detalle_propuesta_after_delete_recalcular_total;
DROP TRIGGER IF EXISTS trg_propuesta_before_update_validar_vigencia;
DROP TRIGGER IF EXISTS trg_visita_web_after_insert_scoring_y_alerta;
DROP TRIGGER IF EXISTS trg_prospecto_after_update_historial_asignacion;

DROP FUNCTION IF EXISTS fn_calcular_subtotal_propuesta;
DROP FUNCTION IF EXISTS fn_calcular_puntaje_compromiso_prospecto;
DROP FUNCTION IF EXISTS fn_tasa_conversion_vendedor;
DROP FUNCTION IF EXISTS fn_dias_restantes_vigencia_propuesta;
DROP FUNCTION IF EXISTS fn_clasificar_habito_cliente;

DROP PROCEDURE IF EXISTS sp_reporte_mensual_ventas;
DROP PROCEDURE IF EXISTS sp_reporte_desempeno_asesores;
DROP PROCEDURE IF EXISTS sp_reporte_rendimiento_campanas;
DROP PROCEDURE IF EXISTS sp_actualizar_propuestas_vencidas_y_alertas;
DROP PROCEDURE IF EXISTS sp_registrar_propuesta_completa;

DELIMITER $$

-- =====================================================================================
-- PARTE 1: IMPLEMENTACIÓN DE FUNCIONES DEFINIDAS POR EL USUARIO (UDF)
-- Cálculos específicos del negocio Zimbra y LoopFuse OneView (RF-05, RF-10, RF-27, RF-31)
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- FUNCIÓN 1: fn_calcular_subtotal_propuesta
-- Propósito: Calcula el valor total acumulado de una propuesta comercial sumando el
--            producto de (cantidad_licencias * precio_unitario) en detalle_propuesta (RF-10).
-- -------------------------------------------------------------------------------------
CREATE FUNCTION fn_calcular_subtotal_propuesta(p_id_propuesta INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_subtotal DECIMAL(12,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(cantidad_licencias * precio_unitario), 0.00)
      INTO v_subtotal
      FROM detalle_propuesta
     WHERE id_propuesta = p_id_propuesta;

    RETURN v_subtotal;
END$$

-- -------------------------------------------------------------------------------------
-- FUNCIÓN 2: fn_calcular_puntaje_compromiso_prospecto
-- Propósito: Calcula el puntaje de interés (Lead Scoring de LoopFuse OneView entre 0 y 100)
--            de un prospecto ponderando sus actividades en visita_web y sus contactos
--            comerciales registrados (RF-04, RF-05).
-- Ponderación:
--   - Visita simple:        +5 puntos
--   - Apertura de correo:  +10 puntos
--   - Consulta de precios: +15 puntos
--   - Descarga de prueba:  +25 puntos
--   - Contacto comercial:  +10 puntos por interacción
-- -------------------------------------------------------------------------------------
CREATE FUNCTION fn_calcular_puntaje_compromiso_prospecto(p_id_prospecto INT)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_puntos_web INT DEFAULT 0;
    DECLARE v_puntos_contactos INT DEFAULT 0;
    DECLARE v_puntaje_base INT DEFAULT 0;
    DECLARE v_total INT DEFAULT 0;

    SELECT COALESCE(puntaje_interes, 0)
      INTO v_puntaje_base
      FROM prospecto
     WHERE id_prospecto = p_id_prospecto;

    SELECT COALESCE(SUM(
        CASE tipo_actividad
            WHEN 'Descarga de prueba'  THEN 25
            WHEN 'Consulta de precios' THEN 15
            WHEN 'Apertura de correo'  THEN 10
            WHEN 'Visita'              THEN 5
            ELSE 5
        END
    ), 0)
      INTO v_puntos_web
      FROM visita_web
     WHERE id_prospecto = p_id_prospecto;

    SELECT COALESCE(COUNT(*) * 10, 0)
      INTO v_puntos_contactos
      FROM contacto_comercial
     WHERE id_prospecto = p_id_prospecto;

    SET v_total = GREATEST(v_puntaje_base, LEAST(100, v_puntos_web + v_puntos_contactos));
    RETURN v_total;
END$$

-- -------------------------------------------------------------------------------------
-- FUNCIÓN 3: fn_tasa_conversion_vendedor
-- Propósito: Calcula el porcentaje de conversión comercial de un asesor de Zimbra
--            ((prospectos en estado 'Convertido' / prospectos totales asignados) * 100),
--            correspondiente al indicador de la Tabla 20 y Reporte R-03 (RF-26, RF-31).
-- -------------------------------------------------------------------------------------
CREATE FUNCTION fn_tasa_conversion_vendedor(p_id_vendedor INT)
RETURNS DECIMAL(5,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_total_asignados INT DEFAULT 0;
    DECLARE v_total_convertidos INT DEFAULT 0;

    SELECT COUNT(*),
           COALESCE(SUM(CASE WHEN estado = 'Convertido' THEN 1 ELSE 0 END), 0)
      INTO v_total_asignados, v_total_convertidos
      FROM prospecto
     WHERE id_vendedor = p_id_vendedor;

    IF v_total_asignados = 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND((v_total_convertidos / v_total_asignados) * 100, 2);
END$$

-- -------------------------------------------------------------------------------------
-- FUNCIÓN 4: fn_dias_restantes_vigencia_propuesta
-- Propósito: Retorna la cantidad de días restantes para el vencimiento de una propuesta
--            comercial (valor negativo si ya expiró), apoyando el control de RF-11 y RF-24.
-- -------------------------------------------------------------------------------------
CREATE FUNCTION fn_dias_restantes_vigencia_propuesta(p_id_propuesta INT)
RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_fecha_vigencia DATE;

    SELECT fecha_vigencia
      INTO v_fecha_vigencia
      FROM propuesta_comercial
     WHERE id_propuesta = p_id_propuesta;

    IF v_fecha_vigencia IS NULL THEN
        RETURN 0;
    END IF;

    RETURN DATEDIFF(v_fecha_vigencia, CURDATE());
END$$

-- -------------------------------------------------------------------------------------
-- FUNCIÓN 5: fn_clasificar_habito_cliente
-- Propósito: Clasifica el hábito de compra de un prospecto/cliente ('Frecuente',
--            'Ocasional', 'Inactivo' o 'Sin compras') según el número de ventas no anuladas
--            y los días de recencia desde su última compra (Tabla 24 y RF-27).
-- -------------------------------------------------------------------------------------
CREATE FUNCTION fn_clasificar_habito_cliente(p_id_prospecto INT)
RETURNS VARCHAR(20)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_compras INT DEFAULT 0;
    DECLARE v_ultima_compra DATE;
    DECLARE v_recencia_dias INT DEFAULT 0;

    SELECT COUNT(ve.id_venta), MAX(ve.fecha_venta)
      INTO v_compras, v_ultima_compra
      FROM propuesta_comercial pc
      JOIN venta ve ON ve.id_propuesta = pc.id_propuesta
     WHERE pc.id_prospecto = p_id_prospecto
       AND ve.estado <> 'Anulada';

    IF v_compras = 0 OR v_ultima_compra IS NULL THEN
        RETURN 'Sin compras';
    END IF;

    SET v_recencia_dias = DATEDIFF(CURDATE(), v_ultima_compra);

    IF v_compras >= 3 AND v_recencia_dias <= 120 THEN
        RETURN 'Frecuente';
    ELSEIF v_recencia_dias > 365 THEN
        RETURN 'Inactivo';
    ELSEIF v_compras >= 2 OR v_recencia_dias <= 180 THEN
        RETURN 'Ocasional';
    ELSE
        RETURN 'Inactivo';
    END IF;
END$$


-- =====================================================================================
-- PARTE 2: CREACIÓN DE TRIGGERS (DISPARADORES AUTOMÁTICOS DE REGLAS DE NEGOCIO)
-- Automatizan la actualización de estados, recálculo de propuestas, lead scoring y alertas
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- TRIGGER 1: trg_venta_after_insert_actualizar_propuesta
-- Evento: AFTER INSERT ON venta
-- Propósito: Cuando se registra una nueva venta no anulada, actualiza automáticamente
--            el estado de la propuesta comercial a 'Aceptada', convierte al prospecto en
--            cliente ('Convertido' con puntaje 100) y marca sus alertas pendientes como
--            atendidas (RF-11, RF-12).
-- -------------------------------------------------------------------------------------
CREATE TRIGGER trg_venta_after_insert_actualizar_propuesta
AFTER INSERT ON venta
FOR EACH ROW
BEGIN
    DECLARE v_id_prospecto INT;

    IF NEW.estado <> 'Anulada' THEN
        SELECT id_prospecto
          INTO v_id_prospecto
          FROM propuesta_comercial
         WHERE id_propuesta = NEW.id_propuesta;

        UPDATE propuesta_comercial
           SET estado = 'Aceptada'
         WHERE id_propuesta = NEW.id_propuesta
           AND estado <> 'Aceptada';

        IF v_id_prospecto IS NOT NULL THEN
            UPDATE prospecto
               SET estado = 'Convertido',
                   puntaje_interes = 100
             WHERE id_prospecto = v_id_prospecto;

            UPDATE alerta
               SET atendida = TRUE
             WHERE id_prospecto = v_id_prospecto
               AND atendida = FALSE;
        END IF;
    END IF;
END$$

-- -------------------------------------------------------------------------------------
-- TRIGGERS 2A, 2B y 2C: Recálculo automático de valor_total en propuesta_comercial
-- Eventos: AFTER INSERT, AFTER UPDATE y AFTER DELETE ON detalle_propuesta
-- Propósito: Mantiene sincronizado el atributo propuesta_comercial.valor_total invocando
--            la función UDF fn_calcular_subtotal_propuesta cada vez que cambian las líneas
--            de detalle de la propuesta (RF-10).
-- -------------------------------------------------------------------------------------
CREATE TRIGGER trg_detalle_propuesta_after_insert_recalcular_total
AFTER INSERT ON detalle_propuesta
FOR EACH ROW
BEGIN
    UPDATE propuesta_comercial
       SET valor_total = fn_calcular_subtotal_propuesta(NEW.id_propuesta)
     WHERE id_propuesta = NEW.id_propuesta;
END$$

CREATE TRIGGER trg_detalle_propuesta_after_update_recalcular_total
AFTER UPDATE ON detalle_propuesta
FOR EACH ROW
BEGIN
    UPDATE propuesta_comercial
       SET valor_total = fn_calcular_subtotal_propuesta(NEW.id_propuesta)
     WHERE id_propuesta = NEW.id_propuesta;
END$$

CREATE TRIGGER trg_detalle_propuesta_after_delete_recalcular_total
AFTER DELETE ON detalle_propuesta
FOR EACH ROW
BEGIN
    UPDATE propuesta_comercial
       SET valor_total = fn_calcular_subtotal_propuesta(OLD.id_propuesta)
     WHERE id_propuesta = OLD.id_propuesta;
END$$

-- -------------------------------------------------------------------------------------
-- TRIGGER 3: trg_propuesta_before_update_validar_vigencia
-- Evento: BEFORE UPDATE ON propuesta_comercial
-- Propósito:
--   1) Impide que una propuesta ya 'Vencida' o 'Rechazada' pase directamente a 'Aceptada'
--      sin haber ampliado antes su fecha_vigencia.
--   2) Si la fecha_vigencia ya expiró (< CURDATE()) y la propuesta sigue en 'Enviada' o
--      'En negociación', actualiza automáticamente su estado a 'Vencida' (RF-11).
-- -------------------------------------------------------------------------------------
CREATE TRIGGER trg_propuesta_before_update_validar_vigencia
BEFORE UPDATE ON propuesta_comercial
FOR EACH ROW
BEGIN
    IF OLD.estado IN ('Vencida', 'Rechazada')
       AND NEW.estado = 'Aceptada'
       AND NEW.fecha_vigencia <= OLD.fecha_vigencia THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Regla de negocio Zimbra: No se puede aceptar una propuesta vencida o rechazada sin renovar su vigencia.';
    END IF;

    IF NEW.fecha_vigencia < CURDATE()
       AND NEW.estado IN ('Enviada', 'En negociación') THEN
        SET NEW.estado = 'Vencida';
    END IF;
END$$

-- -------------------------------------------------------------------------------------
-- TRIGGER 4: trg_visita_web_after_insert_scoring_y_alerta
-- Evento: AFTER INSERT ON visita_web
-- Propósito: Automatiza el motor de marketing de LoopFuse OneView (RF-04, RF-05, RF-24):
--   1) Suma puntos de interés al prospecto según el tipo de actividad web realizada.
--   2) Si el prospecto estaba en estado 'Nuevo' y alcanza >= 60 puntos, actualiza su
--      estado automáticamente a 'Calificado'.
--   3) Si alcanza >= 80 puntos (o descarga la prueba de 60 días), genera una alerta
--      automática de 'Alto interés' o 'Prueba por vencer' para el vendedor asignado.
-- -------------------------------------------------------------------------------------
CREATE TRIGGER trg_visita_web_after_insert_scoring_y_alerta
AFTER INSERT ON visita_web
FOR EACH ROW
BEGIN
    DECLARE v_incremento INT DEFAULT 5;
    DECLARE v_puntaje_actual INT DEFAULT 0;
    DECLARE v_nuevo_puntaje INT DEFAULT 0;
    DECLARE v_estado_actual VARCHAR(20);
    DECLARE v_id_vendedor INT;
    DECLARE v_alertas_activas INT DEFAULT 0;

    IF NEW.id_prospecto IS NOT NULL THEN
        SET v_incremento = CASE NEW.tipo_actividad
            WHEN 'Descarga de prueba'  THEN 25
            WHEN 'Consulta de precios' THEN 15
            WHEN 'Apertura de correo'  THEN 10
            WHEN 'Visita'              THEN 5
            ELSE 5
        END;

        SELECT puntaje_interes, estado, id_vendedor
          INTO v_puntaje_actual, v_estado_actual, v_id_vendedor
          FROM prospecto
         WHERE id_prospecto = NEW.id_prospecto;

        SET v_nuevo_puntaje = LEAST(100, COALESCE(v_puntaje_actual, 0) + v_incremento);

        UPDATE prospecto
           SET puntaje_interes = v_nuevo_puntaje,
               estado = CASE
                   WHEN v_estado_actual = 'Nuevo' AND v_nuevo_puntaje >= 60 THEN 'Calificado'
                   ELSE v_estado_actual
               END
         WHERE id_prospecto = NEW.id_prospecto;

        -- Generar alerta automática de 'Alto interés' si supera 80 puntos y no tiene una pendiente
        IF v_nuevo_puntaje >= 80 THEN
            SELECT COUNT(*)
              INTO v_alertas_activas
              FROM alerta
             WHERE id_prospecto = NEW.id_prospecto
               AND tipo = 'Alto interés'
               AND atendida = FALSE;

            IF v_alertas_activas = 0 THEN
                INSERT INTO alerta (id_prospecto, id_vendedor, tipo, fecha_generada, atendida)
                VALUES (NEW.id_prospecto, v_id_vendedor, 'Alto interés', NOW(), FALSE);
            END IF;
        END IF;

        -- Si descargó la prueba de 60 días de ZCS, programar alerta de seguimiento de prueba
        IF NEW.tipo_actividad = 'Descarga de prueba' THEN
            SELECT COUNT(*)
              INTO v_alertas_activas
              FROM alerta
             WHERE id_prospecto = NEW.id_prospecto
               AND tipo = 'Prueba por vencer'
               AND atendida = FALSE;

            IF v_alertas_activas = 0 THEN
                INSERT INTO alerta (id_prospecto, id_vendedor, tipo, fecha_generada, atendida)
                VALUES (NEW.id_prospecto, v_id_vendedor, 'Prueba por vencer', NOW(), FALSE);
            END IF;
        END IF;
    END IF;
END$$

-- -------------------------------------------------------------------------------------
-- TRIGGER 5: trg_prospecto_after_update_historial_asignacion
-- Evento: AFTER UPDATE ON prospecto
-- Propósito: Cuando se reasigna un prospecto a otro vendedor (cambio en id_vendedor),
--            cierra automáticamente la asignación vigente previa como 'Reasignada' en
--            asignacion_asesor y crea el nuevo registro 'Vigente' (RF-03, RF-23, RNF-18).
-- -------------------------------------------------------------------------------------
CREATE TRIGGER trg_prospecto_after_update_historial_asignacion
AFTER UPDATE ON prospecto
FOR EACH ROW
BEGIN
    IF NEW.id_vendedor IS NOT NULL
       AND (OLD.id_vendedor IS NULL OR OLD.id_vendedor <> NEW.id_vendedor) THEN

        UPDATE asignacion_asesor
           SET estado = 'Reasignada',
               fecha_finalizacion = NOW()
         WHERE id_prospecto = NEW.id_prospecto
           AND estado = 'Vigente';

        INSERT INTO asignacion_asesor (id_prospecto, id_vendedor, fecha_asignacion, estado)
        VALUES (NEW.id_prospecto, NEW.id_vendedor, NOW(), 'Vigente');
    END IF;
END$$


-- =====================================================================================
-- PARTE 3: DESARROLLO DE PROCEDIMIENTOS ALMACENADOS (STORED PROCEDURES)
-- Reportes mensuales, desempeño comercial, ROI de campañas y automatización de propuestas
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- PROCEDIMIENTO 1: sp_reporte_mensual_ventas
-- Propósito: Genera el reporte mensual de ventas consolidado por periodo, vendedor,
--            producto y campaña de origen, calculando total de ventas, licencias vendidas,
--            ingresos totales y ticket promedio (RF-15, RF-28, RF-31 y Reporte R-05).
--            Si p_mes es NULL o 0, devuelve todos los meses del año indicado.
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_reporte_mensual_ventas(
    IN p_anio INT,
    IN p_mes  INT
)
BEGIN
    SELECT DATE_FORMAT(ve.fecha_venta, '%Y-%m') AS periodo,
           CONCAT(v.nombre, ' ', v.apellido)    AS vendedor,
           v.region                             AS region,
           CONCAT(pr.nombre, ' v', pr.version)  AS producto,
           COALESCE(c.nombre, 'Tráfico directo') AS campana_marketing,
           COUNT(DISTINCT ve.id_venta)          AS total_ventas,
           COALESCE(SUM(dp.cantidad_licencias), 0) AS licencias_vendidas,
           ROUND(SUM(dp.cantidad_licencias * dp.precio_unitario), 2) AS ingresos_detalle,
           ROUND(AVG(ve.valor_final), 2)        AS ticket_promedio_venta
      FROM venta ve
      JOIN propuesta_comercial pc ON pc.id_propuesta = ve.id_propuesta
      JOIN detalle_propuesta dp   ON dp.id_propuesta = pc.id_propuesta
      JOIN producto pr            ON pr.id_producto  = dp.id_producto
      JOIN vendedor v             ON v.id_vendedor   = pc.id_vendedor
      JOIN prospecto p            ON p.id_prospecto  = pc.id_prospecto
      LEFT JOIN campana_marketing c ON c.id_campana  = p.id_campana
     WHERE ve.estado <> 'Anulada'
       AND (p_anio IS NULL OR p_anio = 0 OR YEAR(ve.fecha_venta) = p_anio)
       AND (p_mes  IS NULL OR p_mes  = 0 OR MONTH(ve.fecha_venta) = p_mes)
     GROUP BY DATE_FORMAT(ve.fecha_venta, '%Y-%m'),
              v.id_vendedor, v.nombre, v.apellido, v.region,
              pr.id_producto, pr.nombre, pr.version,
              c.id_campana, c.nombre
     ORDER BY periodo DESC, ingresos_detalle DESC;
END$$

-- -------------------------------------------------------------------------------------
-- PROCEDIMIENTO 2: sp_reporte_desempeno_asesores
-- Propósito: Calcula los indicadores de gestión comercial para los 30 asesores de Zimbra
--            definidos en la Tabla 20 y el Reporte R-03 (RF-26, RF-31), integrando la
--            función UDF fn_tasa_conversion_vendedor.
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_reporte_desempeno_asesores()
BEGIN
    SELECT v.id_vendedor,
           CONCAT(v.nombre, ' ', v.apellido) AS asesor,
           v.region,
           COUNT(DISTINCT p.id_prospecto) AS prospectos_asignados,
           COUNT(DISTINCT cc.id_prospecto) AS prospectos_contactados,
           COUNT(DISTINCT cc.id_contacto) AS contactos_realizados,
           COUNT(DISTINCT pc.id_propuesta) AS propuestas_generadas,
           COUNT(DISTINCT CASE WHEN pc.estado = 'Aceptada' THEN pc.id_propuesta END) AS propuestas_aceptadas,
           COUNT(DISTINCT CASE WHEN ve.estado <> 'Anulada' THEN ve.id_venta END) AS ventas_concretadas,
           COALESCE(SUM(DISTINCT CASE WHEN ve.estado <> 'Anulada' THEN ve.valor_final ELSE 0 END), 0.00) AS valor_total_vendido,
           fn_tasa_conversion_vendedor(v.id_vendedor) AS tasa_conversion_pct,
           ROUND(COALESCE(AVG(DATEDIFF(ve.fecha_venta, p.fecha_registro)), 0), 1) AS dias_promedio_cierre
      FROM vendedor v
      LEFT JOIN prospecto p            ON p.id_vendedor  = v.id_vendedor
      LEFT JOIN contacto_comercial cc  ON cc.id_vendedor = v.id_vendedor
      LEFT JOIN propuesta_comercial pc ON pc.id_vendedor = v.id_vendedor
      LEFT JOIN venta ve               ON ve.id_propuesta = pc.id_propuesta
     GROUP BY v.id_vendedor, v.nombre, v.apellido, v.region
     ORDER BY valor_total_vendido DESC, tasa_conversion_pct DESC;
END$$

-- -------------------------------------------------------------------------------------
-- PROCEDIMIENTO 3: sp_reporte_rendimiento_campanas
-- Propósito: Genera el reporte de efectividad y retorno de inversión (ROI) de las campañas
--            de marketing en LoopFuse OneView (RF-16, RF-31 y Reporte R-08).
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_reporte_rendimiento_campanas()
BEGIN
    SELECT c.id_campana,
           c.nombre AS campana,
           c.canal,
           c.estado,
           c.presupuesto,
           COUNT(DISTINCT p.id_prospecto) AS prospectos_generados,
           COUNT(DISTINCT CASE WHEN p.estado IN ('Calificado', 'En seguimiento', 'Convertido') THEN p.id_prospecto END) AS prospectos_calificados,
           COUNT(DISTINCT pc.id_propuesta) AS propuestas_asociadas,
           COUNT(DISTINCT CASE WHEN ve.estado <> 'Anulada' THEN ve.id_venta END) AS ventas_concretadas,
           COALESCE(SUM(CASE WHEN ve.estado <> 'Anulada' THEN ve.valor_final ELSE 0 END), 0.00) AS valor_vendido,
           ROUND(
               CASE
                   WHEN COUNT(DISTINCT p.id_prospecto) = 0 THEN 0.00
                   ELSE (COUNT(DISTINCT CASE WHEN ve.estado <> 'Anulada' THEN ve.id_venta END) / COUNT(DISTINCT p.id_prospecto)) * 100
               END, 2
           ) AS tasa_conversion_pct,
           ROUND(
               CASE
                   WHEN COUNT(DISTINCT CASE WHEN ve.estado <> 'Anulada' THEN ve.id_venta END) = 0 THEN c.presupuesto
                   ELSE c.presupuesto / COUNT(DISTINCT CASE WHEN ve.estado <> 'Anulada' THEN ve.id_venta END)
               END, 2
           ) AS costo_por_venta
      FROM campana_marketing c
      LEFT JOIN prospecto p            ON p.id_campana    = c.id_campana
      LEFT JOIN propuesta_comercial pc ON pc.id_prospecto = p.id_prospecto
      LEFT JOIN venta ve               ON ve.id_propuesta = pc.id_propuesta
     GROUP BY c.id_campana, c.nombre, c.canal, c.estado, c.presupuesto
     ORDER BY valor_vendido DESC, prospectos_generados DESC;
END$$

-- -------------------------------------------------------------------------------------
-- PROCEDIMIENTO 4: sp_actualizar_propuestas_vencidas_y_alertas
-- Propósito: Automatiza la revisión diaria de propuestas comerciales y licencias (RF-11, RF-24):
--   1) Cambia a estado 'Vencida' las propuestas en 'Enviada' o 'En negociación' cuya
--      fecha_vigencia sea anterior a CURDATE().
--   2) Genera alertas 'Propuesta por vencer' para propuestas que vencen en los próximos 7 días.
--   3) Genera alertas 'Licencia por vencer' para ventas cuyas licencias vencen en <= 60 días.
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_actualizar_propuestas_vencidas_y_alertas(
    OUT p_propuestas_vencidas INT,
    OUT p_alertas_creadas     INT
)
BEGIN
    DECLARE v_alertas_propuesta INT DEFAULT 0;
    DECLARE v_alertas_licencia  INT DEFAULT 0;

    START TRANSACTION;

    -- 1. Marcar propuestas expiradas como 'Vencida'
    UPDATE propuesta_comercial
       SET estado = 'Vencida'
     WHERE estado IN ('Enviada', 'En negociación')
       AND fecha_vigencia < CURDATE();

    SET p_propuestas_vencidas = ROW_COUNT();

    -- 2. Generar alertas para propuestas que vencen en los próximos 7 días
    INSERT INTO alerta (id_prospecto, id_vendedor, tipo, fecha_generada, atendida)
    SELECT pc.id_prospecto, pc.id_vendedor, 'Propuesta por vencer', NOW(), FALSE
      FROM propuesta_comercial pc
     WHERE pc.estado IN ('Enviada', 'En negociación')
       AND fn_dias_restantes_vigencia_propuesta(pc.id_propuesta) BETWEEN 0 AND 7
       AND NOT EXISTS (
           SELECT 1
             FROM alerta a
            WHERE a.id_prospecto = pc.id_prospecto
              AND a.tipo = 'Propuesta por vencer'
              AND a.atendida = FALSE
       );

    SET v_alertas_propuesta = ROW_COUNT();

    -- 3. Generar alertas para licencias de clientes que vencen en los próximos 60 días
    INSERT INTO alerta (id_prospecto, id_vendedor, tipo, fecha_generada, atendida)
    SELECT pc.id_prospecto, pc.id_vendedor, 'Licencia por vencer', NOW(), FALSE
      FROM venta ve
      JOIN propuesta_comercial pc ON pc.id_propuesta = ve.id_propuesta
     WHERE ve.estado <> 'Anulada'
       AND ve.fecha_vencimiento_licencia IS NOT NULL
       AND DATEDIFF(ve.fecha_vencimiento_licencia, CURDATE()) BETWEEN 0 AND 60
       AND NOT EXISTS (
           SELECT 1
             FROM alerta a
            WHERE a.id_prospecto = pc.id_prospecto
              AND a.tipo = 'Licencia por vencer'
              AND a.atendida = FALSE
       );

    SET v_alertas_licencia = ROW_COUNT();
    SET p_alertas_creadas = v_alertas_propuesta + v_alertas_licencia;

    COMMIT;
END$$

-- -------------------------------------------------------------------------------------
-- PROCEDIMIENTO 5: sp_registrar_propuesta_completa
-- Propósito: Registra de forma transaccional una nueva propuesta comercial junto con su
--            línea de detalle de licencias ZCS, apoyándose en el trigger
--            trg_detalle_propuesta_after_insert_recalcular_total y la función UDF
--            fn_calcular_subtotal_propuesta, y actualiza el estado del prospecto a
--            'En seguimiento' (RF-09, RF-10).
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_propuesta_completa(
    IN  p_id_prospecto       INT,
    IN  p_id_vendedor        INT,
    IN  p_dias_vigencia      INT,
    IN  p_id_producto        INT,
    IN  p_cantidad_licencias INT,
    IN  p_precio_unitario    DECIMAL(12,2),
    OUT p_id_propuesta       INT,
    OUT p_valor_total        DECIMAL(12,2),
    OUT p_mensaje            VARCHAR(200)
)
BEGIN
    DECLARE v_precio_catalogo DECIMAL(12,2);
    DECLARE v_precio_final    DECIMAL(12,2);
    DECLARE v_dias            INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_propuesta = 0;
        SET p_valor_total  = 0.00;
        SET p_mensaje      = 'ERROR: No fue posible registrar la propuesta comercial. Se ejecutó ROLLBACK.';
    END;

    START TRANSACTION;

    SET v_dias = IF(p_dias_vigencia IS NULL OR p_dias_vigencia <= 0, 30, p_dias_vigencia);

    -- Si no se envía precio unitario explícito, tomar el precio oficial del catálogo producto
    IF p_precio_unitario IS NULL OR p_precio_unitario <= 0 THEN
        SELECT precio_unitario
          INTO v_precio_catalogo
          FROM producto
         WHERE id_producto = p_id_producto;
        SET v_precio_final = COALESCE(v_precio_catalogo, 35.00);
    ELSE
        SET v_precio_final = p_precio_unitario;
    END IF;

    -- 1. Insertar cabecera de propuesta con valor inicial 0.00
    INSERT INTO propuesta_comercial (id_prospecto, id_vendedor, fecha_envio, fecha_vigencia, valor_total, estado)
    VALUES (p_id_prospecto, p_id_vendedor, CURDATE(), DATE_ADD(CURDATE(), INTERVAL v_dias DAY), 0.00, 'Enviada');

    SET p_id_propuesta = LAST_INSERT_ID();

    -- 2. Insertar línea de detalle (dispara automáticamente trg_detalle_propuesta_after_insert_recalcular_total)
    INSERT INTO detalle_propuesta (id_propuesta, id_producto, cantidad_licencias, precio_unitario)
    VALUES (p_id_propuesta, p_id_producto, p_cantidad_licencias, v_precio_final);

    -- 3. Consultar el total calculado mediante la función UDF fn_calcular_subtotal_propuesta
    SET p_valor_total = fn_calcular_subtotal_propuesta(p_id_propuesta);

    -- 4. Pasar el prospecto a 'En seguimiento' si estaba en 'Nuevo' o 'Calificado'
    UPDATE prospecto
       SET estado = CASE
               WHEN estado IN ('Nuevo', 'Calificado') THEN 'En seguimiento'
               ELSE estado
           END
     WHERE id_prospecto = p_id_prospecto;

    COMMIT;

    SET p_mensaje = CONCAT('OK: Propuesta #', p_id_propuesta,
                           ' creada y recalculada automáticamente por Trigger/UDF. Total USD $', p_valor_total);
END$$

DELIMITER ;

-- =====================================================================================
-- PARTE 4: PRUEBAS Y DEMOSTRACIÓN DE TRIGGERS, FUNCIONES UDF Y PROCEDIMIENTOS ALMACENADOS
-- =====================================================================================

-- 4.1 Demostración de las 5 Funciones UDF:
SELECT
    fn_calcular_subtotal_propuesta(1)              AS subtotal_propuesta_1,
    fn_calcular_puntaje_compromiso_prospecto(1)    AS puntaje_compromiso_prospecto_1,
    fn_tasa_conversion_vendedor(1)                 AS tasa_conversion_vendedor_1_pct,
    fn_dias_restantes_vigencia_propuesta(31)       AS dias_vigencia_propuesta_31,
    fn_clasificar_habito_cliente(1)                AS habito_compra_cliente_1;

-- 4.2 Demostración del Trigger trg_visita_web_after_insert_scoring_y_alerta:
-- Insertar una descarga de prueba de 60 días para el prospecto #26 -> incrementa puntaje y crea alerta automática
INSERT INTO visita_web (id_prospecto, id_visitante, fecha_hora, url_visitada, tipo_actividad, duracion_segundos)
VALUES (26, NULL, NOW(), 'https://www.zimbra.com/downloads/zcs-trial-60d', 'Descarga de prueba', 240);

SELECT id_prospecto, nombre, apellido, empresa, estado, puntaje_interes
FROM prospecto
WHERE id_prospecto = 26;

-- 4.3 Demostración del Procedimiento sp_registrar_propuesta_completa + Trigger de recálculo de detalle:
CALL sp_registrar_propuesta_completa(26, 26, 30, 10, 50, 35.00, @id_prop_s3, @total_prop_s3, @msg_prop_s3);
SELECT @id_prop_s3 AS id_propuesta_creada, @total_prop_s3 AS valor_total_calculado, @msg_prop_s3 AS resultado;

-- 4.4 Demostración del Procedimiento sp_actualizar_propuestas_vencidas_y_alertas:
CALL sp_actualizar_propuestas_vencidas_y_alertas(@total_vencidas, @total_alertas);
SELECT @total_vencidas AS propuestas_marcadas_vencidas, @total_alertas AS nuevas_alertas_generadas;

-- 4.5 Demostración del Procedimiento de Reporte Mensual de Ventas (Octubre de 2026):
CALL sp_reporte_mensual_ventas(2026, 10);

-- 4.6 Demostración del Procedimiento de Desempeño por Asesor (Top 30 asesores):
CALL sp_reporte_desempeno_asesores();

-- 4.7 Demostración del Procedimiento de Rendimiento de Campañas de Marketing:
CALL sp_reporte_rendimiento_campanas();
