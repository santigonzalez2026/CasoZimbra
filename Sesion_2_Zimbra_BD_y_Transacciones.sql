-- =====================================================================================
-- CORPORACIÓN UNIVERSITARIA MINUTO DE DIOS - UNIMINUTO
-- Curso: Sistemas Transaccionales de Bases de Datos
-- Caso de Estudio: Zimbra y LoopFuse OneView
-- Entregable: Sesión 2 - Base de datos, datos simulados, transacciones ACID y recuperación
-- Autores:
--   Maria Fernanda Chacón Criales - ID 1103928
--   Sergio Alberto Quiroga Gomez  - ID 798170
--   Santiago Gonzalez Gamboa      - ID 1017544
-- Docente: Ladi Paola Ballen Carrasco
-- Motor: MySQL 8.0+ / MariaDB 10.5+ (Motor transaccional InnoDB)
-- =====================================================================================

DROP DATABASE IF EXISTS zimbra_transaccional;
CREATE DATABASE zimbra_transaccional
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE zimbra_transaccional;

-- =====================================================================================
-- PARTE 1: IMPLEMENTACIÓN DEL MODELO RELACIONAL EN SQL (CREATE TABLE - 13 TABLAS)
-- Incluye las 9 tablas base de la Sesión 1 más las 4 tablas de ampliación (Tabla 21):
-- visitante, usuario, asignacion_asesor y alerta, además de fecha_vencimiento_licencia.
-- =====================================================================================

-- 1. Tabla: vendedor (Fuerza comercial de 30 asesores de Zimbra)
CREATE TABLE vendedor (
    id_vendedor   INT AUTO_INCREMENT PRIMARY KEY,
    nombre        VARCHAR(60)  NOT NULL,
    apellido      VARCHAR(60)  NOT NULL,
    correo        VARCHAR(100) NOT NULL,
    telefono      VARCHAR(20)  NULL,
    region        VARCHAR(50)  NULL,
    fecha_ingreso DATE         NOT NULL,
    activo        BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_vendedor_correo UNIQUE (correo)
) ENGINE=InnoDB;

-- 2. Tabla: producto (Catálogo de ediciones y licencias de Zimbra Collaboration Suite - ZCS)
CREATE TABLE producto (
    id_producto     INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(80)   NOT NULL,
    version         VARCHAR(20)   NOT NULL,
    tipo_licencia   VARCHAR(30)   NOT NULL,
    precio_unitario DECIMAL(12,2) NOT NULL,
    activo          BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_producto_tipo_licencia CHECK (tipo_licencia IN ('Prueba de 60 días', 'Comercial')),
    CONSTRAINT chk_producto_precio        CHECK (precio_unitario >= 0),
    CONSTRAINT uq_producto_catalogo       UNIQUE (nombre, version, tipo_licencia)
) ENGINE=InnoDB;

-- 3. Tabla: campana_marketing (Campañas gestionadas en LoopFuse OneView)
CREATE TABLE campana_marketing (
    id_campana   INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(100)  NOT NULL,
    canal        VARCHAR(40)   NOT NULL,
    fecha_inicio DATE          NOT NULL,
    fecha_fin    DATE          NULL,
    presupuesto  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    estado       VARCHAR(20)   NOT NULL,
    CONSTRAINT chk_campana_canal       CHECK (canal IN ('Correo', 'Web', 'Evento')),
    CONSTRAINT chk_campana_fechas      CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT chk_campana_presupuesto CHECK (presupuesto >= 0),
    CONSTRAINT chk_campana_estado      CHECK (estado IN ('Planeada', 'Activa', 'Finalizada'))
) ENGINE=InnoDB;

