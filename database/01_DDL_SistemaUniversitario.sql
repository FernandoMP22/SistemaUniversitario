-- ============================================================
-- SISTEMA UNIVERSITARIO
-- Ejecutar dentro de la base sistema_universitario
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 1: ORGANIZACIÓN UNIVERSITARIA Y PERSONAS
-- ============================================================


CREATE TABLE public.sede (
    id_sede integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo varchar(20) NOT NULL UNIQUE,
    nombre varchar(100) NOT NULL,
    direccion varchar(255) NOT NULL
);


CREATE TABLE public.facultad (
    id_facultad integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo varchar(20) NOT NULL UNIQUE,
    nombre varchar(100) NOT NULL,
    descripcion text
);


CREATE TABLE public.carrera (
    id_carrera integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_facultad integer NOT NULL,
    codigo varchar(20) NOT NULL UNIQUE,
    nombre varchar(150) NOT NULL,
    descripcion text,

    CONSTRAINT fk_carrera_facultad
        FOREIGN KEY (id_facultad)
        REFERENCES public.facultad (id_facultad)
        ON DELETE RESTRICT
);


CREATE TABLE public.estudiante (
    id_estudiante integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_carrera integer NOT NULL,
    carne varchar(25) NOT NULL UNIQUE,
    nombres varchar(100) NOT NULL,
    apellidos varchar(100) NOT NULL,
    fecha_nacimiento date NOT NULL,
    correo varchar(150) NOT NULL,
    telefono varchar(25),
    direccion varchar(255),

    CONSTRAINT fk_estudiante_carrera
        FOREIGN KEY (id_carrera)
        REFERENCES public.carrera (id_carrera)
        ON DELETE RESTRICT
);


CREATE TABLE public.docente (
    id_docente integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo varchar(20) NOT NULL UNIQUE,
    nombres varchar(100) NOT NULL,
    apellidos varchar(100) NOT NULL,
    correo varchar(150) NOT NULL,
    telefono varchar(25)
);


-- ============================================================
-- FIN BLOQUE 1
-- ============================================================





-- ============================================================
-- INICIO BLOQUE 2: CURSOS, PLANES DE ESTUDIO Y PRERREQUISITOS
-- ============================================================


CREATE TABLE public.curso (
    id_curso integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo varchar(20) NOT NULL UNIQUE,
    nombre varchar(150) NOT NULL,
    descripcion text
);


CREATE TABLE public.plan_estudio (
    id_plan_estudio integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_carrera integer NOT NULL,
    id_curso integer NOT NULL,
    semestre_sugerido smallint NOT NULL
        CHECK (semestre_sugerido > 0),

    UNIQUE (id_carrera, id_curso),

    CONSTRAINT fk_plan_estudio_carrera
        FOREIGN KEY (id_carrera)
        REFERENCES public.carrera (id_carrera)
        ON DELETE RESTRICT,

    CONSTRAINT fk_plan_estudio_curso
        FOREIGN KEY (id_curso)
        REFERENCES public.curso (id_curso)
        ON DELETE RESTRICT
);


CREATE TABLE public.prerrequisito (
    id_prerrequisito integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_curso integer NOT NULL,
    id_curso_requisito integer NOT NULL,

    UNIQUE (id_curso, id_curso_requisito),
    CHECK (id_curso <> id_curso_requisito),

    CONSTRAINT fk_prerrequisito_curso
        FOREIGN KEY (id_curso)
        REFERENCES public.curso (id_curso)
        ON DELETE RESTRICT,

    CONSTRAINT fk_prerrequisito_curso_requisito
        FOREIGN KEY (id_curso_requisito)
        REFERENCES public.curso (id_curso)
        ON DELETE RESTRICT
);


-- ============================================================
-- FIN BLOQUE 2
-- ============================================================





-- ============================================================
-- INICIO BLOQUE 3: PERÍODOS, SALONES, SECCIONES Y HORARIOS
-- ============================================================


