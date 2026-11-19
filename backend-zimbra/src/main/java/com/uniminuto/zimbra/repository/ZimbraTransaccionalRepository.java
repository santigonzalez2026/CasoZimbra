package com.uniminuto.zimbra.repository;

import org.springframework.jdbc.core.CallableStatementCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Types;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Repositorio JDBC que interactúa directamente con las 13 tablas del modelo relacional
 * en MySQL (zimbra_transaccional), incluyendo las transacciones ACID de la Sesión 2 y
 * la invocación de Triggers, Procedimientos Almacenados y Funciones UDF de la Sesión 3.
 */
@Repository
public class ZimbraTransaccionalRepository {

    private final JdbcTemplate jdbcTemplate;

    public ZimbraTransaccionalRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Verifica la conexión activa y retorna el conteo de registros de las 13 tablas del modelo.
     */
    public Map<String, Integer> obtenerConteoTablas() {
        String[] tablas = {
                "vendedor", "producto", "campana_marketing", "prospecto",
                "visitante", "visita_web", "usuario", "asignacion_asesor",
                "contacto_comercial", "alerta", "propuesta_comercial",
                "detalle_propuesta", "venta"
        };
        Map<String, Integer> conteos = new LinkedHashMap<>();
        for (String tabla : tablas) {
            Integer total = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM " + tabla, Integer.class);
            conteos.put(tabla, total != null ? total : 0);
        }
        return conteos;
    }

    public List<Map<String, Object>> listarVendedores() {
        String sql = """
                SELECT id_vendedor, nombre, apellido, correo, telefono, region, fecha_ingreso, activo
                FROM vendedor
                ORDER BY id_vendedor
                """;
        return jdbcTemplate.queryForList(sql);
    }

    public List<Map<String, Object>> listarProductos() {
        String sql = """
                SELECT id_producto, nombre, version, tipo_licencia, precio_unitario, activo
                FROM producto
                ORDER BY id_producto
                """;
        return jdbcTemplate.queryForList(sql);
    }

    public List<Map<String, Object>> listarCampanas() {
        String sql = """
                SELECT id_campana, nombre, canal, fecha_inicio, fecha_fin, presupuesto, estado
                FROM campana_marketing
                ORDER BY id_campana DESC
                """;
        return jdbcTemplate.queryForList(sql);
    }

    public List<Map<String, Object>> listarProspectos() {
        String sql = """
                SELECT p.id_prospecto, p.nombre, p.apellido, p.correo, p.telefono, p.empresa, p.pais,
                       p.fecha_registro, p.estado, p.puntaje_interes,
                       p.id_vendedor,
                       CONCAT(v.nombre, ' ', v.apellido) AS asesor_asignado,
                       c.nombre AS campana_origen,
                       pr.nombre AS producto_interes
                FROM prospecto p
                LEFT JOIN vendedor v           ON v.id_vendedor = p.id_vendedor
                LEFT JOIN campana_marketing c  ON c.id_campana  = p.id_campana
                LEFT JOIN producto pr          ON pr.id_producto = p.id_producto_interes
                ORDER BY p.id_prospecto DESC
                """;
        return jdbcTemplate.queryForList(sql);
    }

    public Map<String, Object> obtenerProspectoPorId(int idProspecto) {
        String sql = """
                SELECT p.*, CONCAT(v.nombre, ' ', v.apellido) AS asesor_asignado
                FROM prospecto p
                LEFT JOIN vendedor v ON v.id_vendedor = p.id_vendedor
                WHERE p.id_prospecto = ?
                """;
        return jdbcTemplate.queryForMap(sql, idProspecto);
    }

