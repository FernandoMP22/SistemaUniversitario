-- ============================================================
-- REGLAS ADICIONALES DE SISTEMA UNIVERSITARIO
-- Ejecutar después de 01_DDL_SistemaUniversitario.sql.
-- Los triggers se recrean para permitir repetir la instalación.
-- Ejecutar sin operaciones concurrentes durante la instalación.
-- La restricción de períodos se crea únicamente si no existe.
-- ============================================================



-- ============================================================
-- BLOQUE 1: PERÍODOS ACADÉMICOS SIN SUPERPOSICIÓN
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.periodo_academico'::regclass
          AND conname = 'ex_periodo_academico_fechas'
    ) THEN
        ALTER TABLE public.periodo_academico
            ADD CONSTRAINT ex_periodo_academico_fechas
            EXCLUDE USING gist (
                daterange(fecha_inicio, fecha_fin, '[]') WITH &&
            );
    END IF;
END;
$$;


-- ============================================================
-- INICIO BLOQUE 2: PRERREQUISITOS SIN CICLOS
-- ============================================================


CREATE OR REPLACE FUNCTION public.validar_ciclo_prerrequisito()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    existe_ciclo boolean;
BEGIN

    -- Exigir aislamiento serializable para proteger
    -- también los cambios simultáneos.

    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION USING
            ERRCODE = '25000',
            MESSAGE = 'Los cambios de prerrequisitos requieren una transacción SERIALIZABLE.';
    END IF;


    -- Recorrer los requisitos del curso propuesto como requisito.
    -- Si llegamos al curso original, la relación forma un ciclo.

    WITH RECURSIVE requisitos(id_curso) AS (
        SELECT NEW.id_curso_requisito

        UNION

        SELECT p.id_curso_requisito
        FROM public.prerrequisito AS p
        INNER JOIN requisitos AS r
            ON p.id_curso = r.id_curso
        WHERE p.id_prerrequisito <> NEW.id_prerrequisito
    )
    SELECT EXISTS (
        SELECT 1
        FROM requisitos
        WHERE id_curso = NEW.id_curso
    )
    INTO existe_ciclo;


    IF existe_ciclo THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'El prerrequisito forma un ciclo.',
            CONSTRAINT = 'regla_prerrequisito_sin_ciclos';
    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_prerrequisito_sin_ciclos
ON public.prerrequisito;

CREATE TRIGGER trg_prerrequisito_sin_ciclos
BEFORE INSERT OR UPDATE
ON public.prerrequisito
FOR EACH ROW
EXECUTE FUNCTION public.validar_ciclo_prerrequisito();


-- ============================================================
-- FIN BLOQUE 2
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 3: PRERREQUISITOS INCLUIDOS EN LOS PLANES
-- ============================================================