CREATE TABLE public.periodo_academico (
    id_periodo_academico integer
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo varchar(20) NOT NULL UNIQUE,
    nombre varchar(100) NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,

    CHECK (fecha_fin > fecha_inicio)
);


CREATE TABLE public.salon (
    id_salon integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede integer NOT NULL,
    codigo varchar(20) NOT NULL,
    capacidad integer NOT NULL CHECK (capacidad > 0),

    UNIQUE (id_sede, codigo),

    CONSTRAINT fk_salon_sede
        FOREIGN KEY (id_sede)
        REFERENCES public.sede (id_sede)
        ON DELETE RESTRICT
);


CREATE TABLE public.seccion (
    id_seccion integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_curso integer NOT NULL,
    id_periodo_academico integer NOT NULL,
    id_docente integer NOT NULL,
    codigo varchar(20) NOT NULL,
    cupo_maximo integer NOT NULL CHECK (cupo_maximo > 0),
    calificaciones_cerradas boolean NOT NULL DEFAULT false,

    UNIQUE (id_curso, id_periodo_academico, codigo),

    CONSTRAINT fk_seccion_curso
        FOREIGN KEY (id_curso)
        REFERENCES public.curso (id_curso)
        ON DELETE RESTRICT,

    CONSTRAINT fk_seccion_periodo
        FOREIGN KEY (id_periodo_academico)
        REFERENCES public.periodo_academico (id_periodo_academico)
        ON DELETE RESTRICT,

    CONSTRAINT fk_seccion_docente
        FOREIGN KEY (id_docente)
        REFERENCES public.docente (id_docente)
        ON DELETE RESTRICT
);


CREATE TABLE public.horario_seccion (
    id_horario_seccion integer
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_seccion integer NOT NULL,
    id_salon integer NOT NULL,
    dia_semana smallint NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    hora_inicio time NOT NULL,
    hora_fin time NOT NULL,

    UNIQUE (id_seccion, dia_semana, hora_inicio, hora_fin),
    CHECK (hora_fin > hora_inicio),

    CONSTRAINT fk_horario_seccion_seccion
        FOREIGN KEY (id_seccion)
        REFERENCES public.seccion (id_seccion)
        ON DELETE RESTRICT,

    CONSTRAINT fk_horario_seccion_salon
        FOREIGN KEY (id_salon)
        REFERENCES public.salon (id_salon)
        ON DELETE RESTRICT
);


-- ============================================================
-- FIN BLOQUE 3
-- ============================================================





-- ============================================================
-- INICIO BLOQUE 4: INSCRIPCIONES Y ASIGNACIONES
-- ============================================================


CREATE TABLE public.inscripcion (
    id_inscripcion integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estudiante integer NOT NULL,
    id_periodo_academico integer NOT NULL,
    fecha_inscripcion date NOT NULL DEFAULT CURRENT_DATE,
    estado varchar(15) NOT NULL DEFAULT 'activa'
        CHECK (estado IN ('activa', 'cancelada', 'finalizada')),

    UNIQUE (id_estudiante, id_periodo_academico),

    CONSTRAINT fk_inscripcion_estudiante
        FOREIGN KEY (id_estudiante)
        REFERENCES public.estudiante (id_estudiante)
        ON DELETE RESTRICT,

    CONSTRAINT fk_inscripcion_periodo
        FOREIGN KEY (id_periodo_academico)
        REFERENCES public.periodo_academico (id_periodo_academico)
        ON DELETE RESTRICT
);


CREATE TABLE public.asignacion_curso (
    id_asignacion_curso integer
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_inscripcion integer NOT NULL,
    id_seccion integer NOT NULL,
    fecha_asignacion date NOT NULL DEFAULT CURRENT_DATE,
    estado varchar(15) NOT NULL DEFAULT 'cursando'
        CHECK (estado IN (
            'cursando', 'aprobada', 'reprobada', 'cancelada'
        )),

    UNIQUE (id_inscripcion, id_seccion),

    CONSTRAINT fk_asignacion_curso_inscripcion
        FOREIGN KEY (id_inscripcion)
        REFERENCES public.inscripcion (id_inscripcion)
        ON DELETE RESTRICT,

    CONSTRAINT fk_asignacion_curso_seccion
        FOREIGN KEY (id_seccion)
        REFERENCES public.seccion (id_seccion)
        ON DELETE RESTRICT
);


