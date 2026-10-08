-- Requiere DDL y reglas instalados. Sin arrays ni bucles.
-- Ejecutar COMPLETO una sola vez en sistema_universitario.
-- Requiere las 17 tablas vacías. No elimina datos existentes.
-- Ante un ERROR: ejecutar ROLLBACK y conservar el mensaje.

BEGIN ISOLATION LEVEL SERIALIZABLE;

-- Protección inicial, sin generación automática de registros.
DO $$
BEGIN
    IF current_database() <> 'sistema_universitario' THEN
        RAISE EXCEPTION 'Ejecutar en sistema_universitario.';
    END IF;
    IF EXISTS (

        SELECT 1 FROM public.sede
        UNION ALL
        SELECT 1 FROM public.facultad
        UNION ALL
        SELECT 1 FROM public.carrera
        UNION ALL
        SELECT 1 FROM public.estudiante
        UNION ALL
        SELECT 1 FROM public.docente
        UNION ALL
        SELECT 1 FROM public.curso
        UNION ALL
        SELECT 1 FROM public.plan_estudio
        UNION ALL
        SELECT 1 FROM public.prerrequisito
        UNION ALL
        SELECT 1 FROM public.periodo_academico
        UNION ALL
        SELECT 1 FROM public.salon
        UNION ALL
        SELECT 1 FROM public.seccion
        UNION ALL
        SELECT 1 FROM public.horario_seccion
        UNION ALL
        SELECT 1 FROM public.inscripcion
        UNION ALL
        SELECT 1 FROM public.asignacion_curso
        UNION ALL
        SELECT 1 FROM public.actividad_academica
        UNION ALL
        SELECT 1 FROM public.calificacion
        UNION ALL
        SELECT 1 FROM public.pago
    ) THEN
        RAISE EXCEPTION 'Hay datos existentes. Carga detenida sin eliminar registros.';
    END IF;
END;
$$;





-- ============================================================
-- INICIO BLOQUE 1: SEDES
-- Se agregan 2 sedes: CENTRAL y OCCIDENTE.
-- ============================================================

INSERT INTO public.sede (codigo, nombre, direccion)
VALUES
    ('CENTRAL', 'Sede Central', 'Ciudad de Guatemala'),
    ('OCCIDENTE', 'Sede Occidente', 'Quetzaltenango');



-- ============================================================
-- INICIO BLOQUE 2: FACULTADES
-- Se agregan 2 facultades: ING y ECO.
-- ============================================================

INSERT INTO public.facultad (codigo, nombre)
VALUES
    ('ING', 'Facultad de Ingenieria'),
    ('ECO', 'Facultad de Ciencias Economicas');



-- ============================================================
-- INICIO BLOQUE 3: CARRERAS
-- Se agregan 2 carreras: SIS en ING y ADM en ECO.
-- ============================================================

INSERT INTO public.carrera (id_facultad, codigo, nombre)
SELECT f.id_facultad, datos.codigo, datos.nombre
FROM (VALUES
    ('ING', 'SIS', 'Ingenieria en Sistemas'),
    ('ECO', 'ADM', 'Administracion de Empresas')
) AS datos (facultad, codigo, nombre)
JOIN public.facultad AS f ON f.codigo=datos.facultad;



-- ============================================================
-- INICIO BLOQUE 4: SALONES
-- Se agregan 2 salones A101: uno por sede, con capacidad de 10.
-- ============================================================

INSERT INTO public.salon (id_sede, codigo, capacidad)
SELECT s.id_sede, datos.codigo, datos.capacidad
FROM (VALUES
    ('CENTRAL', 'A101', 10),
    ('OCCIDENTE', 'A101', 10)
) AS datos (sede, codigo, capacidad)
JOIN public.sede AS s ON s.codigo=datos.sede;



