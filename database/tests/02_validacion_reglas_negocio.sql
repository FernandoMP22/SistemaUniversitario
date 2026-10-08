-- MODO DE EJECUCIÓN:
-- Pruebas automáticas: seleccionar cada bloque completo,
-- desde BEGIN hasta ROLLBACK.
-- Pruebas manuales C1 y C2: ejecutar por partes en tres Query Tool
-- independientes, únicamente en sistema_universitario_pruebas.
-- Ejecutar C1 antes de C2 en una base de pruebas limpia.
-- NO EJECUTAR TODO ESTE ARCHIVO DE UNA SOLA VEZ.



-- Verificar la base actual y la restricción aplicada.

SELECT current_database() AS base_actual;

SELECT
    conname AS restriccion,
    pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'public.periodo_academico'::regclass
  AND contype = 'x';


-- ============================================================
--                          PRUEBAS
-- ============================================================


BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
BEGIN

    -- Período válido de referencia.

    INSERT INTO public.periodo_academico (
        codigo, nombre, fecha_inicio, fecha_fin
    )
    VALUES (
        '__TEST_PERIODO_A__',
        'Período de prueba A',
        DATE '2027-01-01',
        DATE '2027-06-30'
    );


    -- Rechazar un período que se superpone.

    BEGIN
        INSERT INTO public.periodo_academico (
            codigo, nombre, fecha_inicio, fecha_fin
        )
        VALUES (
            '__TEST_PERIODO_B__',
            'Período de prueba B',
            DATE '2027-06-01',
            DATE '2027-12-31'
        );

        RAISE EXCEPTION
            'FALLO: se permitió un período superpuesto.';

    EXCEPTION
        WHEN exclusion_violation THEN
            RAISE NOTICE
                'OK 1: se rechazan períodos superpuestos.';
    END;


    -- Rechazar también una fecha límite compartida.

    BEGIN
        INSERT INTO public.periodo_academico (
            codigo, nombre, fecha_inicio, fecha_fin
        )
        VALUES (
            '__TEST_PERIODO_C__',
            'Período de prueba C',
            DATE '2027-06-30',
            DATE '2027-12-31'
        );

        RAISE EXCEPTION
            'FALLO: se permitió compartir la fecha final.';

    EXCEPTION
        WHEN exclusion_violation THEN
            RAISE NOTICE
                'OK 2: se rechaza una fecha límite compartida.';
    END;


    -- Permitir un período que comienza al día siguiente.

    INSERT INTO public.periodo_academico (
        codigo, nombre, fecha_inicio, fecha_fin
    )
    VALUES (
        '__TEST_PERIODO_D__',
        'Período de prueba D',
        DATE '2027-07-01',
        DATE '2027-12-31'
    );

    RAISE NOTICE
        'OK 3: se permiten períodos consecutivos sin superposición.';

END;
$$;

ROLLBACK;


-- ============================================================
-- INICIO BLOQUE 2: PRUEBAS DE PRERREQUISITOS SIN CICLOS
-- ============================================================


BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    curso_a integer;
    curso_b integer;
    curso_c integer;
    relacion_b_a integer;
BEGIN

    -- Crear tres cursos temporales.

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_CURSO_A__', 'Curso de prueba A')
    RETURNING id_curso INTO curso_a;

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_CURSO_B__', 'Curso de prueba B')
    RETURNING id_curso INTO curso_b;

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_CURSO_C__', 'Curso de prueba C')
    RETURNING id_curso INTO curso_c;


    -- Relaciones válidas:
    -- B requiere A.
    -- C requiere B.

    INSERT INTO public.prerrequisito (
        id_curso, id_curso_requisito
    )
    VALUES (curso_b, curso_a)
    RETURNING id_prerrequisito INTO relacion_b_a;

    INSERT INTO public.prerrequisito (
        id_curso, id_curso_requisito
    )
    VALUES (curso_c, curso_b);

    RAISE NOTICE
        'OK 1: se permite una cadena válida de prerrequisitos.';


    -- Rechazar A requiere B: ciclo de dos cursos.

    BEGIN
        INSERT INTO public.prerrequisito (
            id_curso, id_curso_requisito
        )
        VALUES (curso_a, curso_b);

        RAISE EXCEPTION
            'FALLO: se permitió un ciclo de dos cursos.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 2: se rechaza un ciclo de dos cursos.';
    END;


    -- Rechazar A requiere C: ciclo de tres cursos.

    BEGIN
        INSERT INTO public.prerrequisito (
            id_curso, id_curso_requisito
        )
        VALUES (curso_a, curso_c);

        RAISE EXCEPTION
            'FALLO: se permitió un ciclo de tres cursos.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 3: se rechaza un ciclo indirecto.';
    END;


    -- Rechazar cambiar B requiere A por B requiere C.
    -- Ya existe C requiere B.

    BEGIN
        UPDATE public.prerrequisito
        SET id_curso_requisito = curso_c
        WHERE id_prerrequisito = relacion_b_a;

        RAISE EXCEPTION
            'FALLO: se permitió crear un ciclo mediante UPDATE.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 4: se rechaza un UPDATE que forma un ciclo.';
    END;


    -- Permitir un requisito directo adicional sin ciclo.

    INSERT INTO public.prerrequisito (
        id_curso, id_curso_requisito
    )
    VALUES (curso_c, curso_a);

    RAISE NOTICE
        'OK 5: se permite un requisito adicional sin ciclo.';

END;
$$;

ROLLBACK;


-- ============================================================
-- FIN BLOQUE 2
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 3: PRUEBAS DE PRERREQUISITOS EN PLANES
-- ============================================================


BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    facultad_prueba integer;
    carrera_prueba integer;
    curso_a integer;
    curso_b integer;
    curso_c integer;
BEGIN

    -- Crear organización y cursos temporales.

    INSERT INTO public.facultad (codigo, nombre)
    VALUES ('__TEST_PLAN_F__', 'Facultad de prueba')
    RETURNING id_facultad INTO facultad_prueba;

    INSERT INTO public.carrera (
        id_facultad, codigo, nombre
    )
    VALUES (
        facultad_prueba,
        '__TEST_PLAN_C__',
        'Carrera de prueba'
    )
    RETURNING id_carrera INTO carrera_prueba;

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_PLAN_A__', 'Curso de prueba A')
    RETURNING id_curso INTO curso_a;

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_PLAN_B__', 'Curso de prueba B')
    RETURNING id_curso INTO curso_b;

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_PLAN_D__', 'Curso de prueba C')
    RETURNING id_curso INTO curso_c;


    -- B requiere A.

    INSERT INTO public.prerrequisito (
        id_curso, id_curso_requisito
    )
    VALUES (curso_b, curso_a);


    -- PRUEBA 1: rechazar un plan que incluye B pero no A.

    BEGIN
        INSERT INTO public.plan_estudio (
            id_carrera, id_curso, semestre_sugerido
        )
        VALUES (carrera_prueba, curso_b, 2);

        SET CONSTRAINTS
            trg_plan_prerrequisitos_completos,
            trg_prerrequisito_planes_completos
        IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió un plan sin el requisito.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 1: se rechaza un plan sin el requisito.';
    END;


    -- PRUEBA 2: aceptar B y A en la misma transacción.
    -- Insertamos B primero para comprobar la validación diferida.

    INSERT INTO public.plan_estudio (
        id_carrera, id_curso, semestre_sugerido
    )
    VALUES
        (carrera_prueba, curso_b, 2),
        (carrera_prueba, curso_a, 1);

    SET CONSTRAINTS
        trg_plan_prerrequisitos_completos,
        trg_prerrequisito_planes_completos
    IMMEDIATE;

    RAISE NOTICE
        'OK 2: se acepta un plan con sus requisitos completos.';

    SET CONSTRAINTS
        trg_plan_prerrequisitos_completos,
        trg_prerrequisito_planes_completos
    DEFERRED;


    -- PRUEBA 3: rechazar quitar A mientras B permanece.

    BEGIN
        DELETE FROM public.plan_estudio
        WHERE id_carrera = carrera_prueba
          AND id_curso = curso_a;

        SET CONSTRAINTS
            trg_plan_prerrequisitos_completos,
            trg_prerrequisito_planes_completos
        IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió quitar un requisito necesario.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 3: se impide quitar un requisito necesario.';
    END;


    -- PRUEBA 4: rechazar un nuevo requisito ausente del plan.
    -- Intentamos agregar B requiere C; C no está en el plan.

    BEGIN
        INSERT INTO public.prerrequisito (
            id_curso, id_curso_requisito
        )
        VALUES (curso_b, curso_c);

        SET CONSTRAINTS
            trg_plan_prerrequisitos_completos,
            trg_prerrequisito_planes_completos
        IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió un requisito ausente del plan.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 4: se rechaza un nuevo requisito ausente del plan.';
    END;


    -- Comprobar las validaciones pendientes antes del ROLLBACK.

    SET CONSTRAINTS
        trg_plan_prerrequisitos_completos,
        trg_prerrequisito_planes_completos
    IMMEDIATE;

END;
$$;

ROLLBACK;


-- ============================================================
-- FIN BLOQUE 3
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 4: PRUEBAS DE CAPACIDAD Y SEDE
-- ============================================================


BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    sede_a integer;
    sede_b integer;
    salon_a integer;
    salon_pequeno integer;
    salon_b integer;
    docente_prueba integer;
    curso_prueba integer;
    periodo_prueba integer;
    seccion_prueba integer;
BEGIN

    -- Preparar dos sedes.

    INSERT INTO public.sede (codigo, nombre, direccion)
    VALUES ('__TEST_H_SEDE_A__', 'Sede temporal A', 'Dirección A')
    RETURNING id_sede INTO sede_a;

    INSERT INTO public.sede (codigo, nombre, direccion)
    VALUES ('__TEST_H_SEDE_B__', 'Sede temporal B', 'Dirección B')
    RETURNING id_sede INTO sede_b;


    -- Salón suficiente y salón pequeño en la sede A.
    -- Otro salón suficiente en la sede B.

    INSERT INTO public.salon (id_sede, codigo, capacidad)
    VALUES (sede_a, '__TEST_H_GRANDE__', 40)
    RETURNING id_salon INTO salon_a;

    INSERT INTO public.salon (id_sede, codigo, capacidad)
    VALUES (sede_a, '__TEST_H_PEQUENO__', 20)
    RETURNING id_salon INTO salon_pequeno;

    INSERT INTO public.salon (id_sede, codigo, capacidad)
    VALUES (sede_b, '__TEST_H_OTRA__', 40)
    RETURNING id_salon INTO salon_b;


    -- Preparar docente y curso.

    INSERT INTO public.docente (
        codigo, nombres, apellidos, correo
    )
    VALUES (
        '__TEST_H_DOCENTE__',
        'Docente',
        'Temporal',
        'docente.prueba@example.com'
    )
    RETURNING id_docente INTO docente_prueba;

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_H_CURSO__', 'Curso temporal de horarios')
    RETURNING id_curso INTO curso_prueba;


    -- Utilizar un período existente, si lo hay.
    -- Si no existe ninguno, crear uno temporal.

    SELECT id_periodo_academico
    INTO periodo_prueba
    FROM public.periodo_academico
    ORDER BY id_periodo_academico
    LIMIT 1;

    IF periodo_prueba IS NULL THEN
        INSERT INTO public.periodo_academico (
            codigo, nombre, fecha_inicio, fecha_fin
        )
        VALUES (
            '__TEST_H_PERIODO__',
            'Período temporal',
            DATE '2090-01-01',
            DATE '2090-06-30'
        )
        RETURNING id_periodo_academico INTO periodo_prueba;
    END IF;


    -- Crear una sección con cupo de 30.

    INSERT INTO public.seccion (
        id_curso,
        id_periodo_academico,
        id_docente,
        codigo,
        cupo_maximo
    )
    VALUES (
        curso_prueba,
        periodo_prueba,
        docente_prueba,
        '__TEST_H_SECCION__',
        30
    )
    RETURNING id_seccion INTO seccion_prueba;


    -- PRUEBA 1: aceptar un salón con capacidad suficiente.

    INSERT INTO public.horario_seccion (
        id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
    )
    VALUES (
        seccion_prueba, salon_a, 1, TIME '08:00', TIME '09:00'
    );

    SET CONSTRAINTS
        trg_horario_capacidad_sede,
        trg_seccion_capacidad_sede,
        trg_salon_capacidad_sede
    IMMEDIATE;

    RAISE NOTICE
        'OK 1: se acepta un salón con capacidad suficiente.';

    SET CONSTRAINTS
        trg_horario_capacidad_sede,
        trg_seccion_capacidad_sede,
        trg_salon_capacidad_sede
    DEFERRED;


    -- PRUEBA 2: rechazar un salón demasiado pequeño.

    BEGIN
        INSERT INTO public.horario_seccion (
            id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
        )
        VALUES (
            seccion_prueba,
            salon_pequeno,
            2,
            TIME '08:00',
            TIME '09:00'
        );

        SET CONSTRAINTS
            trg_horario_capacidad_sede,
            trg_seccion_capacidad_sede,
            trg_salon_capacidad_sede
        IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió un salón demasiado pequeño.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 2: se rechaza un salón demasiado pequeño.';
    END;


    -- PRUEBA 3: rechazar otra sede para la misma sección.

    BEGIN
        INSERT INTO public.horario_seccion (
            id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
        )
        VALUES (
            seccion_prueba,
            salon_b,
            2,
            TIME '08:00',
            TIME '09:00'
        );

        SET CONSTRAINTS
            trg_horario_capacidad_sede,
            trg_seccion_capacidad_sede,
            trg_salon_capacidad_sede
        IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitieron dos sedes en la sección.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 3: se rechazan distintas sedes en una sección.';
    END;


    -- PRUEBA 4: rechazar aumentar el cupo por encima de 40.

    BEGIN
        UPDATE public.seccion
        SET cupo_maximo = 45
        WHERE id_seccion = seccion_prueba;

        SET CONSTRAINTS
            trg_horario_capacidad_sede,
            trg_seccion_capacidad_sede,
            trg_salon_capacidad_sede
        IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió un cupo mayor que la capacidad.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 4: se rechaza un aumento de cupo incompatible.';
    END;


    -- PRUEBA 5: rechazar reducir la capacidad por debajo de 30.

    BEGIN
        UPDATE public.salon
        SET capacidad = 25
        WHERE id_salon = salon_a;

        SET CONSTRAINTS
            trg_horario_capacidad_sede,
            trg_seccion_capacidad_sede,
            trg_salon_capacidad_sede
        IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió una reducción incompatible.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 5: se rechaza una reducción de capacidad incompatible.';
    END;


    -- Ejecutar las comprobaciones pendientes.

    SET CONSTRAINTS
        trg_horario_capacidad_sede,
        trg_seccion_capacidad_sede,
        trg_salon_capacidad_sede
    IMMEDIATE;

