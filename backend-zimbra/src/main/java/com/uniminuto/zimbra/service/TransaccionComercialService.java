package com.uniminuto.zimbra.service;

import com.uniminuto.zimbra.dto.CierreVentaRequest;
import com.uniminuto.zimbra.dto.PropuestaProcedimientoRequest;
import com.uniminuto.zimbra.dto.PropuestaRequest;
import com.uniminuto.zimbra.dto.ProspectoRequest;
import com.uniminuto.zimbra.dto.VisitaWebRequest;
import com.uniminuto.zimbra.repository.ZimbraTransaccionalRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.interceptor.TransactionAspectSupport;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Servicio de lógica transaccional ACID (Sesión 2) y automatización con Triggers,
 * Procedimientos Almacenados y Funciones UDF (Sesión 3) para los procesos de Zimbra.
 */
@Service
public class TransaccionComercialService {

    private final ZimbraTransaccionalRepository repository;

    public TransaccionComercialService(ZimbraTransaccionalRepository repository) {
        this.repository = repository;
    }

    /**
     * Transacción ACID 1: Registra un nuevo prospecto, crea su historial en asignacion_asesor
     * y genera la alerta inicial para el asesor asignado (RF-01, RF-03, RF-22, RF-24).
     */
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> registrarProspectoConAsignacion(ProspectoRequest req) {
        int idProspecto = repository.insertarProspecto(
                req.nombre(), req.apellido(), req.correo(), req.telefono(),
                req.empresa(), req.pais(), req.idVendedor(), req.idCampana(), req.idProductoInteres()
        );

        if (req.idVendedor() != null) {
            repository.insertarAsignacionAsesor(idProspecto, req.idVendedor(), "Vigente");
            repository.insertarAlerta(idProspecto, req.idVendedor(), "Sin contacto 24 h");
        }

        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("transaccion", "COMMIT EXITOSO");
        respuesta.put("idProspecto", idProspecto);
        respuesta.put("mensaje", "Prospecto registrado con asignación de asesor y alerta inicial en una sola transacción ACID.");
        return respuesta;
    }

    /**
     * Transacción ACID 2 con SAVEPOINT: Crea la cabecera de propuesta comercial, inserta las líneas
     * obligatorias, crea un SAVEPOINT antes de insertar las líneas opcionales y, si el total supera
     * el presupuesto máximo del cliente, ejecuta ROLLBACK TO SAVEPOINT conservando la propuesta base.
     */
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> crearPropuestaConSavepoint(PropuestaRequest req) {
        int idPropuesta = repository.insertarCabeceraPropuesta(
                req.idProspecto(), req.idVendedor(), req.fechaVigencia()
        );

        // 1. Insertar líneas principales (no opcionales)
        for (PropuestaRequest.LineaDetalleRequest linea : req.detalles()) {
            if (!linea.opcional()) {
                repository.insertarDetallePropuesta(
                        idPropuesta, linea.idProducto(), linea.cantidadLicencias(), linea.precioUnitario()
                );
            }
        }

        // 2. Crear SAVEPOINT después de registrar las líneas base
        TransactionStatus status = TransactionAspectSupport.currentTransactionStatus();
        Object savepointLineasBase = status.createSavepoint();
        boolean rollbackParcialAplicado = false;

        // 3. Insertar líneas opcionales
        for (PropuestaRequest.LineaDetalleRequest linea : req.detalles()) {
            if (linea.opcional()) {
                repository.insertarDetallePropuesta(
                        idPropuesta, linea.idProducto(), linea.cantidadLicencias(), linea.precioUnitario()
                );
            }
        }

        BigDecimal totalCalculado = repository.recalcularValorTotalPropuesta(idPropuesta);

        // 4. Si supera el presupuesto máximo del cliente, revertir al SAVEPOINT (solo descarta las opcionales)
        if (req.presupuestoMaximoCliente() != null
                && totalCalculado.compareTo(req.presupuestoMaximoCliente()) > 0) {
            status.rollbackToSavepoint(savepointLineasBase);
            rollbackParcialAplicado = true;
            totalCalculado = repository.recalcularValorTotalPropuesta(idPropuesta);
        }
        status.releaseSavepoint(savepointLineasBase);

        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("transaccion", "COMMIT CON CONTROL DE SAVEPOINT");
        respuesta.put("idPropuesta", idPropuesta);
        respuesta.put("valorTotalDefinitivo", totalCalculado);
        respuesta.put("rollbackParcialSavepoint", rollbackParcialAplicado);
        respuesta.put("mensaje", rollbackParcialAplicado
                ? "El total con opcionales superó el presupuesto; se ejecutó ROLLBACK TO SAVEPOINT conservando las líneas base."
                : "Propuesta comercial y todas sus líneas registradas exitosamente.");
        return respuesta;
    }