-- ============================================================
-- INICIO BLOQUE 5: ESTUDIANTES
-- Se agregan 8 estudiantes: Ana, Luis, Carla y Diego en SIS; Elena, Mario, Sofia y Pablo en ADM.
-- ============================================================

INSERT INTO public.estudiante (id_carrera, carne, nombres, apellidos, fecha_nacimiento, correo)
SELECT ca.id_carrera, datos.carne, datos.nombres, datos.apellidos,
       datos.nacimiento::date, datos.correo
FROM (VALUES
    ('SIS', '2026-0001', 'Ana', 'Lopez', '2002-01-01', 'estudiante1@example.com'),
    ('SIS', '2026-0002', 'Luis', 'Perez', '2002-01-02', 'estudiante2@example.com'),
    ('SIS', '2026-0003', 'Carla', 'Garcia', '2002-01-03', 'estudiante3@example.com'),
    ('SIS', '2026-0004', 'Diego', 'Martinez', '2002-01-04', 'estudiante4@example.com'),
    ('ADM', '2026-0005', 'Elena', 'Ramirez', '2002-01-05', 'estudiante5@example.com'),
    ('ADM', '2026-0006', 'Mario', 'Flores', '2002-01-06', 'estudiante6@example.com'),
    ('ADM', '2026-0007', 'Sofia', 'Gomez', '2002-01-07', 'estudiante7@example.com'),
    ('ADM', '2026-0008', 'Pablo', 'Morales', '2002-01-08', 'estudiante8@example.com')
) AS datos (carrera, carne, nombres, apellidos, nacimiento, correo)
JOIN public.carrera AS ca ON ca.codigo=datos.carrera;



-- ============================================================
-- INICIO BLOQUE 6: DOCENTES
-- Se agregan 2 docentes: DOC-01 Andrea Castillo y DOC-02 Marco Reyes.
-- ============================================================

INSERT INTO public.docente (codigo, nombres, apellidos, correo)
VALUES
    ('DOC-01', 'Andrea', 'Castillo', 'docente1@example.com'),
    ('DOC-02', 'Marco', 'Reyes', 'docente2@example.com');



-- ============================================================
-- INICIO BLOQUE 7: CURSOS
-- Se agregan 2 cursos: MAT1 Matematica I y EST1 Estadistica I.
-- ============================================================

INSERT INTO public.curso (codigo, nombre)
VALUES
    ('MAT1', 'Matematica I'),
    ('EST1', 'Estadistica I');



-- ============================================================
-- INICIO BLOQUE 8: PLANES DE ESTUDIO
-- Se agregan 4 relaciones: MAT1 y EST1 para cada una de las 2 carreras.
-- ============================================================

INSERT INTO public.plan_estudio (id_carrera, id_curso, semestre_sugerido)
SELECT ca.id_carrera, c.id_curso, datos.semestre
FROM (VALUES
    ('SIS', 'MAT1', 1),
    ('SIS', 'EST1', 2),
    ('ADM', 'MAT1', 1),
    ('ADM', 'EST1', 2)
) AS datos (carrera, curso, semestre)
JOIN public.carrera AS ca ON ca.codigo=datos.carrera
JOIN public.curso AS c ON c.codigo=datos.curso;



-- ============================================================
-- INICIO BLOQUE 9: PRERREQUISITOS
-- Se agrega 1 relación: EST1 requiere MAT1.
-- ============================================================

INSERT INTO public.prerrequisito (id_curso, id_curso_requisito)
SELECT c.id_curso, r.id_curso
FROM (VALUES
    ('EST1', 'MAT1')
) AS datos (curso, requisito)
JOIN public.curso AS c ON c.codigo=datos.curso
JOIN public.curso AS r ON r.codigo=datos.requisito;



-- ============================================================
-- INICIO BLOQUE 10: PERÍODOS ACADÉMICOS
-- Se agregan 2 períodos: 2026-1 y 2026-2.
-- ============================================================