END;
$$;

ROLLBACK;


-- ============================================================
-- FIN BLOQUE 4
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 5: PRUEBAS DE CONFLICTOS DE HORARIOS
-- ============================================================


BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    sede_prueba integer;
    salon_a integer;
    salon_b integer;
    docente_a integer;
    docente_b integer;
    curso_prueba integer;
    periodo_prueba integer;
    seccion_a integer;
    seccion_b integer;
    seccion_c integer;
BEGIN

    -- Preparar sede y dos salones suficientes.

    INSERT INTO public.sede (codigo, nombre, direccion)
    VALUES (
        '__TEST_CR_SEDE__',
        'Sede temporal',
        'Dirección temporal'
    )
    RETURNING id_sede INTO sede_prueba;

    INSERT INTO public.salon (id_sede, codigo, capacidad)
    VALUES (sede_prueba, '__TEST_CR_SALON_A__', 40)
    RETURNING id_salon INTO salon_a;

    INSERT INTO public.salon (id_sede, codigo, capacidad)
    VALUES (sede_prueba, '__TEST_CR_SALON_B__', 40)
    RETURNING id_salon INTO salon_b;


    -- Preparar dos docentes.

    INSERT INTO public.docente (
        codigo, nombres, apellidos, correo
    )
    VALUES (
        '__TEST_CR_DOC_A__',
        'Docente A',
        'Temporal',
        'docente.a@example.com'
    )
    RETURNING id_docente INTO docente_a;

    INSERT INTO public.docente (
        codigo, nombres, apellidos, correo
    )
    VALUES (
        '__TEST_CR_DOC_B__',
        'Docente B',
        'Temporal',
        'docente.b@example.com'
    )
    RETURNING id_docente INTO docente_b;


    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_CR_CURSO__', 'Curso temporal')
    RETURNING id_curso INTO curso_prueba;


    -- Utilizar un período existente o crear uno temporal.

    SELECT id_periodo_academico
    INTO periodo_prueba
    FROM public.periodo_academico
    ORDER BY id_periodo_academico
    LIMIT 1;

    IF periodo_prueba IS NULL THEN
        INSERT INTO public.periodo_academico (
            codigo, nombre, fecha_inicio, fecha_fin
        )
        VALUES (
            '__TEST_CR_PERIODO__',
            'Período temporal',
            DATE '2090-01-01',
            DATE '2090-06-30'
        )
        RETURNING id_periodo_academico INTO periodo_prueba;
    END IF;


    -- A y C tienen el mismo docente.
    -- B tiene otro docente.

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico,
        id_docente, codigo, cupo_maximo
    )
    VALUES (
        curso_prueba, periodo_prueba,
        docente_a, '__TEST_CR_A__', 30
    )
    RETURNING id_seccion INTO seccion_a;

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico,
        id_docente, codigo, cupo_maximo
    )
    VALUES (
        curso_prueba, periodo_prueba,
        docente_b, '__TEST_CR_B__', 30
    )
    RETURNING id_seccion INTO seccion_b;

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico,
        id_docente, codigo, cupo_maximo
    )
    VALUES (
        curso_prueba, periodo_prueba,
        docente_a, '__TEST_CR_C__', 30
    )
    RETURNING id_seccion INTO seccion_c;


    -- PRUEBA 1: horario válido de referencia.

    INSERT INTO public.horario_seccion (
        id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
    )
    VALUES (
        seccion_a, salon_a, 1, TIME '08:00', TIME '09:00'
    );

    SET CONSTRAINTS ALL IMMEDIATE;

    RAISE NOTICE
        'OK 1: se acepta el horario de referencia.';

    SET CONSTRAINTS ALL DEFERRED;


    -- PRUEBA 2: misma sección, horario superpuesto.

    BEGIN
        INSERT INTO public.horario_seccion (
            id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
        )
        VALUES (
            seccion_a, salon_b, 1, TIME '08:30', TIME '09:30'
        );

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió un cruce en la misma sección.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 2: se rechaza un cruce en la misma sección.';
    END;


    -- PRUEBA 3: otro docente, pero mismo salón ocupado.

    BEGIN
        INSERT INTO public.horario_seccion (
            id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
        )
        VALUES (
            seccion_b, salon_a, 1, TIME '08:30', TIME '09:30'
        );

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió un salón ocupado.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 3: se rechaza un cruce de salón.';
    END;


    -- PRUEBA 4: otro salón, pero mismo docente ocupado.

    BEGIN
        INSERT INTO public.horario_seccion (
            id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
        )
        VALUES (
            seccion_c, salon_b, 1, TIME '08:30', TIME '09:30'
        );

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió un docente ocupado.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 4: se rechaza un cruce de docente.';
    END;


    -- PRUEBA 5: permitir bloques consecutivos en el mismo salón.

    INSERT INTO public.horario_seccion (
        id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
    )
    VALUES (
        seccion_b, salon_a, 1, TIME '09:00', TIME '10:00'
    );

    SET CONSTRAINTS ALL IMMEDIATE;

    RAISE NOTICE
        'OK 5: se permiten bloques consecutivos.';

    SET CONSTRAINTS ALL DEFERRED;


    -- PRUEBA 6: simultaneidad válida con otro salón y docente.

    INSERT INTO public.horario_seccion (
        id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
    )
    VALUES (
        seccion_b, salon_b, 1, TIME '08:00', TIME '09:00'
    );

    SET CONSTRAINTS ALL IMMEDIATE;

    RAISE NOTICE
        'OK 6: se permite simultaneidad con distinto salón y docente.';

    SET CONSTRAINTS ALL DEFERRED;


    -- PRUEBA 7: cambiar el docente de B introduce un conflicto.

    BEGIN
        UPDATE public.seccion
        SET id_docente = docente_a
        WHERE id_seccion = seccion_b;

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió un cambio de docente incompatible.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 7: se rechaza un cambio de docente incompatible.';
    END;


    SET CONSTRAINTS ALL IMMEDIATE;

END;
$$;

ROLLBACK;


-- ============================================================
-- FIN BLOQUE 5
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 6: PRUEBAS DE COHERENCIA DE ASIGNACIONES
-- Preparación: usa períodos temporales de 2090 y 2091.
-- Si ya hay períodos que cubren esas fechas, ajustar las fechas.
-- ============================================================


BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    facultad_prueba integer;
    carrera_prueba integer;
    estudiante_prueba integer;
    docente_prueba integer;
    sede_prueba integer;
    salon_prueba integer;
    curso_plan integer;
    curso_fuera integer;
    periodo_a integer;
    periodo_b integer;
    inscripcion_prueba integer;
    seccion_valida integer;
    seccion_otro_periodo integer;
    seccion_fuera_plan integer;
    seccion_sin_horario integer;
BEGIN

    -- Organización y personas temporales.

    INSERT INTO public.facultad (codigo, nombre)
    VALUES ('__TEST_AS_F__', 'Facultad temporal')
    RETURNING id_facultad INTO facultad_prueba;

    INSERT INTO public.carrera (id_facultad, codigo, nombre)
    VALUES (facultad_prueba, '__TEST_AS_C__', 'Carrera temporal')
    RETURNING id_carrera INTO carrera_prueba;

    INSERT INTO public.estudiante (
        id_carrera, carne, nombres, apellidos,
        fecha_nacimiento, correo
    )
    VALUES (
        carrera_prueba, '__TEST_AS_E__', 'Estudiante', 'Temporal',
        DATE '2000-01-01', 'estudiante.prueba@example.com'
    )
    RETURNING id_estudiante INTO estudiante_prueba;

    INSERT INTO public.docente (codigo, nombres, apellidos, correo)
    VALUES (
        '__TEST_AS_D__', 'Docente', 'Temporal',
        'docente.prueba@example.com'
    )
    RETURNING id_docente INTO docente_prueba;

    INSERT INTO public.sede (codigo, nombre, direccion)
    VALUES ('__TEST_AS_SEDE__', 'Sede temporal', 'Dirección temporal')
    RETURNING id_sede INTO sede_prueba;

    INSERT INTO public.salon (id_sede, codigo, capacidad)
    VALUES (sede_prueba, '__TEST_AS_SALON__', 40)
    RETURNING id_salon INTO salon_prueba;


    -- Un curso del plan y otro fuera del plan.

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_AS_CURSO_A__', 'Curso del plan')
    RETURNING id_curso INTO curso_plan;

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_AS_CURSO_B__', 'Curso fuera del plan')
    RETURNING id_curso INTO curso_fuera;

    INSERT INTO public.plan_estudio (
        id_carrera, id_curso, semestre_sugerido
    )
    VALUES (carrera_prueba, curso_plan, 1);


    -- Dos períodos diferentes y sin superposición.

    INSERT INTO public.periodo_academico (
        codigo, nombre, fecha_inicio, fecha_fin
    )
    VALUES (
        '__TEST_AS_P_A__', 'Período temporal A',
        DATE '2090-01-01', DATE '2090-06-30'
    )
    RETURNING id_periodo_academico INTO periodo_a;

    INSERT INTO public.periodo_academico (
        codigo, nombre, fecha_inicio, fecha_fin
    )
    VALUES (
        '__TEST_AS_P_B__', 'Período temporal B',
        DATE '2091-01-01', DATE '2091-06-30'
    )
    RETURNING id_periodo_academico INTO periodo_b;

    INSERT INTO public.inscripcion (
        id_estudiante, id_periodo_academico
    )
    VALUES (estudiante_prueba, periodo_a)
    RETURNING id_inscripcion INTO inscripcion_prueba;


    -- Preparar cuatro secciones para los diferentes casos.

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico, id_docente, codigo, cupo_maximo
    )
    VALUES (curso_plan, periodo_a, docente_prueba, '__TEST_AS_A__', 30)
    RETURNING id_seccion INTO seccion_valida;

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico, id_docente, codigo, cupo_maximo
    )
    VALUES (curso_plan, periodo_b, docente_prueba, '__TEST_AS_B__', 30)
    RETURNING id_seccion INTO seccion_otro_periodo;

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico, id_docente, codigo, cupo_maximo
    )
    VALUES (curso_fuera, periodo_a, docente_prueba, '__TEST_AS_C__', 30)
    RETURNING id_seccion INTO seccion_fuera_plan;

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico, id_docente, codigo, cupo_maximo
    )
    VALUES (curso_plan, periodo_a, docente_prueba, '__TEST_AS_D__', 30)
    RETURNING id_seccion INTO seccion_sin_horario;


    -- Horarios sin conflictos para las tres primeras secciones.

    INSERT INTO public.horario_seccion (
        id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
    )
    VALUES
        (seccion_valida, salon_prueba, 1, TIME '08:00', TIME '09:00'),
        (seccion_otro_periodo, salon_prueba, 1, TIME '08:00', TIME '09:00'),
        (seccion_fuera_plan, salon_prueba, 1, TIME '09:00', TIME '10:00');


    -- Verificar que la preparación cumple las reglas anteriores.

    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;


    -- PRUEBA 1: rechazar otro período.

    BEGIN
        INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
        VALUES (inscripcion_prueba, seccion_otro_periodo);

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió asignar otro período.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 1: se rechaza una sección de otro período.';
    END;


    -- PRUEBA 2: rechazar curso fuera del plan.

    BEGIN
        INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
        VALUES (inscripcion_prueba, seccion_fuera_plan);

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió un curso fuera del plan.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 2: se rechaza un curso fuera del plan.';
    END;


    -- PRUEBA 3: rechazar sección sin horario.

    BEGIN
        INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
        VALUES (inscripcion_prueba, seccion_sin_horario);

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió una sección sin horario.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 3: se rechaza una sección sin horario.';
    END;


    -- PRUEBA 4: aceptar una asignación válida.

    INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
    VALUES (inscripcion_prueba, seccion_valida);

    SET CONSTRAINTS ALL IMMEDIATE;

    RAISE NOTICE
        'OK 4: se acepta una asignación coherente.';

    SET CONSTRAINTS ALL DEFERRED;


    -- PRUEBA 5: impedir quitar su último horario.

    BEGIN
        DELETE FROM public.horario_seccion
        WHERE id_seccion = seccion_valida;

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION
            'FALLO: se permitió quitar el último horario.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 5: se protege el último horario de una sección asignada.';
    END;


    SET CONSTRAINTS ALL IMMEDIATE;

