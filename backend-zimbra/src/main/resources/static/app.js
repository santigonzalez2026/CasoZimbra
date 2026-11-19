/**
 * Lógica del Prototipo Inicial del Front-end - Caso Zimbra y LoopFuse OneView (Sesión 3)
 * Conecta los formularios de Prospectos, Propuestas, Triggers, Procedimientos Almacenados
 * y Funciones UDF con el Back-end Spring Boot en http://localhost:8080/api.
 */

const API_BASE = window.location.protocol === "file:"
    ? "http://localhost:8080/api"
    : "/api";

let catalogoProductos = [];
let modoDemoLocal = false;

// Datos de respaldo coherentes con Sesion_2_Zimbra_BD_y_Transacciones.sql si el servidor no está encendido
const DEMO_VENDEDORES = [
    { id_vendedor: 1, nombre: "Carlos", apellido: "Mendoza", region: "Andina" },
    { id_vendedor: 2, nombre: "Laura", apellido: "Gómez", region: "Andina" },
    { id_vendedor: 3, nombre: "Andrés", apellido: "Villamizar", region: "Caribe" },
    { id_vendedor: 4, nombre: "Diana", apellido: "Patiño", region: "Pacífico" },
    { id_vendedor: 5, nombre: "Jorge", apellido: "Castillo", region: "Cono Sur" }
];

const DEMO_CAMPANAS = [
    { id_campana: 1, nombre: "Lanzamiento ZCS 10 Cloud", canal: "Correo" },
    { id_campana: 2, nombre: "Descarga Prueba 60 Días LATAM", canal: "Web" },
    { id_campana: 3, nombre: "Webinar Migración Exchange a Zimbra", canal: "Evento" },
    { id_campana: 4, nombre: "Campaña Renovación Licencias Anuales", canal: "Correo" }
];

const DEMO_PRODUCTOS = [
    { id_producto: 9, nombre: "ZCS Edición Estándar", version: "9", tipo_licencia: "Comercial", precio_unitario: 32.00 },
    { id_producto: 10, nombre: "ZCS Edición Estándar", version: "10", tipo_licencia: "Comercial", precio_unitario: 35.00 },
    { id_producto: 19, nombre: "ZCS Edición Profesional", version: "9", tipo_licencia: "Comercial", precio_unitario: 48.00 },
    { id_producto: 20, nombre: "ZCS Edición Profesional", version: "10", tipo_licencia: "Comercial", precio_unitario: 52.00 },
    { id_producto: 26, nombre: "Zimbra Archiving & Discovery", version: "10", tipo_licencia: "Comercial", precio_unitario: 20.00 }
];

let demoProspectos = [
    { id_prospecto: 1, nombre: "Ricardo", apellido: "Vargas", correo: "rvargas@andeslogistica.co", empresa: "Andes Logística S.A.S.", asesor_asignado: "Carlos Mendoza", estado: "Convertido", puntaje_interes: 100 },
    { id_prospecto: 2, nombre: "Patricia", apellido: "Lozano", correo: "plozano@tecnoandina.com", empresa: "Tecnoandina S.A.", asesor_asignado: "Laura Gómez", estado: "Convertido", puntaje_interes: 100 },
    { id_prospecto: 3, nombre: "Hernán", apellido: "Mejía", correo: "hmejia@clinicasanrafael.org", empresa: "Clínica San Rafael", asesor_asignado: "Andrés Villamizar", estado: "Convertido", puntaje_interes: 100 },
    { id_prospecto: 26, nombre: "Camila", apellido: "Ospina", correo: "cospina@agroexport.co", empresa: "AgroExport Colombia", asesor_asignado: "Carlos Mendoza", estado: "En seguimiento", puntaje_interes: 85 },
    { id_prospecto: 27, nombre: "Esteban", apellido: "Duarte", correo: "eduarte@finanzasdelnorte.mx", empresa: "Finanzas del Norte", asesor_asignado: "Laura Gómez", estado: "En seguimiento", puntaje_interes: 80 }
];