-- 4. Tabla: prospecto (Posibles clientes y clientes convertidos)
CREATE TABLE prospecto (
    id_prospecto        INT AUTO_INCREMENT PRIMARY KEY,
    nombre              VARCHAR(60)  NOT NULL,
    apellido            VARCHAR(60)  NOT NULL,
    correo              VARCHAR(100) NOT NULL,
    telefono            VARCHAR(20)  NULL,
    empresa             VARCHAR(100) NULL,
    pais                VARCHAR(50)  NULL,
    fecha_registro      DATE         NOT NULL,
    estado              VARCHAR(20)  NOT NULL DEFAULT 'Nuevo',
    puntaje_interes     INT          NOT NULL DEFAULT 0,
    id_vendedor         INT          NULL,
    id_campana          INT          NULL,
    id_producto_interes INT          NULL,
    CONSTRAINT uq_prospecto_correo   UNIQUE (correo),
    CONSTRAINT chk_prospecto_estado  CHECK (estado IN ('Nuevo', 'Calificado', 'En seguimiento', 'Convertido', 'Descartado')),
    CONSTRAINT chk_prospecto_puntaje CHECK (puntaje_interes BETWEEN 0 AND 100),
    CONSTRAINT fk_prospecto_vendedor FOREIGN KEY (id_vendedor)
        REFERENCES vendedor(id_vendedor) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_prospecto_campana  FOREIGN KEY (id_campana)
        REFERENCES campana_marketing(id_campana) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_prospecto_producto FOREIGN KEY (id_producto_interes)
        REFERENCES producto(id_producto) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 5. Tabla: visitante (Seguimiento de visitantes anónimos por cookie - RF-18 y RF-19)
CREATE TABLE visitante (
    id_visitante   INT AUTO_INCREMENT PRIMARY KEY,
    codigo_cookie  VARCHAR(64) NOT NULL,
    primera_visita DATETIME    NOT NULL,
    ultima_visita  DATETIME    NULL,
    id_prospecto   INT         NULL,
    id_campana     INT         NULL,
    CONSTRAINT uq_visitante_cookie    UNIQUE (codigo_cookie),
    CONSTRAINT chk_visitante_fechas   CHECK (ultima_visita IS NULL OR ultima_visita >= primera_visita),
    CONSTRAINT fk_visitante_prospecto FOREIGN KEY (id_prospecto)
        REFERENCES prospecto(id_prospecto) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_visitante_campana   FOREIGN KEY (id_campana)
        REFERENCES campana_marketing(id_campana) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 6. Tabla: visita_web (Actividad en el sitio web de Zimbra de visitantes y prospectos)
CREATE TABLE visita_web (
    id_visita         INT AUTO_INCREMENT PRIMARY KEY,
    id_prospecto      INT          NULL,
    id_visitante      INT          NULL,
    fecha_hora        DATETIME     NOT NULL,
    url_visitada      VARCHAR(255) NOT NULL,
    tipo_actividad    VARCHAR(30)  NOT NULL,
    duracion_segundos INT          NOT NULL DEFAULT 0,
    CONSTRAINT chk_visita_actividad CHECK (tipo_actividad IN ('Visita', 'Descarga de prueba', 'Consulta de precios', 'Apertura de correo')),
    CONSTRAINT chk_visita_duracion  CHECK (duracion_segundos >= 0),
    CONSTRAINT chk_visita_origen    CHECK (id_prospecto IS NOT NULL OR id_visitante IS NOT NULL),
    CONSTRAINT fk_visita_prospecto  FOREIGN KEY (id_prospecto)
        REFERENCES prospecto(id_prospecto) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_visita_visitante  FOREIGN KEY (id_visitante)
        REFERENCES visitante(id_visitante) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 7. Tabla: usuario (Control de acceso por rol - RF-17 y RNF-03)
CREATE TABLE usuario (
    id_usuario      INT AUTO_INCREMENT PRIMARY KEY,
    correo          VARCHAR(100) NOT NULL,
    contrasena_hash VARCHAR(255) NOT NULL,
    rol             VARCHAR(20)  NOT NULL,
    id_vendedor     INT          NULL,
    id_prospecto    INT          NULL,
    activo          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_usuario_correo    UNIQUE (correo),
    CONSTRAINT chk_usuario_rol      CHECK (rol IN ('Administrador', 'Vendedor', 'Marketing', 'Cliente')),
    CONSTRAINT fk_usuario_vendedor  FOREIGN KEY (id_vendedor)
        REFERENCES vendedor(id_vendedor) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_usuario_prospecto FOREIGN KEY (id_prospecto)
        REFERENCES prospecto(id_prospecto) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 8. Tabla: asignacion_asesor (Historial de asignaciones y reasignaciones - RF-22, RF-23, RNF-18)
CREATE TABLE asignacion_asesor (
    id_asignacion      INT AUTO_INCREMENT PRIMARY KEY,
    id_prospecto       INT         NOT NULL,
    id_vendedor        INT         NOT NULL,
    fecha_asignacion   DATETIME    NOT NULL,
    fecha_finalizacion DATETIME    NULL,
    estado             VARCHAR(20) NOT NULL,
    CONSTRAINT chk_asignacion_estado   CHECK (estado IN ('Vigente', 'Reasignada', 'Finalizada')),
    CONSTRAINT chk_asignacion_fechas   CHECK (fecha_finalizacion IS NULL OR fecha_finalizacion >= fecha_asignacion),
    CONSTRAINT fk_asignacion_prospecto FOREIGN KEY (id_prospecto)
        REFERENCES prospecto(id_prospecto) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_asignacion_vendedor  FOREIGN KEY (id_vendedor)
        REFERENCES vendedor(id_vendedor) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 9. Tabla: contacto_comercial (Llamadas y correos de seguimiento comercial - RF-08)
CREATE TABLE contacto_comercial (
    id_contacto   INT AUTO_INCREMENT PRIMARY KEY,
    id_prospecto  INT          NOT NULL,
    id_vendedor   INT          NOT NULL,
    fecha_hora    DATETIME     NOT NULL,
    medio         VARCHAR(15)  NOT NULL,
    resultado     VARCHAR(100) NOT NULL,
    observaciones VARCHAR(255) NULL,
    CONSTRAINT chk_contacto_medio     CHECK (medio IN ('Llamada', 'Correo')),
    CONSTRAINT fk_contacto_prospecto  FOREIGN KEY (id_prospecto)
        REFERENCES prospecto(id_prospecto) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_contacto_vendedor   FOREIGN KEY (id_vendedor)
        REFERENCES vendedor(id_vendedor) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 10. Tabla: alerta (Avisos automáticos a asesores - RF-24)
CREATE TABLE alerta (
    id_alerta      INT AUTO_INCREMENT PRIMARY KEY,
    id_prospecto   INT         NOT NULL,
    id_vendedor    INT         NULL,
    tipo           VARCHAR(30) NOT NULL,
    fecha_generada DATETIME    NOT NULL,
    atendida       BOOLEAN     NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_alerta_tipo      CHECK (tipo IN ('Sin contacto 24 h', 'Alto interés', 'Prueba por vencer', 'Propuesta por vencer', 'Licencia por vencer')),
    CONSTRAINT fk_alerta_prospecto  FOREIGN KEY (id_prospecto)
        REFERENCES prospecto(id_prospecto) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_alerta_vendedor   FOREIGN KEY (id_vendedor)
        REFERENCES vendedor(id_vendedor) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 11. Tabla: propuesta_comercial (Ofertas enviadas a los prospectos - RF-09 a RF-11)
CREATE TABLE propuesta_comercial (
    id_propuesta   INT AUTO_INCREMENT PRIMARY KEY,
    id_prospecto   INT           NOT NULL,
    id_vendedor    INT           NOT NULL,
    fecha_envio    DATE          NOT NULL,
    fecha_vigencia DATE          NOT NULL,
    valor_total    DECIMAL(12,2) NOT NULL,
    estado         VARCHAR(20)   NOT NULL,
    CONSTRAINT chk_propuesta_fechas    CHECK (fecha_vigencia >= fecha_envio),
    CONSTRAINT chk_propuesta_valor     CHECK (valor_total >= 0),
    CONSTRAINT chk_propuesta_estado    CHECK (estado IN ('Enviada', 'En negociación', 'Aceptada', 'Rechazada', 'Vencida')),
    CONSTRAINT fk_propuesta_prospecto  FOREIGN KEY (id_prospecto)
        REFERENCES prospecto(id_prospecto) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_propuesta_vendedor   FOREIGN KEY (id_vendedor)
        REFERENCES vendedor(id_vendedor) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 12. Tabla: detalle_propuesta (Relación N:M entre propuesta_comercial y producto)
CREATE TABLE detalle_propuesta (
    id_propuesta       INT           NOT NULL,
    id_producto        INT           NOT NULL,
    cantidad_licencias INT           NOT NULL,
    precio_unitario    DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (id_propuesta, id_producto),
    CONSTRAINT chk_detalle_cantidad  CHECK (cantidad_licencias > 0),
    CONSTRAINT chk_detalle_precio    CHECK (precio_unitario >= 0),
    CONSTRAINT fk_detalle_propuesta  FOREIGN KEY (id_propuesta)
        REFERENCES propuesta_comercial(id_propuesta) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_detalle_producto   FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 13. Tabla: venta (Cierres comerciales originados en propuestas aceptadas - RF-12)
CREATE TABLE venta (
    id_venta                   INT AUTO_INCREMENT PRIMARY KEY,
    id_propuesta               INT           NOT NULL,
    fecha_venta                DATE          NOT NULL,
    valor_final                DECIMAL(12,2) NOT NULL,
    medio_pago                 VARCHAR(30)   NOT NULL,
    estado                     VARCHAR(20)   NOT NULL,
    fecha_vencimiento_licencia DATE          NULL,
    CONSTRAINT uq_venta_propuesta    UNIQUE (id_propuesta),
    CONSTRAINT chk_venta_valor       CHECK (valor_final >= 0),
    CONSTRAINT chk_venta_estado      CHECK (estado IN ('Registrada', 'Facturada', 'Anulada')),
    CONSTRAINT fk_venta_propuesta    FOREIGN KEY (id_propuesta)
        REFERENCES propuesta_comercial(id_propuesta) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================================================
-- PARTE 2: INSERCIÓN DE DATOS SIMULADOS (MÍNIMO 30 REGISTROS EN CADA UNA DE LAS 13 TABLAS)
-- Datos coherentes con el caso de estudio Zimbra (30 vendedores, pruebas de 60 días,
-- ediciones ZCS, campañas LoopFuse OneView y clientes de las Tablas 24 y 25).
-- =====================================================================================

-- 2.1 Inserción en tabla vendedor (30 registros)
INSERT INTO vendedor (nombre, apellido, correo, telefono, region, fecha_ingreso, activo) VALUES
  ('Carlos', 'Mendoza', 'cmendoza@zimbra.com', '+57-3102001001', 'Andina', '2023-02-10', TRUE),
  ('Laura', 'Gómez', 'lgomez@zimbra.com', '+57-3102001002', 'Andina', '2023-03-15', TRUE),
  ('Andrés', 'Rodríguez', 'arodriguez@zimbra.com', '+57-3102001003', 'Caribe', '2023-04-01', TRUE),
  ('Valentina', 'Herrera', 'vherrera@zimbra.com', '+57-3102001004', 'Pacífico', '2023-05-12', TRUE),
  ('Diego', 'Martínez', 'dmartinez@zimbra.com', '+57-3102001005', 'Andina', '2023-06-20', TRUE),
  ('Camila', 'Vargas', 'cvargas@zimbra.com', '+57-3102001006', 'Cono Sur', '2023-07-08', TRUE),
  ('Sebastián', 'Castro', 'scastro@zimbra.com', '+57-3102001007', 'Norteamérica', '2023-08-14', TRUE),
  ('Natalia', 'Ríos', 'nrios@zimbra.com', '+57-3102001008', 'Centroamérica', '2023-09-01', TRUE),
  ('Felipe', 'Morales', 'fmorales@zimbra.com', '+57-3102001009', 'Andina', '2023-10-05', TRUE),
  ('Daniela', 'Ortiz', 'dortiz@zimbra.com', '+57-3102001010', 'Caribe', '2023-11-11', TRUE),
  ('Alejandro', 'Silva', 'asilva@zimbra.com', '+57-3102001011', 'Pacífico', '2024-01-15', TRUE),
  ('Paula', 'Rojas', 'projas@zimbra.com', '+57-3102001012', 'Cono Sur', '2024-02-01', TRUE),
  ('Mateo', 'Pineda', 'mpineda@zimbra.com', '+57-3102001013', 'Norteamérica', '2024-02-19', TRUE),
  ('Juliana', 'Acosta', 'jacosta@zimbra.com', '+57-3102001014', 'Andina', '2024-03-10', TRUE),
  ('Nicolás', 'León', 'nleon@zimbra.com', '+57-3102001015', 'Centroamérica', '2024-04-04', TRUE),
  ('Mariana', 'Cárdenas', 'mcardenas@zimbra.com', '+57-3102001016', 'Caribe', '2024-04-22', TRUE),
  ('Juan', 'Suárez', 'jsuarez@zimbra.com', '+57-3102001017', 'Pacífico', '2024-05-15', TRUE),
  ('Gabriela', 'Peña', 'gpena@zimbra.com', '+57-3102001018', 'Cono Sur', '2024-06-03', TRUE),
  ('Santiago', 'Delgado', 'sdelgado@zimbra.com', '+57-3102001019', 'Norteamérica', '2024-06-25', TRUE),
  ('Isabella', 'Mora', 'imora@zimbra.com', '+57-3102001020', 'Andina', '2024-07-14', TRUE),
  ('David', 'Guerrero', 'dguerrero@zimbra.com', '+57-3102001021', 'Centroamérica', '2024-08-01', TRUE),
  ('Sara', 'Bautista', 'sbautista@zimbra.com', '+57-3102001022', 'Caribe', '2024-08-19', TRUE),
  ('Tomás', 'Navarro', 'tnavarro@zimbra.com', '+57-3102001023', 'Pacífico', '2024-09-09', TRUE),
  ('Lucía', 'Salazar', 'lsalazar@zimbra.com', '+57-3102001024', 'Cono Sur', '2024-10-02', TRUE),
  ('Miguel', 'Paredes', 'mparedes@zimbra.com', '+57-3102001025', 'Andina', '2024-11-11', TRUE),
  ('Valeria', 'Quintero', 'vquintero@zimbra.com', '+57-3102001026', 'Norteamérica', '2025-01-20', TRUE),
  ('Esteban', 'Cabrera', 'ecabrera@zimbra.com', '+57-3102001027', 'Centroamérica', '2025-02-14', TRUE),
  ('Catalina', 'Vega', 'cvega@zimbra.com', '+57-3102001028', 'Pacífico', '2025-03-05', TRUE),
  ('Óscar', 'Fajardo', 'ofajardo@zimbra.com', '+57-3102001029', 'Caribe', '2025-04-10', FALSE),
  ('Adriana', 'Bermúdez', 'abermudez@zimbra.com', '+57-3102001030', 'Cono Sur', '2025-05-01', FALSE);

-- 2.2 Inserción en tabla producto (30 registros)
INSERT INTO producto (nombre, version, tipo_licencia, precio_unitario, activo) VALUES
  ('Edición Estándar', '8.0', 'Prueba de 60 días', 0.00, TRUE),
  ('Edición Estándar', '8.0', 'Comercial', 25.00, TRUE),
  ('Edición Profesional', '8.0', 'Prueba de 60 días', 0.00, TRUE),
  ('Edición Profesional', '8.0', 'Comercial', 45.00, TRUE),
  ('Edición Estándar', '9.0', 'Prueba de 60 días', 0.00, TRUE),
  ('Edición Estándar', '9.0', 'Comercial', 30.00, TRUE),
  ('Edición Profesional', '9.0', 'Prueba de 60 días', 0.00, TRUE),
  ('Edición Profesional', '9.0', 'Comercial', 50.00, TRUE),
  ('Edición Estándar', '10.0', 'Prueba de 60 días', 0.00, TRUE),
  ('Edición Estándar', '10.0', 'Comercial', 35.00, TRUE),
  ('Edición Profesional', '10.0', 'Prueba de 60 días', 0.00, TRUE),
  ('Edición Profesional', '10.0', 'Comercial', 55.00, TRUE),
  ('ZCS Network Edition Starter', '8.8', 'Prueba de 60 días', 0.00, TRUE),
  ('ZCS Network Edition Starter', '8.8', 'Comercial', 28.00, TRUE),
  ('ZCS Network Edition Business', '8.8', 'Prueba de 60 días', 0.00, TRUE),
  ('ZCS Network Edition Business', '8.8', 'Comercial', 48.00, TRUE),
  ('ZCS Network Edition Enterprise', '9.0', 'Prueba de 60 días', 0.00, TRUE),
  ('ZCS Network Edition Enterprise', '9.0', 'Comercial', 65.00, TRUE),
  ('ZCS Network Edition Enterprise', '10.0', 'Prueba de 60 días', 0.00, TRUE),
  ('ZCS Network Edition Enterprise', '10.0', 'Comercial', 75.00, TRUE),
  ('Zimbra Cloud Suite Basic', '10.0', 'Prueba de 60 días', 0.00, TRUE),
  ('Zimbra Cloud Suite Basic', '10.0', 'Comercial', 22.00, TRUE),
  ('Zimbra Cloud Suite Plus', '10.0', 'Prueba de 60 días', 0.00, TRUE),
  ('Zimbra Cloud Suite Plus', '10.0', 'Comercial', 42.00, TRUE),
  ('Zimbra Archiving & Discovery', '9.0', 'Comercial', 18.00, TRUE),
  ('Zimbra Archiving & Discovery', '10.0', 'Comercial', 20.00, TRUE),
  ('Zimbra Mobile Sync Add-on', '9.0', 'Comercial', 15.00, TRUE),
  ('Zimbra Mobile Sync Add-on', '10.0', 'Comercial', 17.00, TRUE),
  ('Zimbra VoIP Collaboration Pack', '9.0', 'Comercial', 24.00, TRUE),
  ('Zimbra VoIP Collaboration Pack', '10.0', 'Comercial', 29.00, TRUE);

-- 2.3 Inserción en tabla campana_marketing (30 registros)
INSERT INTO campana_marketing (nombre, canal, fecha_inicio, fecha_fin, presupuesto, estado) VALUES
  ('Descarga Prueba 60 Días ZCS Q1', 'Web', '2025-01-10', '2025-03-31', 4500.00, 'Finalizada'),
  ('Migración desde Exchange a Zimbra', 'Correo', '2025-02-01', '2025-04-30', 3800.00, 'Finalizada'),
  ('Cumbre Colaboración Open Source Bogotá', 'Evento', '2025-03-05', '2025-03-20', 6200.00, 'Finalizada'),
  ('Descarga Prueba 60 Días ZCS Q2', 'Web', '2025-04-01', '2025-06-30', 4800.00, 'Finalizada'),
  ('Automatización Correo Corporativo PYMES', 'Correo', '2025-05-01', '2025-07-31', 3100.00, 'Finalizada'),
  ('Foro TI Salud y Clínicas Andinas', 'Evento', '2025-06-10', '2025-06-25', 5400.00, 'Finalizada'),
  ('Descarga Prueba 60 Días ZCS Q3', 'Web', '2025-07-01', '2025-09-30', 5000.00, 'Finalizada'),
  ('Campaña Reactivación Cuentas Trial', 'Correo', '2025-08-01', '2025-10-31', 2900.00, 'Finalizada'),
  ('Webinar Seguridad y Archiving ZCS', 'Evento', '2025-09-10', '2025-09-30', 3500.00, 'Finalizada'),
  ('Descarga Prueba 60 Días ZCS Q4', 'Web', '2025-10-01', '2025-12-31', 5200.00, 'Finalizada'),
  ('Black Friday Licencias Comerciales ZCS', 'Correo', '2025-11-01', '2025-11-30', 4100.00, 'Finalizada'),
  ('Cierre Fiscal Empresas LATAM 2025', 'Correo', '2025-11-15', '2025-12-31', 3900.00, 'Finalizada'),
  ('Lanzamiento ZCS 10 Colaboración Total', 'Web', '2026-01-05', '2026-03-31', 6500.00, 'Finalizada'),
  ('Secuencia Bienvenida Trial LoopFuse', 'Correo', '2026-01-15', '2026-06-30', 3200.00, 'Finalizada'),
  ('Roadshow Transformación Digital Medellín', 'Evento', '2026-02-10', '2026-02-28', 5800.00, 'Finalizada'),
  ('Campaña Sector Logístico y Transporte', 'Correo', '2026-03-01', '2026-05-31', 3600.00, 'Finalizada'),
  ('Banner Comparativo Costos ZCS vs Prop.', 'Web', '2026-03-15', '2026-06-15', 4300.00, 'Finalizada'),
  ('Congreso Latinoamericano de Cloud TI', 'Evento', '2026-04-12', '2026-04-25', 7100.00, 'Finalizada'),
  ('Recordatorio Día 30 Prueba Gratuita', 'Correo', '2026-05-01', '2026-10-31', 2500.00, 'Finalizada'),
  ('Recordatorio Día 50 y 58 Prueba ZCS', 'Correo', '2026-05-01', '2026-10-31', 2700.00, 'Finalizada'),
  ('Landing Page Movilidad y Ajax Web', 'Web', '2026-06-01', '2026-09-30', 4600.00, 'Finalizada'),
  ('Encuentro Directores TI Sector Financiero', 'Evento', '2026-07-08', '2026-07-22', 6900.00, 'Finalizada'),
  ('Campaña Upgrade Edición Estándar a Pro', 'Correo', '2026-08-01', '2026-11-30', 3400.00, 'Activa'),
  ('Atracción Orgánica y Viral Open Source', 'Web', '2026-08-15', '2026-12-31', 4900.00, 'Activa'),
  ('Feria Internacional Software Corporativo', 'Evento', '2026-09-05', '2026-09-20', 7500.00, 'Finalizada'),
  ('Campaña Renovación Anticipada 60 Días', 'Correo', '2026-09-15', '2026-12-31', 3000.00, 'Activa'),
  ('Prueba Gratuita 60 Días ZCS Octubre', 'Web', '2026-10-01', '2026-12-31', 5500.00, 'Activa'),
  ('Campaña Reactivación Clientes Inactivos', 'Correo', '2026-10-10', '2026-12-31', 2800.00, 'Activa'),
  ('Simposio Comunicaciones Unificadas VoIP', 'Evento', '2026-11-15', '2026-11-30', 6000.00, 'Planeada'),
  ('Plan Corporativo ZCS 2027 Preventa', 'Web', '2026-12-01', '2027-02-28', 6800.00, 'Planeada');

-- 2.4 Inserción en tabla prospecto (35 registros)
INSERT INTO prospecto (nombre, apellido, correo, telefono, empresa, pais, fecha_registro, estado, puntaje_interes, id_vendedor, id_campana, id_producto_interes) VALUES
  ('Hernán', 'Salcedo', 'hsalcedo@andeslogistica.com', '+57-3154001001', 'Andes Logística S.A.S.', 'Colombia', '2025-10-05', 'Convertido', 95, 1, 16, 2),
  ('Patricia', 'Lozano', 'plozano@tecnoandina.com', '+57-3154001002', 'Tecnoandina S.A.', 'Colombia', '2026-01-12', 'Convertido', 92, 2, 13, 6),
  ('Mauricio', 'Restrepo', 'mrestrepo@clinicasanrafael.org', '+57-3154001003', 'Clínica San Rafael', 'Colombia', '2026-03-01', 'Convertido', 90, 3, 6, 2),
  ('Claudia', 'Mejía', 'cmejia@cafedelvalle.co', '+57-3154001004', 'Café del Valle Ltda.', 'Colombia', '2025-12-10', 'Convertido', 85, 4, 5, 2),
  ('Jorge', 'Vallecilla', 'jvallecilla@distpacifico.com', '+57-3154001005', 'Distribuidora Pacífico', 'Colombia', '2025-07-15', 'Convertido', 78, 5, 4, 2),
  ('Roberto', 'Alvarado', 'ralvarado@bancolatam.com', '+56-984001006', 'Banco Latam Corp.', 'Chile', '2026-01-20', 'Convertido', 94, 6, 13, 8),
  ('Elena', 'Villanueva', 'evillanueva@agroexport.pe', '+51-994001007', 'AgroExport del Perú S.A.', 'Perú', '2026-02-02', 'Convertido', 88, 7, 14, 6),
  ('Fernando', 'Ibarra', 'fibarra@mexicotel.mx', '+52-554001008', 'MexicoTel Comunicaciones', 'México', '2026-02-15', 'Convertido', 91, 8, 15, 12),
  ('Mónica', 'Zambrano', 'mzambrano@ecuaenergia.ec', '+593-984001009', 'EcuaEnergía S.A.', 'Ecuador', '2026-03-10', 'Convertido', 87, 9, 16, 4),
  ('Gustavo', 'Peralta', 'gperalta@australmining.cl', '+56-984001010', 'Austral Mining Group', 'Chile', '2026-03-22', 'Convertido', 93, 10, 17, 18),
  ('Adriana', 'Correa', 'acorrea@universidadcentral.edu.co', '+57-3154001011', 'Universidad Central Andina', 'Colombia', '2026-04-05', 'Convertido', 89, 11, 18, 6),
  ('Ricardo', 'Montoya', 'rmontoya@segurosbolivar.com.pa', '+507-64001012', 'Seguros del Istmo S.A.', 'Panamá', '2026-04-18', 'Convertido', 86, 12, 18, 8),
  ('Silvia', 'Castañeda', 'scastaneda@farmasalud.mx', '+52-554001013', 'FarmaSalud Nacional', 'México', '2026-05-02', 'Convertido', 92, 13, 19, 10),
  ('Héctor', 'Benítez', 'hbenitez@puertobuenaventura.co', '+57-3154001014', 'Terminal Portuaria Pacífico', 'Colombia', '2026-05-19', 'Convertido', 90, 14, 20, 12),
  ('Lorena', 'Ospina', 'lospina@constructoraurbe.com', '+57-3154001015', 'Constructora Urbe S.A.S.', 'Colombia', '2026-06-04', 'Convertido', 84, 15, 21, 6),
  ('Pablo', 'Sánchez', 'psanchez@retailersur.com.ar', '+54-9114001016', 'Retailer del Sur S.A.', 'Argentina', '2026-06-18', 'Convertido', 88, 16, 21, 8),
  ('Verónica', 'Duarte', 'vduarte@finanzasplatino.uy', '+598-994001017', 'Finanzas Platino S.A.', 'Uruguay', '2026-07-05', 'Convertido', 91, 17, 22, 18),
  ('Javier', 'Arango', 'jarango@textilesmedellin.co', '+57-3154001018', 'Textiles Medellín S.A.', 'Colombia', '2026-07-20', 'Convertido', 85, 18, 23, 4),
  ('Beatriz', 'Nieto', 'bnieto@editorialandes.com', '+57-3154001019', 'Editorial Los Andes Ltda.', 'Colombia', '2026-08-03', 'Convertido', 83, 19, 24, 2),
  ('César', 'Gaitán', 'cgaitan@aerolineascaribe.com', '+57-3154001020', 'Aerolíneas del Caribe', 'Colombia', '2026-08-15', 'Convertido', 94, 20, 25, 20),
  ('Óscar', 'Beltrán', 'obeltran@industriasalfa.com', '+57-3154001021', 'Industrias Alfa S.A.S.', 'Colombia', '2026-09-10', 'En seguimiento', 82, 21, 26, 9),
  ('Natalia', 'Patiño', 'npatino@consultoresdelta.com', '+57-3154001022', 'Consultores Delta Ltda.', 'Colombia', '2026-09-18', 'En seguimiento', 79, 22, 26, 11),
  ('Germán', 'Cifuentes', 'gcifuentes@logisticalima.pe', '+51-994001023', 'Logística Lima Express', 'Perú', '2026-09-25', 'En seguimiento', 86, 23, 27, 7),
  ('Marcela', 'Tamayo', 'mtamayo@grupofenix.mx', '+52-554001024', 'Grupo Empresarial Fénix', 'México', '2026-10-01', 'En seguimiento', 81, 24, 27, 5),
  ('Rodrigo', 'Peñaloza', 'rpenaloza@inmobiliariacapital.cl', '+56-984001025', 'Inmobiliaria Capital', 'Chile', '2026-10-06', 'En seguimiento', 76, 25, 27, 3),
  ('Tatiana', 'Useche', 'tuseche@energiasolar.co', '+57-3154001026', 'Energía Solar Colombia', 'Colombia', '2026-10-10', 'En seguimiento', 84, 26, 27, 11),
  ('Emilio', 'Fonseca', 'efonseca@acerosdelnorte.mx', '+52-554001027', 'Aceros del Norte S.A.', 'México', '2026-10-14', 'Calificado', 74, 27, 27, 9),
  ('Ximena', 'Londoño', 'xlondono@laboratoriosvida.co', '+57-3154001028', 'Laboratorios Vida S.A.', 'Colombia', '2026-10-17', 'Calificado', 71, 28, 28, 5),
  ('Iván', 'Gutiérrez', 'igutierrez@transporteandino.ec', '+593-984001029', 'Transporte Andino Cía.', 'Ecuador', '2026-10-20', 'Calificado', 68, 1, 27, 1),
  ('Paola', 'Serrano', 'pserrano@hotelestelar.com', '+57-3154001030', 'Cadena Hotelera Estelar', 'Colombia', '2026-10-22', 'Calificado', 73, 2, 24, 7),
  ('Esteban', 'Rincón', 'erincon@agrotech.co', '+57-3154001031', 'AgroTech Sabana S.A.S.', 'Colombia', '2026-10-28', 'Nuevo', 45, 3, 27, 9),
  ('Camila', 'Orozco', 'corozco@disenodigital.co', '+57-3154001032', 'Diseño Digital Studio', 'Colombia', '2026-10-29', 'Nuevo', 35, NULL, 27, 1),
  ('Lucas', 'Méndez', 'lmendez@startupsur.cl', '+56-984001033', 'Startup Sur SpA', 'Chile', '2026-10-30', 'Nuevo', 40, NULL, NULL, 5),
  ('arturo', 'Velasco', 'avelasco@talleresunidos.co', '+57-3154001034', 'Talleres Unidos Ltda.', 'Colombia', '2026-04-10', 'Descartado', 15, 4, 4, 1),
  ('Nora', 'Fuentes', 'nfuentes@comercializadorazeta.com', '+57-3154001035', 'Comercializadora Zeta', 'Colombia', '2026-05-12', 'Descartado', 10, 5, 5, 3);

-- 2.5 Inserción en tabla visitante (35 registros: 25 vinculados a prospectos y 10 anónimos)
INSERT INTO visitante (codigo_cookie, primera_visita, ultima_visita, id_prospecto, id_campana) VALUES
  ('zmb_ck_2026_0001_1915d', '2026-01-03 08:03:00', '2026-01-04 17:07:00', 1, 1),
  ('zmb_ck_2026_0002_19c1a', '2026-02-05 08:06:00', '2026-02-06 17:14:00', 2, 2),
  ('zmb_ck_2026_0003_1a6d7', '2026-03-07 08:09:00', '2026-03-08 17:21:00', 3, 3),
  ('zmb_ck_2026_0004_1b194', '2026-04-09 08:12:00', '2026-04-10 17:28:00', 4, 4),
  ('zmb_ck_2026_0005_1bc51', '2026-05-11 08:15:00', '2026-05-12 17:35:00', 5, 5),
  ('zmb_ck_2026_0006_1c70e', '2026-06-13 08:18:00', '2026-06-14 17:42:00', 6, 6),
  ('zmb_ck_2026_0007_1d1cb', '2026-07-15 08:21:00', '2026-07-16 17:49:00', 7, 7),
  ('zmb_ck_2026_0008_1dc88', '2026-08-17 08:24:00', '2026-08-18 17:56:00', 8, 8),
  ('zmb_ck_2026_0009_1e745', '2026-09-19 08:27:00', '2026-09-20 17:03:00', 9, 9),
  ('zmb_ck_2026_0010_1f202', '2026-10-21 08:30:00', '2026-10-22 17:10:00', 10, 10),
  ('zmb_ck_2026_0011_1fcbf', '2026-01-23 08:33:00', '2026-01-24 17:17:00', 11, 11),
  ('zmb_ck_2026_0012_2077c', '2026-02-25 08:36:00', '2026-02-26 17:24:00', 12, 12),
  ('zmb_ck_2026_0013_21239', '2026-03-01 08:39:00', '2026-03-02 17:31:00', 13, 13),
  ('zmb_ck_2026_0014_21cf6', '2026-04-03 08:42:00', '2026-04-04 17:38:00', 14, 14),
  ('zmb_ck_2026_0015_227b3', '2026-05-05 08:45:00', '2026-05-06 17:45:00', 15, 15),
  ('zmb_ck_2026_0016_23270', '2026-06-07 08:48:00', '2026-06-08 17:52:00', 16, 16),
  ('zmb_ck_2026_0017_23d2d', '2026-07-09 08:51:00', '2026-07-10 17:59:00', 17, 17),
  ('zmb_ck_2026_0018_247ea', '2026-08-11 08:54:00', '2026-08-12 17:06:00', 18, 18),
  ('zmb_ck_2026_0019_252a7', '2026-09-13 08:57:00', '2026-09-14 17:13:00', 19, 19),
  ('zmb_ck_2026_0020_25d64', '2026-10-15 08:00:00', '2026-10-16 17:20:00', 20, 20),
  ('zmb_ck_2026_0021_26821', '2026-01-17 08:03:00', '2026-01-18 17:27:00', 21, 21),
  ('zmb_ck_2026_0022_272de', '2026-02-19 08:06:00', '2026-02-20 17:34:00', 22, 22),
  ('zmb_ck_2026_0023_27d9b', '2026-03-21 08:09:00', '2026-03-22 17:41:00', 23, 23),
  ('zmb_ck_2026_0024_28858', '2026-04-23 08:12:00', '2026-04-24 17:48:00', 24, 24),
  ('zmb_ck_2026_0025_29315', '2026-05-25 08:15:00', '2026-05-26 17:55:00', 25, 25),
  ('zmb_ck_2026_0026_29dd2', '2026-06-01 08:18:00', '2026-06-02 17:02:00', NULL, 26),
  ('zmb_ck_2026_0027_2a88f', '2026-07-03 08:21:00', '2026-07-04 17:09:00', NULL, 27),
  ('zmb_ck_2026_0028_2b34c', '2026-08-05 08:24:00', '2026-08-06 17:16:00', NULL, 28),
  ('zmb_ck_2026_0029_2be09', '2026-09-07 08:27:00', '2026-09-08 17:23:00', NULL, 1),
  ('zmb_ck_2026_0030_2c8c6', '2026-10-09 08:30:00', '2026-10-10 17:30:00', NULL, 2),
  ('zmb_ck_2026_0031_2d383', '2026-01-11 08:33:00', '2026-01-12 17:37:00', NULL, 3),
  ('zmb_ck_2026_0032_2de40', '2026-02-13 08:36:00', '2026-02-14 17:44:00', NULL, 4),
  ('zmb_ck_2026_0033_2e8fd', '2026-03-15 08:39:00', '2026-03-16 17:51:00', NULL, 5),
  ('zmb_ck_2026_0034_2f3ba', '2026-04-17 08:42:00', '2026-04-18 17:58:00', NULL, 6),
  ('zmb_ck_2026_0035_2fe77', '2026-05-19 08:45:00', '2026-05-20 17:05:00', NULL, 7);

-- 2.6 Inserción en tabla visita_web (40 registros)
INSERT INTO visita_web (id_prospecto, id_visitante, fecha_hora, url_visitada, tipo_actividad, duracion_segundos) VALUES
  (1, 1, '2026-01-03 10:05:15', '/productos/zcs-enterprise', 'Visita', 149),
  (2, 2, '2026-02-05 10:10:15', '/descargas/prueba-60-dias', 'Descarga de prueba', 318),
  (3, 3, '2026-03-07 10:15:15', '/precios/licencias-comerciales', 'Consulta de precios', 232),
  (4, 4, '2026-04-09 10:20:15', '/campanas/correo-bienvenida', 'Apertura de correo', 111),
  (5, 5, '2026-05-11 10:25:15', '/productos/comparativa-ediciones', 'Visita', 200),
  (6, 6, '2026-06-13 10:30:15', '/precios/calculadora-zcs', 'Consulta de precios', 284),
  (7, 7, '2026-07-15 10:35:15', '/descargas/instalador-linux-zcs', 'Descarga de prueba', 368),
  (8, 8, '2026-08-17 10:40:15', '/campanas/recordatorio-dia-30', 'Apertura de correo', 117),
  (9, 9, '2026-09-19 10:45:15', '/productos/zcs-enterprise', 'Visita', 181),
  (10, 10, '2026-10-21 10:50:15', '/descargas/prueba-60-dias', 'Descarga de prueba', 350),
  (11, 11, '2026-01-23 10:55:15', '/precios/licencias-comerciales', 'Consulta de precios', 264),
  (12, 12, '2026-02-25 10:00:15', '/campanas/correo-bienvenida', 'Apertura de correo', 143),
  (13, 13, '2026-03-27 10:05:15', '/productos/comparativa-ediciones', 'Visita', 232),
  (14, 14, '2026-04-02 10:10:15', '/precios/calculadora-zcs', 'Consulta de precios', 316),
  (15, 15, '2026-05-04 10:15:15', '/descargas/instalador-linux-zcs', 'Descarga de prueba', 400),
  (16, 16, '2026-06-06 10:20:15', '/campanas/recordatorio-dia-30', 'Apertura de correo', 149),
  (17, 17, '2026-07-08 10:25:15', '/productos/zcs-enterprise', 'Visita', 213),
  (18, 18, '2026-08-10 10:30:15', '/descargas/prueba-60-dias', 'Descarga de prueba', 382),
  (19, 19, '2026-09-12 10:35:15', '/precios/licencias-comerciales', 'Consulta de precios', 296),
  (20, 20, '2026-10-14 10:40:15', '/campanas/correo-bienvenida', 'Apertura de correo', 175),
  (21, 21, '2026-01-16 10:45:15', '/productos/comparativa-ediciones', 'Visita', 264),
  (22, 22, '2026-02-18 10:50:15', '/precios/calculadora-zcs', 'Consulta de precios', 348),
  (23, 23, '2026-03-20 10:55:15', '/descargas/instalador-linux-zcs', 'Descarga de prueba', 432),
  (24, 24, '2026-04-22 10:00:15', '/campanas/recordatorio-dia-30', 'Apertura de correo', 181),
  (25, 25, '2026-05-24 10:05:15', '/productos/zcs-enterprise', 'Visita', 245),
  (26, 26, '2026-06-26 10:10:15', '/descargas/prueba-60-dias', 'Descarga de prueba', 414),
  (27, 27, '2026-07-01 10:15:15', '/precios/licencias-comerciales', 'Consulta de precios', 328),
  (28, 28, '2026-08-03 10:20:15', '/campanas/correo-bienvenida', 'Apertura de correo', 207),
  (29, 29, '2026-09-05 10:25:15', '/productos/comparativa-ediciones', 'Visita', 296),
  (30, 30, '2026-10-07 10:30:15', '/precios/calculadora-zcs', 'Consulta de precios', 380),
  (NULL, 31, '2026-01-09 10:35:15', '/descargas/instalador-linux-zcs', 'Descarga de prueba', 464),
  (NULL, 32, '2026-02-11 10:40:15', '/campanas/recordatorio-dia-30', 'Apertura de correo', 213),
  (NULL, 33, '2026-03-13 10:45:15', '/productos/zcs-enterprise', 'Visita', 277),
  (NULL, 34, '2026-04-15 10:50:15', '/descargas/prueba-60-dias', 'Descarga de prueba', 446),
  (NULL, 35, '2026-05-17 10:55:15', '/precios/licencias-comerciales', 'Consulta de precios', 360),
  (NULL, 26, '2026-06-19 10:00:15', '/campanas/correo-bienvenida', 'Apertura de correo', 239),
  (NULL, 27, '2026-07-21 10:05:15', '/productos/comparativa-ediciones', 'Visita', 328),
  (NULL, 28, '2026-08-23 10:10:15', '/precios/calculadora-zcs', 'Consulta de precios', 412),
  (NULL, 29, '2026-09-25 10:15:15', '/descargas/instalador-linux-zcs', 'Descarga de prueba', 496),
  (NULL, 30, '2026-10-27 10:20:15', '/campanas/recordatorio-dia-30', 'Apertura de correo', 245);

-- 2.7 Inserción en tabla usuario (35 registros)
INSERT INTO usuario (correo, contrasena_hash, rol, id_vendedor, id_prospecto, activo) VALUES
  ('admin.principal@zimbra.com', '$2a$10$ZimbraHashAdmin000000000000000000000000000000000001', 'Administrador', NULL, NULL, TRUE),
  ('seguridad.ti@zimbra.com', '$2a$10$ZimbraHashAdmin000000000000000000000000000000000002', 'Administrador', NULL, NULL, TRUE),
  ('greg.armanini@zimbra.com', '$2a$10$ZimbraHashMkt00000000000000000000000000000000000001', 'Marketing', NULL, NULL, TRUE),
  ('analista.campanas@zimbra.com', '$2a$10$ZimbraHashMkt00000000000000000000000000000000000002', 'Marketing', NULL, NULL, TRUE),
  ('automatizacion.oneview@zimbra.com', '$2a$10$ZimbraHashMkt00000000000000000000000000000000000003', 'Marketing', NULL, NULL, TRUE),
  ('cmendoza@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000001', 'Vendedor', 1, NULL, TRUE),
  ('lgomez@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000002', 'Vendedor', 2, NULL, TRUE),
  ('arodriguez@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000003', 'Vendedor', 3, NULL, TRUE),
  ('vherrera@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000004', 'Vendedor', 4, NULL, TRUE),
  ('dmartinez@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000005', 'Vendedor', 5, NULL, TRUE),
  ('cvargas@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000006', 'Vendedor', 6, NULL, TRUE),
  ('scastro@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000007', 'Vendedor', 7, NULL, TRUE),
  ('nrios@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000008', 'Vendedor', 8, NULL, TRUE),
  ('fmorales@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000009', 'Vendedor', 9, NULL, TRUE),
  ('dortiz@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000010', 'Vendedor', 10, NULL, TRUE),
  ('asilva@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000011', 'Vendedor', 11, NULL, TRUE),
  ('projas@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000012', 'Vendedor', 12, NULL, TRUE),
  ('mpineda@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000013', 'Vendedor', 13, NULL, TRUE),
  ('jacosta@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000014', 'Vendedor', 14, NULL, TRUE),
  ('nleon@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000015', 'Vendedor', 15, NULL, TRUE),
  ('mcardenas@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000016', 'Vendedor', 16, NULL, TRUE),
  ('jsuarez@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000017', 'Vendedor', 17, NULL, TRUE),
  ('gpena@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000018', 'Vendedor', 18, NULL, TRUE),
  ('sdelgado@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000019', 'Vendedor', 19, NULL, TRUE),
  ('imora@zimbra.com', '$2a$10$ZimbraHashVend000000000000000000000000000000000020', 'Vendedor', 20, NULL, TRUE),
  ('hsalcedo@andeslogistica.com', '$2a$10$ZimbraHashCli0000000000000000000000000000000000001', 'Cliente', NULL, 1, TRUE),
  ('plozano@tecnoandina.com', '$2a$10$ZimbraHashCli0000000000000000000000000000000000002', 'Cliente', NULL, 2, TRUE),
  ('mrestrepo@clinicasanrafael.org', '$2a$10$ZimbraHashCli0000000000000000000000000000000000003', 'Cliente', NULL, 3, TRUE),
  ('cmejia@cafedelvalle.co', '$2a$10$ZimbraHashCli0000000000000000000000000000000000004', 'Cliente', NULL, 4, TRUE),
  ('jvallecilla@distpacifico.com', '$2a$10$ZimbraHashCli0000000000000000000000000000000000005', 'Cliente', NULL, 5, TRUE),
  ('ralvarado@bancolatam.com', '$2a$10$ZimbraHashCli0000000000000000000000000000000000006', 'Cliente', NULL, 6, TRUE),
  ('evillanueva@agroexport.pe', '$2a$10$ZimbraHashCli0000000000000000000000000000000000007', 'Cliente', NULL, 7, TRUE),
  ('fibarra@mexicotel.mx', '$2a$10$ZimbraHashCli0000000000000000000000000000000000008', 'Cliente', NULL, 8, TRUE),
  ('mzambrano@ecuaenergia.ec', '$2a$10$ZimbraHashCli0000000000000000000000000000000000009', 'Cliente', NULL, 9, TRUE),
  ('gperalta@australmining.cl', '$2a$10$ZimbraHashCli0000000000000000000000000000000000010', 'Cliente', NULL, 10, TRUE);

-- 2.8 Inserción en tabla asignacion_asesor (35 registros)
INSERT INTO asignacion_asesor (id_prospecto, id_vendedor, fecha_asignacion, fecha_finalizacion, estado) VALUES
  (1, 29, '2025-10-05 09:00:00', '2025-10-10 14:00:00', 'Reasignada'),
  (2, 30, '2026-01-12 09:30:00', '2026-01-15 11:00:00', 'Reasignada'),
  (6, 29, '2026-01-20 10:00:00', '2026-01-25 16:00:00', 'Reasignada'),
  (34, 4, '2026-04-10 08:30:00', '2026-05-01 17:00:00', 'Finalizada'),
  (35, 5, '2026-05-12 09:15:00', '2026-06-01 18:00:00', 'Finalizada'),
  (1, 1, '2025-10-05 10:00:00', NULL, 'Vigente'),
  (2, 2, '2026-01-12 10:00:00', NULL, 'Vigente'),
  (3, 3, '2026-03-01 10:00:00', NULL, 'Vigente'),
  (4, 4, '2025-12-10 10:00:00', NULL, 'Vigente'),
  (5, 5, '2025-07-15 10:00:00', NULL, 'Vigente'),
  (6, 6, '2026-01-20 10:00:00', NULL, 'Vigente'),
  (7, 7, '2026-02-02 10:00:00', NULL, 'Vigente'),
  (8, 8, '2026-02-15 10:00:00', NULL, 'Vigente'),
  (9, 9, '2026-03-10 10:00:00', NULL, 'Vigente'),
  (10, 10, '2026-03-22 10:00:00', NULL, 'Vigente'),
  (11, 11, '2026-04-05 10:00:00', NULL, 'Vigente'),
  (12, 12, '2026-04-18 10:00:00', NULL, 'Vigente'),
  (13, 13, '2026-05-02 10:00:00', NULL, 'Vigente'),
  (14, 14, '2026-05-19 10:00:00', NULL, 'Vigente'),
  (15, 15, '2026-06-04 10:00:00', NULL, 'Vigente'),
  (16, 16, '2026-06-18 10:00:00', NULL, 'Vigente'),
  (17, 17, '2026-07-05 10:00:00', NULL, 'Vigente'),
  (18, 18, '2026-07-20 10:00:00', NULL, 'Vigente'),
  (19, 19, '2026-08-03 10:00:00', NULL, 'Vigente'),
  (20, 20, '2026-08-15 10:00:00', NULL, 'Vigente'),
  (21, 21, '2026-09-10 10:00:00', NULL, 'Vigente'),
  (22, 22, '2026-09-18 10:00:00', NULL, 'Vigente'),
  (23, 23, '2026-09-25 10:00:00', NULL, 'Vigente'),
  (24, 24, '2026-10-01 10:00:00', NULL, 'Vigente'),
  (25, 25, '2026-10-06 10:00:00', NULL, 'Vigente'),
  (26, 26, '2026-10-10 10:00:00', NULL, 'Vigente'),
  (27, 27, '2026-10-14 10:00:00', NULL, 'Vigente'),
  (28, 28, '2026-10-17 10:00:00', NULL, 'Vigente'),
  (29, 1, '2026-10-20 10:00:00', NULL, 'Vigente'),
  (30, 2, '2026-10-22 10:00:00', NULL, 'Vigente');

-- 2.9 Inserción en tabla contacto_comercial (40 registros)
INSERT INTO contacto_comercial (id_prospecto, id_vendedor, fecha_hora, medio, resultado, observaciones) VALUES
  (1, 1, '2025-10-05 14:07:00', 'Llamada', 'Interesado - Solicita propuesta formal', 'Se validó requerimiento de buzones y agenda compartida ZCS.'),
  (2, 2, '2026-01-12 14:14:00', 'Correo', 'Envío de información técnica y precios', 'Se adjuntó comparativa entre Edición Estándar y Profesional.'),
  (3, 3, '2026-03-01 14:21:00', 'Llamada', 'Demostración técnica agendada', 'El director de TI solicitó prueba de integración con directorio activo.'),
  (4, 4, '2025-12-10 14:28:00', 'Correo', 'Confirmación de recepción de propuesta', 'El cliente revisará la oferta económica en comité de compras.'),
  (5, 5, '2025-07-15 14:35:00', 'Llamada', 'Negociación de licencias y descuento por volumen', 'Solicitan ampliar cantidad de licencias comerciales.'),
  (6, 6, '2026-01-20 14:42:00', 'Llamada', 'Interesado - Solicita propuesta formal', 'Se validó requerimiento de buzones y agenda compartida ZCS.'),
  (7, 7, '2026-02-02 14:49:00', 'Correo', 'Envío de información técnica y precios', 'Se adjuntó comparativa entre Edición Estándar y Profesional.'),
  (8, 8, '2026-02-15 14:56:00', 'Llamada', 'Demostración técnica agendada', 'El director de TI solicitó prueba de integración con directorio activo.'),
  (9, 9, '2026-03-10 14:03:00', 'Correo', 'Confirmación de recepción de propuesta', 'El cliente revisará la oferta económica en comité de compras.'),
  (10, 10, '2026-03-22 14:10:00', 'Llamada', 'Negociación de licencias y descuento por volumen', 'Solicitan ampliar cantidad de licencias comerciales.'),
  (11, 11, '2026-04-05 14:17:00', 'Llamada', 'Interesado - Solicita propuesta formal', 'Se validó requerimiento de buzones y agenda compartida ZCS.'),
  (12, 12, '2026-04-18 14:24:00', 'Correo', 'Envío de información técnica y precios', 'Se adjuntó comparativa entre Edición Estándar y Profesional.'),
  (13, 13, '2026-05-02 14:31:00', 'Llamada', 'Demostración técnica agendada', 'El director de TI solicitó prueba de integración con directorio activo.'),
  (14, 14, '2026-05-19 14:38:00', 'Correo', 'Confirmación de recepción de propuesta', 'El cliente revisará la oferta económica en comité de compras.'),
  (15, 15, '2026-06-04 14:45:00', 'Llamada', 'Negociación de licencias y descuento por volumen', 'Solicitan ampliar cantidad de licencias comerciales.'),
  (16, 16, '2026-06-18 14:52:00', 'Llamada', 'Interesado - Solicita propuesta formal', 'Se validó requerimiento de buzones y agenda compartida ZCS.'),
  (17, 17, '2026-07-05 14:59:00', 'Correo', 'Envío de información técnica y precios', 'Se adjuntó comparativa entre Edición Estándar y Profesional.'),
  (18, 18, '2026-07-20 14:06:00', 'Llamada', 'Demostración técnica agendada', 'El director de TI solicitó prueba de integración con directorio activo.'),
  (19, 19, '2026-08-03 14:13:00', 'Correo', 'Confirmación de recepción de propuesta', 'El cliente revisará la oferta económica en comité de compras.'),
  (20, 20, '2026-08-15 14:20:00', 'Llamada', 'Negociación de licencias y descuento por volumen', 'Solicitan ampliar cantidad de licencias comerciales.'),
  (21, 21, '2026-09-10 14:27:00', 'Llamada', 'Interesado - Solicita propuesta formal', 'Se validó requerimiento de buzones y agenda compartida ZCS.'),
  (22, 22, '2026-09-18 14:34:00', 'Correo', 'Envío de información técnica y precios', 'Se adjuntó comparativa entre Edición Estándar y Profesional.'),
  (23, 23, '2026-09-25 14:41:00', 'Llamada', 'Demostración técnica agendada', 'El director de TI solicitó prueba de integración con directorio activo.'),
  (24, 24, '2026-10-01 14:48:00', 'Correo', 'Confirmación de recepción de propuesta', 'El cliente revisará la oferta económica en comité de compras.'),
  (25, 25, '2026-10-06 14:55:00', 'Llamada', 'Negociación de licencias y descuento por volumen', 'Solicitan ampliar cantidad de licencias comerciales.'),
  (26, 26, '2026-10-10 14:02:00', 'Llamada', 'Interesado - Solicita propuesta formal', 'Se validó requerimiento de buzones y agenda compartida ZCS.'),
  (27, 27, '2026-10-14 14:09:00', 'Correo', 'Envío de información técnica y precios', 'Se adjuntó comparativa entre Edición Estándar y Profesional.'),
  (28, 28, '2026-10-17 14:16:00', 'Llamada', 'Demostración técnica agendada', 'El director de TI solicitó prueba de integración con directorio activo.'),
  (29, 1, '2026-10-20 14:23:00', 'Correo', 'Confirmación de recepción de propuesta', 'El cliente revisará la oferta económica en comité de compras.'),
  (30, 2, '2026-10-22 14:30:00', 'Llamada', 'Negociación de licencias y descuento por volumen', 'Solicitan ampliar cantidad de licencias comerciales.'),
  (1, 1, '2025-10-05 14:37:00', 'Llamada', 'Interesado - Solicita propuesta formal', 'Se validó requerimiento de buzones y agenda compartida ZCS.'),
  (2, 2, '2026-01-12 14:44:00', 'Correo', 'Envío de información técnica y precios', 'Se adjuntó comparativa entre Edición Estándar y Profesional.'),
  (3, 3, '2026-03-01 14:51:00', 'Llamada', 'Demostración técnica agendada', 'El director de TI solicitó prueba de integración con directorio activo.'),
  (4, 4, '2025-12-10 14:58:00', 'Correo', 'Confirmación de recepción de propuesta', 'El cliente revisará la oferta económica en comité de compras.'),
  (5, 5, '2025-07-15 14:05:00', 'Llamada', 'Negociación de licencias y descuento por volumen', 'Solicitan ampliar cantidad de licencias comerciales.'),
  (6, 6, '2026-01-20 14:12:00', 'Llamada', 'Interesado - Solicita propuesta formal', 'Se validó requerimiento de buzones y agenda compartida ZCS.'),
  (7, 7, '2026-02-02 14:19:00', 'Correo', 'Envío de información técnica y precios', 'Se adjuntó comparativa entre Edición Estándar y Profesional.'),
  (8, 8, '2026-02-15 14:26:00', 'Llamada', 'Demostración técnica agendada', 'El director de TI solicitó prueba de integración con directorio activo.'),
  (9, 9, '2026-03-10 14:33:00', 'Correo', 'Confirmación de recepción de propuesta', 'El cliente revisará la oferta económica en comité de compras.'),
  (10, 10, '2026-03-22 14:40:00', 'Llamada', 'Negociación de licencias y descuento por volumen', 'Solicitan ampliar cantidad de licencias comerciales.');

-- 2.10 Inserción en tabla alerta (35 registros)
INSERT INTO alerta (id_prospecto, id_vendedor, tipo, fecha_generada, atendida) VALUES
  (1, 1, 'Sin contacto 24 h', '2026-01-04 09:00:00', TRUE),
  (2, 2, 'Alto interés', '2026-02-07 09:00:00', TRUE),
  (3, 3, 'Prueba por vencer', '2026-03-10 09:00:00', TRUE),
  (4, 4, 'Propuesta por vencer', '2026-04-13 09:00:00', TRUE),
  (5, 5, 'Licencia por vencer', '2026-05-16 09:00:00', TRUE),
  (6, 6, 'Sin contacto 24 h', '2026-06-19 09:00:00', TRUE),
  (7, 7, 'Alto interés', '2026-07-22 09:00:00', TRUE),
  (8, 8, 'Prueba por vencer', '2026-08-25 09:00:00', TRUE),
  (9, 9, 'Propuesta por vencer', '2026-09-02 09:00:00', TRUE),
  (10, 10, 'Licencia por vencer', '2026-10-05 09:00:00', TRUE),
  (11, 11, 'Sin contacto 24 h', '2026-01-08 09:00:00', TRUE),
  (12, 12, 'Alto interés', '2026-02-11 09:00:00', TRUE),
  (13, 13, 'Prueba por vencer', '2026-03-14 09:00:00', TRUE),
  (14, 14, 'Propuesta por vencer', '2026-04-17 09:00:00', TRUE),
  (15, 15, 'Licencia por vencer', '2026-05-20 09:00:00', TRUE),
  (16, 16, 'Sin contacto 24 h', '2026-06-23 09:00:00', TRUE),
  (17, 17, 'Alto interés', '2026-07-26 09:00:00', TRUE),
  (18, 18, 'Prueba por vencer', '2026-08-03 09:00:00', TRUE),
  (19, 19, 'Propuesta por vencer', '2026-09-06 09:00:00', TRUE),
  (20, 20, 'Licencia por vencer', '2026-10-09 09:00:00', TRUE),
  (21, 21, 'Sin contacto 24 h', '2026-01-12 09:00:00', FALSE),
  (22, 22, 'Alto interés', '2026-02-15 09:00:00', FALSE),
  (23, 23, 'Prueba por vencer', '2026-03-18 09:00:00', FALSE),
  (24, 24, 'Propuesta por vencer', '2026-04-21 09:00:00', FALSE),
  (25, 25, 'Licencia por vencer', '2026-05-24 09:00:00', FALSE),
  (26, 26, 'Sin contacto 24 h', '2026-06-01 09:00:00', FALSE),
  (27, 27, 'Alto interés', '2026-07-04 09:00:00', FALSE),
  (28, 28, 'Prueba por vencer', '2026-08-07 09:00:00', FALSE),
  (29, 1, 'Propuesta por vencer', '2026-09-10 09:00:00', FALSE),
  (30, 2, 'Licencia por vencer', '2026-10-13 09:00:00', FALSE),
  (31, 3, 'Sin contacto 24 h', '2026-01-16 09:00:00', FALSE),
  (32, NULL, 'Alto interés', '2026-02-19 09:00:00', FALSE),
  (33, NULL, 'Prueba por vencer', '2026-03-22 09:00:00', FALSE),
  (1, 1, 'Propuesta por vencer', '2026-04-25 09:00:00', FALSE),
  (2, 2, 'Licencia por vencer', '2026-05-02 09:00:00', FALSE);

-- 2.11 Inserción en tabla propuesta_comercial (40 registros)
INSERT INTO propuesta_comercial (id_prospecto, id_vendedor, fecha_envio, fecha_vigencia, valor_total, estado) VALUES
  (1, 1, '2025-10-15', '2025-11-15', 1500.00, 'Aceptada'),
  (1, 1, '2025-12-10', '2026-01-10', 1500.00, 'Aceptada'),
  (1, 1, '2026-02-18', '2026-03-18', 1500.00, 'Aceptada'),
  (1, 1, '2026-04-22', '2026-05-22', 1500.00, 'Aceptada'),
  (1, 1, '2026-07-05', '2026-08-05', 1500.00, 'Aceptada'),
  (1, 1, '2026-09-10', '2026-10-10', 1500.00, 'Aceptada'),
  (2, 2, '2026-01-25', '2026-02-25', 1800.00, 'Aceptada'),
  (2, 2, '2026-03-28', '2026-04-28', 1800.00, 'Aceptada'),
  (2, 2, '2026-05-30', '2026-06-30', 1800.00, 'Aceptada'),
  (2, 2, '2026-07-28', '2026-08-28', 1800.00, 'Aceptada'),
  (3, 3, '2026-03-25', '2026-04-25', 1800.00, 'Aceptada'),
  (3, 3, '2026-06-28', '2026-07-28', 1800.00, 'Aceptada'),
  (3, 3, '2026-10-01', '2026-10-31', 1800.00, 'Aceptada'),
  (4, 4, '2026-01-05', '2026-02-05', 1200.00, 'Aceptada'),
  (4, 4, '2026-06-05', '2026-07-05', 1200.00, 'Aceptada'),
  (5, 5, '2025-08-10', '2025-09-10', 600.00, 'Aceptada'),
  (6, 6, '2026-02-01', '2026-03-01', 2500.00, 'Aceptada'),
  (7, 7, '2026-02-14', '2026-03-14', 1800.00, 'Aceptada'),
  (8, 8, '2026-02-28', '2026-03-28', 3300.00, 'Aceptada'),
  (9, 9, '2026-03-20', '2026-04-20', 2250.00, 'Aceptada'),
  (10, 10, '2026-04-02', '2026-05-02', 3900.00, 'Aceptada'),
  (11, 11, '2026-04-15', '2026-05-15', 2400.00, 'Aceptada'),
  (12, 12, '2026-04-28', '2026-05-28', 2000.00, 'Aceptada'),
  (13, 13, '2026-05-12', '2026-06-12', 2800.00, 'Aceptada'),
  (14, 14, '2026-05-28', '2026-06-28', 3850.00, 'Aceptada'),
  (15, 15, '2026-06-15', '2026-07-15', 1500.00, 'Aceptada'),
  (16, 16, '2026-06-28', '2026-07-28', 3000.00, 'Aceptada'),
  (17, 17, '2026-07-15', '2026-08-15', 3250.00, 'Aceptada'),
  (18, 18, '2026-08-01', '2026-08-31', 1800.00, 'Aceptada'),
  (19, 19, '2026-08-18', '2026-09-18', 1250.00, 'Aceptada'),
  (20, 20, '2026-09-01', '2026-10-01', 3750.00, 'Aceptada'),
  (21, 21, '2026-10-05', '2026-11-15', 2100.00, 'En negociación'),
  (22, 22, '2026-10-08', '2026-11-20', 2750.00, 'En negociación'),
  (23, 23, '2026-10-12', '2026-11-25', 1750.00, 'Enviada'),
  (24, 24, '2026-10-15', '2026-11-30', 1650.00, 'Enviada'),
  (25, 25, '2026-10-18', '2026-11-18', 1350.00, 'Enviada'),
  (26, 26, '2026-09-01', '2026-09-30', 2200.00, 'Vencida'),
  (27, 27, '2026-09-10', '2026-10-10', 1400.00, 'Vencida'),
  (34, 4, '2026-04-15', '2026-05-15', 1000.00, 'Rechazada'),
  (35, 5, '2026-05-18', '2026-06-18', 1350.00, 'Rechazada');

-- 2.12 Inserción en tabla detalle_propuesta (45 registros)
INSERT INTO detalle_propuesta (id_propuesta, id_producto, cantidad_licencias, precio_unitario) VALUES
  (1, 2, 20, 25.00),
  (1, 4, 25, 40.00),
  (2, 2, 60, 25.00),
  (3, 4, 30, 50.00),
  (4, 2, 60, 25.00),
  (5, 4, 30, 50.00),
  (6, 2, 60, 25.00),
  (7, 6, 30, 30.00),
  (7, 8, 18, 50.00),
  (8, 6, 60, 30.00),
  (9, 8, 36, 50.00),
  (10, 6, 60, 30.00),
  (11, 2, 72, 25.00),
  (12, 2, 72, 25.00),
  (13, 2, 72, 25.00),
  (14, 2, 48, 25.00),
  (15, 2, 48, 25.00),
  (16, 2, 24, 25.00),
  (17, 8, 50, 50.00),
  (18, 6, 60, 30.00),
  (19, 12, 60, 55.00),
  (20, 4, 50, 45.00),
  (21, 18, 60, 65.00),
  (22, 6, 80, 30.00),
  (23, 8, 40, 50.00),
  (24, 10, 80, 35.00),
  (25, 12, 70, 55.00),
  (26, 6, 50, 30.00),
  (27, 8, 60, 50.00),
  (28, 18, 50, 65.00),
  (29, 4, 40, 45.00),
  (30, 2, 50, 25.00),
  (31, 20, 50, 75.00),
  (32, 10, 60, 35.00),
  (33, 12, 50, 55.00),
  (34, 10, 50, 35.00),
  (35, 12, 30, 55.00),
  (36, 4, 30, 45.00),
  (37, 12, 40, 55.00),
  (38, 10, 40, 35.00),
  (39, 2, 40, 25.00),
  (40, 4, 30, 45.00),
  (17, 25, 25, 18.00),
  (19, 28, 30, 17.00),
  (21, 30, 20, 29.00);

-- 2.13 Inserción en tabla venta (30 registros)
INSERT INTO venta (id_propuesta, fecha_venta, valor_final, medio_pago, estado, fecha_vencimiento_licencia) VALUES
  (1, '2025-10-20', 1500.00, 'Transferencia bancaria', 'Facturada', '2026-10-20'),
  (2, '2025-12-22', 1500.00, 'Transferencia bancaria', 'Facturada', '2026-12-22'),
  (3, '2026-02-25', 1500.00, 'Transferencia bancaria', 'Facturada', '2027-02-25'),
  (4, '2026-05-01', 1500.00, 'Transferencia bancaria', 'Facturada', '2027-05-01'),
  (5, '2026-07-10', 1500.00, 'Transferencia bancaria', 'Facturada', '2027-07-10'),
  (6, '2026-09-15', 1500.00, 'Transferencia bancaria', 'Facturada', '2027-09-15'),
  (7, '2026-02-03', 1800.00, 'Tarjeta corporativa', 'Facturada', '2027-02-03'),
  (8, '2026-04-04', 1800.00, 'Tarjeta corporativa', 'Facturada', '2027-04-04'),
  (9, '2026-06-03', 1800.00, 'Tarjeta corporativa', 'Facturada', '2027-06-03'),
  (10, '2026-08-02', 1800.00, 'Tarjeta corporativa', 'Facturada', '2027-08-02'),
  (11, '2026-04-02', 1800.00, 'Orden de compra', 'Facturada', '2027-04-02'),
  (12, '2026-07-04', 1800.00, 'Orden de compra', 'Facturada', '2027-07-04'),
  (13, '2026-10-05', 1800.00, 'Orden de compra', 'Facturada', '2027-10-05'),
  (14, '2026-01-10', 1200.00, 'Transferencia bancaria', 'Facturada', '2027-01-10'),
  (15, '2026-06-10', 1200.00, 'Transferencia bancaria', 'Facturada', '2027-06-10'),
  (16, '2025-08-20', 600.00, 'Transferencia bancaria', 'Facturada', '2026-08-20'),
  (17, '2026-02-10', 2950.00, 'Transferencia bancaria', 'Facturada', '2026-11-30'),
  (18, '2026-02-22', 1800.00, 'Tarjeta corporativa', 'Facturada', '2026-12-05'),
  (19, '2026-03-08', 3810.00, 'Transferencia bancaria', 'Facturada', '2026-12-15'),
  (20, '2026-03-28', 2250.00, 'Orden de compra', 'Facturada', '2026-12-20'),
  (21, '2026-04-12', 4480.00, 'Transferencia bancaria', 'Facturada', '2027-04-12'),
  (22, '2026-04-22', 2400.00, 'Orden de compra', 'Facturada', '2027-04-22'),
  (23, '2026-05-06', 2000.00, 'Tarjeta corporativa', 'Facturada', '2027-05-06'),
  (24, '2026-05-20', 2800.00, 'Transferencia bancaria', 'Facturada', '2027-05-20'),
  (25, '2026-06-05', 3850.00, 'Orden de compra', 'Facturada', '2027-06-05'),
  (26, '2026-06-22', 1500.00, 'Transferencia bancaria', 'Facturada', '2027-06-22'),
  (27, '2026-07-08', 3000.00, 'Tarjeta corporativa', 'Facturada', '2027-07-08'),
  (28, '2026-07-25', 3250.00, 'Transferencia bancaria', 'Registrada', '2027-07-25'),
  (29, '2026-08-10', 1800.00, 'Tarjeta corporativa', 'Registrada', '2027-08-10'),
  (30, '2026-08-28', 1250.00, 'Transferencia bancaria', 'Anulada', '2027-08-28');

-- =====================================================================================
-- VERIFICACIÓN DEL MÍNIMO DE 30 REGISTROS POR TABLA (13 TABLAS)
-- =====================================================================================
SELECT 'vendedor'            AS tabla, COUNT(*) AS total_registros FROM vendedor
UNION ALL SELECT 'producto',            COUNT(*) FROM producto
UNION ALL SELECT 'campana_marketing',   COUNT(*) FROM campana_marketing
UNION ALL SELECT 'prospecto',           COUNT(*) FROM prospecto
UNION ALL SELECT 'visitante',           COUNT(*) FROM visitante
UNION ALL SELECT 'visita_web',          COUNT(*) FROM visita_web
UNION ALL SELECT 'usuario',             COUNT(*) FROM usuario
UNION ALL SELECT 'asignacion_asesor',   COUNT(*) FROM asignacion_asesor
UNION ALL SELECT 'contacto_comercial',  COUNT(*) FROM contacto_comercial
UNION ALL SELECT 'alerta',              COUNT(*) FROM alerta
UNION ALL SELECT 'propuesta_comercial', COUNT(*) FROM propuesta_comercial
UNION ALL SELECT 'detalle_propuesta',   COUNT(*) FROM detalle_propuesta
UNION ALL SELECT 'venta',               COUNT(*) FROM venta;

-- =====================================================================================
-- PARTE 3: PROGRAMACIÓN DE TRANSACCIONES ACID
-- Cumple con RNF-02 (Consistencia transaccional ACID) y las actividades de la Sesión 2:
--   1. Transacción con START TRANSACTION / BEGIN y COMMIT (Cierre de venta y conversión)
--   2. Transacción con SAVEPOINT y ROLLBACK TO SAVEPOINT (Creación de propuesta comercial)
--   3. Transacción con ROLLBACK total (Cancelación por rechazo en validación de pago)
--   4. Procedimiento almacenado transaccional con conversión de visitante a prospecto
-- =====================================================================================

-- Asegurar que autocommit esté deshabilitado durante las pruebas manuales o controlar con START TRANSACTION
SET autocommit = 1;

-- -------------------------------------------------------------------------------------
-- TRANSACCIÓN 1: CIERRE COMERCIAL Y CONVERSIÓN DE PROSPECTO EN CLIENTE (COMMIT)
-- Proceso 7 (Tabla 4 de Sesión 1) / RF-12 / RNF-02:
-- Cuando la propuesta #32 (de Industrias Alfa S.A.S., id_prospecto = 21) pasa a 'Aceptada',
-- en una sola unidad atómica (ACID) se:
--   a) Actualiza propuesta_comercial.estado = 'Aceptada'.
--   b) Inserta la nueva venta con fecha_vencimiento_licencia a 1 año.
--   c) Actualiza prospecto.estado = 'Convertido' y puntaje_interes = 100.
--   d) Marca como atendidas las alertas abiertas del prospecto.
--   e) Registra el contacto comercial de cierre y confirma con COMMIT.
-- -------------------------------------------------------------------------------------
START TRANSACTION;

-- Paso 1: Aceptar la propuesta comercial #32
UPDATE propuesta_comercial
SET estado = 'Aceptada'
WHERE id_propuesta = 32
  AND estado = 'En negociación';

-- Paso 2: Registrar la venta derivada de la propuesta #32
INSERT INTO venta (id_propuesta, fecha_venta, valor_final, medio_pago, estado, fecha_vencimiento_licencia)
VALUES (32, '2026-10-31', 2100.00, 'Transferencia bancaria', 'Registrada', '2027-10-31');

-- Paso 3: Convertir al prospecto #21 (Industrias Alfa S.A.S.) en cliente ('Convertido')
UPDATE prospecto
SET estado = 'Convertido',
    puntaje_interes = 100
WHERE id_prospecto = 21;

-- Paso 4: Marcar como atendidas las alertas pendientes del prospecto #21
UPDATE alerta
SET atendida = TRUE
WHERE id_prospecto = 21
  AND atendida = FALSE;

-- Paso 5: Dejar trazabilidad del cierre en contacto_comercial
INSERT INTO contacto_comercial (id_prospecto, id_vendedor, fecha_hora, medio, resultado, observaciones)
VALUES (21, 21, '2026-10-31 11:30:00', 'Llamada', 'Cierre de venta exitoso', 'Propuesta #32 aceptada y venta registrada mediante transacción ACID.');

-- Confirmar todos los cambios de manera permanente (Durabilidad)
COMMIT;

-- Verificación posterior al COMMIT de la Transacción 1:
SELECT p.id_prospecto, p.empresa, p.estado AS estado_prospecto,
       pc.id_propuesta, pc.estado AS estado_propuesta,
       v.id_venta, v.valor_final, v.estado AS estado_venta, v.fecha_vencimiento_licencia
FROM prospecto p
JOIN propuesta_comercial pc ON pc.id_prospecto = p.id_prospecto
JOIN venta v                ON v.id_propuesta  = pc.id_propuesta
WHERE pc.id_propuesta = 32;


-- -------------------------------------------------------------------------------------
-- TRANSACCIÓN 2: CREACIÓN DE PROPUESTA MULTIPRODUCTO CON USO DE SAVEPOINT
-- Proceso 6 (Propuesta comercial - RF-09 y RF-10):
-- Un asesor crea una propuesta para el prospecto #27 (Aceros del Norte S.A., id_vendedor = 27).
--   a) Inserta la cabecera de propuesta_comercial y crea SAVEPOINT sp_cabecera_creada.
--   b) Inserta dos productos principales en detalle_propuesta y crea SAVEPOINT sp_lineas_base.
--   c) Agrega un tercer producto opcional (VoIP Pack), pero el cliente decide excluirlo
--      por límite presupuestal antes de confirmar el envío.
--   d) Se ejecuta ROLLBACK TO SAVEPOINT sp_lineas_base (deshace solo el tercer producto,
--      conservando la cabecera y los dos primeros productos).
--   e) Se recalcula valor_total de la propuesta, se pasa el prospecto a 'En seguimiento'
--      y se ejecuta COMMIT.
-- -------------------------------------------------------------------------------------
START TRANSACTION;