END;
$$;

ROLLBACK;


-- ============================================================
-- FIN BLOQUE 6
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 7: PRUEBAS DE CUPO Y CONFLICTOS
-- ============================================================


BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    facultad_prueba integer;
    carrera_prueba integer;
    estudiante_a integer;
    estudiante_b integer;
    inscripcion_a integer;
    inscripcion_b integer;
    docente_a integer;
    docente_b integer;
    sede_prueba integer;
    salon_a integer;
    salon_b integer;
    curso_a integer;
    curso_b integer;
    periodo_prueba integer;
    seccion_a integer;
    seccion_b integer;
    seccion_c integer;
    asignacion_prueba integer;
BEGIN

    -- Preparar organización y estudiantes.

    INSERT INTO public.facultad (codigo, nombre)
    VALUES ('__TEST_CC_F__', 'Facultad temporal')
    RETURNING id_facultad INTO facultad_prueba;

    INSERT INTO public.carrera (id_facultad, codigo, nombre)
    VALUES (facultad_prueba, '__TEST_CC_C__', 'Carrera temporal')
    RETURNING id_carrera INTO carrera_prueba;

    INSERT INTO public.estudiante (
        id_carrera, carne, nombres, apellidos,
        fecha_nacimiento, correo
    )
    VALUES (
        carrera_prueba, '__TEST_CC_E_A__', 'Estudiante A',
        'Temporal', DATE '2000-01-01', 'a@example.com'
    )
    RETURNING id_estudiante INTO estudiante_a;

    INSERT INTO public.estudiante (
        id_carrera, carne, nombres, apellidos,
        fecha_nacimiento, correo
    )
    VALUES (
        carrera_prueba, '__TEST_CC_E_B__', 'Estudiante B',
        'Temporal', DATE '2000-01-01', 'b@example.com'
    )
    RETURNING id_estudiante INTO estudiante_b;


    -- Preparar docentes y salones.

    INSERT INTO public.docente (codigo, nombres, apellidos, correo)
    VALUES ('__TEST_CC_D_A__', 'Docente A', 'Temporal', 'da@example.com')
    RETURNING id_docente INTO docente_a;

    INSERT INTO public.docente (codigo, nombres, apellidos, correo)
    VALUES ('__TEST_CC_D_B__', 'Docente B', 'Temporal', 'db@example.com')
    RETURNING id_docente INTO docente_b;

    INSERT INTO public.sede (codigo, nombre, direccion)
    VALUES ('__TEST_CC_SEDE__', 'Sede temporal', 'Dirección temporal')
    RETURNING id_sede INTO sede_prueba;

    INSERT INTO public.salon (id_sede, codigo, capacidad)
    VALUES (sede_prueba, '__TEST_CC_S_A__', 40)
    RETURNING id_salon INTO salon_a;

    INSERT INTO public.salon (id_sede, codigo, capacidad)
    VALUES (sede_prueba, '__TEST_CC_S_B__', 40)
    RETURNING id_salon INTO salon_b;


    -- Preparar cursos incluidos en el plan.

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_CC_CURSO_A__', 'Curso temporal A')
    RETURNING id_curso INTO curso_a;

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__TEST_CC_CURSO_B__', 'Curso temporal B')
    RETURNING id_curso INTO curso_b;

    INSERT INTO public.plan_estudio (
        id_carrera, id_curso, semestre_sugerido
    )
    VALUES
        (carrera_prueba, curso_a, 1),
        (carrera_prueba, curso_b, 1);


    -- Utilizar un período existente o crear uno temporal.

    SELECT id_periodo_academico
    INTO periodo_prueba
    FROM public.periodo_academico
    ORDER BY id_periodo_academico
    LIMIT 1;

    IF periodo_prueba IS NULL THEN
        INSERT INTO public.periodo_academico (
            codigo, nombre, fecha_inicio, fecha_fin
        )
        VALUES (
            '__TEST_CC_PERIODO__', 'Período temporal',
            DATE '2090-01-01', DATE '2090-06-30'
        )
        RETURNING id_periodo_academico INTO periodo_prueba;
    END IF;

    INSERT INTO public.inscripcion (
        id_estudiante, id_periodo_academico
    )
    VALUES (estudiante_a, periodo_prueba)
    RETURNING id_inscripcion INTO inscripcion_a;

    INSERT INTO public.inscripcion (
        id_estudiante, id_periodo_academico
    )
    VALUES (estudiante_b, periodo_prueba)
    RETURNING id_inscripcion INTO inscripcion_b;


    -- A: curso A, cupo 1, lunes 08:00–09:00.
    -- B: mismo curso, otro horario.
    -- C: curso B, horario superpuesto con A,
    -- pero con otro docente y salón.

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico, id_docente, codigo, cupo_maximo
    )
    VALUES (curso_a, periodo_prueba, docente_a, '__TEST_CC_A__', 1)
    RETURNING id_seccion INTO seccion_a;

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico, id_docente, codigo, cupo_maximo
    )
    VALUES (curso_a, periodo_prueba, docente_a, '__TEST_CC_B__', 30)
    RETURNING id_seccion INTO seccion_b;

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico, id_docente, codigo, cupo_maximo
    )
    VALUES (curso_b, periodo_prueba, docente_b, '__TEST_CC_C__', 30)
    RETURNING id_seccion INTO seccion_c;

    INSERT INTO public.horario_seccion (
        id_seccion, id_salon, dia_semana, hora_inicio, hora_fin
    )
    VALUES
        (seccion_a, salon_a, 1, TIME '08:00', TIME '09:00'),
        (seccion_b, salon_a, 1, TIME '09:00', TIME '10:00'),
        (seccion_c, salon_b, 1, TIME '08:30', TIME '09:30');

    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;


    -- PRUEBA 1: aceptar la primera asignación.

    INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
    VALUES (inscripcion_a, seccion_a)
    RETURNING id_asignacion_curso INTO asignacion_prueba;

    SET CONSTRAINTS ALL IMMEDIATE;

    RAISE NOTICE 'OK 1: se acepta la primera asignación.';

    SET CONSTRAINTS ALL DEFERRED;


    -- PRUEBA 2: rechazar otro estudiante cuando el cupo está lleno.

    BEGIN
        INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
        VALUES (inscripcion_b, seccion_a);

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION 'FALLO: se permitió superar el cupo.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'OK 2: se rechaza superar el cupo.';
    END;


    -- PRUEBA 3: rechazar el mismo curso en otra sección.

    BEGIN
        INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
        VALUES (inscripcion_a, seccion_b);

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION 'FALLO: se permitió duplicar el curso.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'OK 3: se rechaza duplicar el curso.';
    END;


    -- PRUEBA 4: rechazar otro curso con horario superpuesto.

    BEGIN
        INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
        VALUES (inscripcion_a, seccion_c);

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION 'FALLO: se permitió un cruce del estudiante.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'OK 4: se rechaza un cruce del estudiante.';
    END;


    -- PRUEBA 5: cancelar libera cupo para otro estudiante.

    UPDATE public.asignacion_curso
    SET estado = 'cancelada'
    WHERE id_asignacion_curso = asignacion_prueba;

    INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
    VALUES (inscripcion_b, seccion_a);

    SET CONSTRAINTS ALL IMMEDIATE;

    RAISE NOTICE 'OK 5: cancelar libera cupo para otro estudiante.';

    SET CONSTRAINTS ALL DEFERRED;


    -- PRUEBA 6: el horario cancelado ya no bloquea al estudiante A.

    INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
    VALUES (inscripcion_a, seccion_c);

    SET CONSTRAINTS ALL IMMEDIATE;

    RAISE NOTICE 'OK 6: una asignación cancelada no bloquea horarios.';

    SET CONSTRAINTS ALL DEFERRED;


    -- PRUEBA 7: rechazar reactivación cuando el cupo está ocupado.

    BEGIN
        UPDATE public.asignacion_curso
        SET estado = 'cursando'
        WHERE id_asignacion_curso = asignacion_prueba;

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION 'FALLO: se permitió reactivar sin cupo.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'OK 7: se rechaza reactivar sin cupo.';
    END;

    -- --------------------------------------------------------
    -- PRUEBAS DEL BLOQUE 8: INICIO Y REACTIVACIÓN
    -- Utilizan los datos temporales preparados en el bloque 7.
    -- --------------------------------------------------------


    -- PRUEBA 8: rechazar una asignación nueva como aprobada.
    -- Esta combinación de inscripción y sección todavía no existe.

    BEGIN
        INSERT INTO public.asignacion_curso (
            id_inscripcion, id_seccion, estado
        )
        VALUES (
            inscripcion_b, seccion_b, 'aprobada'
        );

        RAISE EXCEPTION
            'FALLO: se permitió iniciar una asignación aprobada.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 8: una asignación nueva debe comenzar en cursando.';
    END;


    -- PRUEBA 9: una inscripción finalizada no permite asignar.
    -- El bloque interno se deshace al capturar el rechazo.

    BEGIN
        UPDATE public.inscripcion
        SET estado = 'finalizada'
        WHERE id_inscripcion = inscripcion_b;

        INSERT INTO public.asignacion_curso (
            id_inscripcion, id_seccion
        )
        VALUES (inscripcion_b, seccion_b);

        RAISE EXCEPTION
            'FALLO: se permitió asignar con inscripción finalizada.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 9: se rechaza asignar con inscripción finalizada.';
    END;


    -- PRUEBA 10: una inscripción cancelada no permite reactivar.
    -- asignacion_prueba permanece cancelada desde la prueba 5.

    BEGIN
        UPDATE public.inscripcion
        SET estado = 'cancelada'
        WHERE id_inscripcion = inscripcion_a;

        UPDATE public.asignacion_curso
        SET estado = 'cursando'
        WHERE id_asignacion_curso = asignacion_prueba;

        RAISE EXCEPTION
            'FALLO: se permitió reactivar con inscripción cancelada.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 10: se rechaza reactivar con inscripción cancelada.';
    END;


    -- PRUEBA 11: una cancelada no puede pasar directamente a aprobada.

    BEGIN
        UPDATE public.asignacion_curso
        SET estado = 'aprobada'
        WHERE id_asignacion_curso = asignacion_prueba;

        RAISE EXCEPTION
            'FALLO: se permitió aprobar directamente una cancelada.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 11: una cancelada solo puede reactivarse a cursando.';
    END;


    -- PRUEBA 12: impedir trasladar una asignación a otra sección.

    BEGIN
        UPDATE public.asignacion_curso
        SET id_seccion = seccion_b
        WHERE id_asignacion_curso = asignacion_prueba;

        RAISE EXCEPTION
            'FALLO: se permitió trasladar una asignación.';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 12: se conserva la inscripción y sección originales.';
    END;


    SET CONSTRAINTS ALL IMMEDIATE;

END;
$$;

ROLLBACK;


-- ============================================================
-- FIN BLOQUE 7
-- ============================================================



-- ============================================================
-- INICIO BLOQUES 8 Y 9: INICIO, REACTIVACIÓN Y REQUISITOS ACADÉMICOS
--
-- Ya no simula aprobaciones: utiliza cerrar_calificaciones.
-- ============================================================

BEGIN ISOLATION LEVEL SERIALIZABLE;

