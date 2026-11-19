package com.uniminuto.zimbra.dto;

/**
 * DTO de entrada para registrar un nuevo prospecto y asignarle un asesor inicial (RF-01, RF-03, RF-22).
 */
public record ProspectoRequest(
        String nombre,
        String apellido,
        String correo,
        String telefono,
        String empresa,
        String pais,
        Integer idVendedor,
        Integer idCampana,
        Integer idProductoInteres
) {
}