CREATE OR REPLACE FUNCTION public.validar_prerrequisitos_en_planes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION USING
            ERRCODE = '25000',
            MESSAGE = 'Los cambios de planes y prerrequisitos requieren una transacción SERIALIZABLE.';
    END IF;


    -- Buscar un curso incluido en una carrera cuyo requisito
    -- no esté incluido en el plan de esa misma carrera.

    IF EXISTS (
        SELECT 1
        FROM public.plan_estudio AS plan
        INNER JOIN public.prerrequisito AS requisito
            ON requisito.id_curso = plan.id_curso
        WHERE NOT EXISTS (
            SELECT 1
            FROM public.plan_estudio AS plan_requisito
            WHERE plan_requisito.id_carrera = plan.id_carrera
              AND plan_requisito.id_curso =
                  requisito.id_curso_requisito
        )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Un plan incluye un curso sin incluir todos sus prerrequisitos.',
            CONSTRAINT = 'regla_prerrequisitos_en_planes';
    END IF;

    RETURN NULL;

END;
$$;


DROP TRIGGER IF EXISTS trg_plan_prerrequisitos_completos
ON public.plan_estudio;

CREATE CONSTRAINT TRIGGER trg_plan_prerrequisitos_completos
AFTER INSERT OR UPDATE OR DELETE
ON public.plan_estudio
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_prerrequisitos_en_planes();


DROP TRIGGER IF EXISTS trg_prerrequisito_planes_completos
ON public.prerrequisito;

CREATE CONSTRAINT TRIGGER trg_prerrequisito_planes_completos
AFTER INSERT OR UPDATE OR DELETE
ON public.prerrequisito
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_prerrequisitos_en_planes();


-- ============================================================
-- FIN BLOQUE 3
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 4: CAPACIDAD Y SEDE DE LOS SALONES
-- ============================================================


CREATE OR REPLACE FUNCTION public.validar_capacidad_sede_secciones()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION USING
            ERRCODE = '25000',
            MESSAGE = 'Los cambios de horarios, secciones y salones requieren una transacción SERIALIZABLE.';
    END IF;


    -- Regla 1: cada salón debe admitir el cupo de la sección.

    IF EXISTS (
        SELECT 1
        FROM public.horario_seccion AS h
        INNER JOIN public.seccion AS s
            ON s.id_seccion = h.id_seccion
        INNER JOIN public.salon AS salon
            ON salon.id_salon = h.id_salon
        WHERE salon.capacidad < s.cupo_maximo
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'La capacidad de un salón es menor que el cupo de su sección.',
            CONSTRAINT = 'regla_salon_capacidad_seccion';
    END IF;


    -- Regla 2: una sección no puede utilizar distintas sedes.

    IF EXISTS (
        SELECT h.id_seccion
        FROM public.horario_seccion AS h
        INNER JOIN public.salon AS salon
            ON salon.id_salon = h.id_salon
        GROUP BY h.id_seccion
        HAVING COUNT(DISTINCT salon.id_sede) > 1
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Los horarios de una sección deben pertenecer a la misma sede.',
            CONSTRAINT = 'regla_seccion_sede_unica';
    END IF;

    RETURN NULL;

END;
$$;


DROP TRIGGER IF EXISTS trg_horario_capacidad_sede
ON public.horario_seccion;

CREATE CONSTRAINT TRIGGER trg_horario_capacidad_sede
AFTER INSERT OR UPDATE OR DELETE
ON public.horario_seccion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_capacidad_sede_secciones();


DROP TRIGGER IF EXISTS trg_seccion_capacidad_sede
ON public.seccion;

CREATE CONSTRAINT TRIGGER trg_seccion_capacidad_sede
AFTER INSERT OR UPDATE
ON public.seccion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_capacidad_sede_secciones();


DROP TRIGGER IF EXISTS trg_salon_capacidad_sede
ON public.salon;

CREATE CONSTRAINT TRIGGER trg_salon_capacidad_sede
AFTER INSERT OR UPDATE
ON public.salon
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_capacidad_sede_secciones();


-- ============================================================
-- FIN BLOQUE 4
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 5: CONFLICTOS DE HORARIOS
-- ============================================================


CREATE OR REPLACE FUNCTION public.validar_conflictos_horarios()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION USING
            ERRCODE = '25000',
            MESSAGE = 'Los cambios de horarios y secciones requieren una transacción SERIALIZABLE.';
    END IF;


    IF EXISTS (
        SELECT 1
        FROM public.horario_seccion AS h1
        INNER JOIN public.horario_seccion AS h2
            ON h1.id_horario_seccion < h2.id_horario_seccion
        INNER JOIN public.seccion AS s1
            ON s1.id_seccion = h1.id_seccion
        INNER JOIN public.seccion AS s2
            ON s2.id_seccion = h2.id_seccion
        WHERE h1.dia_semana = h2.dia_semana
          AND s1.id_periodo_academico = s2.id_periodo_academico
          AND h1.hora_inicio < h2.hora_fin
          AND h2.hora_inicio < h1.hora_fin
          AND (
              h1.id_seccion = h2.id_seccion
              OR h1.id_salon = h2.id_salon
              OR s1.id_docente = s2.id_docente
          )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Existe un cruce de horarios de sección, salón o docente.',
            CONSTRAINT = 'regla_horarios_sin_conflictos';
    END IF;

    RETURN NULL;

END;
$$;


DROP TRIGGER IF EXISTS trg_horario_sin_conflictos
ON public.horario_seccion;

CREATE CONSTRAINT TRIGGER trg_horario_sin_conflictos
AFTER INSERT OR UPDATE OR DELETE
ON public.horario_seccion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_conflictos_horarios();


DROP TRIGGER IF EXISTS trg_seccion_sin_conflictos
ON public.seccion;

CREATE CONSTRAINT TRIGGER trg_seccion_sin_conflictos
AFTER INSERT OR UPDATE
ON public.seccion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_conflictos_horarios();


-- ============================================================
-- FIN BLOQUE 5
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 6: COHERENCIA BÁSICA DE ASIGNACIONES
-- ============================================================


CREATE OR REPLACE FUNCTION public.validar_coherencia_asignaciones()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION USING
            ERRCODE = '25000',
            MESSAGE = 'Los cambios relacionados con asignaciones requieren una transacción SERIALIZABLE.';
    END IF;


    -- La inscripción y la sección deben tener el mismo período.
    -- También se comprueba en asignaciones canceladas.

    IF EXISTS (
        SELECT 1
        FROM public.asignacion_curso AS a
        INNER JOIN public.inscripcion AS i
            ON i.id_inscripcion = a.id_inscripcion
        INNER JOIN public.seccion AS s
            ON s.id_seccion = a.id_seccion
        WHERE i.id_periodo_academico <> s.id_periodo_academico
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'La sección y la inscripción pertenecen a distintos períodos.',
            CONSTRAINT = 'regla_asignacion_periodo';
    END IF;


    -- El curso de una asignación vigente debe estar en el plan
    -- de la carrera del estudiante.

    IF EXISTS (
        SELECT 1
        FROM public.asignacion_curso AS a
        INNER JOIN public.inscripcion AS i
            ON i.id_inscripcion = a.id_inscripcion
        INNER JOIN public.estudiante AS e
            ON e.id_estudiante = i.id_estudiante
        INNER JOIN public.seccion AS s
            ON s.id_seccion = a.id_seccion
        WHERE a.estado <> 'cancelada'
          AND NOT EXISTS (
              SELECT 1
              FROM public.plan_estudio AS p
              WHERE p.id_carrera = e.id_carrera
                AND p.id_curso = s.id_curso
          )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'El curso asignado no pertenece al plan de la carrera del estudiante.',
            CONSTRAINT = 'regla_asignacion_plan';
    END IF;


    -- Una asignación vigente necesita una sección con horario.

    IF EXISTS (
        SELECT 1
        FROM public.asignacion_curso AS a
        WHERE a.estado <> 'cancelada'
          AND NOT EXISTS (
              SELECT 1
              FROM public.horario_seccion AS h
              WHERE h.id_seccion = a.id_seccion
          )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Una sección con asignaciones vigentes debe tener horario.',
            CONSTRAINT = 'regla_asignacion_horario';
    END IF;

    RETURN NULL;

END;
$$;


DROP TRIGGER IF EXISTS trg_asignacion_coherencia
ON public.asignacion_curso;

CREATE CONSTRAINT TRIGGER trg_asignacion_coherencia
AFTER INSERT OR UPDATE OR DELETE
ON public.asignacion_curso
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_coherencia_asignaciones();


DROP TRIGGER IF EXISTS trg_inscripcion_coherencia
ON public.inscripcion;

CREATE CONSTRAINT TRIGGER trg_inscripcion_coherencia
AFTER INSERT OR UPDATE
ON public.inscripcion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_coherencia_asignaciones();


DROP TRIGGER IF EXISTS trg_seccion_coherencia
ON public.seccion;

CREATE CONSTRAINT TRIGGER trg_seccion_coherencia
AFTER INSERT OR UPDATE
ON public.seccion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_coherencia_asignaciones();


DROP TRIGGER IF EXISTS trg_estudiante_coherencia
ON public.estudiante;

CREATE CONSTRAINT TRIGGER trg_estudiante_coherencia
AFTER INSERT OR UPDATE
ON public.estudiante
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_coherencia_asignaciones();


DROP TRIGGER IF EXISTS trg_plan_coherencia
ON public.plan_estudio;

CREATE CONSTRAINT TRIGGER trg_plan_coherencia
AFTER INSERT OR UPDATE OR DELETE
ON public.plan_estudio
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_coherencia_asignaciones();


DROP TRIGGER IF EXISTS trg_horario_coherencia
ON public.horario_seccion;

CREATE CONSTRAINT TRIGGER trg_horario_coherencia
AFTER INSERT OR UPDATE OR DELETE
ON public.horario_seccion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_coherencia_asignaciones();


-- ============================================================
-- FIN BLOQUE 6
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 7: CUPO Y CONFLICTOS DE ASIGNACIONES
-- ============================================================


CREATE OR REPLACE FUNCTION public.validar_cupo_conflictos_asignaciones()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION USING
            ERRCODE = '25000',
            MESSAGE = 'Los cambios relacionados con asignaciones requieren SERIALIZABLE.';
    END IF;


    -- 1. Las asignaciones no canceladas no deben superar el cupo.

    IF EXISTS (
        SELECT s.id_seccion
        FROM public.seccion AS s
        INNER JOIN public.asignacion_curso AS a
            ON a.id_seccion = s.id_seccion
        WHERE a.estado <> 'cancelada'
        GROUP BY s.id_seccion, s.cupo_maximo
        HAVING COUNT(*) > s.cupo_maximo
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Las asignaciones superan el cupo de una sección.',
            CONSTRAINT = 'regla_asignacion_cupo';
    END IF;


    -- 2. Un estudiante no puede tener dos asignaciones
    -- no canceladas del mismo curso en un período.

    IF EXISTS (
        SELECT i.id_estudiante, i.id_periodo_academico, s.id_curso
        FROM public.asignacion_curso AS a
        INNER JOIN public.inscripcion AS i
            ON i.id_inscripcion = a.id_inscripcion
        INNER JOIN public.seccion AS s
            ON s.id_seccion = a.id_seccion
        WHERE a.estado <> 'cancelada'
        GROUP BY
            i.id_estudiante,
            i.id_periodo_academico,
            s.id_curso
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Un estudiante tiene el mismo curso asignado dos veces en un período.',
            CONSTRAINT = 'regla_asignacion_curso_unico';
    END IF;


    -- 3. Un estudiante no puede tener asignaciones no canceladas
    -- cuyos horarios se superpongan dentro del mismo período.

    IF EXISTS (
        SELECT 1
        FROM public.asignacion_curso AS a1
        INNER JOIN public.asignacion_curso AS a2
            ON a1.id_asignacion_curso < a2.id_asignacion_curso
        INNER JOIN public.inscripcion AS i1
            ON i1.id_inscripcion = a1.id_inscripcion
        INNER JOIN public.inscripcion AS i2
            ON i2.id_inscripcion = a2.id_inscripcion
        INNER JOIN public.horario_seccion AS h1
            ON h1.id_seccion = a1.id_seccion
        INNER JOIN public.horario_seccion AS h2
            ON h2.id_seccion = a2.id_seccion
        WHERE a1.estado <> 'cancelada'
          AND a2.estado <> 'cancelada'
          AND i1.id_estudiante = i2.id_estudiante
          AND i1.id_periodo_academico = i2.id_periodo_academico
          AND h1.dia_semana = h2.dia_semana
          AND h1.hora_inicio < h2.hora_fin
          AND h2.hora_inicio < h1.hora_fin
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Un estudiante tiene cursos con horarios superpuestos.',
            CONSTRAINT = 'regla_asignacion_horario_estudiante';
    END IF;

    RETURN NULL;

END;
$$;


DROP TRIGGER IF EXISTS trg_asignacion_cupo_conflictos
ON public.asignacion_curso;

CREATE CONSTRAINT TRIGGER trg_asignacion_cupo_conflictos
AFTER INSERT OR UPDATE OR DELETE
ON public.asignacion_curso
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_cupo_conflictos_asignaciones();


DROP TRIGGER IF EXISTS trg_seccion_cupo_conflictos
ON public.seccion;

CREATE CONSTRAINT TRIGGER trg_seccion_cupo_conflictos
AFTER INSERT OR UPDATE
ON public.seccion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_cupo_conflictos_asignaciones();


DROP TRIGGER IF EXISTS trg_horario_asignacion_conflictos
ON public.horario_seccion;

CREATE CONSTRAINT TRIGGER trg_horario_asignacion_conflictos
AFTER INSERT OR UPDATE OR DELETE
ON public.horario_seccion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_cupo_conflictos_asignaciones();


DROP TRIGGER IF EXISTS trg_inscripcion_asignacion_conflictos
ON public.inscripcion;

CREATE CONSTRAINT TRIGGER trg_inscripcion_asignacion_conflictos
AFTER INSERT OR UPDATE
ON public.inscripcion
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validar_cupo_conflictos_asignaciones();


-- ============================================================
-- FIN BLOQUE 7
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 8: INICIO Y REACTIVACIÓN DE ASIGNACIONES
-- ============================================================


CREATE OR REPLACE FUNCTION public.validar_inicio_asignacion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    estado_inscripcion varchar(15);
    comprobar_inscripcion boolean := false;
BEGIN

    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION USING
            ERRCODE = '25000',
            MESSAGE = 'Los cambios de asignaciones requieren SERIALIZABLE.';
    END IF;


    IF TG_OP = 'INSERT' THEN

        IF NEW.estado <> 'cursando' THEN
            RAISE EXCEPTION USING
                ERRCODE = '23514',
                MESSAGE = 'Una asignación nueva debe comenzar en cursando.',
                CONSTRAINT = 'regla_asignacion_estado_inicial';
        END IF;

        comprobar_inscripcion := true;

    ELSE

        -- Conservar la identidad académica del registro.

        IF NEW.id_inscripcion <> OLD.id_inscripcion
           OR NEW.id_seccion <> OLD.id_seccion THEN
            RAISE EXCEPTION USING
                ERRCODE = '23514',
                MESSAGE = 'No se puede cambiar la inscripción o sección de una asignación existente.',
                CONSTRAINT = 'regla_asignacion_identidad';
        END IF;


        IF OLD.estado = 'cancelada'
           AND NEW.estado <> 'cancelada' THEN

            IF NEW.estado <> 'cursando' THEN
                RAISE EXCEPTION USING
                    ERRCODE = '23514',
                    MESSAGE = 'Una asignación cancelada solo puede reactivarse a cursando.',
                    CONSTRAINT = 'regla_asignacion_reactivacion';
            END IF;

            comprobar_inscripcion := true;

        END IF;

    END IF;


    IF comprobar_inscripcion THEN

        SELECT estado
        INTO estado_inscripcion
        FROM public.inscripcion
        WHERE id_inscripcion = NEW.id_inscripcion;

        -- Una inscripción inexistente será rechazada por la FK.
        -- Aquí comprobamos el estado de las que sí existen.

        IF FOUND THEN
            IF estado_inscripcion <> 'activa' THEN
                RAISE EXCEPTION USING
                    ERRCODE = '23514',
                    MESSAGE = 'La inscripción debe estar activa para asignar o reactivar cursos.',
                    CONSTRAINT = 'regla_asignacion_inscripcion_activa';
            END IF;
        END IF;

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_asignacion_inicio
ON public.asignacion_curso;

CREATE TRIGGER trg_asignacion_inicio
BEFORE INSERT OR UPDATE
ON public.asignacion_curso
FOR EACH ROW
EXECUTE FUNCTION public.validar_inicio_asignacion();


-- ============================================================
-- FIN BLOQUE 8
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 9: REQUISITOS ACADÉMICOS DE ASIGNACIÓN
-- ============================================================


CREATE OR REPLACE FUNCTION public.validar_requisitos_asignacion()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    estudiante_actual integer;
    curso_actual integer;
    inicio_periodo_actual date;
BEGIN

    -- Comprobar nuevas asignaciones y reactivaciones.
    -- Los cambios de resultado académico se validarán al cerrar notas.

    IF TG_OP = 'UPDATE' THEN
        IF NOT (
            OLD.estado = 'cancelada'
            AND NEW.estado = 'cursando'
        ) THEN
            RETURN NEW;
        END IF;
    END IF;


    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION USING
            ERRCODE = '25000',
            MESSAGE = 'La asignación de cursos requiere SERIALIZABLE.';
    END IF;


    SELECT
        i.id_estudiante,
        s.id_curso,
        p.fecha_inicio
    INTO
        estudiante_actual,
        curso_actual,
        inicio_periodo_actual
    FROM public.inscripcion AS i
    CROSS JOIN public.seccion AS s
    INNER JOIN public.periodo_academico AS p
        ON p.id_periodo_academico = s.id_periodo_academico
    WHERE i.id_inscripcion = NEW.id_inscripcion
      AND s.id_seccion = NEW.id_seccion;

    -- Las referencias inexistentes serán rechazadas por las FK.

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;


    -- 1. Rechazar un curso que el estudiante ya aprobó.

    IF EXISTS (
        SELECT 1
        FROM public.asignacion_curso AS a
        INNER JOIN public.inscripcion AS i
            ON i.id_inscripcion = a.id_inscripcion
        INNER JOIN public.seccion AS s
            ON s.id_seccion = a.id_seccion
        WHERE i.id_estudiante = estudiante_actual
          AND s.id_curso = curso_actual
          AND a.estado = 'aprobada'
          AND s.calificaciones_cerradas = true
          AND a.id_asignacion_curso <> NEW.id_asignacion_curso
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'El estudiante ya aprobó este curso.',
            CONSTRAINT = 'regla_curso_ya_aprobado';
    END IF;


    -- 2. Buscar un prerrequisito sin aprobación anterior.

    IF EXISTS (
        SELECT 1
        FROM public.prerrequisito AS requisito
        WHERE requisito.id_curso = curso_actual
          AND NOT EXISTS (
              SELECT 1
              FROM public.asignacion_curso AS a
              INNER JOIN public.inscripcion AS i
                  ON i.id_inscripcion = a.id_inscripcion
              INNER JOIN public.seccion AS s
                  ON s.id_seccion = a.id_seccion
              INNER JOIN public.periodo_academico AS p
                  ON p.id_periodo_academico =
                     s.id_periodo_academico
              WHERE i.id_estudiante = estudiante_actual
                AND s.id_curso = requisito.id_curso_requisito
                AND a.estado = 'aprobada'
                AND s.calificaciones_cerradas = true
                AND p.fecha_fin < inicio_periodo_actual
          )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'El estudiante no aprobó todos los prerrequisitos en períodos anteriores.',
            CONSTRAINT = 'regla_prerrequisitos_aprobados';
    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS trg_asignacion_requisitos_academicos
ON public.asignacion_curso;

CREATE TRIGGER trg_asignacion_requisitos_academicos
BEFORE INSERT OR UPDATE
ON public.asignacion_curso
FOR EACH ROW
EXECUTE FUNCTION public.validar_requisitos_asignacion();


-- ============================================================
-- FIN BLOQUE 9
-- ============================================================




-- ============================================================
-- INICIO BLOQUE 10: ACTIVIDADES Y TRANSACCIONES
-- ============================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.exigir_transaccion_serializable()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION USING ERRCODE = '25000',
            MESSAGE = 'Esta operación requiere BEGIN ISOLATION LEVEL SERIALIZABLE.';
    END IF;
    RETURN NULL;
END;
$$;

-- Control al iniciar la sentencia, incluso si no afecta filas.
DO $$
DECLARE tabla text;
BEGIN
    FOREACH tabla IN ARRAY ARRAY[
        'actividad_academica','calificacion','seccion','asignacion_curso',
        'inscripcion','pago','periodo_academico','estudiante',
        'plan_estudio','prerrequisito','horario_seccion','salon'
    ] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_exigir_serializable ON public.%I', tabla);
        EXECUTE format(
            'CREATE TRIGGER trg_exigir_serializable BEFORE INSERT OR UPDATE OR DELETE
             ON public.%I FOR EACH STATEMENT
             EXECUTE FUNCTION public.exigir_transaccion_serializable()', tabla);
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.proteger_actividad()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE cerrada boolean;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        SELECT calificaciones_cerradas INTO cerrada
        FROM public.seccion WHERE id_seccion = OLD.id_seccion;
        IF cerrada THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'La sección ya está cerrada.',
                CONSTRAINT = 'regla_actividad_cerrada';
        END IF;
        IF TG_OP = 'UPDATE' AND NEW.id_seccion <> OLD.id_seccion THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se puede trasladar una actividad.',
                CONSTRAINT = 'regla_actividad_identidad';
        END IF;
    END IF;
    IF TG_OP <> 'DELETE' THEN
        SELECT calificaciones_cerradas INTO cerrada
        FROM public.seccion WHERE id_seccion = NEW.id_seccion;
        IF cerrada THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'La sección ya está cerrada.',
                CONSTRAINT = 'regla_actividad_cerrada';
        END IF;
        RETURN NEW;
    END IF;
    RETURN OLD;
END;
$$;
DROP TRIGGER IF EXISTS trg_proteger_actividad ON public.actividad_academica;
CREATE TRIGGER trg_proteger_actividad BEFORE INSERT OR UPDATE OR DELETE
ON public.actividad_academica FOR EACH ROW EXECUTE FUNCTION public.proteger_actividad();

CREATE OR REPLACE FUNCTION public.validar_actividades()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.actividad_academica a
        JOIN public.seccion s USING (id_seccion)
        JOIN public.periodo_academico p USING (id_periodo_academico)
        WHERE a.fecha NOT BETWEEN p.fecha_inicio AND p.fecha_fin
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Actividad fuera del período.',
            CONSTRAINT = 'regla_actividad_fecha';
    END IF;
    IF EXISTS (
        SELECT id_seccion FROM public.actividad_academica
        GROUP BY id_seccion HAVING SUM(puntaje_maximo) > 100
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Las actividades superan 100 puntos.',
            CONSTRAINT = 'regla_actividad_suma';
    END IF;
    RETURN NULL;
END;
$$;
DO $$
DECLARE tabla text;
BEGIN
    FOREACH tabla IN ARRAY ARRAY['actividad_academica','seccion','periodo_academico'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_validar_actividades ON public.%I', tabla);
        EXECUTE format('CREATE CONSTRAINT TRIGGER trg_validar_actividades
            AFTER INSERT OR UPDATE OR DELETE ON public.%I
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
            EXECUTE FUNCTION public.validar_actividades()', tabla);
    END LOOP;
END;
$$;
COMMIT;
-- FIN BLOQUE 10



-- ============================================================
-- INICIO BLOQUE 11: CALIFICACIONES
-- ============================================================
BEGIN;
CREATE OR REPLACE FUNCTION public.proteger_calificacion()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE cerrada boolean; estado_asignacion text;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        SELECT s.calificaciones_cerradas INTO cerrada
        FROM public.actividad_academica a JOIN public.seccion s USING (id_seccion)
        WHERE a.id_actividad_academica = OLD.id_actividad_academica;
        IF cerrada THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se modifican notas cerradas.',
                CONSTRAINT = 'regla_calificacion_cerrada';
        END IF;
        IF TG_OP = 'UPDATE' AND (
            NEW.id_actividad_academica <> OLD.id_actividad_academica OR
            NEW.id_asignacion_curso <> OLD.id_asignacion_curso
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se puede trasladar una calificación.',
                CONSTRAINT = 'regla_calificacion_identidad';
        END IF;
    END IF;
    IF TG_OP <> 'DELETE' THEN
        SELECT s.calificaciones_cerradas INTO cerrada
        FROM public.actividad_academica a JOIN public.seccion s USING (id_seccion)
        WHERE a.id_actividad_academica = NEW.id_actividad_academica;
        IF cerrada THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se modifican notas cerradas.',
                CONSTRAINT = 'regla_calificacion_cerrada';
        END IF;
        SELECT estado INTO estado_asignacion FROM public.asignacion_curso
        WHERE id_asignacion_curso = NEW.id_asignacion_curso;
        IF estado_asignacion = 'cancelada' THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'La asignación está cancelada.',
                CONSTRAINT = 'regla_calificacion_cancelada';
        END IF;
        RETURN NEW;
    END IF;
    RETURN OLD;
END;
$$;
DROP TRIGGER IF EXISTS trg_proteger_calificacion ON public.calificacion;
CREATE TRIGGER trg_proteger_calificacion BEFORE INSERT OR UPDATE OR DELETE
ON public.calificacion FOR EACH ROW EXECUTE FUNCTION public.proteger_calificacion();

CREATE OR REPLACE FUNCTION public.validar_calificaciones()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.calificacion c
        JOIN public.actividad_academica a USING (id_actividad_academica)
        JOIN public.asignacion_curso ac USING (id_asignacion_curso)
        WHERE a.id_seccion <> ac.id_seccion
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Actividad y asignación de distinta sección.',
            CONSTRAINT = 'regla_calificacion_seccion';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.calificacion c
        JOIN public.actividad_academica a USING (id_actividad_academica)
        WHERE c.puntaje_obtenido > a.puntaje_maximo
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Puntaje mayor que el máximo de la actividad.',
            CONSTRAINT = 'regla_calificacion_maximo';
    END IF;
    RETURN NULL;
END;
$$;
DO $$
DECLARE tabla text;
BEGIN
    FOREACH tabla IN ARRAY ARRAY['calificacion','actividad_academica','asignacion_curso'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_validar_calificaciones ON public.%I', tabla);
        EXECUTE format('CREATE CONSTRAINT TRIGGER trg_validar_calificaciones
            AFTER INSERT OR UPDATE OR DELETE ON public.%I
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
            EXECUTE FUNCTION public.validar_calificaciones()', tabla);
    END LOOP;
END;
$$;
COMMIT;
-- FIN BLOQUE 11



-- ============================================================
-- INICIO BLOQUE 12: CIERRE DE NOTAS Y RESULTADOS
-- ============================================================
BEGIN;
CREATE OR REPLACE FUNCTION public.proteger_seccion_cierre()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE total numeric;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.calificaciones_cerradas THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Una sección nueva comienza abierta.',
                CONSTRAINT = 'regla_seccion_inicial';
        END IF;
        RETURN NEW;
    END IF;
    IF TG_OP = 'DELETE' THEN
        IF OLD.calificaciones_cerradas THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se elimina una sección cerrada.',
                CONSTRAINT = 'regla_seccion_cerrada';
        END IF;
        RETURN OLD;
    END IF;
    IF OLD.calificaciones_cerradas AND NEW IS DISTINCT FROM OLD THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'La sección cerrada es inmutable.',
            CONSTRAINT = 'regla_seccion_cerrada';
    END IF;
    IF (NEW.id_curso <> OLD.id_curso OR
        NEW.id_periodo_academico <> OLD.id_periodo_academico)
        AND EXISTS (SELECT 1 FROM public.asignacion_curso WHERE id_seccion = OLD.id_seccion) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Una sección asignada no cambia de curso o período.',
            CONSTRAINT = 'regla_seccion_identidad';
    END IF;
    IF NOT OLD.calificaciones_cerradas AND NEW.calificaciones_cerradas THEN
        SELECT COALESCE(SUM(puntaje_maximo), 0) INTO total
        FROM public.actividad_academica WHERE id_seccion = OLD.id_seccion;
        IF total <> 100 THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'El cierre exige exactamente 100 puntos.',
                CONSTRAINT = 'regla_cierre_suma';
        END IF;
        IF EXISTS (
            SELECT 1 FROM public.asignacion_curso ac
            JOIN public.actividad_academica a ON a.id_seccion = ac.id_seccion
            WHERE ac.id_seccion = OLD.id_seccion AND ac.estado = 'cursando'
            AND NOT EXISTS (SELECT 1 FROM public.calificacion c
                WHERE c.id_asignacion_curso = ac.id_asignacion_curso
                  AND c.id_actividad_academica = a.id_actividad_academica)
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Faltan calificaciones para cerrar.',
                CONSTRAINT = 'regla_cierre_completo';
        END IF;
        -- Comprobar puntajes y secciones antes de calcular resultados.
        IF EXISTS (
            SELECT 1 FROM public.calificacion c
            JOIN public.actividad_academica a USING (id_actividad_academica)
            JOIN public.asignacion_curso ac USING (id_asignacion_curso)
            WHERE (a.id_seccion = OLD.id_seccion OR ac.id_seccion = OLD.id_seccion)
              AND (c.puntaje_obtenido > a.puntaje_maximo OR a.id_seccion <> ac.id_seccion)
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Hay calificaciones inválidas para el cierre.',
                CONSTRAINT = 'regla_cierre_calificaciones';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_proteger_seccion_cierre ON public.seccion;
CREATE TRIGGER trg_proteger_seccion_cierre BEFORE INSERT OR UPDATE OR DELETE
ON public.seccion FOR EACH ROW EXECUTE FUNCTION public.proteger_seccion_cierre();

CREATE OR REPLACE FUNCTION public.proteger_resultado_asignacion()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE cerrada boolean; nota numeric; esperado text;
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Las asignaciones se cancelan, no se eliminan.',
            CONSTRAINT = 'regla_asignacion_conservar';
    END IF;
    SELECT calificaciones_cerradas INTO cerrada
    FROM public.seccion WHERE id_seccion = NEW.id_seccion;
    IF TG_OP = 'INSERT' THEN
        IF cerrada THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se asigna una sección cerrada.',
                CONSTRAINT = 'regla_asignacion_seccion_cerrada';
        END IF;
        RETURN NEW;
    END IF;
    IF NEW.fecha_asignacion <> OLD.fecha_asignacion THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'La fecha original de asignación se conserva.',
            CONSTRAINT = 'regla_asignacion_fecha';
    END IF;
    IF OLD.estado IN ('aprobada','reprobada') AND NEW IS DISTINCT FROM OLD THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'El resultado final no se modifica.',
            CONSTRAINT = 'regla_resultado_inmutable';
    END IF;
    IF cerrada AND OLD.estado = 'cancelada' AND NEW IS DISTINCT FROM OLD THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se reactiva una sección cerrada.',
            CONSTRAINT = 'regla_asignacion_seccion_cerrada';
    END IF;
    IF NEW.estado IN ('aprobada','reprobada') AND NEW.estado <> OLD.estado THEN
        IF NOT cerrada OR OLD.estado <> 'cursando' THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'El resultado solo se obtiene al cerrar notas.',
                CONSTRAINT = 'regla_resultado_cierre';
        END IF;
        SELECT COALESCE(SUM(puntaje_obtenido),0) INTO nota
        FROM public.calificacion WHERE id_asignacion_curso = OLD.id_asignacion_curso;
        esperado := CASE WHEN nota >= 61 THEN 'aprobada' ELSE 'reprobada' END;
        IF NEW.estado <> esperado THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'El estado no corresponde a la nota.',
                CONSTRAINT = 'regla_resultado_nota';
        END IF;
    END IF;
    IF cerrada AND NEW.estado = 'cursando' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Una sección cerrada no admite cursando.',
            CONSTRAINT = 'regla_asignacion_seccion_cerrada';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_proteger_resultado_asignacion ON public.asignacion_curso;
CREATE TRIGGER trg_proteger_resultado_asignacion BEFORE INSERT OR UPDATE OR DELETE
ON public.asignacion_curso FOR EACH ROW EXECUTE FUNCTION public.proteger_resultado_asignacion();

CREATE OR REPLACE FUNCTION public.aplicar_resultados_cierre()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT OLD.calificaciones_cerradas AND NEW.calificaciones_cerradas THEN
        UPDATE public.asignacion_curso ac
        SET estado = CASE WHEN (
            SELECT COALESCE(SUM(c.puntaje_obtenido),0)
            FROM public.calificacion c
            WHERE c.id_asignacion_curso = ac.id_asignacion_curso
        ) >= 61 THEN 'aprobada' ELSE 'reprobada' END
        WHERE ac.id_seccion = NEW.id_seccion AND ac.estado = 'cursando';
    END IF;
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_aplicar_resultados_cierre ON public.seccion;
CREATE TRIGGER trg_aplicar_resultados_cierre AFTER UPDATE ON public.seccion
FOR EACH ROW EXECUTE FUNCTION public.aplicar_resultados_cierre();

CREATE OR REPLACE FUNCTION public.cerrar_calificaciones(p_id_seccion integer)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE cerrada boolean;
BEGIN
    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION USING ERRCODE = '25000', MESSAGE = 'El cierre requiere SERIALIZABLE.';
    END IF;
    SELECT calificaciones_cerradas INTO cerrada FROM public.seccion
    WHERE id_seccion = p_id_seccion FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La sección % no existe.', p_id_seccion;
    END IF;
    IF cerrada THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'La sección ya está cerrada.',
            CONSTRAINT = 'regla_seccion_cerrada';
    END IF;
    UPDATE public.seccion SET calificaciones_cerradas = true WHERE id_seccion = p_id_seccion;
END;
$$;
COMMIT;
-- FIN BLOQUE 12



-- ============================================================
-- INICIO BLOQUE 13: INSCRIPCIONES E HISTORIAL
-- ============================================================
BEGIN;
CREATE OR REPLACE FUNCTION public.proteger_inscripcion()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Las inscripciones se conservan.',
            CONSTRAINT = 'regla_inscripcion_conservar';
    END IF;
    IF TG_OP = 'INSERT' THEN
        IF NEW.estado <> 'activa' THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Una inscripción nueva comienza activa.',
                CONSTRAINT = 'regla_inscripcion_inicial';
        END IF;
        RETURN NEW;
    END IF;
    IF NEW.id_estudiante <> OLD.id_estudiante OR
       NEW.id_periodo_academico <> OLD.id_periodo_academico OR
       NEW.fecha_inscripcion <> OLD.fecha_inscripcion THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'La identidad original de la inscripción se conserva.',
            CONSTRAINT = 'regla_inscripcion_identidad';
    END IF;
    IF OLD.estado = 'finalizada' AND NEW IS DISTINCT FROM OLD THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Una inscripción finalizada es inmutable.',
            CONSTRAINT = 'regla_inscripcion_finalizada';
    END IF;
    IF NEW.estado = 'finalizada' AND EXISTS (
        SELECT 1 FROM public.asignacion_curso
        WHERE id_inscripcion = OLD.id_inscripcion AND estado = 'cursando'
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Hay cursos pendientes de cerrar.',
            CONSTRAINT = 'regla_inscripcion_finalizar';
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_proteger_inscripcion ON public.inscripcion;
CREATE TRIGGER trg_proteger_inscripcion BEFORE INSERT OR UPDATE OR DELETE
ON public.inscripcion FOR EACH ROW EXECUTE FUNCTION public.proteger_inscripcion();

CREATE OR REPLACE FUNCTION public.cancelar_asignaciones_inscripcion()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.estado = 'cancelada' AND OLD.estado <> 'cancelada' THEN
        UPDATE public.asignacion_curso SET estado = 'cancelada'
        WHERE id_inscripcion = NEW.id_inscripcion AND estado = 'cursando';
    END IF;
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_cancelar_asignaciones_inscripcion ON public.inscripcion;
CREATE TRIGGER trg_cancelar_asignaciones_inscripcion AFTER UPDATE ON public.inscripcion
FOR EACH ROW EXECUTE FUNCTION public.cancelar_asignaciones_inscripcion();

CREATE OR REPLACE FUNCTION public.proteger_historial_relacionado()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_TABLE_NAME = 'estudiante' THEN
        IF NEW.id_carrera <> OLD.id_carrera THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Los cambios de carrera están fuera del alcance.',
                CONSTRAINT = 'regla_estudiante_carrera';
        END IF;
    ELSIF TG_TABLE_NAME = 'periodo_academico' THEN
        IF (NEW.fecha_inicio <> OLD.fecha_inicio OR NEW.fecha_fin <> OLD.fecha_fin)
            AND EXISTS (SELECT 1 FROM public.seccion
                WHERE id_periodo_academico = OLD.id_periodo_academico AND calificaciones_cerradas) THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se cambian fechas de períodos con resultados cerrados.',
                CONSTRAINT = 'regla_periodo_historial';
        END IF;
    ELSIF TG_TABLE_NAME = 'horario_seccion' THEN
        IF TG_OP <> 'INSERT' AND EXISTS (SELECT 1 FROM public.seccion
            WHERE id_seccion = OLD.id_seccion AND calificaciones_cerradas) THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se modifican horarios de una sección cerrada.',
                CONSTRAINT = 'regla_horario_cerrado';
        END IF;
        IF TG_OP <> 'DELETE' AND EXISTS (SELECT 1 FROM public.seccion
            WHERE id_seccion = NEW.id_seccion AND calificaciones_cerradas) THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se agregan horarios a una sección cerrada.',
                CONSTRAINT = 'regla_horario_cerrado';
        END IF;
    ELSIF TG_TABLE_NAME = 'salon' THEN
        IF NEW.id_sede <> OLD.id_sede AND EXISTS (
            SELECT 1 FROM public.horario_seccion h JOIN public.seccion s USING (id_seccion)
            WHERE h.id_salon = OLD.id_salon AND s.calificaciones_cerradas
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'El salón conserva la sede del historial cerrado.',
                CONSTRAINT = 'regla_salon_historial';
        END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;
DO $$
DECLARE tabla text;
BEGIN
    FOREACH tabla IN ARRAY ARRAY['estudiante','periodo_academico','salon'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_proteger_historial ON public.%I', tabla);
        EXECUTE format('CREATE TRIGGER trg_proteger_historial BEFORE UPDATE ON public.%I
            FOR EACH ROW EXECUTE FUNCTION public.proteger_historial_relacionado()', tabla);
    END LOOP;
END;
$$;
DROP TRIGGER IF EXISTS trg_proteger_historial ON public.horario_seccion;
CREATE TRIGGER trg_proteger_historial BEFORE INSERT OR UPDATE OR DELETE
ON public.horario_seccion FOR EACH ROW EXECUTE FUNCTION public.proteger_historial_relacionado();

-- Los identificadores primarios no se editan manualmente.
CREATE OR REPLACE FUNCTION public.proteger_identificador()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE columna text := 'id_' || TG_TABLE_NAME;
BEGIN
    IF (to_jsonb(NEW)->columna) IS DISTINCT FROM (to_jsonb(OLD)->columna) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'No se cambia el identificador primario.',
            CONSTRAINT = 'regla_identificador_inmutable';
    END IF;
    RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION public.impedir_truncate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION USING ERRCODE = '23514',
        MESSAGE = 'TRUNCATE no forma parte de las operaciones normales del sistema.',
        CONSTRAINT = 'regla_conservar_historial';
END;
$$;
DO $$
DECLARE tabla text;
BEGIN
    FOREACH tabla IN ARRAY ARRAY[
        'sede','facultad','carrera','estudiante','docente','curso','plan_estudio',
        'prerrequisito','periodo_academico','salon','seccion','horario_seccion',
        'inscripcion','asignacion_curso','actividad_academica','calificacion','pago'
    ] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_identificador_inmutable ON public.%I', tabla);
        EXECUTE format('CREATE TRIGGER trg_identificador_inmutable BEFORE UPDATE ON public.%I
            FOR EACH ROW EXECUTE FUNCTION public.proteger_identificador()', tabla);
        EXECUTE format('DROP TRIGGER IF EXISTS trg_impedir_truncate ON public.%I', tabla);
        EXECUTE format('CREATE TRIGGER trg_impedir_truncate BEFORE TRUNCATE ON public.%I
            FOR EACH STATEMENT EXECUTE FUNCTION public.impedir_truncate()', tabla);
    END LOOP;
END;
$$;
COMMIT;
-- FIN BLOQUE 13



-- ============================================================
-- INICIO BLOQUE 14: PAGOS Y COMPROBACIÓN CONJUNTA
-- ============================================================
BEGIN;
CREATE OR REPLACE FUNCTION public.proteger_pago()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Los pagos se anulan, no se eliminan.',
            CONSTRAINT = 'regla_pago_conservar';
    END IF;
    IF TG_OP = 'INSERT' THEN
        IF NEW.estado <> 'registrado' THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Un pago nuevo comienza registrado.',
                CONSTRAINT = 'regla_pago_inicial';
        END IF;
    ELSE
        IF OLD.estado = 'anulado' AND NEW IS DISTINCT FROM OLD THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Un pago anulado no se modifica.',
                CONSTRAINT = 'regla_pago_anulado';
        END IF;
        IF (to_jsonb(NEW) - 'estado') IS DISTINCT FROM (to_jsonb(OLD) - 'estado') THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Para corregir un pago, anular y registrar otro.',
                CONSTRAINT = 'regla_pago_identidad';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_proteger_pago ON public.pago;
CREATE TRIGGER trg_proteger_pago BEFORE INSERT OR UPDATE OR DELETE
ON public.pago FOR EACH ROW EXECUTE FUNCTION public.proteger_pago();

CREATE OR REPLACE FUNCTION public.validar_integridad_final()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    -- Mensualidades realizadas, incluso anuladas, deben conservar
    -- una referencia de mes correspondiente al período original.
    IF EXISTS (
        SELECT 1 FROM public.pago pago
        JOIN public.inscripcion i USING (id_inscripcion)
        JOIN public.periodo_academico p USING (id_periodo_academico)
        WHERE pago.concepto = 'mensualidad'
          AND (
              make_date(pago.anio_mensualidad, pago.mes_mensualidad, 1) > p.fecha_fin
              OR (make_date(pago.anio_mensualidad, pago.mes_mensualidad, 1)
                    + INTERVAL '1 month' - INTERVAL '1 day')::date < p.fecha_inicio
          )
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'La mensualidad no corresponde al período.',
            CONSTRAINT = 'regla_pago_periodo';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.inscripcion i JOIN public.asignacion_curso a USING (id_inscripcion)
        WHERE i.estado <> 'activa' AND a.estado = 'cursando'
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Una inscripción no activa conserva cursos pendientes.',
            CONSTRAINT = 'regla_inscripcion_asignaciones';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.asignacion_curso ac JOIN public.seccion s USING (id_seccion)
        WHERE (s.calificaciones_cerradas AND ac.estado = 'cursando')
           OR (NOT s.calificaciones_cerradas AND ac.estado IN ('aprobada','reprobada'))
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Estado académico incompatible con el cierre.',
            CONSTRAINT = 'regla_estado_cierre';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.seccion s WHERE s.calificaciones_cerradas
        AND (SELECT COALESCE(SUM(a.puntaje_maximo),0) FROM public.actividad_academica a
             WHERE a.id_seccion = s.id_seccion) <> 100
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Una sección cerrada no suma 100 puntos.',
            CONSTRAINT = 'regla_cierre_suma';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.asignacion_curso ac
        JOIN public.actividad_academica a ON a.id_seccion = ac.id_seccion
        WHERE ac.estado IN ('aprobada','reprobada')
        AND NOT EXISTS (SELECT 1 FROM public.calificacion c
            WHERE c.id_asignacion_curso = ac.id_asignacion_curso
              AND c.id_actividad_academica = a.id_actividad_academica)
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Un resultado final tiene notas pendientes.',
            CONSTRAINT = 'regla_cierre_completo';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.asignacion_curso ac WHERE ac.estado IN ('aprobada','reprobada')
        AND ac.estado <> CASE WHEN (SELECT COALESCE(SUM(c.puntaje_obtenido),0)
            FROM public.calificacion c WHERE c.id_asignacion_curso = ac.id_asignacion_curso)
            >= 61 THEN 'aprobada' ELSE 'reprobada' END
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'El resultado no coincide con la nota final.',
            CONSTRAINT = 'regla_resultado_nota';
    END IF;
    -- Proteger también contra cambios posteriores de requisitos,
    -- períodos o relaciones del historial.
    IF EXISTS (
        SELECT 1 FROM public.asignacion_curso ac
        JOIN public.inscripcion i USING (id_inscripcion)
        JOIN public.seccion s USING (id_seccion)
        JOIN public.periodo_academico p ON p.id_periodo_academico = s.id_periodo_academico
        JOIN public.prerrequisito r ON r.id_curso = s.id_curso
        WHERE ac.estado <> 'cancelada' AND NOT EXISTS (
            SELECT 1 FROM public.asignacion_curso anterior
            JOIN public.inscripcion ia ON ia.id_inscripcion = anterior.id_inscripcion
            JOIN public.seccion sa ON sa.id_seccion = anterior.id_seccion
            JOIN public.periodo_academico pa ON pa.id_periodo_academico = sa.id_periodo_academico
            WHERE ia.id_estudiante = i.id_estudiante
              AND sa.id_curso = r.id_curso_requisito
              AND anterior.estado = 'aprobada' AND sa.calificaciones_cerradas
              AND pa.fecha_fin < p.fecha_inicio
        )
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Una asignación perdió sus prerrequisitos aprobados.',
            CONSTRAINT = 'regla_historial_prerrequisitos';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.asignacion_curso ac
        JOIN public.inscripcion i USING (id_inscripcion)
        JOIN public.seccion s USING (id_seccion)
        JOIN public.periodo_academico p ON p.id_periodo_academico = s.id_periodo_academico
        JOIN public.asignacion_curso anterior ON anterior.id_asignacion_curso <> ac.id_asignacion_curso
        JOIN public.inscripcion ia ON ia.id_inscripcion = anterior.id_inscripcion
        JOIN public.seccion sa ON sa.id_seccion = anterior.id_seccion
        JOIN public.periodo_academico pa ON pa.id_periodo_academico = sa.id_periodo_academico
        WHERE ac.estado <> 'cancelada' AND ia.id_estudiante = i.id_estudiante
          AND sa.id_curso = s.id_curso AND anterior.estado = 'aprobada'
          AND sa.calificaciones_cerradas AND pa.fecha_fin < p.fecha_inicio
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'Existe un intento posterior a una aprobación.',
            CONSTRAINT = 'regla_historial_curso_aprobado';
    END IF;
    RETURN NULL;
END;
$$;
DO $$
DECLARE tabla text;
BEGIN
    FOREACH tabla IN ARRAY ARRAY[
        'actividad_academica','calificacion','asignacion_curso','seccion',
        'inscripcion','pago','periodo_academico','prerrequisito','plan_estudio','estudiante'
    ] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_integridad_final ON public.%I', tabla);
        EXECUTE format('CREATE CONSTRAINT TRIGGER trg_integridad_final
            AFTER INSERT OR UPDATE OR DELETE ON public.%I
            DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
            EXECUTE FUNCTION public.validar_integridad_final()', tabla);
    END LOOP;
END;
$$;
COMMIT;
-- FIN BLOQUE 14