CREATE OR REPLACE FUNCTION pg_temp.esperar_rechazo(
    etiqueta text, sentencia text, codigo text, restriccion text DEFAULT ''
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE recibido text; regla text;
BEGIN
    BEGIN
        EXECUTE sentencia;
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'FALLO %: la operación fue aceptada.', etiqueta;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS recibido = RETURNED_SQLSTATE, regla = CONSTRAINT_NAME;
        IF recibido <> codigo OR (restriccion <> '' AND regla IS DISTINCT FROM restriccion) THEN
            RAISE;
        END IF;
        RAISE NOTICE 'OK %', etiqueta;
    END;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.comprobar(etiqueta text, condicion boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF condicion IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO %', etiqueta; END IF;
    RAISE NOTICE 'OK %', etiqueta;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.preparar()
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE f integer; ca integer; e1 integer; e2 integer; e3 integer;
    d integer; sede integer; salon integer; c1 integer; c2 integer;
    p0 integer; p1 integer; s0 integer; s1 integer; s2 integer;
    i1 integer; i2 integer; i3 integer; ia integer; a1 integer; a2 integer; a3 integer;
BEGIN
    INSERT INTO public.facultad(codigo,nombre) VALUES ('__FIN_F__','Facultad temporal') RETURNING id_facultad INTO f;
    INSERT INTO public.carrera(id_facultad,codigo,nombre) VALUES (f,'__FIN_C__','Carrera temporal') RETURNING id_carrera INTO ca;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E1__','Ana','Temporal','2000-01-01','ana@example.com') RETURNING id_estudiante INTO e1;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E2__','Luis','Temporal','2000-01-01','luis@example.com') RETURNING id_estudiante INTO e2;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E3__','Eva','Temporal','2000-01-01','eva@example.com') RETURNING id_estudiante INTO e3;
    INSERT INTO public.docente(codigo,nombres,apellidos,correo)
    VALUES('__FIN_D__','Docente','Temporal','d@example.com') RETURNING id_docente INTO d;
    INSERT INTO public.sede(codigo,nombre,direccion) VALUES('__FIN_SEDE__','Sede temporal','Temporal') RETURNING id_sede INTO sede;
    INSERT INTO public.salon(id_sede,codigo,capacidad) VALUES(sede,'__FIN_SALON__',40) RETURNING id_salon INTO salon;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_A__','Curso A') RETURNING id_curso INTO c1;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_B__','Curso B') RETURNING id_curso INTO c2;
    INSERT INTO public.plan_estudio(id_carrera,id_curso,semestre_sugerido) VALUES(ca,c1,1),(ca,c2,2);
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P0__','Anterior','2090-01-01','2090-06-30') RETURNING id_periodo_academico INTO p0;
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P1__','Actual','2091-01-01','2091-06-30') RETURNING id_periodo_academico INTO p1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p0,d,'__FIN_S0__',30) RETURNING id_seccion INTO s0;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c2,p1,d,'__FIN_S1__',30) RETURNING id_seccion INTO s1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p1,d,'__FIN_S2__',30) RETURNING id_seccion INTO s2;
    INSERT INTO public.horario_seccion(id_seccion,id_salon,dia_semana,hora_inicio,hora_fin)
    VALUES(s0,salon,1,'08:00','09:00'),(s1,salon,1,'08:00','09:00'),(s2,salon,2,'08:00','09:00');
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p0) RETURNING id_inscripcion INTO i1;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e2,p0) RETURNING id_inscripcion INTO i2;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e3,p0) RETURNING id_inscripcion INTO i3;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p1) RETURNING id_inscripcion INTO ia;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i1,s0) RETURNING id_asignacion_curso INTO a1;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i2,s0) RETURNING id_asignacion_curso INTO a2;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i3,s0) RETURNING id_asignacion_curso INTO a3;
    UPDATE public.asignacion_curso SET estado='cancelada' WHERE id_asignacion_curso=a3;
    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
    RETURN jsonb_build_object('carrera',ca,'e1',e1,'c1',c1,'c2',c2,'p0',p0,'p1',p1,
        's0',s0,'s1',s1,'s2',s2,'i1',i1,'i2',i2,'i3',i3,'ia',ia,'a1',a1,'a2',a2,'a3',a3);
END;
$$;

DO $$
DECLARE j jsonb; x integer; y integer; z integer; w integer;
BEGIN
 j := pg_temp.preparar();

-- PRUEBAS DEL BLOQUE 8: INICIO E IDENTIDAD DE ASIGNACIONES.

PERFORM pg_temp.esperar_rechazo(
    '8.1: asignación nueva comienza en cursando',
    format(
        'INSERT INTO public.asignacion_curso
            (id_inscripcion, id_seccion, estado)
         VALUES (%s, %s, %L)',
        j->>'i3', j->>'s0', 'cancelada'
    ),
    '23514', 'regla_asignacion_estado_inicial'
);

UPDATE public.asignacion_curso
SET estado = 'cursando'
WHERE id_asignacion_curso = (j->>'a3')::integer;

SET CONSTRAINTS ALL IMMEDIATE;

PERFORM pg_temp.comprobar(
    '8.2: reactivación válida a cursando',
    (SELECT estado = 'cursando'
     FROM public.asignacion_curso
     WHERE id_asignacion_curso = (j->>'a3')::integer)
);

SET CONSTRAINTS ALL DEFERRED;

-- Restablecer la asignación para las pruebas siguientes.
UPDATE public.asignacion_curso
SET estado = 'cancelada'
WHERE id_asignacion_curso = (j->>'a3')::integer;

SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

PERFORM pg_temp.esperar_rechazo(
    '8.3: inscripción de asignación inmutable',
    format(
        'UPDATE public.asignacion_curso SET id_inscripcion = %s
         WHERE id_asignacion_curso = %s',
        j->>'i2', j->>'a1'
    ),
    '23514', 'regla_asignacion_identidad'
);

PERFORM pg_temp.esperar_rechazo(
    '8.4: sección de asignación inmutable',
    format(
        'UPDATE public.asignacion_curso SET id_seccion = %s
         WHERE id_asignacion_curso = %s',
        j->>'s2', j->>'a1'
    ),
    '23514', 'regla_asignacion_identidad'
);

-- PRUEBAS DEL BLOQUE 9: REQUISITOS ACADÉMICOS.


INSERT INTO public.prerrequisito(id_curso,id_curso_requisito)
VALUES((j->>'c2')::int,(j->>'c1')::int);
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('9.1: requisito aún cursando no cuenta',format(
 'INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(%s,%s)',j->>'ia',j->>'s1'),
 '23514','regla_prerrequisitos_aprobados');
PERFORM pg_temp.esperar_rechazo('9.2: no simular aprobación sin cierre',format(
 'UPDATE public.asignacion_curso SET estado=''aprobada'' WHERE id_asignacion_curso=%s',j->>'a1'),
 '23514','regla_resultado_cierre');

INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 60','examen','2090-03-01',60)
RETURNING id_actividad_academica INTO x;
INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 40','tarea','2090-04-01',40)
RETURNING id_actividad_academica INTO y;

INSERT INTO public.calificacion(id_actividad_academica,id_asignacion_curso,puntaje_obtenido)
VALUES(x,(j->>'a1')::int,60),(y,(j->>'a1')::int,1),
      (x,(j->>'a2')::int,60),(y,(j->>'a2')::int,0);

PERFORM public.cerrar_calificaciones((j->>'s0')::int);
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico)
SELECT i.id_estudiante,(j->>'p1')::int FROM public.inscripcion i
WHERE i.id_inscripcion=(j->>'i2')::int RETURNING id_inscripcion INTO w;
PERFORM pg_temp.esperar_rechazo('9.3: requisito reprobado no cuenta',format(
 'INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(%s,%s)',w,j->>'s1'),
 '23514','regla_prerrequisitos_aprobados');
INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion)
VALUES((j->>'ia')::int,(j->>'s1')::int);
SET CONSTRAINTS ALL IMMEDIATE;
PERFORM pg_temp.comprobar('9.4: requisito aprobado anteriormente permite asignación',EXISTS(
 SELECT 1 FROM public.asignacion_curso WHERE id_inscripcion=(j->>'ia')::int AND id_seccion=(j->>'s1')::int));
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('9.5: curso aprobado no se repite',format(
 'INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(%s,%s)',j->>'ia',j->>'s2'),
 '23514','regla_curso_ya_aprobado');

 SET CONSTRAINTS ALL IMMEDIATE;
END;
$$;
ROLLBACK;



-- ============================================================
-- FIN BLOQUES 8 Y 9
-- ============================================================




-- ============================================================
-- INICIO PRUEBAS BLOQUE 10
-- ============================================================
BEGIN ISOLATION LEVEL SERIALIZABLE;

CREATE OR REPLACE FUNCTION pg_temp.esperar_rechazo(
    etiqueta text, sentencia text, codigo text, restriccion text DEFAULT ''
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE recibido text; regla text;
BEGIN
    BEGIN
        EXECUTE sentencia;
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'FALLO %: la operación fue aceptada.', etiqueta;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS recibido = RETURNED_SQLSTATE, regla = CONSTRAINT_NAME;
        IF recibido <> codigo OR (restriccion <> '' AND regla IS DISTINCT FROM restriccion) THEN
            RAISE;
        END IF;
        RAISE NOTICE 'OK %', etiqueta;
    END;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.comprobar(etiqueta text, condicion boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF condicion IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO %', etiqueta; END IF;
    RAISE NOTICE 'OK %', etiqueta;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.preparar()
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE f integer; ca integer; e1 integer; e2 integer; e3 integer;
    d integer; sede integer; salon integer; c1 integer; c2 integer;
    p0 integer; p1 integer; s0 integer; s1 integer; s2 integer;
    i1 integer; i2 integer; i3 integer; ia integer; a1 integer; a2 integer; a3 integer;
BEGIN
    INSERT INTO public.facultad(codigo,nombre) VALUES ('__FIN_F__','Facultad temporal') RETURNING id_facultad INTO f;
    INSERT INTO public.carrera(id_facultad,codigo,nombre) VALUES (f,'__FIN_C__','Carrera temporal') RETURNING id_carrera INTO ca;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E1__','Ana','Temporal','2000-01-01','ana@example.com') RETURNING id_estudiante INTO e1;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E2__','Luis','Temporal','2000-01-01','luis@example.com') RETURNING id_estudiante INTO e2;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E3__','Eva','Temporal','2000-01-01','eva@example.com') RETURNING id_estudiante INTO e3;
    INSERT INTO public.docente(codigo,nombres,apellidos,correo)
    VALUES('__FIN_D__','Docente','Temporal','d@example.com') RETURNING id_docente INTO d;
    INSERT INTO public.sede(codigo,nombre,direccion) VALUES('__FIN_SEDE__','Sede temporal','Temporal') RETURNING id_sede INTO sede;
    INSERT INTO public.salon(id_sede,codigo,capacidad) VALUES(sede,'__FIN_SALON__',40) RETURNING id_salon INTO salon;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_A__','Curso A') RETURNING id_curso INTO c1;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_B__','Curso B') RETURNING id_curso INTO c2;
    INSERT INTO public.plan_estudio(id_carrera,id_curso,semestre_sugerido) VALUES(ca,c1,1),(ca,c2,2);
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P0__','Anterior','2090-01-01','2090-06-30') RETURNING id_periodo_academico INTO p0;
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P1__','Actual','2091-01-01','2091-06-30') RETURNING id_periodo_academico INTO p1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p0,d,'__FIN_S0__',30) RETURNING id_seccion INTO s0;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c2,p1,d,'__FIN_S1__',30) RETURNING id_seccion INTO s1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p1,d,'__FIN_S2__',30) RETURNING id_seccion INTO s2;
    INSERT INTO public.horario_seccion(id_seccion,id_salon,dia_semana,hora_inicio,hora_fin)
    VALUES(s0,salon,1,'08:00','09:00'),(s1,salon,1,'08:00','09:00'),(s2,salon,2,'08:00','09:00');
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p0) RETURNING id_inscripcion INTO i1;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e2,p0) RETURNING id_inscripcion INTO i2;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e3,p0) RETURNING id_inscripcion INTO i3;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p1) RETURNING id_inscripcion INTO ia;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i1,s0) RETURNING id_asignacion_curso INTO a1;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i2,s0) RETURNING id_asignacion_curso INTO a2;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i3,s0) RETURNING id_asignacion_curso INTO a3;
    UPDATE public.asignacion_curso SET estado='cancelada' WHERE id_asignacion_curso=a3;
    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
    RETURN jsonb_build_object('carrera',ca,'e1',e1,'c1',c1,'c2',c2,'p0',p0,'p1',p1,
        's0',s0,'s1',s1,'s2',s2,'i1',i1,'i2',i2,'i3',i3,'ia',ia,'a1',a1,'a2',a2,'a3',a3);
END;
$$;

DO $$
DECLARE j jsonb; x integer; y integer; z integer; w integer;
BEGIN
    j := pg_temp.preparar();

INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 60','examen','2090-03-01',60)
RETURNING id_actividad_academica INTO x;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.comprobar('10.1: actividad válida', EXISTS(SELECT 1 FROM public.actividad_academica WHERE id_actividad_academica=x));
PERFORM pg_temp.esperar_rechazo('10.2: fecha fuera del período',format(
    'INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo) VALUES(%s,''Fuera'',''tarea'',''2091-01-01'',10)',j->>'s0'),
    '23514','regla_actividad_fecha');
PERFORM pg_temp.esperar_rechazo('10.3: más de 100 puntos',format(
    'INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo) VALUES(%s,''Exceso'',''tarea'',''2090-04-01'',41)',j->>'s0'),
    '23514','regla_actividad_suma');
INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 40','tarea','2090-04-01',40);
SET CONSTRAINTS ALL IMMEDIATE;
PERFORM pg_temp.comprobar('10.4: suma exactamente 100',
    (SELECT SUM(puntaje_maximo)=100 FROM public.actividad_academica WHERE id_seccion=(j->>'s0')::int));
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('10.5: cambio de fecha del período incompatible',format(
    'UPDATE public.periodo_academico SET fecha_fin=''2090-03-15'' WHERE id_periodo_academico=%s',j->>'p0'),
    '23514','regla_actividad_fecha');

    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE NOTICE 'BLOQUE 10 COMPLETO';
END;
$$;
ROLLBACK;
-- FIN PRUEBAS BLOQUE 10


-- ============================================================
-- INICIO PRUEBAS BLOQUE 11
-- ============================================================
BEGIN ISOLATION LEVEL SERIALIZABLE;

