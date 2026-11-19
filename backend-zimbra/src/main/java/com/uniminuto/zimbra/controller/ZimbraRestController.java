package com.uniminuto.zimbra.controller;

import com.uniminuto.zimbra.dto.CierreVentaRequest;
import com.uniminuto.zimbra.dto.PropuestaProcedimientoRequest;
import com.uniminuto.zimbra.dto.PropuestaRequest;
import com.uniminuto.zimbra.dto.ProspectoRequest;
import com.uniminuto.zimbra.dto.VisitaWebRequest;
import com.uniminuto.zimbra.repository.ZimbraTransaccionalRepository;
import com.uniminuto.zimbra.service.TransaccionComercialService;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Controlador REST con los endpoints de la Sesión 2 (conexión y transacciones ACID)
 * y de la Sesión 3 (invocación de Procedimientos Almacenados, Funciones UDF y Triggers,
 * consumidos desde el prototipo inicial del Front-end).
 */
@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class ZimbraRestController {

    private final ZimbraTransaccionalRepository repository;
    private final TransaccionComercialService transaccionService;

    public ZimbraRestController(ZimbraTransaccionalRepository repository,
                                TransaccionComercialService transaccionService) {
        this.repository = repository;
        this.transaccionService = transaccionService;
    }

    // =====================================================================================
    // ENDPOINTS SESIÓN 2: CONEXIÓN A BD Y TRANSACCIONES ACID
    // =====================================================================================

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> verificarSaludConexion() {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("estado", "CONECTADO");
        body.put("baseDatos", "zimbra_transaccional (MySQL InnoDB)");
        body.put("fechaHoraServidor", LocalDateTime.now().toString());
        body.put("registrosPorTabla", repository.obtenerConteoTablas());
        return ResponseEntity.ok(body);
    }

    @GetMapping("/vendedores")
    public ResponseEntity<List<Map<String, Object>>> listarVendedores() {
        return ResponseEntity.ok(repository.listarVendedores());
    }

    @GetMapping("/productos")
    public ResponseEntity<List<Map<String, Object>>> listarProductos() {
        return ResponseEntity.ok(repository.listarProductos());
    }

    @GetMapping("/campanas")
    public ResponseEntity<List<Map<String, Object>>> listarCampanas() {
        return ResponseEntity.ok(repository.listarCampanas());
    }

    @GetMapping("/prospectos")
    public ResponseEntity<List<Map<String, Object>>> listarProspectos() {
        return ResponseEntity.ok(repository.listarProspectos());
    }

    @GetMapping("/prospectos/{id}")
    public ResponseEntity<Map<String, Object>> obtenerProspecto(@PathVariable int id) {
        return ResponseEntity.ok(repository.obtenerProspectoPorId(id));
    }

    @PostMapping("/prospectos")
    public ResponseEntity<Map<String, Object>> crearProspecto(@RequestBody ProspectoRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(transaccionService.registrarProspectoConAsignacion(request));
    }

    @GetMapping("/propuestas")
    public ResponseEntity<List<Map<String, Object>>> listarPropuestas() {
        return ResponseEntity.ok(repository.listarPropuestas());
    }

    @PostMapping("/propuestas")
    public ResponseEntity<Map<String, Object>> crearPropuestaConSavepoint(@RequestBody PropuestaRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(transaccionService.crearPropuestaConSavepoint(request));
    }

    @GetMapping("/ventas")
    public ResponseEntity<List<Map<String, Object>>> listarVentas() {
        return ResponseEntity.ok(repository.listarVentas());
    }

    @PostMapping("/ventas/cerrar")
    public ResponseEntity<Map<String, Object>> cerrarVenta(@RequestBody CierreVentaRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(transaccionService.cerrarVentaTransaccional(request));
    }

    @GetMapping("/alertas")
    public ResponseEntity<List<Map<String, Object>>> listarAlertas() {
        return ResponseEntity.ok(repository.listarAlertas());
    }

    @GetMapping("/bitacora-errores")
    public ResponseEntity<List<Map<String, Object>>> listarBitacoraErrores() {
        return ResponseEntity.ok(repository.listarBitacoraErrores());
    }

    // =====================================================================================
    // ENDPOINTS SESIÓN 3: PROCEDIMIENTOS ALMACENADOS, FUNCIONES UDF Y TRIGGERS
    // =====================================================================================

    /**
     * Endpoint S3-1: Llama al procedimiento almacenado sp_reporte_mensual_ventas(anio, mes).
     */
    @GetMapping("/reportes/mensual")
    public ResponseEntity<List<Map<String, Object>>> obtenerReporteMensualVentas(
            @RequestParam(required = false, defaultValue = "2026") Integer anio,
            @RequestParam(required = false, defaultValue = "0") Integer mes) {
        return ResponseEntity.ok(repository.llamarReporteMensualVentas(anio, mes));
    }

    /**
     * Endpoint S3-2: Llama al procedimiento almacenado sp_reporte_desempeno_asesores(),
     * que integra la función UDF fn_tasa_conversion_vendedor.
     */
    @GetMapping("/reportes/desempeno-asesores")
    public ResponseEntity<List<Map<String, Object>>> obtenerReporteDesempenoAsesores() {
        return ResponseEntity.ok(repository.llamarReporteDesempenoAsesores());
    }

    /**
     * Endpoint S3-3: Llama al procedimiento almacenado sp_reporte_rendimiento_campanas().
     */
    @GetMapping("/reportes/rendimiento-campanas")
    public ResponseEntity<List<Map<String, Object>>> obtenerReporteRendimientoCampanas() {
        return ResponseEntity.ok(repository.llamarReporteRendimientoCampanas());
    }

    /**
     * Endpoint S3-4: Llama al procedimiento almacenado sp_actualizar_propuestas_vencidas_y_alertas(OUT, OUT).
     */
    @PostMapping("/automatizacion/verificar-vencimientos")
    public ResponseEntity<Map<String, Object>> ejecutarVerificacionVencimientosYAlertas() {
        return ResponseEntity.ok(repository.llamarActualizarPropuestasVencidasYAlertas());
    }

    /**
     * Endpoint S3-5: Llama al procedimiento almacenado sp_registrar_propuesta_completa(...)
     * y dispara el trigger trg_detalle_propuesta_after_insert_recalcular_total.
     */
    @PostMapping("/propuestas/procedimiento")
    public ResponseEntity<Map<String, Object>> crearPropuestaMedianteProcedimiento(
            @RequestBody PropuestaProcedimientoRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(transaccionService.registrarPropuestaPorProcedimiento(request));
    }

    /**
     * Endpoint S3-6: Invoca las funciones UDF fn_calcular_puntaje_compromiso_prospecto y
     * fn_clasificar_habito_cliente para un prospecto/cliente.
     */
    @GetMapping("/funciones/prospecto/{id}/indicadores")
    public ResponseEntity<Map<String, Object>> consultarFuncionesProspecto(@PathVariable int id) {
        return ResponseEntity.ok(repository.consultarIndicadoresUdfProspecto(id));
    }

    /**
     * Endpoint S3-7: Invoca las funciones UDF fn_calcular_subtotal_propuesta y
     * fn_dias_restantes_vigencia_propuesta para una propuesta comercial.
     */
    @GetMapping("/funciones/propuesta/{id}/indicadores")
    public ResponseEntity<Map<String, Object>> consultarFuncionesPropuesta(@PathVariable int id) {
        return ResponseEntity.ok(repository.consultarIndicadoresUdfPropuesta(id));
    }

    /**
     * Endpoint S3-8: Invoca la función UDF fn_tasa_conversion_vendedor para un vendedor.
     */
    @GetMapping("/funciones/vendedor/{id}/conversion")
    public ResponseEntity<Map<String, Object>> consultarFuncionConversionVendedor(@PathVariable int id) {
        return ResponseEntity.ok(repository.consultarTasaConversionUdfVendedor(id));
    }

    /**
     * Endpoint S3-9: Inserta una actividad en visita_web para disparar el trigger
     * trg_visita_web_after_insert_scoring_y_alerta (actualización automática de scoring y alertas).
     */
    @PostMapping("/visitas-web")
    public ResponseEntity<Map<String, Object>> registrarVisitaWebConTrigger(@RequestBody VisitaWebRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(transaccionService.registrarVisitaWebConTrigger(request));
    }

    /**
     * Manejador de errores SQL / transaccionales que evidencia el ROLLBACK automático
     * ante violaciones de integridad (UNIQUE, CHECK, FOREIGN KEY) o reglas de negocio / Triggers.
     */
    @ExceptionHandler({DataAccessException.class, IllegalStateException.class, IllegalArgumentException.class})
    public ResponseEntity<Map<String, Object>> manejarErrorTransaccional(Exception ex) {
        Map<String, Object> error = new LinkedHashMap<>();
        error.put("transaccion", "ROLLBACK EJECUTADO AUTOMÁTICAMENTE");
        error.put("fechaEvento", LocalDateTime.now().toString());
        error.put("tipoExcepcion", ex.getClass().getSimpleName());
        error.put("detalleError", ex.getMessage());
        return ResponseEntity.status(HttpStatus.CONFLICT).body(error);
    }
}