INSERT INTO public.periodo_academico (codigo, nombre, fecha_inicio, fecha_fin)
VALUES
    ('2026-1', 'Primer semestre 2026', '2026-01-01', '2026-06-30'),
    ('2026-2', 'Segundo semestre 2026', '2026-07-01', '2026-12-31');



-- ============================================================
-- INICIO BLOQUE 11: INSCRIPCIONES
-- Se agregan 8 inscripciones: 2 anteriores y 6 actuales. Diego y Pablo todavía no se inscriben.
-- ============================================================

INSERT INTO public.inscripcion (id_estudiante, id_periodo_academico, fecha_inscripcion)
SELECT e.id_estudiante, p.id_periodo_academico, datos.fecha::date
FROM (VALUES
    ('2026-0001', '2026-1', '2026-01-05'),
    ('2026-0005', '2026-1', '2026-01-05'),
    ('2026-0001', '2026-2', '2026-07-05'),
    ('2026-0002', '2026-2', '2026-07-05'),
    ('2026-0003', '2026-2', '2026-07-05'),
    ('2026-0005', '2026-2', '2026-07-05'),
    ('2026-0006', '2026-2', '2026-07-05'),
    ('2026-0007', '2026-2', '2026-07-05')
) AS datos (carne, periodo, fecha)
JOIN public.estudiante AS e ON e.carne=datos.carne
JOIN public.periodo_academico AS p ON p.codigo=datos.periodo;

-- Estudiantes 4 y 8: registrados, sin inscripción todavía.
-- No se exige que cada estudiante tenga historia en todos los períodos.



-- ============================================================
-- INICIO BLOQUE 12: SECCIONES
-- Se agregan 5 secciones: 2 anteriores y 3 actuales, con cupo de 4 cada una.
-- ============================================================

INSERT INTO public.seccion (id_curso, id_periodo_academico, id_docente, codigo, cupo_maximo)
SELECT c.id_curso, p.id_periodo_academico, d.id_docente, datos.codigo, datos.cupo
FROM (VALUES
    ('MAT1', '2026-1', 'DOC-01', 'P1-SIS-MAT1', 4),
    ('MAT1', '2026-1', 'DOC-02', 'P1-ADM-MAT1', 4),
    ('MAT1', '2026-2', 'DOC-01', 'P2-SIS-MAT1', 4),
    ('EST1', '2026-2', 'DOC-01', 'P2-SIS-EST1', 4),
    ('MAT1', '2026-2', 'DOC-02', 'P2-ADM-MAT1', 4)
) AS datos (curso, periodo, docente, codigo, cupo)
JOIN public.curso AS c ON c.codigo=datos.curso
JOIN public.periodo_academico AS p ON p.codigo=datos.periodo
JOIN public.docente AS d ON d.codigo=datos.docente;



-- ============================================================
-- INICIO BLOQUE 13: HORARIOS DE SECCIONES
-- Se agregan 5 horarios: uno por sección, distribuidos entre lunes y martes.
-- ============================================================

INSERT INTO public.horario_seccion (id_seccion, id_salon, dia_semana, hora_inicio, hora_fin)
SELECT s.id_seccion, sa.id_salon, datos.dia, datos.inicio::time, datos.fin::time
FROM (VALUES
    ('P1-SIS-MAT1', 'CENTRAL', 'A101', 1, '08:00', '09:00'),
    ('P1-ADM-MAT1', 'OCCIDENTE', 'A101', 2, '08:00', '09:00'),
    ('P2-SIS-MAT1', 'CENTRAL', 'A101', 1, '08:00', '09:00'),
    ('P2-SIS-EST1', 'CENTRAL', 'A101', 1, '09:00', '10:00'),
    ('P2-ADM-MAT1', 'OCCIDENTE', 'A101', 2, '08:00', '09:00')
) AS datos (seccion, sede, salon, dia, inicio, fin)
JOIN public.seccion AS s ON s.codigo=datos.seccion
JOIN public.sede AS sd ON sd.codigo=datos.sede
JOIN public.salon AS sa ON sa.id_sede=sd.id_sede AND sa.codigo=datos.salon;