-- a) Insertar cabecera de la propuesta comercial
INSERT INTO propuesta_comercial (id_prospecto, id_vendedor, fecha_envio, fecha_vigencia, valor_total, estado)
VALUES (27, 27, '2026-10-31', '2026-11-30', 0.00, 'Enviada');

SET @id_nueva_propuesta = LAST_INSERT_ID();

SAVEPOINT sp_cabecera_creada;

-- b) Insertar las dos líneas base solicitadas por el cliente (Edición Estándar v10 y Archiving v10)
INSERT INTO detalle_propuesta (id_propuesta, id_producto, cantidad_licencias, precio_unitario)
VALUES
  (@id_nueva_propuesta, 10, 40, 35.00), -- 40 * 35.00 = 1400.00
  (@id_nueva_propuesta, 26, 40, 20.00); -- 40 * 20.00 =  800.00

SAVEPOINT sp_lineas_base;

-- c) Intentar agregar paquete opcional de VoIP (id_producto = 30) que excede el presupuesto autorizado (2500.00)
INSERT INTO detalle_propuesta (id_propuesta, id_producto, cantidad_licencias, precio_unitario)
VALUES (@id_nueva_propuesta, 30, 40, 29.00); -- 40 * 29.00 = 1160.00 (Total sería 3360.00 > 2500.00)