let demoPropuestas = [
    { id_propuesta: 1, prospecto: "Andes Logística S.A.S.", vendedor: "Carlos Mendoza", fecha_vigencia: "2026-10-15", valor_total: 1500.00, estado: "Aceptada" },
    { id_propuesta: 2, prospecto: "Tecnoandina S.A.", vendedor: "Laura Gómez", fecha_vigencia: "2026-09-01", valor_total: 1800.00, estado: "Aceptada" },
    { id_propuesta: 34, prospecto: "Logística Lima Express", vendedor: "Diana Patiño", fecha_vigencia: "2026-11-25", valor_total: 1750.00, estado: "Enviada" },
    { id_propuesta: 35, prospecto: "AgroExport Colombia", vendedor: "Carlos Mendoza", fecha_vigencia: "2026-12-05", valor_total: 2450.00, estado: "En negociación" }
];

function cambiarTab(tabId) {
    document.querySelectorAll(".tab-btn").forEach(btn => {
        btn.classList.toggle("active", btn.dataset.tab === tabId);
    });
    document.querySelectorAll(".tab-panel").forEach(panel => {
        panel.classList.toggle("active", panel.id === tabId);
    });
}

function mostrarAlerta(mensaje, exito = true) {
    const box = document.getElementById("alertaGlobal");
    box.textContent = mensaje;
    box.className = "alert-box " + (exito ? "alert-success" : "alert-error");
    setTimeout(() => {
        box.classList.add("hidden");
    }, 7000);
}

