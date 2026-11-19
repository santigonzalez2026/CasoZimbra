package com.uniminuto.zimbra.dto;

import java.math.BigDecimal;

/**
 * DTO de entrada para registrar una propuesta comercial invocando el procedimiento almacenado
 * sp_registrar_propuesta_completa y el trigger de recálculo automático (Sesión 3 - RF-09, RF-10).
 */
public record PropuestaProcedimientoRequest(
        Integer idProspecto,
        Integer idVendedor,
        Integer diasVigencia,
        Integer idProducto,
        Integer cantidadLicencias,
        BigDecimal precioUnitario
) {
}