-- d) Revertir únicamente la línea opcional volviendo al punto de guardado sp_lineas_base
ROLLBACK TO SAVEPOINT sp_lineas_base;

-- Liberar el savepoint intermedio y actualizar el valor_total definitivo (1400 + 800 = 2200.00)
RELEASE SAVEPOINT sp_lineas_base;

UPDATE propuesta_comercial
SET valor_total = (
    SELECT COALESCE(SUM(cantidad_licencias * precio_unitario), 0.00)
    FROM detalle_propuesta
    WHERE id_propuesta = @id_nueva_propuesta
)
WHERE id_propuesta = @id_nueva_propuesta;

-- e) Actualizar estado del prospecto #27 a 'En seguimiento'
UPDATE prospecto
SET estado = 'En seguimiento',
    puntaje_interes = 80
WHERE id_prospecto = 27;

COMMIT;

-- Verificación posterior al uso de SAVEPOINT y COMMIT:
SELECT pc.id_propuesta, pc.id_prospecto, pc.valor_total, pc.estado,
       COUNT(dp.id_producto) AS productos_incluidos
FROM propuesta_comercial pc
JOIN detalle_propuesta dp ON dp.id_propuesta = pc.id_propuesta
WHERE pc.id_propuesta = @id_nueva_propuesta
GROUP BY pc.id_propuesta, pc.id_prospecto, pc.valor_total, pc.estado;