    public List<Map<String, Object>> listarPropuestas() {
        String sql = """
                SELECT pc.id_propuesta, pc.fecha_envio, pc.fecha_vigencia, pc.valor_total, pc.estado,
                       p.id_prospecto, COALESCE(p.empresa, CONCAT(p.nombre, ' ', p.apellido)) AS prospecto,
                       CONCAT(v.nombre, ' ', v.apellido) AS vendedor
                FROM propuesta_comercial pc
                JOIN prospecto p ON p.id_prospecto = pc.id_prospecto
                JOIN vendedor v  ON v.id_vendedor  = pc.id_vendedor
                ORDER BY pc.id_propuesta DESC
                """;
        return jdbcTemplate.queryForList(sql);
    }

    public List<Map<String, Object>> listarVentas() {
        String sql = """
                SELECT ve.id_venta, ve.id_propuesta, ve.fecha_venta, ve.valor_final,
                       ve.medio_pago, ve.estado, ve.fecha_vencimiento_licencia,
                       COALESCE(p.empresa, CONCAT(p.nombre, ' ', p.apellido)) AS cliente,
                       CONCAT(v.nombre, ' ', v.apellido) AS vendedor
                FROM venta ve
                JOIN propuesta_comercial pc ON pc.id_propuesta = ve.id_propuesta
                JOIN prospecto p            ON p.id_prospecto  = pc.id_prospecto
                JOIN vendedor v             ON v.id_vendedor   = pc.id_vendedor
                ORDER BY ve.id_venta DESC
                """;
        return jdbcTemplate.queryForList(sql);
    }

    public List<Map<String, Object>> listarAlertas() {
        String sql = """
                SELECT a.id_alerta, a.id_prospecto,
                       COALESCE(p.empresa, CONCAT(p.nombre, ' ', p.apellido)) AS prospecto,
                       CONCAT(v.nombre, ' ', v.apellido) AS asesor,
                       a.tipo, a.fecha_generada, a.atendida
                FROM alerta a
                JOIN prospecto p ON p.id_prospecto = a.id_prospecto
                LEFT JOIN vendedor v ON v.id_vendedor = a.id_vendedor
                ORDER BY a.id_alerta DESC
                LIMIT 50
                """;
        return jdbcTemplate.queryForList(sql);
    }

    public List<Map<String, Object>> listarBitacoraErrores() {
        String sql = """
                SELECT id_error, fecha_evento, operacion, codigo_sqlstate,
                       numero_error, mensaje_error, accion_tomada
                FROM bitacora_errores_transaccion
                ORDER BY id_error DESC
                """;
        return jdbcTemplate.queryForList(sql);
    }