-- ============================================================
-- FIN BLOQUE 4
-- ============================================================





-- ============================================================
-- INICIO BLOQUE 5: ACTIVIDADES Y CALIFICACIONES
-- ============================================================


CREATE TABLE public.actividad_academica (
    id_actividad_academica integer
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_seccion integer NOT NULL,
    nombre varchar(150) NOT NULL,
    tipo varchar(15) NOT NULL
        CHECK (tipo IN ('tarea', 'proyecto', 'examen', 'otra')),
    fecha date NOT NULL,
    puntaje_maximo numeric(5,2) NOT NULL
        CHECK (puntaje_maximo > 0 AND puntaje_maximo <= 100),

    CONSTRAINT fk_actividad_academica_seccion
        FOREIGN KEY (id_seccion)
        REFERENCES public.seccion (id_seccion)
        ON DELETE RESTRICT
);


CREATE TABLE public.calificacion (
    id_calificacion integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_actividad_academica integer NOT NULL,
    id_asignacion_curso integer NOT NULL,
    puntaje_obtenido numeric(5,2) NOT NULL
        CHECK (puntaje_obtenido BETWEEN 0 AND 100),

    UNIQUE (id_actividad_academica, id_asignacion_curso),

    CONSTRAINT fk_calificacion_actividad
        FOREIGN KEY (id_actividad_academica)
        REFERENCES public.actividad_academica (id_actividad_academica)
        ON DELETE RESTRICT,

    CONSTRAINT fk_calificacion_asignacion
        FOREIGN KEY (id_asignacion_curso)
        REFERENCES public.asignacion_curso (id_asignacion_curso)
        ON DELETE RESTRICT
);


-- ============================================================
-- FIN BLOQUE 5
-- ============================================================





-- ============================================================
-- INICIO BLOQUE 6: PAGOS E ÍNDICES ÚNICOS PARCIALES
-- ============================================================


CREATE TABLE public.pago (
    id_pago integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_inscripcion integer NOT NULL,
    numero_comprobante varchar(50) NOT NULL UNIQUE,
    concepto varchar(15) NOT NULL
        CHECK (concepto IN ('matricula', 'mensualidad')),
    monto numeric(10,2) NOT NULL CHECK (monto > 0),
    fecha_pago date NOT NULL DEFAULT CURRENT_DATE,
    estado varchar(15) NOT NULL DEFAULT 'registrado'
        CHECK (estado IN ('registrado', 'anulado')),
    anio_mensualidad smallint CHECK (anio_mensualidad > 0),
    mes_mensualidad smallint CHECK (mes_mensualidad BETWEEN 1 AND 12),

    CHECK (
        (
            concepto = 'matricula'
            AND anio_mensualidad IS NULL
            AND mes_mensualidad IS NULL
        )
        OR
        (
            concepto = 'mensualidad'
            AND anio_mensualidad IS NOT NULL
            AND mes_mensualidad IS NOT NULL
        )
    ),

    CONSTRAINT fk_pago_inscripcion
        FOREIGN KEY (id_inscripcion)
        REFERENCES public.inscripcion (id_inscripcion)
        ON DELETE RESTRICT
);


-- Una sola matrícula registrada por inscripción.

CREATE UNIQUE INDEX uq_pago_matricula_registrada
    ON public.pago (id_inscripcion)
    WHERE concepto = 'matricula'
      AND estado = 'registrado';


-- Una sola mensualidad registrada por inscripción, año y mes.

CREATE UNIQUE INDEX uq_pago_mensualidad_registrada
    ON public.pago (
        id_inscripcion,
        anio_mensualidad,
        mes_mensualidad
    )
    WHERE concepto = 'mensualidad'
      AND estado = 'registrado';


-- ============================================================
-- FIN BLOQUE 6
-- ============================================================