-- -------------------------------------------------------------------------------------
-- TRANSACCIÓN 3: REVERSIÓN COMPLETA CON ROLLBACK (ATOMICIDAD ANTE OPERACIÓN INVÁLIDA)
-- Escenario: Se intenta cerrar de forma anticipada la propuesta #34 (Logística Lima Express,
-- id_prospecto = 23), pero durante la validación financiera la orden de pago es rechazada
-- por el banco emisor. Se ejecuta ROLLBACK total para que ningún cambio persista.
-- -------------------------------------------------------------------------------------
START TRANSACTION;

UPDATE propuesta_comercial
SET estado = 'Aceptada'
WHERE id_propuesta = 34;

INSERT INTO venta (id_propuesta, fecha_venta, valor_final, medio_pago, estado, fecha_vencimiento_licencia)
VALUES (34, '2026-10-31', 1750.00, 'Tarjeta corporativa', 'Registrada', '2027-10-31');

UPDATE prospecto
SET estado = 'Convertido'
WHERE id_prospecto = 23;

-- Simulación de rechazo en la pasarela de pago: se revierte toda la transacción
ROLLBACK;

-- Verificación de que la propuesta #34 sigue en estado 'Enviada' y NO existe venta asociada:
SELECT pc.id_propuesta, pc.estado AS estado_propuesta, p.estado AS estado_prospecto,
       (SELECT COUNT(*) FROM venta v WHERE v.id_propuesta = 34) AS ventas_registradas