function formatearMoneda(valor) {
    const num = Number(valor || 0);
    return "USD $" + num.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function claseEstado(estado) {
    if (!estado) return "pill-blue";
    const e = estado.toLowerCase();
    if (e.includes("convertido") || e.includes("aceptada") || e.includes("facturada")) return "pill-green";
    if (e.includes("calificado") || e.includes("seguimiento") || e.includes("negociación") || e.includes("enviada")) return "pill-blue";
    if (e.includes("nuevo")) return "pill-amber";
    return "pill-red";
}

async function inicializarPortal() {
    const badge = document.getElementById("badgeConexion");
    try {
        const resp = await fetch(`${API_BASE}/health`);
        if (!resp.ok) throw new Error("HTTP " + resp.status);
        const data = await resp.json();
        modoDemoLocal = false;
        badge.textContent = `CONECTADO A MYSQL (${data.baseDatos})`;
        badge.className = "status-pill status-online";

        await Promise.all([
            cargarCatalogosBackend(),
            cargarProspectosBackend(),
            cargarPropuestasBackend()
        ]);
        const params = new URLSearchParams(window.location.search);
        const tabParam = params.get("tab");
        if (tabParam && document.getElementById(tabParam)) {
            cambiarTab(tabParam);
        }
        const repParam = params.get("rep");
        if (repParam === "asesores") {
            await cargarReporteDesempeno();
        } else if (repParam === "campanas") {
            await cargarReporteCampanas();
        } else {
            await cargarReporteMensual();
        }
        if (params.get("udf") === "prospecto") {
            await consultarUdfProspecto();
        } else if (params.get("udf") === "propuesta") {
            await consultarUdfPropuesta();
        }
    } catch (err) {
        modoDemoLocal = true;
        badge.textContent = "MODO PROTOTIPO LOCAL (Inicie Spring Boot en :8080 para BD en vivo)";
        badge.className = "status-pill status-offline";
        cargarDatosDemoLocales();
    }
}

async function cargarCatalogosBackend() {
    const [vendResp, campResp, prodResp] = await Promise.all([
        fetch(`${API_BASE}/vendedores`),
        fetch(`${API_BASE}/campanas`),
        fetch(`${API_BASE}/productos`)
    ]);
    const vendedores = await vendResp.json();
    const campanas = await campResp.json();
    catalogoProductos = await prodResp.json();

    poblarSelectVendedores(vendedores);
    poblarSelectCampanas(campanas);
    poblarSelectProductos(catalogoProductos);
}

function cargarDatosDemoLocales() {
    catalogoProductos = DEMO_PRODUCTOS;
    poblarSelectVendedores(DEMO_VENDEDORES);
    poblarSelectCampanas(DEMO_CAMPANAS);
    poblarSelectProductos(DEMO_PRODUCTOS);
    renderizarProspectos(demoProspectos);
    renderizarPropuestas(demoPropuestas);
    cargarReporteMensual();
}

function poblarSelectVendedores(vendedores) {
    const html = vendedores.map(v =>
        `<option value="${v.id_vendedor}">${v.id_vendedor} - ${v.nombre} ${v.apellido} (${v.region || 'LATAM'})</option>`
    ).join("");
    document.getElementById("prospVendedor").innerHTML = html;
    document.getElementById("propVendedor").innerHTML = html;
}

function poblarSelectCampanas(campanas) {
    document.getElementById("prospCampana").innerHTML = campanas.map(c =>
        `<option value="${c.id_campana}">${c.id_campana} - ${c.nombre} [${c.canal}]</option>`
    ).join("");
}

function poblarSelectProductos(productos) {
    const html = productos.map(p =>
        `<option value="${p.id_producto}" data-precio="${p.precio_unitario}">${p.nombre} v${p.version} (${p.tipo_licencia}) - USD $${p.precio_unitario}</option>`
    ).join("");
    document.getElementById("prospProducto").innerHTML = html;
    document.getElementById("propProducto").innerHTML = html;
    actualizarPrecioSugerido();
}

function actualizarPrecioSugerido() {
    const select = document.getElementById("propProducto");
    const opt = select.options[select.selectedIndex];
    if (opt && opt.dataset.precio) {
        document.getElementById("propPrecio").value = Number(opt.dataset.precio).toFixed(2);
        recalcularVistaPreviaPropuesta();
    }
}

function recalcularVistaPreviaPropuesta() {
    const cant = Number(document.getElementById("propCantidad").value || 0);
    const precio = Number(document.getElementById("propPrecio").value || 0);
    document.getElementById("propTotalPreview").textContent = formatearMoneda(cant * precio);
}

async function cargarProspectosBackend() {
    const resp = await fetch(`${API_BASE}/prospectos`);
    const lista = await resp.json();
    renderizarProspectos(lista);
}

function renderizarProspectos(lista) {
    document.getElementById("contadorProspectos").textContent = `${lista.length} prospectos`;
    const tbody = document.getElementById("tablaProspectosBody");
    tbody.innerHTML = lista.slice(0, 25).map(p => `
        <tr>
            <td><strong>#${p.id_prospecto}</strong></td>
            <td><strong>${p.empresa || '-'}</strong><br><small>${p.nombre} ${p.apellido}</small></td>
            <td>${p.correo}</td>
            <td>${p.asesor_asignado || 'Sin asignar'}</td>
            <td><span class="pill ${claseEstado(p.estado)}">${p.estado}</span></td>
            <td><strong>${p.puntaje_interes}</strong> / 100</td>
        </tr>
    `).join("");

    const optsProspecto = lista.map(p =>
        `<option value="${p.id_prospecto}">#${p.id_prospecto} - ${p.empresa || (p.nombre + ' ' + p.apellido)} (${p.estado})</option>`
    ).join("");
    document.getElementById("propProspecto").innerHTML = optsProspecto;
    document.getElementById("visitaProspecto").innerHTML = optsProspecto;
}

async function cargarPropuestasBackend() {
    const resp = await fetch(`${API_BASE}/propuestas`);
    const lista = await resp.json();
    renderizarPropuestas(lista);
}

function renderizarPropuestas(lista) {
    document.getElementById("contadorPropuestas").textContent = `${lista.length} propuestas`;
    const tbody = document.getElementById("tablaPropuestasBody");
    tbody.innerHTML = lista.slice(0, 25).map(pc => `
        <tr>
            <td><strong>#${pc.id_propuesta}</strong></td>
            <td>${pc.prospecto}</td>
            <td>${pc.vendedor}</td>
            <td>${pc.fecha_vigencia}</td>
            <td><strong>${formatearMoneda(pc.valor_total)}</strong></td>
            <td><span class="pill ${claseEstado(pc.estado)}">${pc.estado}</span></td>
        </tr>
    `).join("");
}

async function registrarProspecto(event) {
    event.preventDefault();
    const payload = {
        nombre: document.getElementById("prospNombre").value.trim(),
        apellido: document.getElementById("prospApellido").value.trim(),
        correo: document.getElementById("prospCorreo").value.trim(),
        telefono: document.getElementById("prospTelefono").value.trim(),
        empresa: document.getElementById("prospEmpresa").value.trim(),
        pais: document.getElementById("prospPais").value,
        idVendedor: Number(document.getElementById("prospVendedor").value),
        idCampana: Number(document.getElementById("prospCampana").value),
        idProductoInteres: Number(document.getElementById("prospProducto").value)
    };

    if (modoDemoLocal) {
        const nuevoId = demoProspectos.length + 31;
        demoProspectos.unshift({
            id_prospecto: nuevoId,
            nombre: payload.nombre,
            apellido: payload.apellido,
            correo: payload.correo,
            empresa: payload.empresa,
            asesor_asignado: "Carlos Mendoza",
            estado: "Nuevo",
            puntaje_interes: 30
        });
        renderizarProspectos(demoProspectos);
        document.getElementById("formProspecto").reset();
        mostrarAlerta(`COMMIT EXITOSO: Prospecto #${nuevoId} (${payload.empresa}) registrado con asignación y alerta inicial.`);
        return;
    }

    try {
        const resp = await fetch(`${API_BASE}/prospectos`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.detalleError || "Error en la transacción");
        mostrarAlerta(`${data.transaccion}: ${data.mensaje} (ID #${data.idProspecto})`);
        document.getElementById("formProspecto").reset();
        await cargarProspectosBackend();
    } catch (err) {
        mostrarAlerta(`Error al registrar prospecto: ${err.message}`, false);
    }
}

async function registrarPropuesta(event) {
    event.preventDefault();
    const payload = {
        idProspecto: Number(document.getElementById("propProspecto").value),
        idVendedor: Number(document.getElementById("propVendedor").value),
        diasVigencia: Number(document.getElementById("propVigencia").value),
        idProducto: Number(document.getElementById("propProducto").value),
        cantidadLicencias: Number(document.getElementById("propCantidad").value),
        precioUnitario: Number(document.getElementById("propPrecio").value)
    };

    if (modoDemoLocal) {
        const nuevoId = demoPropuestas.length + 40;
        const total = payload.cantidadLicencias * payload.precioUnitario;
        demoPropuestas.unshift({
            id_propuesta: nuevoId,
            prospecto: `Prospecto #${payload.idProspecto}`,
            vendedor: `Asesor #${payload.idVendedor}`,
            fecha_vigencia: "2026-12-07",
            valor_total: total,
            estado: "Enviada"
        });
        renderizarPropuestas(demoPropuestas);
        mostrarAlerta(`OK: Procedimiento sp_registrar_propuesta_completa ejecutado. Propuesta #${nuevoId} creada con total ${formatearMoneda(total)}.`);
        return;
    }

    try {
        const resp = await fetch(`${API_BASE}/propuestas/procedimiento`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.detalleError || "Error en el procedimiento almacenado");
        mostrarAlerta(`${data.mensaje} [Trigger: ${data.triggerActivado}]`);
        await Promise.all([cargarPropuestasBackend(), cargarProspectosBackend()]);
    } catch (err) {
        mostrarAlerta(`Error al generar propuesta: ${err.message}`, false);
    }
}

async function cerrarVentaPropuesta(event) {
    event.preventDefault();
    const valorInput = document.getElementById("ventaValorFinal").value;
    const payload = {
        idPropuesta: Number(document.getElementById("ventaIdPropuesta").value),
        valorFinal: valorInput ? Number(valorInput) : null,
        medioPago: document.getElementById("ventaMedioPago").value,
        observacionesContacto: "Venta cerrada desde el prototipo Front-end de la Sesión 3."
    };

    if (modoDemoLocal) {
        mostrarAlerta(`COMMIT EXITOSO: Propuesta #${payload.idPropuesta} actualizada a 'Aceptada' y prospecto a 'Convertido' por Trigger.`);
        return;
    }

    try {
        const resp = await fetch(`${API_BASE}/ventas/cerrar`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.detalleError || "No se pudo cerrar la venta");
        mostrarAlerta(`${data.transaccion}: Venta #${data.idVenta} registrada para la propuesta #${data.idPropuesta}.`);
        await Promise.all([cargarPropuestasBackend(), cargarProspectosBackend()]);
    } catch (err) {
        mostrarAlerta(`ROLLBACK ejecutado: ${err.message}`, false);
    }
}

async function simularVisitaWebTrigger(event) {
    event.preventDefault();
    const payload = {
        idProspecto: Number(document.getElementById("visitaProspecto").value),
        tipoActividad: document.getElementById("visitaTipo").value,
        urlVisitada: "https://www.zimbra.com/downloads/zcs-enterprise",
        duracionSegundos: 210
    };

    if (modoDemoLocal) {
        mostrarAlerta(`Trigger trg_visita_web_after_insert_scoring_y_alerta ejecutado para prospecto #${payload.idProspecto} (${payload.tipoActividad}).`);
        return;
    }

    try {
        const resp = await fetch(`${API_BASE}/visitas-web`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
        });
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.detalleError || "Error al insertar visita web");
        const p = data.prospectoActualizado;
        mostrarAlerta(`Trigger ejecutado: Prospecto #${p.id_prospecto} ahora tiene estado '${p.estado}' y puntaje ${p.puntaje_interes}/100.`);
        await cargarProspectosBackend();
    } catch (err) {
        mostrarAlerta(`Error al disparar trigger: ${err.message}`, false);
    }
}

