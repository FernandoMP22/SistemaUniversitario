-- ============================================================
-- VALIDACIÓN INICIAL DE SISTEMA UNIVERSITARIO
-- Ejecutar dentro de la base sistema_universitario.
-- ============================================================



-- ============================================================
-- INICIO BLOQUE 1: VERIFICACIÓN DE ESTRUCTURA
-- ============================================================


-- 1. Confirmar la base actual.
-- Resultado esperado: sistema_universitario.

SELECT current_database() AS base_actual;


-- 2. Listar las tablas y mostrar su cantidad total.
-- Resultado esperado: 17 tablas.

SELECT
    table_name AS tabla,
    COUNT(*) OVER () AS total_tablas
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;


-- 3. Contar las llaves primarias y foráneas.
-- Resultado esperado: 17 primarias y 20 foráneas.

SELECT
    COUNT(*) FILTER (WHERE contype = 'p') AS llaves_primarias,
    COUNT(*) FILTER (WHERE contype = 'f') AS llaves_foraneas
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace;


-- 4. Mostrar las llaves primarias y foráneas con su definición.

SELECT
    conrelid::regclass AS tabla,
    conname AS restriccion,
    CASE contype
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'f' THEN 'FOREIGN KEY'
    END AS tipo,
    pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND contype IN ('p', 'f')
ORDER BY tabla, tipo, restriccion;


-- 5. Revisar las condiciones CHECK de pago.
-- El concepto debe utilizar matricula sin tilde.

SELECT
    conname AS restriccion,
    pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'public.pago'::regclass
  AND contype = 'c'
ORDER BY conname;


-- 6. Revisar los índices únicos parciales de pagos.
-- Resultado esperado: dos índices con estado = 'registrado'.

SELECT
    indexname AS indice,
    indexdef AS definicion
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'pago'
  AND indexname IN (
      'uq_pago_matricula_registrada',
      'uq_pago_mensualidad_registrada'
  )
ORDER BY indexname;


-- ============================================================
-- FIN BLOQUE 1
-- ============================================================


-- ============================================================
-- INICIO BLOQUE 2: PRUEBAS DE INTEGRIDAD
-- Los registros de prueba se deshacen mediante ROLLBACK.
-- Las secuencias de identidad pueden avanzar y dejar saltos.
-- ============================================================


BEGIN;

DO $$
DECLARE
    sede_prueba integer;
    facultad_inexistente integer;
BEGIN

    -- Crear una sede temporal.

    INSERT INTO public.sede (codigo, nombre, direccion)
    VALUES (
        '__TEST_INTEGRIDAD__',
        'Sede de prueba',
        'Dirección de prueba'
    )
    RETURNING id_sede INTO sede_prueba;



    -- --------------------------------------------------------
    -- PRUEBA 1: UNIQUE
    -- Rechazar un código de sede repetido.
    -- --------------------------------------------------------

    BEGIN
        INSERT INTO public.sede (codigo, nombre, direccion)
        VALUES (
            '__TEST_INTEGRIDAD__',
            'Otra sede de prueba',
            'Otra dirección'
        );

        RAISE EXCEPTION
            'FALLO: se permitió un código duplicado.';

    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE
                'OK 1: UNIQUE rechaza códigos duplicados.';
    END;



    -- --------------------------------------------------------
    -- PRUEBA 2: NOT NULL
    -- Rechazar un nombre obligatorio sin valor.
    -- --------------------------------------------------------

    BEGIN
        INSERT INTO public.sede (codigo, nombre, direccion)
        VALUES (
            '__TEST_NULL__',
            NULL,
            'Dirección de prueba'
        );

        RAISE EXCEPTION
            'FALLO: se permitió un nombre NULL.';

    EXCEPTION
        WHEN not_null_violation THEN
            RAISE NOTICE
                'OK 2: NOT NULL exige el nombre.';
    END;



    -- --------------------------------------------------------
    -- PRUEBA 3: CHECK DE CAPACIDAD
    -- Rechazar un salón con capacidad igual a cero.
    -- --------------------------------------------------------

    BEGIN
        INSERT INTO public.salon (id_sede, codigo, capacidad)
        VALUES (
            sede_prueba,
            '__TEST_SALON__',
            0
        );

        RAISE EXCEPTION
            'FALLO: se permitió capacidad cero.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 3: CHECK rechaza capacidad cero.';
    END;



    -- --------------------------------------------------------
    -- PRUEBA 4: FOREIGN KEY
    -- Rechazar una carrera con facultad inexistente.
    -- --------------------------------------------------------

    SELECT candidato
    INTO facultad_inexistente
    FROM generate_series(-1000, -1) AS g(candidato)
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.facultad AS f
        WHERE f.id_facultad = g.candidato
    )
    LIMIT 1;

    IF facultad_inexistente IS NULL THEN
    RAISE EXCEPTION
        'No se encontró un identificador libre para la prueba 4.';
	END IF;

    BEGIN
        INSERT INTO public.carrera (
            id_facultad,
            codigo,
            nombre
        )
        VALUES (
            facultad_inexistente,
            '__TEST_CARRERA__',
            'Carrera de prueba'
        );

        RAISE EXCEPTION
            'FALLO: se permitió una facultad inexistente.';

    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE
                'OK 4: FK rechaza una facultad inexistente.';
    END;



    -- --------------------------------------------------------
    -- PRUEBA 5: CHECK DE FECHAS
    -- Rechazar un período con fechas invertidas.
    -- --------------------------------------------------------

    BEGIN
        INSERT INTO public.periodo_academico (
            codigo,
            nombre,
            fecha_inicio,
            fecha_fin
        )
        VALUES (
            '__TEST_PERIODO__',
            'Período de prueba',
            DATE '2027-06-30',
            DATE '2027-01-01'
        );

        RAISE EXCEPTION
            'FALLO: se permitieron fechas invertidas.';

    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE
                'OK 5: CHECK rechaza fechas invertidas.';
    END;



    -- --------------------------------------------------------
    -- PRUEBA 6: ON DELETE RESTRICT
    -- Rechazar la eliminación de una sede con salones.
    -- --------------------------------------------------------

    INSERT INTO public.salon (id_sede, codigo, capacidad)
    VALUES (
        sede_prueba,
        '__TEST_SALON_OK__',
        30
    );

    BEGIN
        DELETE FROM public.sede
        WHERE id_sede = sede_prueba;

        RAISE EXCEPTION
            'FALLO: se permitió borrar una sede referenciada.';

    EXCEPTION
        WHEN restrict_violation THEN
            RAISE NOTICE
                'OK 6: RESTRICT protege la sede referenciada.';
    END;

END;
$$;

ROLLBACK;


-- ============================================================
-- FIN BLOQUE 2
-- ============================================================