-- ============================================================
-- INICIO BLOQUE 14: ACTIVIDADES ACADÉMICAS
-- Se agregan 5 actividades: una Evaluacion unica de 100 puntos por sección.
-- ============================================================

INSERT INTO public.actividad_academica (id_seccion, nombre, tipo, fecha, puntaje_maximo)
SELECT s.id_seccion, datos.nombre, 'examen', datos.fecha::date, 100
FROM (VALUES
    ('P1-SIS-MAT1', 'Evaluacion unica', '2026-06-15'),
    ('P1-ADM-MAT1', 'Evaluacion unica', '2026-06-15'),
    ('P2-SIS-MAT1', 'Evaluacion unica', '2026-09-15'),
    ('P2-SIS-EST1', 'Evaluacion unica', '2026-09-15'),
    ('P2-ADM-MAT1', 'Evaluacion unica', '2026-09-15')
) AS datos (seccion, nombre, fecha)
JOIN public.seccion AS s ON s.codigo=datos.seccion;



-- ============================================================
-- INICIO BLOQUE 15: ASIGNACIONES DE CURSOS
-- Se agregan 2 asignaciones anteriores: Ana y Elena cursan MAT1.
-- ============================================================

INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion, fecha_asignacion)
SELECT i.id_inscripcion, s.id_seccion, datos.fecha::date
FROM (VALUES
    ('2026-0001', 'P1-SIS-MAT1', '2026-01-06'),
    ('2026-0005', 'P1-ADM-MAT1', '2026-01-06')
) AS datos (carne, seccion, fecha)
JOIN public.estudiante AS e ON e.carne=datos.carne
JOIN public.seccion AS s ON s.codigo=datos.seccion
JOIN public.inscripcion AS i ON i.id_estudiante=e.id_estudiante
    AND i.id_periodo_academico=s.id_periodo_academico;



-- ============================================================
-- INICIO BLOQUE 16: CALIFICACIONES
-- Se agregan 2 notas anteriores: Ana obtiene 80 y Elena obtiene 60.
-- ============================================================

INSERT INTO public.calificacion (id_actividad_academica, id_asignacion_curso, puntaje_obtenido)
SELECT a.id_actividad_academica, ac.id_asignacion_curso, datos.puntaje
FROM (VALUES
    ('2026-0001', 'P1-SIS-MAT1', 80),
    ('2026-0005', 'P1-ADM-MAT1', 60)
) AS datos (carne, seccion, puntaje)
JOIN public.estudiante AS e ON e.carne=datos.carne
JOIN public.seccion AS s ON s.codigo=datos.seccion
JOIN public.inscripcion AS i ON i.id_estudiante=e.id_estudiante
    AND i.id_periodo_academico=s.id_periodo_academico
JOIN public.asignacion_curso AS ac ON ac.id_inscripcion=i.id_inscripcion
    AND ac.id_seccion=s.id_seccion
JOIN public.actividad_academica AS a ON a.id_seccion=s.id_seccion
    AND a.nombre='Evaluacion unica';

SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;



-- ============================================================
-- INICIO BLOQUE 17: SECCIONES: CIERRE DE CALIFICACIONES
-- No se insertan filas: se cierra P1-SIS-MAT1 y Ana queda aprobada.
-- ============================================================

SELECT public.cerrar_calificaciones(id_seccion)
FROM public.seccion WHERE codigo='P1-SIS-MAT1';



-- ============================================================
-- INICIO BLOQUE 18: SECCIONES: CIERRE DE CALIFICACIONES
-- No se insertan filas: se cierra P1-ADM-MAT1 y Elena queda reprobada.
-- ============================================================

SELECT public.cerrar_calificaciones(id_seccion)
FROM public.seccion WHERE codigo='P1-ADM-MAT1';