CREATE OR REPLACE FUNCTION pg_temp.esperar_rechazo(
    etiqueta text, sentencia text, codigo text, restriccion text DEFAULT ''
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE recibido text; regla text;
BEGIN
    BEGIN
        EXECUTE sentencia;
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'FALLO %: la operación fue aceptada.', etiqueta;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS recibido = RETURNED_SQLSTATE, regla = CONSTRAINT_NAME;
        IF recibido <> codigo OR (restriccion <> '' AND regla IS DISTINCT FROM restriccion) THEN
            RAISE;
        END IF;
        RAISE NOTICE 'OK %', etiqueta;
    END;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.comprobar(etiqueta text, condicion boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF condicion IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO %', etiqueta; END IF;
    RAISE NOTICE 'OK %', etiqueta;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.preparar()
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE f integer; ca integer; e1 integer; e2 integer; e3 integer;
    d integer; sede integer; salon integer; c1 integer; c2 integer;
    p0 integer; p1 integer; s0 integer; s1 integer; s2 integer;
    i1 integer; i2 integer; i3 integer; ia integer; a1 integer; a2 integer; a3 integer;
BEGIN
    INSERT INTO public.facultad(codigo,nombre) VALUES ('__FIN_F__','Facultad temporal') RETURNING id_facultad INTO f;
    INSERT INTO public.carrera(id_facultad,codigo,nombre) VALUES (f,'__FIN_C__','Carrera temporal') RETURNING id_carrera INTO ca;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E1__','Ana','Temporal','2000-01-01','ana@example.com') RETURNING id_estudiante INTO e1;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E2__','Luis','Temporal','2000-01-01','luis@example.com') RETURNING id_estudiante INTO e2;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E3__','Eva','Temporal','2000-01-01','eva@example.com') RETURNING id_estudiante INTO e3;
    INSERT INTO public.docente(codigo,nombres,apellidos,correo)
    VALUES('__FIN_D__','Docente','Temporal','d@example.com') RETURNING id_docente INTO d;
    INSERT INTO public.sede(codigo,nombre,direccion) VALUES('__FIN_SEDE__','Sede temporal','Temporal') RETURNING id_sede INTO sede;
    INSERT INTO public.salon(id_sede,codigo,capacidad) VALUES(sede,'__FIN_SALON__',40) RETURNING id_salon INTO salon;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_A__','Curso A') RETURNING id_curso INTO c1;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_B__','Curso B') RETURNING id_curso INTO c2;
    INSERT INTO public.plan_estudio(id_carrera,id_curso,semestre_sugerido) VALUES(ca,c1,1),(ca,c2,2);
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P0__','Anterior','2090-01-01','2090-06-30') RETURNING id_periodo_academico INTO p0;
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P1__','Actual','2091-01-01','2091-06-30') RETURNING id_periodo_academico INTO p1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p0,d,'__FIN_S0__',30) RETURNING id_seccion INTO s0;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c2,p1,d,'__FIN_S1__',30) RETURNING id_seccion INTO s1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p1,d,'__FIN_S2__',30) RETURNING id_seccion INTO s2;
    INSERT INTO public.horario_seccion(id_seccion,id_salon,dia_semana,hora_inicio,hora_fin)
    VALUES(s0,salon,1,'08:00','09:00'),(s1,salon,1,'08:00','09:00'),(s2,salon,2,'08:00','09:00');
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p0) RETURNING id_inscripcion INTO i1;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e2,p0) RETURNING id_inscripcion INTO i2;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e3,p0) RETURNING id_inscripcion INTO i3;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p1) RETURNING id_inscripcion INTO ia;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i1,s0) RETURNING id_asignacion_curso INTO a1;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i2,s0) RETURNING id_asignacion_curso INTO a2;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i3,s0) RETURNING id_asignacion_curso INTO a3;
    UPDATE public.asignacion_curso SET estado='cancelada' WHERE id_asignacion_curso=a3;
    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
    RETURN jsonb_build_object('carrera',ca,'e1',e1,'c1',c1,'c2',c2,'p0',p0,'p1',p1,
        's0',s0,'s1',s1,'s2',s2,'i1',i1,'i2',i2,'i3',i3,'ia',ia,'a1',a1,'a2',a2,'a3',a3);
END;
$$;

DO $$
DECLARE j jsonb; x integer; y integer; z integer; w integer;
BEGIN
    j := pg_temp.preparar();

INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 60','examen','2090-03-01',60)
RETURNING id_actividad_academica INTO x;
INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 40','tarea','2090-04-01',40)
RETURNING id_actividad_academica INTO y;

INSERT INTO public.calificacion(id_actividad_academica,id_asignacion_curso,puntaje_obtenido)
VALUES(x,(j->>'a1')::int,50) RETURNING id_calificacion INTO z;
SET CONSTRAINTS ALL IMMEDIATE;
PERFORM pg_temp.comprobar('11.1: calificación válida',EXISTS(SELECT 1 FROM public.calificacion WHERE id_calificacion=z));
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('11.2: puntaje mayor que máximo',format(
    'INSERT INTO public.calificacion(id_actividad_academica,id_asignacion_curso,puntaje_obtenido) VALUES(%s,%s,41)',y,j->>'a1'),
    '23514','regla_calificacion_maximo');
INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s1')::int,'Otra sección','examen','2091-03-01',100) RETURNING id_actividad_academica INTO w;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('11.3: distinta sección',format(
    'INSERT INTO public.calificacion(id_actividad_academica,id_asignacion_curso,puntaje_obtenido) VALUES(%s,%s,10)',w,j->>'a1'),
    '23514','regla_calificacion_seccion');
PERFORM pg_temp.esperar_rechazo('11.4: asignación cancelada',format(
    'INSERT INTO public.calificacion(id_actividad_academica,id_asignacion_curso,puntaje_obtenido) VALUES(%s,%s,10)',x,j->>'a3'),
    '23514','regla_calificacion_cancelada');
PERFORM pg_temp.esperar_rechazo('11.5: máximo reducido por debajo de nota',format(
    'UPDATE public.actividad_academica SET puntaje_maximo=40 WHERE id_actividad_academica=%s',x),
    '23514','regla_calificacion_maximo');
INSERT INTO public.calificacion(id_actividad_academica,id_asignacion_curso,puntaje_obtenido)
VALUES(y,(j->>'a1')::int,0);
SET CONSTRAINTS ALL IMMEDIATE;
PERFORM pg_temp.comprobar('11.6: cero explícito válido',EXISTS(
    SELECT 1 FROM public.calificacion WHERE id_actividad_academica=y AND id_asignacion_curso=(j->>'a1')::int AND puntaje_obtenido=0));

    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE NOTICE 'BLOQUE 11 COMPLETO';
END;
$$;
ROLLBACK;
-- FIN PRUEBAS BLOQUE 11


-- ============================================================
-- INICIO PRUEBAS BLOQUE 12
-- ============================================================
BEGIN ISOLATION LEVEL SERIALIZABLE;

CREATE OR REPLACE FUNCTION pg_temp.esperar_rechazo(
    etiqueta text, sentencia text, codigo text, restriccion text DEFAULT ''
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE recibido text; regla text;
BEGIN
    BEGIN
        EXECUTE sentencia;
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'FALLO %: la operación fue aceptada.', etiqueta;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS recibido = RETURNED_SQLSTATE, regla = CONSTRAINT_NAME;
        IF recibido <> codigo OR (restriccion <> '' AND regla IS DISTINCT FROM restriccion) THEN
            RAISE;
        END IF;
        RAISE NOTICE 'OK %', etiqueta;
    END;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.comprobar(etiqueta text, condicion boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF condicion IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO %', etiqueta; END IF;
    RAISE NOTICE 'OK %', etiqueta;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.preparar()
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE f integer; ca integer; e1 integer; e2 integer; e3 integer;
    d integer; sede integer; salon integer; c1 integer; c2 integer;
    p0 integer; p1 integer; s0 integer; s1 integer; s2 integer;
    i1 integer; i2 integer; i3 integer; ia integer; a1 integer; a2 integer; a3 integer;
BEGIN
    INSERT INTO public.facultad(codigo,nombre) VALUES ('__FIN_F__','Facultad temporal') RETURNING id_facultad INTO f;
    INSERT INTO public.carrera(id_facultad,codigo,nombre) VALUES (f,'__FIN_C__','Carrera temporal') RETURNING id_carrera INTO ca;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E1__','Ana','Temporal','2000-01-01','ana@example.com') RETURNING id_estudiante INTO e1;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E2__','Luis','Temporal','2000-01-01','luis@example.com') RETURNING id_estudiante INTO e2;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E3__','Eva','Temporal','2000-01-01','eva@example.com') RETURNING id_estudiante INTO e3;
    INSERT INTO public.docente(codigo,nombres,apellidos,correo)
    VALUES('__FIN_D__','Docente','Temporal','d@example.com') RETURNING id_docente INTO d;
    INSERT INTO public.sede(codigo,nombre,direccion) VALUES('__FIN_SEDE__','Sede temporal','Temporal') RETURNING id_sede INTO sede;
    INSERT INTO public.salon(id_sede,codigo,capacidad) VALUES(sede,'__FIN_SALON__',40) RETURNING id_salon INTO salon;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_A__','Curso A') RETURNING id_curso INTO c1;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_B__','Curso B') RETURNING id_curso INTO c2;
    INSERT INTO public.plan_estudio(id_carrera,id_curso,semestre_sugerido) VALUES(ca,c1,1),(ca,c2,2);
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P0__','Anterior','2090-01-01','2090-06-30') RETURNING id_periodo_academico INTO p0;
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P1__','Actual','2091-01-01','2091-06-30') RETURNING id_periodo_academico INTO p1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p0,d,'__FIN_S0__',30) RETURNING id_seccion INTO s0;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c2,p1,d,'__FIN_S1__',30) RETURNING id_seccion INTO s1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p1,d,'__FIN_S2__',30) RETURNING id_seccion INTO s2;
    INSERT INTO public.horario_seccion(id_seccion,id_salon,dia_semana,hora_inicio,hora_fin)
    VALUES(s0,salon,1,'08:00','09:00'),(s1,salon,1,'08:00','09:00'),(s2,salon,2,'08:00','09:00');
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p0) RETURNING id_inscripcion INTO i1;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e2,p0) RETURNING id_inscripcion INTO i2;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e3,p0) RETURNING id_inscripcion INTO i3;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p1) RETURNING id_inscripcion INTO ia;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i1,s0) RETURNING id_asignacion_curso INTO a1;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i2,s0) RETURNING id_asignacion_curso INTO a2;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i3,s0) RETURNING id_asignacion_curso INTO a3;
    UPDATE public.asignacion_curso SET estado='cancelada' WHERE id_asignacion_curso=a3;
    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
    RETURN jsonb_build_object('carrera',ca,'e1',e1,'c1',c1,'c2',c2,'p0',p0,'p1',p1,
        's0',s0,'s1',s1,'s2',s2,'i1',i1,'i2',i2,'i3',i3,'ia',ia,'a1',a1,'a2',a2,'a3',a3);
END;
$$;

DO $$
DECLARE j jsonb; x integer; y integer; z integer; w integer;
BEGIN
    j := pg_temp.preparar();

INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 60','examen','2090-03-01',60) RETURNING id_actividad_academica INTO x;
PERFORM pg_temp.esperar_rechazo('12.1: cierre sin 100 puntos',format(
    'SELECT public.cerrar_calificaciones(%s)',j->>'s0'),'23514','regla_cierre_suma');
INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 40','tarea','2090-04-01',40) RETURNING id_actividad_academica INTO y;
PERFORM pg_temp.esperar_rechazo('12.2: cierre con notas pendientes',format(
    'SELECT public.cerrar_calificaciones(%s)',j->>'s0'),'23514','regla_cierre_completo');

INSERT INTO public.calificacion(id_actividad_academica,id_asignacion_curso,puntaje_obtenido)
VALUES(x,(j->>'a1')::int,60),(y,(j->>'a1')::int,1),
      (x,(j->>'a2')::int,60),(y,(j->>'a2')::int,0);

PERFORM pg_temp.esperar_rechazo('12.3: aprobación manual antes de cierre',format(
    'UPDATE public.asignacion_curso SET estado=''aprobada'' WHERE id_asignacion_curso=%s',j->>'a1'),
    '23514','regla_resultado_cierre');
PERFORM public.cerrar_calificaciones((j->>'s0')::int);
SET CONSTRAINTS ALL IMMEDIATE;
PERFORM pg_temp.comprobar('12.4: 61 aprueba', (SELECT estado='aprobada' FROM public.asignacion_curso WHERE id_asignacion_curso=(j->>'a1')::int));
PERFORM pg_temp.comprobar('12.5: 60 reprueba', (SELECT estado='reprobada' FROM public.asignacion_curso WHERE id_asignacion_curso=(j->>'a2')::int));
PERFORM pg_temp.comprobar('12.6: cancelada conserva su estado', (SELECT estado='cancelada' FROM public.asignacion_curso WHERE id_asignacion_curso=(j->>'a3')::int));
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('12.7: nota cerrada inmutable',format(
    'UPDATE public.calificacion SET puntaje_obtenido=59 WHERE id_actividad_academica=%s AND id_asignacion_curso=%s',x,j->>'a1'),
    '23514','regla_calificacion_cerrada');
PERFORM pg_temp.esperar_rechazo('12.8: actividad cerrada inmutable',format(
    'UPDATE public.actividad_academica SET nombre=''Cambio'' WHERE id_actividad_academica=%s',x),
    '23514','regla_actividad_cerrada');
PERFORM pg_temp.esperar_rechazo('12.9: impedir reapertura',format(
    'UPDATE public.seccion SET calificaciones_cerradas=false WHERE id_seccion=%s',j->>'s0'),
    '23514','regla_seccion_cerrada');
PERFORM pg_temp.esperar_rechazo('12.10: resultado final inmutable',format(
    'UPDATE public.asignacion_curso SET estado=''reprobada'' WHERE id_asignacion_curso=%s',j->>'a1'),
    '23514','regla_resultado_inmutable');