    public int insertarProspecto(String nombre, String apellido, String correo, String telefono,
                                 String empresa, String pais, Integer idVendedor,
                                 Integer idCampana, Integer idProductoInteres) {
        String sql = """
                INSERT INTO prospecto
                (nombre, apellido, correo, telefono, empresa, pais, fecha_registro, estado, puntaje_interes, id_vendedor, id_campana, id_producto_interes)
                VALUES (?, ?, ?, ?, ?, ?, CURDATE(), 'Nuevo', 30, ?, ?, ?)
                """;
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(con -> {
            PreparedStatement ps = con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, nombre);
            ps.setString(2, apellido);
            ps.setString(3, correo);
            ps.setString(4, telefono);
            ps.setString(5, empresa);
            ps.setString(6, pais);
            if (idVendedor != null) ps.setInt(7, idVendedor); else ps.setNull(7, Types.INTEGER);
            if (idCampana != null) ps.setInt(8, idCampana); else ps.setNull(8, Types.INTEGER);
            if (idProductoInteres != null) ps.setInt(9, idProductoInteres); else ps.setNull(9, Types.INTEGER);
            return ps;
        }, keyHolder);
        return keyHolder.getKey().intValue();
    }

    public void insertarAsignacionAsesor(int idProspecto, int idVendedor, String estado) {
        String sql = """
                INSERT INTO asignacion_asesor (id_prospecto, id_vendedor, fecha_asignacion, estado)
                VALUES (?, ?, NOW(), ?)
                """;
        jdbcTemplate.update(sql, idProspecto, idVendedor, estado);
    }

    public void insertarAlerta(int idProspecto, Integer idVendedor, String tipo) {
        String sql = """
                INSERT INTO alerta (id_prospecto, id_vendedor, tipo, fecha_generada, atendida)
                VALUES (?, ?, ?, NOW(), FALSE)
                """;
        jdbcTemplate.update(sql, idProspecto, idVendedor, tipo);
    }

    public int insertarCabeceraPropuesta(int idProspecto, int idVendedor, LocalDate fechaVigencia) {
        String sql = """
                INSERT INTO propuesta_comercial (id_prospecto, id_vendedor, fecha_envio, fecha_vigencia, valor_total, estado)
                VALUES (?, ?, CURDATE(), ?, 0.00, 'Enviada')
                """;
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(con -> {
            PreparedStatement ps = con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            ps.setInt(1, idProspecto);
            ps.setInt(2, idVendedor);
            ps.setDate(3, Date.valueOf(fechaVigencia != null ? fechaVigencia : LocalDate.now().plusDays(30)));
            return ps;
        }, keyHolder);
        return keyHolder.getKey().intValue();
    }

    public void insertarDetallePropuesta(int idPropuesta, int idProducto, int cantidad, BigDecimal precioUnitario) {
        String sql = """
                INSERT INTO detalle_propuesta (id_propuesta, id_producto, cantidad_licencias, precio_unitario)
                VALUES (?, ?, ?, ?)
                """;
        jdbcTemplate.update(sql, idPropuesta, idProducto, cantidad, precioUnitario);
    }

    public BigDecimal recalcularValorTotalPropuesta(int idPropuesta) {
        String sqlTotal = """
                SELECT COALESCE(SUM(cantidad_licencias * precio_unitario), 0.00)
                FROM detalle_propuesta
                WHERE id_propuesta = ?
                """;
        BigDecimal total = jdbcTemplate.queryForObject(sqlTotal, BigDecimal.class, idPropuesta);
        jdbcTemplate.update("UPDATE propuesta_comercial SET valor_total = ? WHERE id_propuesta = ?", total, idPropuesta);
        return total;
    }

    public Map<String, Object> obtenerPropuestaParaBloqueo(int idPropuesta) {
        String sql = """
                SELECT id_propuesta, id_prospecto, id_vendedor, valor_total, estado
                FROM propuesta_comercial
                WHERE id_propuesta = ?
                FOR UPDATE
                """;
        return jdbcTemplate.queryForMap(sql, idPropuesta);
    }

    public void actualizarEstadoPropuesta(int idPropuesta, String nuevoEstado) {
        jdbcTemplate.update("UPDATE propuesta_comercial SET estado = ? WHERE id_propuesta = ?", nuevoEstado, idPropuesta);
    }

    public int insertarVenta(int idPropuesta, BigDecimal valorFinal, String medioPago) {
        String sql = """
                INSERT INTO venta (id_propuesta, fecha_venta, valor_final, medio_pago, estado, fecha_vencimiento_licencia)
                VALUES (?, CURDATE(), ?, ?, 'Registrada', DATE_ADD(CURDATE(), INTERVAL 1 YEAR))
                """;
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(con -> {
            PreparedStatement ps = con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            ps.setInt(1, idPropuesta);
            ps.setBigDecimal(2, valorFinal);
            ps.setString(3, medioPago);
            return ps;
        }, keyHolder);
        return keyHolder.getKey().intValue();
    }

    public void actualizarProspectoConvertido(int idProspecto) {
        String sql = "UPDATE prospecto SET estado = 'Convertido', puntaje_interes = 100 WHERE id_prospecto = ?";
        jdbcTemplate.update(sql, idProspecto);
    }

    public void marcarAlertasAtendidas(int idProspecto) {
        String sql = "UPDATE alerta SET atendida = TRUE WHERE id_prospecto = ? AND atendida = FALSE";
        jdbcTemplate.update(sql, idProspecto);
    }

    public void insertarContactoComercial(int idProspecto, int idVendedor, String medio, String resultado, String observaciones) {
        String sql = """
                INSERT INTO contacto_comercial (id_prospecto, id_vendedor, fecha_hora, medio, resultado, observaciones)
                VALUES (?, ?, NOW(), ?, ?, ?)
                """;
        jdbcTemplate.update(sql, idProspecto, idVendedor, medio, resultado, observaciones);
    }

    // =====================================================================================
    // SESIÓN 3: INVOCACIÓN DE PROCEDIMIENTOS ALMACENADOS, FUNCIONES UDF Y TRIGGERS
    // =====================================================================================

    /**
     * Invoca el procedimiento almacenado sp_reporte_mensual_ventas(p_anio, p_mes) (RF-15, RF-28).
     */
    public List<Map<String, Object>> llamarReporteMensualVentas(Integer anio, Integer mes) {
        int anioParam = (anio != null) ? anio : 0;
        int mesParam = (mes != null) ? mes : 0;
        return jdbcTemplate.queryForList("CALL sp_reporte_mensual_ventas(?, ?)", anioParam, mesParam);
    }

    /**
     * Invoca el procedimiento almacenado sp_reporte_desempeno_asesores() (RF-26, RF-31, Tabla 20).
     */
    public List<Map<String, Object>> llamarReporteDesempenoAsesores() {
        return jdbcTemplate.queryForList("CALL sp_reporte_desempeno_asesores()");
    }

    /**
     * Invoca el procedimiento almacenado sp_reporte_rendimiento_campanas() (RF-16, RF-31, Reporte R-08).
     */
    public List<Map<String, Object>> llamarReporteRendimientoCampanas() {
        return jdbcTemplate.queryForList("CALL sp_reporte_rendimiento_campanas()");
    }

    /**
     * Invoca el procedimiento almacenado sp_actualizar_propuestas_vencidas_y_alertas(OUT, OUT) (RF-11, RF-24).
     */
    public Map<String, Object> llamarActualizarPropuestasVencidasYAlertas() {
        return jdbcTemplate.execute(
                con -> con.prepareCall("{CALL sp_actualizar_propuestas_vencidas_y_alertas(?, ?)}"),
                (CallableStatementCallback<Map<String, Object>>) (CallableStatement cs) -> {
                    cs.registerOutParameter(1, Types.INTEGER);
                    cs.registerOutParameter(2, Types.INTEGER);
                    cs.execute();
                    Map<String, Object> res = new LinkedHashMap<>();
                    res.put("procedimiento", "sp_actualizar_propuestas_vencidas_y_alertas");
                    res.put("propuestasMarcadasVencidas", cs.getInt(1));
                    res.put("nuevasAlertasGeneradas", cs.getInt(2));
                    return res;
                }
        );
    }

    /**
     * Invoca el procedimiento almacenado sp_registrar_propuesta_completa(IN..., OUT...) (RF-09, RF-10).
     */
    public Map<String, Object> llamarRegistrarPropuestaCompleta(
            int idProspecto, int idVendedor, Integer diasVigencia,
            int idProducto, int cantidadLicencias, BigDecimal precioUnitario) {
        return jdbcTemplate.execute(
                con -> con.prepareCall("{CALL sp_registrar_propuesta_completa(?, ?, ?, ?, ?, ?, ?, ?, ?)}"),
                (CallableStatementCallback<Map<String, Object>>) (CallableStatement cs) -> {
                    cs.setInt(1, idProspecto);
                    cs.setInt(2, idVendedor);
                    cs.setInt(3, diasVigencia != null ? diasVigencia : 30);
                    cs.setInt(4, idProducto);
                    cs.setInt(5, cantidadLicencias);
                    if (precioUnitario != null) {
                        cs.setBigDecimal(6, precioUnitario);
                    } else {
                        cs.setNull(6, Types.DECIMAL);
                    }
                    cs.registerOutParameter(7, Types.INTEGER);
                    cs.registerOutParameter(8, Types.DECIMAL);
                    cs.registerOutParameter(9, Types.VARCHAR);
                    cs.execute();

                    Map<String, Object> res = new LinkedHashMap<>();
                    res.put("procedimiento", "sp_registrar_propuesta_completa");
                    res.put("triggerActivado", "trg_detalle_propuesta_after_insert_recalcular_total");
                    res.put("funcionUdfInvocada", "fn_calcular_subtotal_propuesta");
                    res.put("idPropuesta", cs.getInt(7));
                    res.put("valorTotalCalculado", cs.getBigDecimal(8));
                    res.put("mensaje", cs.getString(9));
                    return res;
                }
        );
    }

    /**
     * Consulta las funciones UDF fn_calcular_puntaje_compromiso_prospecto y fn_clasificar_habito_cliente
     * para un prospecto/cliente específico (RF-05, RF-27).
     */
    public Map<String, Object> consultarIndicadoresUdfProspecto(int idProspecto) {
        String sql = """
                SELECT p.id_prospecto,
                       CONCAT(p.nombre, ' ', p.apellido) AS nombre_completo,
                       p.empresa,
                       p.estado,
                       p.puntaje_interes AS puntaje_actual_tabla,
                       fn_calcular_puntaje_compromiso_prospecto(p.id_prospecto) AS puntaje_compromiso_udf,
                       fn_clasificar_habito_cliente(p.id_prospecto) AS clasificacion_habito_udf
                FROM prospecto p
                WHERE p.id_prospecto = ?
                """;
        return jdbcTemplate.queryForMap(sql, idProspecto);
    }

    /**
     * Consulta las funciones UDF fn_calcular_subtotal_propuesta y fn_dias_restantes_vigencia_propuesta
     * para una propuesta comercial específica (RF-10, RF-11).
     */
    public Map<String, Object> consultarIndicadoresUdfPropuesta(int idPropuesta) {
        String sql = """
                SELECT pc.id_propuesta,
                       pc.estado,
                       pc.fecha_envio,
                       pc.fecha_vigencia,
                       pc.valor_total AS valor_registrado_tabla,
                       fn_calcular_subtotal_propuesta(pc.id_propuesta) AS subtotal_calculado_udf,
                       fn_dias_restantes_vigencia_propuesta(pc.id_propuesta) AS dias_restantes_vigencia_udf
                FROM propuesta_comercial pc
                WHERE pc.id_propuesta = ?
                """;
        return jdbcTemplate.queryForMap(sql, idPropuesta);
    }

    /**
     * Consulta la función UDF fn_tasa_conversion_vendedor para un asesor específico (RF-26, RF-31).
     */
    public Map<String, Object> consultarTasaConversionUdfVendedor(int idVendedor) {
        String sql = """
                SELECT v.id_vendedor,
                       CONCAT(v.nombre, ' ', v.apellido) AS vendedor,
                       v.region,
                       fn_tasa_conversion_vendedor(v.id_vendedor) AS tasa_conversion_pct_udf
                FROM vendedor v
                WHERE v.id_vendedor = ?
                """;
        return jdbcTemplate.queryForMap(sql, idVendedor);
    }

    /**
     * Inserta una actividad en visita_web para demostrar en tiempo real la ejecución del trigger
     * trg_visita_web_after_insert_scoring_y_alerta (RF-04, RF-05, RF-24).
     */
    public int insertarVisitaWebProspecto(int idProspecto, String urlVisitada, String tipoActividad, int duracionSegundos) {
        String sql = """
                INSERT INTO visita_web (id_prospecto, id_visitante, fecha_hora, url_visitada, tipo_actividad, duracion_segundos)
                VALUES (?, NULL, NOW(), ?, ?, ?)
                """;
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(con -> {
            PreparedStatement ps = con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            ps.setInt(1, idProspecto);
            ps.setString(2, urlVisitada);
            ps.setString(3, tipoActividad);
            ps.setInt(4, duracionSegundos);
            return ps;
        }, keyHolder);
        return keyHolder.getKey().intValue();
    }
}
