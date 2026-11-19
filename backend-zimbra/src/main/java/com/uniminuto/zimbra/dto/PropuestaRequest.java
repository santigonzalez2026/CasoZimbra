package com.uniminuto.zimbra.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * DTO para crear una propuesta comercial con sus líneas de detalle y límite presupuestal opcional
 * para demostrar el uso de SAVEPOINT (RF-09, RF-10).
 */
public record PropuestaRequest(
        Integer idProspecto,
        Integer idVendedor,
        LocalDate fechaVigencia,
        BigDecimal presupuestoMaximoCliente,
        List<LineaDetalleRequest> detalles
) {
    public record LineaDetalleRequest(
            Integer idProducto,
            Integer cantidadLicencias,
            BigDecimal precioUnitario,
            boolean opcional
    ) {
    }
}