PERFORM pg_temp.esperar_rechazo('12.11: cancelada no reactiva después del cierre',format(
    'UPDATE public.asignacion_curso SET estado=''cursando'' WHERE id_asignacion_curso=%s',j->>'a3'),
    '23514','regla_asignacion_seccion_cerrada');

    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE NOTICE 'BLOQUE 12 COMPLETO';
END;
$$;
ROLLBACK;
-- FIN PRUEBAS BLOQUE 12


-- ============================================================
-- INICIO PRUEBAS BLOQUE 13
-- ============================================================
BEGIN ISOLATION LEVEL SERIALIZABLE;

CREATE OR REPLACE FUNCTION pg_temp.esperar_rechazo(
    etiqueta text, sentencia text, codigo text, restriccion text DEFAULT ''
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE recibido text; regla text;
BEGIN
    BEGIN
        EXECUTE sentencia;
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'FALLO %: la operación fue aceptada.', etiqueta;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS recibido = RETURNED_SQLSTATE, regla = CONSTRAINT_NAME;
        IF recibido <> codigo OR (restriccion <> '' AND regla IS DISTINCT FROM restriccion) THEN
            RAISE;
        END IF;
        RAISE NOTICE 'OK %', etiqueta;
    END;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.comprobar(etiqueta text, condicion boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF condicion IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO %', etiqueta; END IF;
    RAISE NOTICE 'OK %', etiqueta;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.preparar()
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE f integer; ca integer; e1 integer; e2 integer; e3 integer;
    d integer; sede integer; salon integer; c1 integer; c2 integer;
    p0 integer; p1 integer; s0 integer; s1 integer; s2 integer;
    i1 integer; i2 integer; i3 integer; ia integer; a1 integer; a2 integer; a3 integer;
BEGIN
    INSERT INTO public.facultad(codigo,nombre) VALUES ('__FIN_F__','Facultad temporal') RETURNING id_facultad INTO f;
    INSERT INTO public.carrera(id_facultad,codigo,nombre) VALUES (f,'__FIN_C__','Carrera temporal') RETURNING id_carrera INTO ca;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E1__','Ana','Temporal','2000-01-01','ana@example.com') RETURNING id_estudiante INTO e1;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E2__','Luis','Temporal','2000-01-01','luis@example.com') RETURNING id_estudiante INTO e2;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E3__','Eva','Temporal','2000-01-01','eva@example.com') RETURNING id_estudiante INTO e3;
    INSERT INTO public.docente(codigo,nombres,apellidos,correo)
    VALUES('__FIN_D__','Docente','Temporal','d@example.com') RETURNING id_docente INTO d;
    INSERT INTO public.sede(codigo,nombre,direccion) VALUES('__FIN_SEDE__','Sede temporal','Temporal') RETURNING id_sede INTO sede;
    INSERT INTO public.salon(id_sede,codigo,capacidad) VALUES(sede,'__FIN_SALON__',40) RETURNING id_salon INTO salon;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_A__','Curso A') RETURNING id_curso INTO c1;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_B__','Curso B') RETURNING id_curso INTO c2;
    INSERT INTO public.plan_estudio(id_carrera,id_curso,semestre_sugerido) VALUES(ca,c1,1),(ca,c2,2);
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P0__','Anterior','2090-01-01','2090-06-30') RETURNING id_periodo_academico INTO p0;
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P1__','Actual','2091-01-01','2091-06-30') RETURNING id_periodo_academico INTO p1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p0,d,'__FIN_S0__',30) RETURNING id_seccion INTO s0;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c2,p1,d,'__FIN_S1__',30) RETURNING id_seccion INTO s1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p1,d,'__FIN_S2__',30) RETURNING id_seccion INTO s2;
    INSERT INTO public.horario_seccion(id_seccion,id_salon,dia_semana,hora_inicio,hora_fin)
    VALUES(s0,salon,1,'08:00','09:00'),(s1,salon,1,'08:00','09:00'),(s2,salon,2,'08:00','09:00');
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p0) RETURNING id_inscripcion INTO i1;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e2,p0) RETURNING id_inscripcion INTO i2;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e3,p0) RETURNING id_inscripcion INTO i3;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p1) RETURNING id_inscripcion INTO ia;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i1,s0) RETURNING id_asignacion_curso INTO a1;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i2,s0) RETURNING id_asignacion_curso INTO a2;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i3,s0) RETURNING id_asignacion_curso INTO a3;
    UPDATE public.asignacion_curso SET estado='cancelada' WHERE id_asignacion_curso=a3;
    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
    RETURN jsonb_build_object('carrera',ca,'e1',e1,'c1',c1,'c2',c2,'p0',p0,'p1',p1,
        's0',s0,'s1',s1,'s2',s2,'i1',i1,'i2',i2,'i3',i3,'ia',ia,'a1',a1,'a2',a2,'a3',a3);
END;
$$;

DO $$
DECLARE j jsonb; x integer; y integer; z integer; w integer;
BEGIN
    j := pg_temp.preparar();

PERFORM pg_temp.esperar_rechazo('13.1: no finalizar con cursando',format(
    'UPDATE public.inscripcion SET estado=''finalizada'' WHERE id_inscripcion=%s',j->>'i1'),
    '23514','regla_inscripcion_finalizar');
UPDATE public.inscripcion SET estado='cancelada' WHERE id_inscripcion=(j->>'i2')::int;
SET CONSTRAINTS ALL IMMEDIATE;
PERFORM pg_temp.comprobar('13.2: cancelación propaga a cursos',
    (SELECT estado='cancelada' FROM public.asignacion_curso WHERE id_asignacion_curso=(j->>'a2')::int));
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('13.3: inscripción cancelada no reactiva',format(
    'UPDATE public.asignacion_curso SET estado=''cursando'' WHERE id_asignacion_curso=%s',j->>'a2'),
    '23514','regla_asignacion_inscripcion_activa');
PERFORM pg_temp.esperar_rechazo('13.4: sección asignada no cambia de curso',format(
    'UPDATE public.seccion SET id_curso=%s WHERE id_seccion=%s',j->>'c2',j->>'s0'),
    '23514','regla_seccion_identidad');
PERFORM pg_temp.esperar_rechazo('13.5: conservar inscripción',format(
    'DELETE FROM public.inscripcion WHERE id_inscripcion=%s',j->>'i1'),
    '23514','regla_inscripcion_conservar');
PERFORM pg_temp.esperar_rechazo('13.6: conservar asignación',format(
    'DELETE FROM public.asignacion_curso WHERE id_asignacion_curso=%s',j->>'a3'),
    '23514','regla_asignacion_conservar');

INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 60','examen','2090-03-01',60)
RETURNING id_actividad_academica INTO x;
INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 40','tarea','2090-04-01',40)
RETURNING id_actividad_academica INTO y;

INSERT INTO public.calificacion(id_actividad_academica,id_asignacion_curso,puntaje_obtenido)
VALUES(x,(j->>'a1')::int,60),(y,(j->>'a1')::int,1);
PERFORM public.cerrar_calificaciones((j->>'s0')::int);
UPDATE public.inscripcion SET estado='finalizada' WHERE id_inscripcion=(j->>'i1')::int;
SET CONSTRAINTS ALL IMMEDIATE;
PERFORM pg_temp.comprobar('13.7: finaliza sin cursando',
    (SELECT estado='finalizada' FROM public.inscripcion WHERE id_inscripcion=(j->>'i1')::int));
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('13.8: finalizada inmutable',format(
    'UPDATE public.inscripcion SET estado=''activa'' WHERE id_inscripcion=%s',j->>'i1'),
    '23514','regla_inscripcion_finalizada');
PERFORM pg_temp.esperar_rechazo('13.9: horario cerrado inmutable',format(
    'UPDATE public.horario_seccion SET hora_fin=''09:30'' WHERE id_seccion=%s',j->>'s0'),
    '23514','regla_horario_cerrado');
PERFORM pg_temp.esperar_rechazo('13.10: fechas históricas inmutables',format(
    'UPDATE public.periodo_academico SET fecha_inicio=''2090-01-02'' WHERE id_periodo_academico=%s',j->>'p0'),
    '23514','regla_periodo_historial');
PERFORM pg_temp.esperar_rechazo('13.11: TRUNCATE prohibido',
    'TRUNCATE public.calificacion','23514','regla_conservar_historial');

    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE NOTICE 'BLOQUE 13 COMPLETO';
END;
$$;
ROLLBACK;
-- FIN PRUEBAS BLOQUE 13


-- ============================================================
-- INICIO PRUEBAS BLOQUE 14
-- ============================================================
BEGIN ISOLATION LEVEL SERIALIZABLE;

CREATE OR REPLACE FUNCTION pg_temp.esperar_rechazo(
    etiqueta text, sentencia text, codigo text, restriccion text DEFAULT ''
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE recibido text; regla text;
BEGIN
    BEGIN
        EXECUTE sentencia;
        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'FALLO %: la operación fue aceptada.', etiqueta;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS recibido = RETURNED_SQLSTATE, regla = CONSTRAINT_NAME;
        IF recibido <> codigo OR (restriccion <> '' AND regla IS DISTINCT FROM restriccion) THEN
            RAISE;
        END IF;
        RAISE NOTICE 'OK %', etiqueta;
    END;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.comprobar(etiqueta text, condicion boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF condicion IS DISTINCT FROM true THEN RAISE EXCEPTION 'FALLO %', etiqueta; END IF;
    RAISE NOTICE 'OK %', etiqueta;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.preparar()
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE f integer; ca integer; e1 integer; e2 integer; e3 integer;
    d integer; sede integer; salon integer; c1 integer; c2 integer;
    p0 integer; p1 integer; s0 integer; s1 integer; s2 integer;
    i1 integer; i2 integer; i3 integer; ia integer; a1 integer; a2 integer; a3 integer;
BEGIN
    INSERT INTO public.facultad(codigo,nombre) VALUES ('__FIN_F__','Facultad temporal') RETURNING id_facultad INTO f;
    INSERT INTO public.carrera(id_facultad,codigo,nombre) VALUES (f,'__FIN_C__','Carrera temporal') RETURNING id_carrera INTO ca;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E1__','Ana','Temporal','2000-01-01','ana@example.com') RETURNING id_estudiante INTO e1;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E2__','Luis','Temporal','2000-01-01','luis@example.com') RETURNING id_estudiante INTO e2;
    INSERT INTO public.estudiante(id_carrera,carne,nombres,apellidos,fecha_nacimiento,correo)
    VALUES(ca,'__FIN_E3__','Eva','Temporal','2000-01-01','eva@example.com') RETURNING id_estudiante INTO e3;
    INSERT INTO public.docente(codigo,nombres,apellidos,correo)
    VALUES('__FIN_D__','Docente','Temporal','d@example.com') RETURNING id_docente INTO d;
    INSERT INTO public.sede(codigo,nombre,direccion) VALUES('__FIN_SEDE__','Sede temporal','Temporal') RETURNING id_sede INTO sede;
    INSERT INTO public.salon(id_sede,codigo,capacidad) VALUES(sede,'__FIN_SALON__',40) RETURNING id_salon INTO salon;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_A__','Curso A') RETURNING id_curso INTO c1;
    INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_B__','Curso B') RETURNING id_curso INTO c2;
    INSERT INTO public.plan_estudio(id_carrera,id_curso,semestre_sugerido) VALUES(ca,c1,1),(ca,c2,2);
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P0__','Anterior','2090-01-01','2090-06-30') RETURNING id_periodo_academico INTO p0;
    INSERT INTO public.periodo_academico(codigo,nombre,fecha_inicio,fecha_fin)
    VALUES('__FIN_P1__','Actual','2091-01-01','2091-06-30') RETURNING id_periodo_academico INTO p1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p0,d,'__FIN_S0__',30) RETURNING id_seccion INTO s0;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c2,p1,d,'__FIN_S1__',30) RETURNING id_seccion INTO s1;
    INSERT INTO public.seccion(id_curso,id_periodo_academico,id_docente,codigo,cupo_maximo)
    VALUES(c1,p1,d,'__FIN_S2__',30) RETURNING id_seccion INTO s2;
    INSERT INTO public.horario_seccion(id_seccion,id_salon,dia_semana,hora_inicio,hora_fin)
    VALUES(s0,salon,1,'08:00','09:00'),(s1,salon,1,'08:00','09:00'),(s2,salon,2,'08:00','09:00');
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p0) RETURNING id_inscripcion INTO i1;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e2,p0) RETURNING id_inscripcion INTO i2;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e3,p0) RETURNING id_inscripcion INTO i3;
    INSERT INTO public.inscripcion(id_estudiante,id_periodo_academico) VALUES(e1,p1) RETURNING id_inscripcion INTO ia;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i1,s0) RETURNING id_asignacion_curso INTO a1;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i2,s0) RETURNING id_asignacion_curso INTO a2;
    INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(i3,s0) RETURNING id_asignacion_curso INTO a3;
    UPDATE public.asignacion_curso SET estado='cancelada' WHERE id_asignacion_curso=a3;
    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
    RETURN jsonb_build_object('carrera',ca,'e1',e1,'c1',c1,'c2',c2,'p0',p0,'p1',p1,
        's0',s0,'s1',s1,'s2',s2,'i1',i1,'i2',i2,'i3',i3,'ia',ia,'a1',a1,'a2',a2,'a3',a3);
END;
$$;

DO $$
DECLARE j jsonb; x integer; y integer; z integer; w integer;
BEGIN
    j := pg_temp.preparar();