-- ============================================================
-- INICIO BLOQUE 19: INSCRIPCIONES: ACTUALIZACIÓN DE ESTADO
-- No se insertan filas: las 2 inscripciones del período 2026-1 quedan finalizadas.
-- ============================================================

UPDATE public.inscripcion AS i SET estado='finalizada'
FROM public.periodo_academico AS p
WHERE i.id_periodo_academico=p.id_periodo_academico AND p.codigo='2026-1';

SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;



-- ============================================================
-- INICIO BLOQUE 20: ASIGNACIONES DE CURSOS — REGISTROS ADICIONALES
-- Se agregan 6 asignaciones actuales: Ana cursa EST1; Luis, Carla, Elena, Mario y Sofia cursan MAT1.
-- ============================================================

INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion, fecha_asignacion)
SELECT i.id_inscripcion, s.id_seccion, datos.fecha::date
FROM (VALUES
    ('2026-0001', 'P2-SIS-EST1', '2026-07-06'),
    ('2026-0002', 'P2-SIS-MAT1', '2026-07-06'),
    ('2026-0003', 'P2-SIS-MAT1', '2026-07-06'),
    ('2026-0005', 'P2-ADM-MAT1', '2026-07-06'),
    ('2026-0006', 'P2-ADM-MAT1', '2026-07-06'),
    ('2026-0007', 'P2-ADM-MAT1', '2026-07-06')
) AS datos (carne, seccion, fecha)
JOIN public.estudiante AS e ON e.carne=datos.carne
JOIN public.seccion AS s ON s.codigo=datos.seccion
JOIN public.inscripcion AS i ON i.id_estudiante=e.id_estudiante
    AND i.id_periodo_academico=s.id_periodo_academico;

-- Ana cursa Estadistica porque aprobó Matematica anteriormente.
-- Elena repite Matematica porque la reprobó.
-- Sofia cancela su inscripción; el trigger cancela su asignación.



-- ============================================================
-- INICIO BLOQUE 21: INSCRIPCIONES: ACTUALIZACIÓN DE ESTADO
-- No se insertan filas: se cancela la inscripción actual de Sofia y su asignación.
-- ============================================================

UPDATE public.inscripcion AS i SET estado='cancelada'
FROM public.estudiante AS e, public.periodo_academico AS p
WHERE i.id_estudiante=e.id_estudiante
  AND i.id_periodo_academico=p.id_periodo_academico
  AND e.carne='2026-0007' AND p.codigo='2026-2';



-- ============================================================
-- INICIO BLOQUE 22: CALIFICACIONES — REGISTROS ADICIONALES
-- Se agregan 2 notas actuales: Ana obtiene 75 en EST1 y Luis obtiene 70 en MAT1. Las secciones siguen abiertas.
-- ============================================================

INSERT INTO public.calificacion (id_actividad_academica, id_asignacion_curso, puntaje_obtenido)
SELECT a.id_actividad_academica, ac.id_asignacion_curso, datos.puntaje
FROM (VALUES
    ('2026-0001', 'P2-SIS-EST1', 75),
    ('2026-0002', 'P2-SIS-MAT1', 70)
) AS datos (carne, seccion, puntaje)
JOIN public.estudiante AS e ON e.carne=datos.carne
JOIN public.seccion AS s ON s.codigo=datos.seccion
JOIN public.inscripcion AS i ON i.id_estudiante=e.id_estudiante
    AND i.id_periodo_academico=s.id_periodo_academico
JOIN public.asignacion_curso AS ac ON ac.id_inscripcion=i.id_inscripcion
    AND ac.id_seccion=s.id_seccion
JOIN public.actividad_academica AS a ON a.id_seccion=s.id_seccion
    AND a.nombre='Evaluacion unica';

-- Las secciones actuales permanecen abiertas. Hay notas pendientes.



