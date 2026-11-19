package com.uniminuto.zimbra.dto;

import java.math.BigDecimal;

/**
 * DTO de entrada para ejecutar la transacción ACID de cierre de venta y conversión de prospecto (RF-12, RNF-02).
 */
public record CierreVentaRequest(
        Integer idPropuesta,
        BigDecimal valorFinal,
        String medioPago,
        String observacionesContacto
) {
}