INSERT INTO public.pago(id_inscripcion,numero_comprobante,concepto,monto)
VALUES((j->>'i1')::int,'__FIN_MAT_1__','matricula',100) RETURNING id_pago INTO x;
PERFORM pg_temp.esperar_rechazo('14.1: matrícula duplicada',format(
    'INSERT INTO public.pago(id_inscripcion,numero_comprobante,concepto,monto) VALUES(%s,''__FIN_MAT_2__'',''matricula'',100)',j->>'i1'),
    '23505','uq_pago_matricula_registrada');
UPDATE public.pago SET estado='anulado' WHERE id_pago=x;
INSERT INTO public.pago(id_inscripcion,numero_comprobante,concepto,monto)
VALUES((j->>'i1')::int,'__FIN_MAT_2__','matricula',100);
SET CONSTRAINTS ALL IMMEDIATE;
PERFORM pg_temp.comprobar('14.2: anulación permite sustitución',
    (SELECT COUNT(*)=2 FROM public.pago WHERE id_inscripcion=(j->>'i1')::int AND concepto='matricula'));
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('14.3: anulado no reactiva',format(
    'UPDATE public.pago SET estado=''registrado'' WHERE id_pago=%s',x),
    '23514','regla_pago_anulado');
INSERT INTO public.pago(id_inscripcion,numero_comprobante,concepto,monto,anio_mensualidad,mes_mensualidad)
VALUES((j->>'i1')::int,'__FIN_MES_1__','mensualidad',100,2090,1) RETURNING id_pago INTO y;
PERFORM pg_temp.esperar_rechazo('14.4: mensualidad duplicada',format(
    'INSERT INTO public.pago(id_inscripcion,numero_comprobante,concepto,monto,anio_mensualidad,mes_mensualidad) VALUES(%s,''__FIN_MES_2__'',''mensualidad'',100,2090,1)',j->>'i1'),
    '23505','uq_pago_mensualidad_registrada');
UPDATE public.pago SET estado='anulado' WHERE id_pago=y;
INSERT INTO public.pago(id_inscripcion,numero_comprobante,concepto,monto,anio_mensualidad,mes_mensualidad)
VALUES((j->>'i1')::int,'__FIN_MES_2__','mensualidad',100,2090,1);
SET CONSTRAINTS ALL IMMEDIATE;
PERFORM pg_temp.comprobar('14.5: sustituir mensualidad anulada',
    (SELECT COUNT(*)=2 FROM public.pago WHERE id_inscripcion=(j->>'i1')::int AND concepto='mensualidad'));
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('14.6: mes fuera del período',format(
    'INSERT INTO public.pago(id_inscripcion,numero_comprobante,concepto,monto,anio_mensualidad,mes_mensualidad) VALUES(%s,''__FIN_MES_FUERA__'',''mensualidad'',100,2090,7)',j->>'i1'),
    '23514','regla_pago_periodo');
PERFORM pg_temp.esperar_rechazo('14.7: pago no se elimina',format(
    'DELETE FROM public.pago WHERE id_pago=%s',x),'23514','regla_pago_conservar');
PERFORM pg_temp.esperar_rechazo('14.8: no editar importe original',format(
    'UPDATE public.pago SET monto=200 WHERE id_inscripcion=%s AND estado=%L AND concepto=%L',j->>'i1','registrado','matricula'),
    '23514','regla_pago_identidad');

INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 60','examen','2090-03-01',60)
RETURNING id_actividad_academica INTO x;
INSERT INTO public.actividad_academica(id_seccion,nombre,tipo,fecha,puntaje_maximo)
VALUES((j->>'s0')::int,'Actividad 40','tarea','2090-04-01',40)
RETURNING id_actividad_academica INTO y;

INSERT INTO public.calificacion(id_actividad_academica,id_asignacion_curso,puntaje_obtenido)
VALUES(x,(j->>'a1')::int,60),(y,(j->>'a1')::int,1),
      (x,(j->>'a2')::int,60),(y,(j->>'a2')::int,0);

-- La aprobación se obtiene ahora con el cierre real.
PERFORM public.cerrar_calificaciones((j->>'s0')::int);
INSERT INTO public.prerrequisito(id_curso,id_curso_requisito)
VALUES((j->>'c2')::int,(j->>'c1')::int);
INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion)
VALUES((j->>'ia')::int,(j->>'s1')::int);
SET CONSTRAINTS ALL IMMEDIATE;
PERFORM pg_temp.comprobar('14.9: requisito aprobado mediante cierre real',EXISTS(
    SELECT 1 FROM public.asignacion_curso WHERE id_inscripcion=(j->>'ia')::int AND id_seccion=(j->>'s1')::int));
SET CONSTRAINTS ALL DEFERRED;
PERFORM pg_temp.esperar_rechazo('14.10: no repetir aprobado',format(
    'INSERT INTO public.asignacion_curso(id_inscripcion,id_seccion) VALUES(%s,%s)',j->>'ia',j->>'s2'),
    '23514','regla_curso_ya_aprobado');
INSERT INTO public.curso(codigo,nombre) VALUES('__FIN_CURSO_C__','Requisito tardío') RETURNING id_curso INTO z;
INSERT INTO public.plan_estudio(id_carrera,id_curso,semestre_sugerido)
VALUES((j->>'carrera')::int,z,1);
PERFORM pg_temp.esperar_rechazo('14.11: requisito posterior no invalida historial',format(
    'INSERT INTO public.prerrequisito(id_curso,id_curso_requisito) VALUES(%s,%s)',j->>'c1',z),
    '23514','regla_historial_prerrequisitos');

    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE NOTICE 'BLOQUE 14 COMPLETO';
END;
$$;
ROLLBACK;
-- FIN PRUEBAS BLOQUE 14



-- ============================================================
-- CONCURRENCIA C1: ÚLTIMO CUPO (PASOS 06.x)
-- ============================================================
-- Base: sistema_universitario_pruebas.
-- Requiere DDL y reglas de negocio instalados.
--
-- Abrir TRES Query Tool independientes:
--   INICIAL: preparación y verificación.
--   A: primer estudiante.
--   B: segundo estudiante.
--
-- Ejecutar por bloques en el orden indicado.
-- NO ejecutar toda esta sección de una sola vez.
-- La preparación se ejecuta una sola vez en una base limpia.
-- Ante cualquier error, ejecutar ROLLBACK en esa sesión.


-- ------------------------------------------------------------
-- 06.1. INICIAL, A Y B: ejecutar en cada ventana por separado.
-- ------------------------------------------------------------

ROLLBACK;

SELECT
    current_database() AS base_actual,
    pg_backend_pid() AS conexion;

-- Esperado:
-- Las tres bases deben ser sistema_universitario_pruebas.
-- Los tres identificadores de conexión deben ser distintos.


-- ------------------------------------------------------------
-- 06.2. INICIAL: preparación completa.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    facultad_id integer;
    carrera_id integer;
    estudiante_a_id integer;
    estudiante_b_id integer;
    docente_id integer;
    sede_id integer;
    salon_id integer;
    curso_id integer;
    periodo_id integer;
    seccion_id integer;
BEGIN
    IF current_database() <> 'sistema_universitario_pruebas' THEN
        RAISE EXCEPTION 'Ejecutar únicamente en la base de pruebas.';
    END IF;

    INSERT INTO public.facultad (codigo, nombre)
    VALUES ('__CF_F__', 'Facultad temporal')
    RETURNING id_facultad INTO facultad_id;

    INSERT INTO public.carrera (id_facultad, codigo, nombre)
    VALUES (facultad_id, '__CF_C__', 'Carrera temporal')
    RETURNING id_carrera INTO carrera_id;

    INSERT INTO public.estudiante (
        id_carrera, carne, nombres, apellidos,
        fecha_nacimiento, correo
    )
    VALUES (
        carrera_id, '__CF_E1__', 'A', 'Temporal',
        DATE '2000-01-01', 'a@example.com'
    )
    RETURNING id_estudiante INTO estudiante_a_id;

    INSERT INTO public.estudiante (
        id_carrera, carne, nombres, apellidos,
        fecha_nacimiento, correo
    )
    VALUES (
        carrera_id, '__CF_E2__', 'B', 'Temporal',
        DATE '2000-01-01', 'b@example.com'
    )
    RETURNING id_estudiante INTO estudiante_b_id;

    INSERT INTO public.docente (
        codigo, nombres, apellidos, correo
    )
    VALUES ('__CF_D__', 'D', 'Temporal', 'd@example.com')
    RETURNING id_docente INTO docente_id;

    INSERT INTO public.sede (codigo, nombre, direccion)
    VALUES ('__CF_SEDE__', 'Sede temporal', 'Direccion temporal')
    RETURNING id_sede INTO sede_id;

    INSERT INTO public.salon (id_sede, codigo, capacidad)
    VALUES (sede_id, '__CF_SALON__', 30)
    RETURNING id_salon INTO salon_id;

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__CU_CURSO__', 'Curso prueba cupo')
    RETURNING id_curso INTO curso_id;

    INSERT INTO public.plan_estudio (
        id_carrera, id_curso, semestre_sugerido
    )
    VALUES (carrera_id, curso_id, 1);

    INSERT INTO public.periodo_academico (
        codigo, nombre, fecha_inicio, fecha_fin
    )
    VALUES (
        '__CF_PERIODO__', 'Periodo temporal',
        DATE '2090-01-01', DATE '2090-06-30'
    )
    RETURNING id_periodo_academico INTO periodo_id;

    INSERT INTO public.inscripcion (
        id_estudiante, id_periodo_academico
    )
    VALUES
        (estudiante_a_id, periodo_id),
        (estudiante_b_id, periodo_id);

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico,
        id_docente, codigo, cupo_maximo
    )
    VALUES (
        curso_id, periodo_id,
        docente_id, '__CU_SECCION__', 1
    )
    RETURNING id_seccion INTO seccion_id;

    INSERT INTO public.horario_seccion (
        id_seccion, id_salon, dia_semana,
        hora_inicio, hora_fin
    )
    VALUES (
        seccion_id, salon_id, 1,
        '10:00', '11:00'
    );
END;
$$;

COMMIT;


-- ------------------------------------------------------------
-- 06.3. A: ejecutar SIN COMMIT.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

INSERT INTO public.asignacion_curso (
    id_inscripcion, id_seccion
)
SELECT i.id_inscripcion, s.id_seccion
FROM public.inscripcion AS i
JOIN public.estudiante AS e USING (id_estudiante)
JOIN public.seccion AS s
    ON s.id_periodo_academico = i.id_periodo_academico
WHERE e.carne = '__CF_E1__'
  AND s.codigo = '__CU_SECCION__';

-- Esperado: INSERT 0 1.
-- No confirmar todavía.


-- ------------------------------------------------------------
-- 06.4. B: ejecutar ANTES del COMMIT de A, SIN COMMIT.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

INSERT INTO public.asignacion_curso (
    id_inscripcion, id_seccion
)
SELECT i.id_inscripcion, s.id_seccion
FROM public.inscripcion AS i
JOIN public.estudiante AS e USING (id_estudiante)
JOIN public.seccion AS s
    ON s.id_periodo_academico = i.id_periodo_academico
WHERE e.carne = '__CF_E2__'
  AND s.codigo = '__CU_SECCION__';

-- Esperado: INSERT 0 1, o rechazo durante la operación.
-- Si queda esperando, continuar con el COMMIT de A.
-- Si recibe un error, ejecutar ROLLBACK en B.


-- ------------------------------------------------------------
-- 06.5. A: confirmar.
-- ------------------------------------------------------------

COMMIT;


-- ------------------------------------------------------------
-- 06.6. B: confirmar SOLO si su INSERT terminó sin error.
-- ------------------------------------------------------------

COMMIT;

-- Esperado: una de las transacciones es rechazada.
-- Normalmente SQLSTATE 40001; puede haber rechazo por cupo.
-- No es obligatorio que falle siempre la misma sesión.


-- ------------------------------------------------------------
-- 06.7. SESIÓN RECHAZADA: descartar la transacción.
-- ------------------------------------------------------------

ROLLBACK;


-- ------------------------------------------------------------
-- 06.8. INICIAL: verificar el cupo.
-- ------------------------------------------------------------

SELECT
    s.cupo_maximo,
    COUNT(a.id_asignacion_curso)
        FILTER (WHERE a.estado <> 'cancelada') AS ocupados
FROM public.seccion AS s
LEFT JOIN public.asignacion_curso AS a USING (id_seccion)
WHERE s.codigo = '__CU_SECCION__'
GROUP BY s.id_seccion, s.cupo_maximo;

-- Esperado: una fila con cupo_maximo = 1 y ocupados = 1.


-- ------------------------------------------------------------
-- 06.9. SESIÓN RECHAZADA: reintento completo.
-- Ejecutar después del ROLLBACK.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

INSERT INTO public.asignacion_curso (
    id_inscripcion, id_seccion
)
SELECT i.id_inscripcion, s.id_seccion
FROM public.inscripcion AS i
JOIN public.estudiante AS e USING (id_estudiante)
JOIN public.seccion AS s
    ON s.id_periodo_academico = i.id_periodo_academico
WHERE e.carne IN ('__CF_E1__', '__CF_E2__')
  AND s.codigo = '__CU_SECCION__'
  AND NOT EXISTS (
      SELECT 1
      FROM public.asignacion_curso AS a
      WHERE a.id_inscripcion = i.id_inscripcion
        AND a.id_seccion = s.id_seccion
  );