async function consultarUdfProspecto() {
    const id = Number(document.getElementById("udfIdProspecto").value || 1);
    const box = document.getElementById("resultadoUdfBox");
    if (modoDemoLocal) {
        box.textContent = JSON.stringify({
            id_prospecto: id,
            nombre_completo: "Ricardo Vargas",
            empresa: "Andes Logística S.A.S.",
            estado: "Convertido",
            fn_calcular_puntaje_compromiso_prospecto: 100,
            fn_clasificar_habito_cliente: "Frecuente"
        }, null, 2);
        return;
    }
    try {
        const resp = await fetch(`${API_BASE}/funciones/prospecto/${id}/indicadores`);
        const data = await resp.json();
        box.textContent = JSON.stringify(data, null, 2);
    } catch (err) {
        box.textContent = "Error al consultar funciones UDF: " + err.message;
    }
}

async function consultarUdfPropuesta() {
    const id = Number(document.getElementById("udfIdPropuesta").value || 1);
    const box = document.getElementById("resultadoUdfBox");
    if (modoDemoLocal) {
        box.textContent = JSON.stringify({
            id_propuesta: id,
            estado: "Aceptada",
            fn_calcular_subtotal_propuesta: 1500.00,
            fn_dias_restantes_vigencia_propuesta: 23
        }, null, 2);
        return;
    }
    try {
        const resp = await fetch(`${API_BASE}/funciones/propuesta/${id}/indicadores`);
        const data = await resp.json();
        box.textContent = JSON.stringify(data, null, 2);
    } catch (err) {
        box.textContent = "Error al consultar funciones UDF: " + err.message;
    }
}