    /**
     * Transacción ACID 3: Cierre comercial completo (Proceso 7 - RF-12 y RNF-02).
     * En la Sesión 3, al insertar la venta también se dispara el trigger
     * trg_venta_after_insert_actualizar_propuesta en MySQL.
     */
    @Transactional(isolation = Isolation.REPEATABLE_READ, rollbackFor = Exception.class)
    public Map<String, Object> cerrarVentaTransaccional(CierreVentaRequest req) {
        Map<String, Object> propuesta = repository.obtenerPropuestaParaBloqueo(req.idPropuesta());
        String estadoActual = (String) propuesta.get("estado");

        if ("Rechazada".equalsIgnoreCase(estadoActual) || "Vencida".equalsIgnoreCase(estadoActual)) {
            throw new IllegalStateException(
                    "No se puede registrar una venta para la propuesta #" + req.idPropuesta()
                            + " porque se encuentra en estado '" + estadoActual + "'. Se ejecuta ROLLBACK."
            );
        }

        int idProspecto = ((Number) propuesta.get("id_prospecto")).intValue();
        int idVendedor = ((Number) propuesta.get("id_vendedor")).intValue();
        BigDecimal valorFinal = req.valorFinal() != null
                ? req.valorFinal()
                : (BigDecimal) propuesta.get("valor_total");

        // Paso 1: Actualizar propuesta a 'Aceptada'
        repository.actualizarEstadoPropuesta(req.idPropuesta(), "Aceptada");

        // Paso 2: Insertar la venta con vencimiento de licencia a 1 año
        int idVenta = repository.insertarVenta(req.idPropuesta(), valorFinal, req.medioPago());

        // Paso 3: Convertir el prospecto en cliente ('Convertido')
        repository.actualizarProspectoConvertido(idProspecto);

        // Paso 4: Marcar alertas pendientes del prospecto como atendidas
        repository.marcarAlertasAtendidas(idProspecto);

        // Paso 5: Registrar el contacto comercial de cierre
        repository.insertarContactoComercial(
                idProspecto, idVendedor, "Llamada", "Cierre de venta exitoso",
                req.observacionesContacto() != null
                        ? req.observacionesContacto()
                        : "Venta cerrada desde el Back-end Spring Boot mediante transacción ACID."
        );

        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("transaccion", "COMMIT EXITOSO (ACID + TRIGGER)");
        respuesta.put("idVenta", idVenta);
        respuesta.put("idPropuesta", req.idPropuesta());
        respuesta.put("idProspectoConvertido", idProspecto);
        respuesta.put("valorFinal", valorFinal);
        respuesta.put("mensaje", "Propuesta aceptada, venta creada y prospecto actualizado a Convertido en una sola transacción.");
        return respuesta;
    }

    /**
     * Sesión 3: Registra una propuesta comercial invocando directamente el procedimiento almacenado
     * sp_registrar_propuesta_completa, el cual dispara trg_detalle_propuesta_after_insert_recalcular_total
     * y utiliza la función UDF fn_calcular_subtotal_propuesta.
     */
    public Map<String, Object> registrarPropuestaPorProcedimiento(PropuestaProcedimientoRequest req) {
        return repository.llamarRegistrarPropuestaCompleta(
                req.idProspecto(),
                req.idVendedor(),
                req.diasVigencia(),
                req.idProducto(),
                req.cantidadLicencias(),
                req.precioUnitario()
        );
    }

    /**
     * Sesión 3: Registra una actividad web de un prospecto y retorna el estado actualizado
     * automáticamente por el trigger trg_visita_web_after_insert_scoring_y_alerta.
     */
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> registrarVisitaWebConTrigger(VisitaWebRequest req) {
        int idVisita = repository.insertarVisitaWebProspecto(
                req.idProspecto(),
                req.urlVisitada() != null && !req.urlVisitada().isBlank()
                        ? req.urlVisitada()
                        : "https://www.zimbra.com/downloads/zcs-trial-60d",
                req.tipoActividad() != null && !req.tipoActividad().isBlank()
                        ? req.tipoActividad()
                        : "Descarga de prueba",
                req.duracionSegundos() != null ? req.duracionSegundos() : 180
        );

        Map<String, Object> prospectoActualizado = repository.obtenerProspectoPorId(req.idProspecto());

        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("idVisita", idVisita);
        respuesta.put("triggerEjecutado", "trg_visita_web_after_insert_scoring_y_alerta");
        respuesta.put("prospectoActualizado", prospectoActualizado);
        respuesta.put("mensaje", "Actividad web registrada; el Trigger actualizó automáticamente el puntaje de interés, estado y alertas.");
        return respuesta;
    }
}