COMMIT;

-- Esperado: rechazo por cupo excedido, SQLSTATE 23514.
-- Puede ocurrir durante el INSERT o al confirmar.


-- ------------------------------------------------------------
-- 06.10. SESIÓN RECHAZADA: después del error del reintento.
-- ------------------------------------------------------------

ROLLBACK;


-- ------------------------------------------------------------
-- 06.11. INICIAL: verificar nuevamente.
-- ------------------------------------------------------------

SELECT
    s.cupo_maximo,
    COUNT(a.id_asignacion_curso)
        FILTER (WHERE a.estado <> 'cancelada') AS ocupados
FROM public.seccion AS s
LEFT JOIN public.asignacion_curso AS a USING (id_seccion)
WHERE s.codigo = '__CU_SECCION__'
GROUP BY s.id_seccion, s.cupo_maximo;

-- Esperado: cupo_maximo = 1 y ocupados = 1.
-- Conservar la base: la prueba 07 utiliza estos datos.



-- ============================================================
-- CONCURRENCIA C2: CIERRE Y PRERREQUISITOS (PASOS 07.x):
--     CIERRE DE NOTAS Y PRERREQUISITOS
-- ============================================================
-- Ejecutar después de completar la prueba 06.
-- Base: sistema_universitario_pruebas.
-- Utilizar las mismas tres conexiones: INICIAL, A y B.
-- NO ejecutar toda esta sección de una sola vez.
-- Ante un error: guardar el mensaje y ejecutar ROLLBACK.


-- ============================================================
-- ESCENARIO 1: CAMBIO DE NOTA CONTRA CIERRE SIMULTÁNEO
-- ============================================================

-- ------------------------------------------------------------
-- 07.1. INICIAL, A Y B: ejecutar por separado en cada ventana.
-- ------------------------------------------------------------

ROLLBACK;


-- ------------------------------------------------------------
-- 07.2. INICIAL: preparación completa, una sola vez.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    carrera_id integer;
    inscripcion_id integer;
    docente_id integer;
    salon_id integer;
    periodo_id integer;
    curso_id integer;
    seccion_id integer;
    asignacion_id integer;
    actividad_id integer;
BEGIN
    IF current_database() <> 'sistema_universitario_pruebas' THEN
        RAISE EXCEPTION 'Ejecutar únicamente en la base de pruebas.';
    END IF;

    SELECT id_carrera INTO STRICT carrera_id
    FROM public.carrera
    WHERE codigo = '__CF_C__';

    SELECT id_periodo_academico INTO STRICT periodo_id
    FROM public.periodo_academico
    WHERE codigo = '__CF_PERIODO__';

    SELECT i.id_inscripcion INTO STRICT inscripcion_id
    FROM public.inscripcion AS i
    JOIN public.estudiante AS e USING (id_estudiante)
    WHERE e.carne = '__CF_E1__'
      AND i.id_periodo_academico = periodo_id;

    SELECT id_docente INTO STRICT docente_id
    FROM public.docente
    WHERE codigo = '__CF_D__';

    SELECT sa.id_salon INTO STRICT salon_id
    FROM public.salon AS sa
    JOIN public.sede AS sd USING (id_sede)
    WHERE sa.codigo = '__CF_SALON__'
      AND sd.codigo = '__CF_SEDE__';

    INSERT INTO public.curso (codigo, nombre)
    VALUES ('__CN_CURSO__', 'Curso prueba cierre')
    RETURNING id_curso INTO curso_id;

    INSERT INTO public.plan_estudio (
        id_carrera, id_curso, semestre_sugerido
    )
    VALUES (carrera_id, curso_id, 1);

    INSERT INTO public.seccion (
        id_curso, id_periodo_academico,
        id_docente, codigo, cupo_maximo
    )
    VALUES (
        curso_id, periodo_id,
        docente_id, '__CN_SECCION__', 1
    )
    RETURNING id_seccion INTO seccion_id;

    INSERT INTO public.horario_seccion (
        id_seccion, id_salon, dia_semana,
        hora_inicio, hora_fin
    )
    VALUES (
        seccion_id, salon_id, 1,
        '09:00', '10:00'
    );

    INSERT INTO public.asignacion_curso (
        id_inscripcion, id_seccion
    )
    VALUES (inscripcion_id, seccion_id)
    RETURNING id_asignacion_curso INTO asignacion_id;

    INSERT INTO public.actividad_academica (
        id_seccion, nombre, tipo, fecha, puntaje_maximo
    )
    VALUES (
        seccion_id, '__CN_EXAMEN__', 'examen',
        DATE '2090-03-01', 100
    )
    RETURNING id_actividad_academica INTO actividad_id;

    INSERT INTO public.calificacion (
        id_actividad_academica,
        id_asignacion_curso,
        puntaje_obtenido
    )
    VALUES (actividad_id, asignacion_id, 61);
END;
$$;

COMMIT;


-- ------------------------------------------------------------
-- 07.3. INICIAL: comprobar el estado inicial.
-- ------------------------------------------------------------

SELECT
    s.calificaciones_cerradas,
    ac.estado,
    c.puntaje_obtenido
FROM public.seccion AS s
JOIN public.asignacion_curso AS ac USING (id_seccion)
JOIN public.calificacion AS c USING (id_asignacion_curso)
WHERE s.codigo = '__CN_SECCION__';

-- Esperado: una fila con false / cursando / 61.00.


-- ------------------------------------------------------------
-- 07.4. A: iniciar el cierre, SIN COMMIT.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

SELECT public.cerrar_calificaciones(id_seccion)
FROM public.seccion
WHERE codigo = '__CN_SECCION__';


-- ------------------------------------------------------------
-- 07.5. B: cambiar la nota ANTES del COMMIT de A.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

UPDATE public.calificacion AS c
SET puntaje_obtenido = 60
FROM public.actividad_academica AS actividad
JOIN public.seccion AS s USING (id_seccion)
WHERE c.id_actividad_academica =
      actividad.id_actividad_academica
  AND s.codigo = '__CN_SECCION__'
  AND actividad.nombre = '__CN_EXAMEN__';

-- Si queda esperando, continuar con el COMMIT de A.
-- Si recibe un error, ejecutar ROLLBACK en B.


-- ------------------------------------------------------------
-- 07.6. A: confirmar.
-- ------------------------------------------------------------

COMMIT;


-- ------------------------------------------------------------
-- 07.7. B: confirmar SOLO si el UPDATE terminó sin error.
-- ------------------------------------------------------------

COMMIT;

-- Esperado: rechazo de una transacción, normalmente 40001.
-- También puede rechazarse el cambio por notas cerradas.


-- ------------------------------------------------------------
-- 07.8. SESIÓN RECHAZADA: descartar.
-- ------------------------------------------------------------

ROLLBACK;


-- ------------------------------------------------------------
-- 07.9. INICIAL: verificar el resultado.
-- ------------------------------------------------------------

SELECT
    s.calificaciones_cerradas,
    ac.estado,
    c.puntaje_obtenido
FROM public.seccion AS s
JOIN public.asignacion_curso AS ac USING (id_seccion)
JOIN public.calificacion AS c USING (id_asignacion_curso)
WHERE s.codigo = '__CN_SECCION__';

-- Resultados válidos:
--   true  / aprobada / 61.00: confirmó el cierre.
--   false / cursando / 60.00: confirmó el cambio y falló el cierre.
--
-- Nunca debe quedar true / aprobada / 60.00.
-- Una de las operaciones debe haber sido rechazada.


-- ------------------------------------------------------------
-- 07.10. B: reintento SOLO si el cierre quedó confirmado.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

UPDATE public.calificacion AS c
SET puntaje_obtenido = 60
FROM public.actividad_academica AS actividad
JOIN public.seccion AS s USING (id_seccion)
WHERE c.id_actividad_academica =
      actividad.id_actividad_academica
  AND s.codigo = '__CN_SECCION__'
  AND actividad.nombre = '__CN_EXAMEN__';

-- Esperado: SQLSTATE 23514, no se modifican notas cerradas.
-- No ejecutar este bloque si la sección quedó abierta.


-- ------------------------------------------------------------
-- 07.11. B: después del error del reintento.
-- ------------------------------------------------------------

ROLLBACK;


-- ============================================================
-- ESCENARIO 2: QUITAR UN CURSO CONTRA NUEVO PRERREQUISITO
-- ============================================================

-- ------------------------------------------------------------
-- 07.12. A Y B: ejecutar por separado.
-- ------------------------------------------------------------

ROLLBACK;


-- ------------------------------------------------------------
-- 07.13. INICIAL: preparación completa, una sola vez.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
DECLARE
    carrera_id integer;
BEGIN
    IF current_database() <> 'sistema_universitario_pruebas' THEN
        RAISE EXCEPTION 'Ejecutar únicamente en la base de pruebas.';
    END IF;

    SELECT id_carrera INTO STRICT carrera_id
    FROM public.carrera
    WHERE codigo = '__CF_C__';

    INSERT INTO public.curso (codigo, nombre)
    VALUES
        ('__CP_A__', 'Curso temporal A'),
        ('__CP_B__', 'Curso temporal B');

    INSERT INTO public.plan_estudio (
        id_carrera, id_curso, semestre_sugerido
    )
    SELECT carrera_id, c.id_curso, 1
    FROM public.curso AS c
    WHERE c.codigo IN ('__CP_A__', '__CP_B__');
END;
$$;

COMMIT;


-- ------------------------------------------------------------
-- 07.14. A: quitar B del plan, SIN COMMIT.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

DELETE FROM public.plan_estudio AS p
USING public.curso AS c, public.carrera AS ca
WHERE p.id_curso = c.id_curso
  AND p.id_carrera = ca.id_carrera
  AND c.codigo = '__CP_B__'
  AND ca.codigo = '__CF_C__';

-- Esperado: DELETE 1.
-- Si muestra DELETE 0, detener la prueba y revisar preparación.


-- ------------------------------------------------------------
-- 07.15. B: agregar el prerrequisito ANTES del COMMIT de A.
-- ------------------------------------------------------------

BEGIN ISOLATION LEVEL SERIALIZABLE;

INSERT INTO public.prerrequisito (
    id_curso, id_curso_requisito
)
SELECT a.id_curso, b.id_curso
FROM public.curso AS a
CROSS JOIN public.curso AS b
WHERE a.codigo = '__CP_A__'
  AND b.codigo = '__CP_B__';

-- Esperado: INSERT 0 1, o rechazo durante la operación.
-- Si queda esperando, continuar con el COMMIT de A.


-- ------------------------------------------------------------
-- 07.16. A: confirmar.
-- ------------------------------------------------------------

COMMIT;


-- ------------------------------------------------------------
-- 07.17. B: confirmar SOLO si el INSERT terminó sin error.
-- ------------------------------------------------------------

COMMIT;

-- Esperado: una transacción rechazada, normalmente 40001.
-- Puede producirse un rechazo específico de integridad, 23514.


-- ------------------------------------------------------------
-- 07.18. SESIÓN RECHAZADA: descartar.
-- ------------------------------------------------------------

ROLLBACK;


-- ------------------------------------------------------------
-- 07.19. INICIAL: verificar integridad del plan.
-- ------------------------------------------------------------

SELECT
    ca.codigo AS carrera,
    c.codigo AS curso,
    r.codigo AS requisito_faltante
FROM public.plan_estudio AS p
JOIN public.carrera AS ca USING (id_carrera)
JOIN public.curso AS c USING (id_curso)
JOIN public.prerrequisito AS pr
    ON pr.id_curso = c.id_curso
JOIN public.curso AS r
    ON r.id_curso = pr.id_curso_requisito
WHERE ca.codigo = '__CF_C__'
  AND NOT EXISTS (
      SELECT 1
      FROM public.plan_estudio AS requisito
      WHERE requisito.id_carrera = p.id_carrera
        AND requisito.id_curso = r.id_curso
  );

-- Esperado: cero filas.


-- ------------------------------------------------------------
-- 07.20. INICIAL: comprobar qué operación quedó confirmada.
-- ------------------------------------------------------------

SELECT
    EXISTS (
        SELECT 1
        FROM public.plan_estudio AS p
        JOIN public.carrera AS ca USING (id_carrera)
        JOIN public.curso AS c USING (id_curso)
        WHERE ca.codigo = '__CF_C__'
          AND c.codigo = '__CP_B__'
    ) AS curso_b_en_plan,
    EXISTS (
        SELECT 1
        FROM public.prerrequisito AS pr
        JOIN public.curso AS a
            ON a.id_curso = pr.id_curso
        JOIN public.curso AS b
            ON b.id_curso = pr.id_curso_requisito
        WHERE a.codigo = '__CP_A__'
          AND b.codigo = '__CP_B__'
    ) AS prerrequisito_creado;

-- Resultados:
--   false / false: confirmó A; B fue rechazada.
--   true  / true:  confirmó B; A fue rechazada.
--   true  / false: no quedó ningún cambio; revisar errores.
--   false / true:  estado inválido; revisar las reglas.


-- ============================================================
-- LIMPIEZA FINAL, DESPUÉS DE VERIFICAR 06 Y 07
-- ============================================================
-- Guardar errores y resultados como evidencia.
-- Cerrar TODOS los Query Tool de sistema_universitario_pruebas.
-- Abrir un Query Tool conectado a postgres.
-- Ejecutar allí, por separado:
--
-- DROP DATABASE sistema_universitario_pruebas;
--
-- No eliminar la base principal sistema_universitario.