async function cargarReporteMensual() {
    const anio = Number(document.getElementById("repAnio").value || 2026);
    const mes = Number(document.getElementById("repMes").value || 0);
    document.getElementById("tituloTablaReporte").textContent =
        `Resultado de Procedimiento Almacenado: CALL sp_reporte_mensual_ventas(${anio}, ${mes})`;

    if (modoDemoLocal) {
        renderizarTablaDinamica([
            { periodo: "2026-10", vendedor: "Carlos Mendoza", region: "Andina", producto: "ZCS Edición Estándar v8", campana_marketing: "Lanzamiento ZCS 10 Cloud", total_ventas: 2, licencias_vendidas: 65, ingresos_detalle: 9000.00, ticket_promedio_venta: 1500.00 },
            { periodo: "2026-09", vendedor: "Laura Gómez", region: "Andina", producto: "ZCS Edición Profesional v9", campana_marketing: "Descarga Prueba 60 Días LATAM", total_ventas: 2, licencias_vendidas: 100, ingresos_detalle: 7200.00, ticket_promedio_venta: 1800.00 },
            { periodo: "2026-10", vendedor: "Andrés Villamizar", region: "Caribe", producto: "ZCS Edición Estándar v8", campana_marketing: "Webinar Migración Exchange", total_ventas: 1, licencias_vendidas: 30, ingresos_detalle: 5400.00, ticket_promedio_venta: 1800.00 }
        ]);
        return;
    }

    try {
        const resp = await fetch(`${API_BASE}/reportes/mensual?anio=${anio}&mes=${mes}`);
        const filas = await resp.json();
        renderizarTablaDinamica(filas);
    } catch (err) {
        mostrarAlerta("Error al invocar sp_reporte_mensual_ventas: " + err.message, false);
    }
}