FROM propuesta_comercial pc
JOIN prospecto p ON p.id_prospecto = pc.id_prospecto
WHERE pc.id_propuesta = 34;


-- =====================================================================================
-- PARTE 4: SIMULACIÓN DE ERRORES Y RECUPERACIÓN EN TRANSACCIONES
-- Demuestra el manejo de excepciones SQL (violación de llaves únicas, restricciones CHECK,
-- llaves foráneas), recuperación automática con ROLLBACK / SAVEPOINT y registro en bitácora.
-- =====================================================================================

-- Tabla auxiliar de bitácora para auditar errores transaccionales y su recuperación
CREATE TABLE bitacora_errores_transaccion (
    id_error         INT AUTO_INCREMENT PRIMARY KEY,
    fecha_evento     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    operacion        VARCHAR(100) NOT NULL,
    codigo_sqlstate  CHAR(5)      NOT NULL,
    numero_error     INT          NOT NULL,
    mensaje_error    VARCHAR(255) NOT NULL,
    accion_tomada    VARCHAR(120) NOT NULL
) ENGINE=InnoDB;

DELIMITER $$

-- -------------------------------------------------------------------------------------
-- PROCEDIMIENTO 1: sp_cerrar_venta_segura
-- Ejecuta una transacción ACID completa de cierre de venta. Si ocurre cualquier error
-- (por ejemplo: propuesta inexistente, propuesta ya vendida por UNIQUE uq_venta_propuesta,
-- o valor negativo que viola CHECK chk_venta_valor), el EXIT HANDLER ejecuta ROLLBACK
-- y registra el incidente en bitacora_errores_transaccion sin dejar datos corruptos.
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_cerrar_venta_segura(
    IN p_id_propuesta INT,
    IN p_valor_final  DECIMAL(12,2),
    IN p_medio_pago   VARCHAR(30),
    OUT p_resultado   VARCHAR(150)
)
BEGIN
    DECLARE v_id_prospecto INT;
    DECLARE v_sqlstate CHAR(5) DEFAULT '00000';
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg TEXT;

    -- Manejador de error para revertir toda la transacción (ROLLBACK) y auditar el fallo
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errno    = MYSQL_ERRNO,
            v_msg      = MESSAGE_TEXT;

        ROLLBACK;

        INSERT INTO bitacora_errores_transaccion
            (operacion, codigo_sqlstate, numero_error, mensaje_error, accion_tomada)
        VALUES
            (CONCAT('sp_cerrar_venta_segura(propuesta=', p_id_propuesta, ')'),
             v_sqlstate, v_errno, LEFT(v_msg, 250),
             'ROLLBACK ejecutado: estado restaurado sin afectación a tablas');

        SET p_resultado = CONCAT('ERROR [', v_errno, ' - ', v_sqlstate, ']: Transacción revertida con ROLLBACK.');
    END;

    START TRANSACTION;

    -- Obtener el prospecto dueño de la propuesta
    SELECT id_prospecto INTO v_id_prospecto
    FROM propuesta_comercial
    WHERE id_propuesta = p_id_propuesta
    FOR UPDATE;

    IF v_id_prospecto IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La propuesta comercial indicada no existe.';
    END IF;

    -- 1. Marcar propuesta como Aceptada
    UPDATE propuesta_comercial
    SET estado = 'Aceptada'
    WHERE id_propuesta = p_id_propuesta;

    -- 2. Insertar la venta (puede disparar error si id_propuesta ya tiene venta o valor_final < 0)
    INSERT INTO venta (id_propuesta, fecha_venta, valor_final, medio_pago, estado, fecha_vencimiento_licencia)
    VALUES (p_id_propuesta, CURDATE(), p_valor_final, p_medio_pago, 'Registrada', DATE_ADD(CURDATE(), INTERVAL 1 YEAR));

    -- 3. Actualizar prospecto a Convertido
    UPDATE prospecto
    SET estado = 'Convertido',
        puntaje_interes = 100
    WHERE id_prospecto = v_id_prospecto;

    COMMIT;
    SET p_resultado = CONCAT('OK: Venta registrada exitosamente para propuesta #', p_id_propuesta);
