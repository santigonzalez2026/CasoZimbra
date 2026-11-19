package com.uniminuto.zimbra.dto;

/**
 * DTO de entrada para registrar una actividad en visita_web y disparar el trigger
 * trg_visita_web_after_insert_scoring_y_alerta de LoopFuse OneView (Sesión 3 - RF-04, RF-05, RF-24).
 */
public record VisitaWebRequest(
        Integer idProspecto,
        String urlVisitada,
        String tipoActividad,
        Integer duracionSegundos
) {
}