async function cargarReporteDesempeno() {
    document.getElementById("tituloTablaReporte").textContent =
        "Resultado de Procedimiento Almacenado: CALL sp_reporte_desempeno_asesores() + UDF fn_tasa_conversion_vendedor";

    if (modoDemoLocal) {
        renderizarTablaDinamica([
            { id_vendedor: 1, asesor: "Carlos Mendoza", region: "Andina", prospectos_asignados: 2, prospectos_contactados: 2, propuestas_generadas: 2, ventas_concretadas: 2, valor_total_vendido: 9000.00, tasa_conversion_pct: 100.00, dias_promedio_cierre: 18.5 },
            { id_vendedor: 2, asesor: "Laura Gómez", region: "Andina", prospectos_asignados: 2, prospectos_contactados: 2, propuestas_generadas: 2, ventas_concretadas: 2, valor_total_vendido: 7200.00, tasa_conversion_pct: 100.00, dias_promedio_cierre: 21.0 }
        ]);
        return;
    }

    try {
        const resp = await fetch(`${API_BASE}/reportes/desempeno-asesores`);
        const filas = await resp.json();
        renderizarTablaDinamica(filas);
    } catch (err) {
        mostrarAlerta("Error al invocar sp_reporte_desempeno_asesores: " + err.message, false);
    }
}

async function cargarReporteCampanas() {
    document.getElementById("tituloTablaReporte").textContent =
        "Resultado de Procedimiento Almacenado: CALL sp_reporte_rendimiento_campanas()";

    if (modoDemoLocal) {
        renderizarTablaDinamica([
            { id_campana: 1, campana: "Lanzamiento ZCS 10 Cloud", canal: "Correo", estado: "Activa", presupuesto: 4500.00, prospectos_generados: 4, ventas_concretadas: 2, valor_vendido: 9000.00, tasa_conversion_pct: 50.00, costo_por_venta: 2250.00 },
            { id_campana: 2, campana: "Descarga Prueba 60 Días LATAM", canal: "Web", estado: "Activa", presupuesto: 3800.00, prospectos_generados: 3, ventas_concretadas: 2, valor_vendido: 7200.00, tasa_conversion_pct: 66.67, costo_por_venta: 1900.00 }
        ]);
        return;
    }

    try {
        const resp = await fetch(`${API_BASE}/reportes/rendimiento-campanas`);
        const filas = await resp.json();
        renderizarTablaDinamica(filas);
    } catch (err) {
        mostrarAlerta("Error al invocar sp_reporte_rendimiento_campanas: " + err.message, false);
    }
}

async function ejecutarBatchVencimientos() {
    if (modoDemoLocal) {
        mostrarAlerta("Procedimiento sp_actualizar_propuestas_vencidas_y_alertas ejecutado: 1 propuesta vencida actualizada y 3 alertas creadas.");
        return;
    }
    try {
        const resp = await fetch(`${API_BASE}/automatizacion/verificar-vencimientos`, { method: "POST" });
        const data = await resp.json();
        mostrarAlerta(`Procedimiento ${data.procedimiento} ejecutado: ${data.propuestasMarcadasVencidas} propuestas marcadas vencidas y ${data.nuevasAlertasGeneradas} alertas nuevas.`);
        await cargarPropuestasBackend();
    } catch (err) {
        mostrarAlerta("Error al ejecutar verificación de vencimientos: " + err.message, false);
    }
}

function renderizarTablaDinamica(filas) {
    const thead = document.getElementById("tablaReporteHead");
    const tbody = document.getElementById("tablaReporteBody");
    document.getElementById("contadorReporte").textContent = `${filas ? filas.length : 0} filas`;

    if (!filas || filas.length === 0) {
        thead.innerHTML = "";
        tbody.innerHTML = `<tr><td class="empty-cell">El procedimiento almacenado no retornó registros para los filtros indicados.</td></tr>`;
        return;
    }

    const columnas = Object.keys(filas[0]);
    thead.innerHTML = `<tr>${columnas.map(c => `<th>${c.replace(/_/g, " ").toUpperCase()}</th>`).join("")}</tr>`;
    tbody.innerHTML = filas.map(fila => `
        <tr>
            ${columnas.map(c => `<td>${fila[c] !== null && fila[c] !== undefined ? fila[c] : "-"}</td>`).join("")}
        </tr>
    `).join("");
}

window.addEventListener("DOMContentLoaded", inicializarPortal);