END$$


-- -------------------------------------------------------------------------------------
-- PROCEDIMIENTO 2: sp_convertir_visitante_con_savepoint
-- Simula la conversión de un visitante anónimo en prospecto (RF-18, RF-19) y su asignación
-- de asesor con SAVEPOINT: si el vendedor indicado no existe o falla la alerta inicial,
-- se recupera al SAVEPOINT sp_prospecto_registrado asignando al vendedor de respaldo (#1)
-- sin perder el registro del nuevo prospecto ni la vinculación de sus visitas web.
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_convertir_visitante_con_savepoint(
    IN p_id_visitante       INT,
    IN p_nombre             VARCHAR(60),
    IN p_apellido           VARCHAR(60),
    IN p_correo             VARCHAR(100),
    IN p_empresa            VARCHAR(100),
    IN p_pais               VARCHAR(50),
    IN p_id_vendedor_pref   INT,
    OUT p_estado_operacion  VARCHAR(180)
)
BEGIN
    DECLARE v_id_prospecto INT;
    DECLARE v_id_campana INT;
    DECLARE v_error_asignacion BOOLEAN DEFAULT FALSE;
    DECLARE v_sqlstate CHAR(5);
    DECLARE v_errno INT;
    DECLARE v_msg TEXT;

    -- Manejador CONTINUE para capturar error en la asignación preferida y recuperar con SAVEPOINT
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_sqlstate = RETURNED_SQLSTATE,
            v_errno    = MYSQL_ERRNO,
            v_msg      = MESSAGE_TEXT;
        SET v_error_asignacion = TRUE;
    END;

    START TRANSACTION;

    SELECT id_campana INTO v_id_campana
    FROM visitante
    WHERE id_visitante = p_id_visitante;

    -- Paso 1: Crear el prospecto y vincular su historial de visitante
    INSERT INTO prospecto (nombre, apellido, correo, empresa, pais, fecha_registro, estado, puntaje_interes, id_campana, id_producto_interes)
    VALUES (p_nombre, p_apellido, p_correo, p_empresa, p_pais, CURDATE(), 'Nuevo', 55, v_id_campana, 9);

    SET v_id_prospecto = LAST_INSERT_ID();

    UPDATE visitante
    SET id_prospecto = v_id_prospecto,
        ultima_visita = NOW()
    WHERE id_visitante = p_id_visitante;

    UPDATE visita_web
    SET id_prospecto = v_id_prospecto
    WHERE id_visitante = p_id_visitante
      AND id_prospecto IS NULL;

    -- Crear SAVEPOINT una vez asegurado el registro del prospecto y su historial web
    SAVEPOINT sp_prospecto_registrado;

    -- Paso 2: Intentar asignar el vendedor preferido (puede fallar por FK si p_id_vendedor_pref no existe)
    INSERT INTO asignacion_asesor (id_prospecto, id_vendedor, fecha_asignacion, estado)
    VALUES (v_id_prospecto, p_id_vendedor_pref, NOW(), 'Vigente');

    IF v_error_asignacion = TRUE THEN
        -- Recuperación parcial al SAVEPOINT: conservar prospecto y asignar asesor de respaldo (id_vendedor = 1)
        ROLLBACK TO SAVEPOINT sp_prospecto_registrado;

        INSERT INTO bitacora_errores_transaccion
            (operacion, codigo_sqlstate, numero_error, mensaje_error, accion_tomada)
        VALUES
            (CONCAT('sp_convertir_visitante_con_savepoint(visitante=', p_id_visitante, ')'),
             v_sqlstate, v_errno, LEFT(v_msg, 250),
             'ROLLBACK TO SAVEPOINT sp_prospecto_registrado y asignación a vendedor de respaldo #1');

        SET v_error_asignacion = FALSE;

        INSERT INTO asignacion_asesor (id_prospecto, id_vendedor, fecha_asignacion, estado)
        VALUES (v_id_prospecto, 1, NOW(), 'Vigente');

        UPDATE prospecto SET id_vendedor = 1 WHERE id_prospecto = v_id_prospecto;

        SET p_estado_operacion = CONCAT('RECUPERADO CON SAVEPOINT: Prospecto #', v_id_prospecto, ' creado y asignado al asesor de respaldo #1.');
    ELSE
        UPDATE prospecto SET id_vendedor = p_id_vendedor_pref WHERE id_prospecto = v_id_prospecto;
        SET p_estado_operacion = CONCAT('OK: Prospecto #', v_id_prospecto, ' creado y asignado al asesor #', p_id_vendedor_pref);
    END IF;

    COMMIT;
END$$

DELIMITER ;

-- -------------------------------------------------------------------------------------
-- EJECUCIÓN DE LAS SIMULACIONES DE ERROR Y RECUPERACIÓN
-- -------------------------------------------------------------------------------------

-- Simulación A: Error por duplicidad de venta (propuesta #1 ya tiene una venta en la tabla venta)
-- Dispara violación de restricción UNIQUE (uq_venta_propuesta) -> ejecuta ROLLBACK automático
CALL sp_cerrar_venta_segura(1, 1500.00, 'Transferencia bancaria', @res_error_duplicado);
SELECT @res_error_duplicado AS resultado_simulacion_A;

-- Simulación B: Error por violación de restricción CHECK (valor_final negativo = -500.00 en propuesta #33)
-- Dispara violación de chk_venta_valor -> ejecuta ROLLBACK automático y la propuesta #33 sigue 'En negociación'
CALL sp_cerrar_venta_segura(33, -500.00, 'Tarjeta corporativa', @res_error_check);
SELECT @res_error_check AS resultado_simulacion_B;

-- Simulación C: Error de llave foránea al asignar un vendedor inexistente (id_vendedor = 999)
-- al convertir al visitante anónimo #26 -> se recupera con ROLLBACK TO SAVEPOINT y asigna al vendedor #1
CALL sp_convertir_visitante_con_savepoint(
    26, 'Mauricio', 'Cárdenas', 'mcardenas@logisticaexpress.co',
    'Logística Express S.A.S.', 'Colombia', 999, @res_savepoint
);
SELECT @res_savepoint AS resultado_simulacion_C;

-- Simulación D: Ejecución exitosa con la propuesta #33 corrigiendo el valor a 2750.00
CALL sp_cerrar_venta_segura(33, 2750.00, 'Tarjeta corporativa', @res_exito);
SELECT @res_exito AS resultado_simulacion_D;

-- Consulta de la bitácora de auditoría para evidenciar los errores simulados y su recuperación:
SELECT id_error, fecha_evento, operacion, codigo_sqlstate, numero_error, mensaje_error, accion_tomada
FROM bitacora_errores_transaccion;
