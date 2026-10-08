-- ============================================================
-- PRUEBA MANUAL DE CONCURRENCIA: CICLOS DE PRERREQUISITOS
-- Base: sistema_universitario_pruebas.
-- Requiere el DDL y las reglas de negocio instalados.
--
-- Abrir tres Query Tool independientes:
--   INICIAL: preparación, verificación y limpieza.
--   A: insertar A requiere B.
--   B: insertar B requiere A.
--
-- NO ejecutar todo el archivo junto.
-- Ejecutar cada bloque en la ventana indicada.
-- La preparación se ejecuta una sola vez.
-- Ante un error: guardar el mensaje y ejecutar ROLLBACK.
-- ============================================================


-- ============================================================
-- 1. INICIAL, A Y B: COMPROBAR CONEXIONES
-- Ejecutar en cada ventana por separado.
-- ============================================================

ROLLBACK;

SELECT
    current_database() AS base_actual,
    pg_backend_pid() AS conexion;

-- Esperado:
-- Base: sistema_universitario_pruebas en las tres ventanas.
-- Identificadores de conexión distintos.


-- ============================================================
-- 2. INICIAL: PREPARACIÓN COMPLETA
-- ============================================================

BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
BEGIN
    IF current_database() <> 'sistema_universitario_pruebas' THEN
        RAISE EXCEPTION
            'Ejecutar únicamente en sistema_universitario_pruebas.';
    END IF;

    INSERT INTO public.curso (codigo, nombre)
    VALUES
        ('__TEST_CONC_A__', 'Curso temporal de concurrencia A'),
        ('__TEST_CONC_B__', 'Curso temporal de concurrencia B');
END;
$$;

COMMIT;

SELECT id_curso, codigo
FROM public.curso
WHERE codigo IN ('__TEST_CONC_A__', '__TEST_CONC_B__')
ORDER BY codigo;

-- Esperado: dos filas.


-- ============================================================
-- 3. A: INSERTAR A REQUIERE B
-- NO confirmar todavía.
-- ============================================================

BEGIN ISOLATION LEVEL SERIALIZABLE;

INSERT INTO public.prerrequisito (
    id_curso,
    id_curso_requisito
)
SELECT a.id_curso, b.id_curso
FROM public.curso AS a
CROSS JOIN public.curso AS b
WHERE a.codigo = '__TEST_CONC_A__'
  AND b.codigo = '__TEST_CONC_B__';

-- Esperado: INSERT 0 1.
-- Si muestra INSERT 0 0, detenerse y revisar la preparación.


-- ============================================================
-- 4. B: INSERTAR B REQUIERE A
-- Ejecutar ANTES del COMMIT de A.
-- NO confirmar todavía.
-- ============================================================

BEGIN ISOLATION LEVEL SERIALIZABLE;

INSERT INTO public.prerrequisito (
    id_curso,
    id_curso_requisito
)
SELECT b.id_curso, a.id_curso
FROM public.curso AS a
CROSS JOIN public.curso AS b
WHERE a.codigo = '__TEST_CONC_A__'
  AND b.codigo = '__TEST_CONC_B__';

-- Si queda esperando, continuar con el COMMIT de A.
-- Si recibe un error, guardar el mensaje y ejecutar ROLLBACK en B.
-- Si muestra INSERT 0 0, detenerse y revisar la preparación.


-- ============================================================
-- 5. A: CONFIRMAR
-- ============================================================

COMMIT;

-- Si recibe un error, guardar el mensaje y ejecutar ROLLBACK en A.


-- ============================================================
-- 6. B: CONFIRMAR
-- Ejecutar SOLO si su INSERT terminó sin error.
-- ============================================================

COMMIT;

-- Esperado: una transacción rechazada, normalmente SQLSTATE 40001.
-- El rechazo puede ocurrir durante el INSERT o el COMMIT.
-- No es obligatorio que falle siempre la misma sesión.


-- ============================================================
-- 7. SESIÓN RECHAZADA: DESCARTAR LA TRANSACCIÓN
-- ============================================================

ROLLBACK;


-- ============================================================
-- 8. INICIAL: VERIFICAR EL RESULTADO
-- Ejecutar cuando A y B hayan terminado sus transacciones.
-- ============================================================

SELECT
    c.codigo AS curso,
    r.codigo AS requisito
FROM public.prerrequisito AS p
JOIN public.curso AS c
    ON c.id_curso = p.id_curso
JOIN public.curso AS r
    ON r.id_curso = p.id_curso_requisito
WHERE c.codigo IN ('__TEST_CONC_A__', '__TEST_CONC_B__')
  AND r.codigo IN ('__TEST_CONC_A__', '__TEST_CONC_B__');

-- Esperado: exactamente una relación.
-- No deben quedar confirmadas ambas relaciones.


-- ============================================================
-- 9. SESIÓN RECHAZADA: REINTENTO COMPLETO
-- Ejecutar después de su ROLLBACK.
-- Intenta agregar la relación opuesta a la que quedó confirmada.
-- ============================================================

BEGIN ISOLATION LEVEL SERIALIZABLE;

INSERT INTO public.prerrequisito (
    id_curso,
    id_curso_requisito
)
SELECT p.id_curso_requisito, p.id_curso
FROM public.prerrequisito AS p
JOIN public.curso AS c
    ON c.id_curso = p.id_curso
JOIN public.curso AS r
    ON r.id_curso = p.id_curso_requisito
WHERE c.codigo IN ('__TEST_CONC_A__', '__TEST_CONC_B__')
  AND r.codigo IN ('__TEST_CONC_A__', '__TEST_CONC_B__');

-- Esperado: SQLSTATE 23514, el prerrequisito forma un ciclo.
-- Si no se produjo ese rechazo, detenerse y revisar el resultado.


-- ============================================================
-- 10. SESIÓN DEL REINTENTO: DESCARTAR
-- ============================================================

ROLLBACK;


-- ============================================================
-- 11. INICIAL: LIMPIEZA COMPLETA
-- Ejecutar después de guardar los resultados.
-- ============================================================

BEGIN ISOLATION LEVEL SERIALIZABLE;

DO $$
BEGIN
    IF current_database() <> 'sistema_universitario_pruebas' THEN
        RAISE EXCEPTION
            'Ejecutar únicamente en sistema_universitario_pruebas.';
    END IF;

    DELETE FROM public.prerrequisito
    WHERE id_curso IN (
        SELECT id_curso
        FROM public.curso
        WHERE codigo IN ('__TEST_CONC_A__', '__TEST_CONC_B__')
    )
    OR id_curso_requisito IN (
        SELECT id_curso
        FROM public.curso
        WHERE codigo IN ('__TEST_CONC_A__', '__TEST_CONC_B__')
    );

    DELETE FROM public.curso
    WHERE codigo IN ('__TEST_CONC_A__', '__TEST_CONC_B__');
END;
$$;

COMMIT;


-- ============================================================
-- 12. INICIAL: COMPROBAR LA LIMPIEZA
-- ============================================================

SELECT id_curso, codigo
FROM public.curso
WHERE codigo IN ('__TEST_CONC_A__', '__TEST_CONC_B__');

-- Esperado: cero filas.

-- ============================================================
-- FIN DE LA PRUEBA MANUAL
-- ============================================================