-- ============================================================
-- INICIO BLOQUE 23: PAGOS
-- Se agregan 7 pagos de matrícula de Q500. Sofia no tiene pagos en esta muestra.
-- ============================================================

INSERT INTO public.pago (id_inscripcion, numero_comprobante, concepto, monto, fecha_pago)
SELECT i.id_inscripcion, datos.comprobante, 'matricula', 500, datos.fecha::date
FROM (VALUES
    ('2026-0001', '2026-1', 'MAT-1-0001', '2026-01-05'),
    ('2026-0005', '2026-1', 'MAT-1-0005', '2026-01-05'),
    ('2026-0001', '2026-2', 'MAT-2-0001', '2026-07-05'),
    ('2026-0002', '2026-2', 'MAT-2-0002', '2026-07-05'),
    ('2026-0003', '2026-2', 'MAT-2-0003', '2026-07-05'),
    ('2026-0005', '2026-2', 'MAT-2-0005', '2026-07-05'),
    ('2026-0006', '2026-2', 'MAT-2-0006', '2026-07-05')
) AS datos (carne, periodo, comprobante, fecha)
JOIN public.estudiante AS e ON e.carne=datos.carne
JOIN public.periodo_academico AS p ON p.codigo=datos.periodo
JOIN public.inscripcion AS i ON i.id_estudiante=e.id_estudiante
    AND i.id_periodo_academico=p.id_periodo_academico;



-- ============================================================
-- INICIO BLOQUE 24: PAGOS: ACTUALIZACIÓN DE ESTADO
-- No se insertan filas: se anula la matrícula MAT-2-0001.
-- ============================================================

UPDATE public.pago SET estado='anulado' WHERE numero_comprobante='MAT-2-0001';



-- ============================================================
-- INICIO BLOQUE 25: PAGOS — REGISTROS ADICIONALES
-- Se agrega 1 matrícula sustituta de Q500: MAT-2-0001-R.
-- ============================================================

INSERT INTO public.pago (id_inscripcion, numero_comprobante, concepto, monto, fecha_pago)
SELECT i.id_inscripcion, datos.comprobante, 'matricula', 500, datos.fecha::date
FROM (VALUES
    ('2026-0001', '2026-2', 'MAT-2-0001-R', '2026-07-06')
) AS datos (carne, periodo, comprobante, fecha)
JOIN public.estudiante AS e ON e.carne=datos.carne
JOIN public.periodo_academico AS p ON p.codigo=datos.periodo
JOIN public.inscripcion AS i ON i.id_estudiante=e.id_estudiante
    AND i.id_periodo_academico=p.id_periodo_academico;



-- ============================================================
-- INICIO BLOQUE 26: PAGOS — REGISTROS ADICIONALES
-- Se agrega 1 mensualidad de Q750: julio de 2026, para Ana.
-- ============================================================

INSERT INTO public.pago (id_inscripcion, numero_comprobante, concepto, monto, fecha_pago, anio_mensualidad, mes_mensualidad)
SELECT i.id_inscripcion, datos.comprobante, 'mensualidad', 750, datos.fecha::date, 2026, 7
FROM (VALUES
    ('2026-0001', '2026-2', 'MEN-2-0001-07', '2026-07-10')
) AS datos (carne, periodo, comprobante, fecha)
JOIN public.estudiante AS e ON e.carne=datos.carne
JOIN public.periodo_academico AS p ON p.codigo=datos.periodo
JOIN public.inscripcion AS i ON i.id_estudiante=e.id_estudiante
    AND i.id_periodo_academico=p.id_periodo_academico;

-- Los demás pagos mensuales no se han registrado todavía.
-- La inscripción cancelada no tiene pagos en esta muestra.






-- ============================================================
-- CONFIRMACIÓN FINAL DE TODO EL POBLADO
-- ============================================================

SET CONSTRAINTS ALL IMMEDIATE;
COMMIT;

