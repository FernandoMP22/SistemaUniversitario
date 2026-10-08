-- VERIFICACIÓN DEL DML REDUCIDO: 8 ESTUDIANTES, 4 POR CARRERA.
-- Ejecutar después del COMMIT correcto del DML.
-- Solo contiene SELECT: no modifica datos.
-- Ejecutar completo o seleccionar cada bloque en orden.
-- No necesita BEGIN, COMMIT ni ROLLBACK.
-- Conteos esperados de la carga inicial, antes de editar datos.


-- ============================================================
-- INICIO BLOQUE 1: BASE ACTUAL
-- Esperado: sistema_universitario.
-- ============================================================

SELECT current_database() AS base_actual;


-- ============================================================
-- INICIO BLOQUE 2: CONTEOS DE LAS 17 TABLAS
-- Todas las filas deben mostrar coincide=true.
-- ============================================================

SELECT tabla,esperado,actual,actual=esperado AS coincide
FROM (
    SELECT 'sede' AS tabla,2 AS esperado,COUNT(*) AS actual FROM public.sede
    UNION ALL SELECT 'facultad',2,COUNT(*) FROM public.facultad
    UNION ALL SELECT 'carrera',2,COUNT(*) FROM public.carrera
    UNION ALL SELECT 'estudiante',8,COUNT(*) FROM public.estudiante
    UNION ALL SELECT 'docente',2,COUNT(*) FROM public.docente
    UNION ALL SELECT 'curso',2,COUNT(*) FROM public.curso
    UNION ALL SELECT 'plan_estudio',4,COUNT(*) FROM public.plan_estudio
    UNION ALL SELECT 'prerrequisito',1,COUNT(*) FROM public.prerrequisito
    UNION ALL SELECT 'periodo_academico',2,COUNT(*) FROM public.periodo_academico
    UNION ALL SELECT 'salon',2,COUNT(*) FROM public.salon
    UNION ALL SELECT 'seccion',5,COUNT(*) FROM public.seccion
    UNION ALL SELECT 'horario_seccion',5,COUNT(*) FROM public.horario_seccion
    UNION ALL SELECT 'inscripcion',8,COUNT(*) FROM public.inscripcion
    UNION ALL SELECT 'asignacion_curso',8,COUNT(*) FROM public.asignacion_curso
    UNION ALL SELECT 'actividad_academica',5,COUNT(*) FROM public.actividad_academica
    UNION ALL SELECT 'calificacion',4,COUNT(*) FROM public.calificacion
    UNION ALL SELECT 'pago',9,COUNT(*) FROM public.pago
) AS conteos ORDER BY tabla;


-- ============================================================
-- INICIO BLOQUE 3: ESTADOS DE ASIGNACIONES
-- Asignaciones: aprobada=1, reprobada=1, cursando=5, cancelada=1.
-- ============================================================

SELECT estado,COUNT(*) AS cantidad FROM public.asignacion_curso
GROUP BY estado ORDER BY estado;


-- ============================================================
-- INICIO BLOQUE 4: ESTADOS DE INSCRIPCIONES
-- Inscripciones: finalizada=2, activa=5, cancelada=1.
-- ============================================================

SELECT estado,COUNT(*) AS cantidad FROM public.inscripcion
GROUP BY estado ORDER BY estado;


-- ============================================================
-- INICIO BLOQUE 5: CIERRE DE SECCIONES
-- 2026-1: 2 cerradas. 2026-2: 3 abiertas.
-- ============================================================

SELECT p.codigo,s.calificaciones_cerradas,COUNT(*) AS secciones
FROM public.seccion AS s JOIN public.periodo_academico AS p USING(id_periodo_academico)
GROUP BY p.codigo,s.calificaciones_cerradas ORDER BY p.codigo;


-- ============================================================
-- INICIO BLOQUE 6: HISTORIAL ACADÉMICO Y NOTAS
-- Historial y notas actuales. NULL significa que no hay nota registrada.
-- 8 filas: Ana 80 y 75; Elena 60; Luis 70; otras 4 notas NULL.
-- ============================================================

SELECT e.carne,e.nombres,p.codigo AS periodo,c.codigo AS curso,
    ac.estado,cal.puntaje_obtenido,s.calificaciones_cerradas
FROM public.asignacion_curso AS ac
JOIN public.inscripcion AS i USING(id_inscripcion)
JOIN public.estudiante AS e USING(id_estudiante)
JOIN public.seccion AS s USING(id_seccion)
JOIN public.curso AS c USING(id_curso)
JOIN public.periodo_academico AS p ON p.id_periodo_academico=s.id_periodo_academico
LEFT JOIN public.calificacion AS cal USING(id_asignacion_curso)
ORDER BY e.carne,p.codigo;


-- ============================================================
-- INICIO BLOQUE 7: CUPOS Y OCUPACIÓN
-- Cupos: ninguna sección debe superar 4 ocupados.
-- ============================================================

SELECT s.codigo,s.cupo_maximo,
    COUNT(ac.id_asignacion_curso) FILTER(WHERE ac.estado<>'cancelada') AS ocupados
FROM public.seccion AS s LEFT JOIN public.asignacion_curso AS ac USING(id_seccion)
GROUP BY s.id_seccion,s.codigo,s.cupo_maximo ORDER BY s.codigo;


-- ============================================================
-- INICIO BLOQUE 8: PAGOS POR CONCEPTO Y ESTADO
-- Pagos: 7 matrículas registradas, 1 matrícula anulada, 1 mensualidad registrada.
-- ============================================================

SELECT concepto,estado,COUNT(*) AS cantidad,SUM(monto) AS monto
FROM public.pago GROUP BY concepto,estado ORDER BY concepto,estado;

-- ============================================================
-- INICIO BLOQUE 9: INGRESOS REGISTRADOS
-- Esperado: 4250.00. Excluye pagos anulados.
-- ============================================================

SELECT SUM(monto) AS ingresos_registrados FROM public.pago WHERE estado='registrado';


-- ============================================================
-- INICIO BLOQUE 10: ESTUDIANTES SIN INSCRIPCIÓN
-- Estudiantes sin inscripción: carnes 2026-0004 y 2026-0008.
-- ============================================================

SELECT e.carne,e.nombres FROM public.estudiante AS e
WHERE NOT EXISTS(SELECT 1 FROM public.inscripcion AS i WHERE i.id_estudiante=e.id_estudiante)
ORDER BY e.carne;


-- ============================================================
-- INICIO BLOQUE 11: INTEGRIDAD DE RESULTADOS CERRADOS
-- Resultados cerrados incoherentes: cero filas.
-- ============================================================

SELECT ac.id_asignacion_curso,ac.estado,SUM(c.puntaje_obtenido) AS nota
FROM public.asignacion_curso AS ac JOIN public.seccion AS s USING(id_seccion)
LEFT JOIN public.calificacion AS c USING(id_asignacion_curso)
WHERE s.calificaciones_cerradas AND ac.estado<>'cancelada'
GROUP BY ac.id_asignacion_curso,ac.estado
HAVING ac.estado<>CASE WHEN COALESCE(SUM(c.puntaje_obtenido),0)>=61
    THEN 'aprobada' ELSE 'reprobada' END;
