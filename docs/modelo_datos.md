# Modelo de datos — SistemaUniversitario

## 1. Convenciones

- Los nombres de tablas y columnas se escribirán en snake_case.
- Cada tabla tendrá una llave primaria id_<tabla>.
- Las llaves primarias serán enteros generados automáticamente.
- Las llaves foráneas utilizarán el mismo tipo que la llave referenciada.
- Los campos serán obligatorios salvo que se indique opcional.
- PK significa llave primaria.
- FK significa llave foránea.
- UNIQUE significa que el valor o combinación no puede repetirse.
- CHECK representa una condición que deben cumplir los datos.
- Los importes monetarios se expresarán en quetzales.
- Los valores internos de estados, tipos y conceptos se escribirán
  en minúsculas y sin tildes.
- Los nombres, descripciones y etiquetas de la interfaz conservarán
  sus tildes; el concepto interno `matricula` se mostrará como Matrícula.
- No se utilizará eliminación en cascada para el historial académico
  ni financiero.

## 2. Tablas y atributos

### 1. sede

Representa las ubicaciones físicas de la universidad.

| Columna | Tipo | Restricción |
|---|---|---|
| id_sede | integer | PK, generado automáticamente |
| codigo | varchar(20) | UNIQUE |
| nombre | varchar(100) | Obligatorio |
| direccion | varchar(255) | Obligatorio |

### 2. facultad

Agrupa las carreras de una misma área académica.

| Columna | Tipo | Restricción |
|---|---|---|
| id_facultad | integer | PK, generado automáticamente |
| codigo | varchar(20) | UNIQUE |
| nombre | varchar(100) | Obligatorio |
| descripcion | text | Opcional |

### 3. carrera

Representa las carreras ofrecidas por la universidad.

| Columna | Tipo | Restricción |
|---|---|---|
| id_carrera | integer | PK, generado automáticamente |
| id_facultad | integer | FK → facultad |
| codigo | varchar(20) | UNIQUE |
| nombre | varchar(150) | Obligatorio |
| descripcion | text | Opcional |

### 4. estudiante

Registra los datos del estudiante y su carrera actual.

| Columna | Tipo | Restricción |
|---|---|---|
| id_estudiante | integer | PK, generado automáticamente |
| id_carrera | integer | FK → carrera |
| carne | varchar(25) | UNIQUE |
| nombres | varchar(100) | Obligatorio |
| apellidos | varchar(100) | Obligatorio |
| fecha_nacimiento | date | Obligatorio |
| correo | varchar(150) | Obligatorio |
| telefono | varchar(25) | Opcional |
| direccion | varchar(255) | Opcional |

### 5. docente

Registra los datos de los docentes.

| Columna | Tipo | Restricción |
|---|---|---|
| id_docente | integer | PK, generado automáticamente |
| codigo | varchar(20) | UNIQUE |
| nombres | varchar(100) | Obligatorio |
| apellidos | varchar(100) | Obligatorio |
| correo | varchar(150) | Obligatorio |
| telefono | varchar(25) | Opcional |

### 6. curso

Representa los cursos del catálogo académico.

| Columna | Tipo | Restricción |
|---|---|---|
| id_curso | integer | PK, generado automáticamente |
| codigo | varchar(20) | UNIQUE |
| nombre | varchar(150) | Obligatorio |
| descripcion | text | Opcional |

### 7. plan_estudio

Relaciona carreras y cursos, indicando el semestre sugerido.
Cada fila representa un curso dentro del plan de una carrera.

| Columna | Tipo | Restricción |
|---|---|---|
| id_plan_estudio | integer | PK, generado automáticamente |
| id_carrera | integer | FK → carrera |
| id_curso | integer | FK → curso |
| semestre_sugerido | smallint | CHECK > 0 |

Restricción adicional:

- UNIQUE (id_carrera, id_curso).

### 8. prerrequisito

Relaciona un curso con otro que debe aprobarse previamente.
Cada fila representa un requisito directo.

| Columna | Tipo | Restricción |
|---|---|---|
| id_prerrequisito | integer | PK, generado automáticamente |
| id_curso | integer | FK → curso |
| id_curso_requisito | integer | FK → curso |

Restricciones adicionales:

- UNIQUE (id_curso, id_curso_requisito).
- CHECK (id_curso <> id_curso_requisito).
- Los ciclos y la presencia del requisito en los planes relacionados
  requieren validación adicional.

### 9. periodo_academico

Representa los períodos en los que se imparten cursos.

| Columna | Tipo | Restricción |
|---|---|---|
| id_periodo_academico | integer | PK, generado automáticamente |
| codigo | varchar(20) | UNIQUE |
| nombre | varchar(100) | Obligatorio |
| fecha_inicio | date | Obligatorio |
| fecha_fin | date | Obligatorio |

Restricciones adicionales:

- CHECK (fecha_fin > fecha_inicio).
- No se permiten períodos con fechas superpuestas en este alcance.

### 10. salon

Representa los espacios físicos disponibles en cada sede.

| Columna | Tipo | Restricción |
|---|---|---|
| id_salon | integer | PK, generado automáticamente |
| id_sede | integer | FK → sede |
| codigo | varchar(20) | Obligatorio |
| capacidad | integer | CHECK > 0 |

Restricción adicional:

- UNIQUE (id_sede, codigo).

### 11. seccion

Representa una oferta de un curso en un período y con un docente.

| Columna | Tipo | Restricción |
|---|---|---|
| id_seccion | integer | PK, generado automáticamente |
| id_curso | integer | FK → curso |
| id_periodo_academico | integer | FK → periodo_academico |
| id_docente | integer | FK → docente |
| codigo | varchar(20) | Obligatorio |
| cupo_maximo | integer | CHECK > 0 |
| calificaciones_cerradas | boolean | DEFAULT false |

Restricción adicional:

- UNIQUE (id_curso, id_periodo_academico, codigo).

El indicador calificaciones_cerradas permite identificar el cierre
aunque la sección todavía no tenga estudiantes.

### 12. horario_seccion

Representa cada bloque semanal de una sección.

| Columna | Tipo | Restricción |
|---|---|---|
| id_horario_seccion | integer | PK, generado automáticamente |
| id_seccion | integer | FK → seccion |
| id_salon | integer | FK → salon |
| dia_semana | smallint | CHECK entre 1 y 7 |
| hora_inicio | time | Obligatorio |
| hora_fin | time | Obligatorio |

Restricciones adicionales:

- CHECK (hora_fin > hora_inicio).
- UNIQUE (id_seccion, dia_semana, hora_inicio, hora_fin).
- Capacidad, sede común y conflictos de horario requieren
  validación adicional.

### 13. inscripcion

Relaciona a un estudiante con un período académico.

| Columna | Tipo | Restricción |
|---|---|---|
| id_inscripcion | integer | PK, generado automáticamente |
| id_estudiante | integer | FK → estudiante |
| id_periodo_academico | integer | FK → periodo_academico |
| fecha_inscripcion | date | DEFAULT CURRENT_DATE |
| estado | varchar(15) | DEFAULT 'activa' |

Restricciones adicionales:

- UNIQUE (id_estudiante, id_periodo_academico).
- CHECK: estado en activa, cancelada o finalizada.

### 14. asignacion_curso

Relaciona una inscripción con una sección y conserva el resultado
académico de ese intento.

| Columna | Tipo | Restricción |
|---|---|---|
| id_asignacion_curso | integer | PK, generado automáticamente |
| id_inscripcion | integer | FK → inscripcion |
| id_seccion | integer | FK → seccion |
| fecha_asignacion | date | DEFAULT CURRENT_DATE |
| estado | varchar(15) | DEFAULT 'cursando' |

Restricciones adicionales:

- UNIQUE (id_inscripcion, id_seccion).
- CHECK: estado en cursando, aprobada, reprobada o cancelada.

La nota final no se almacenará en esta tabla: se calculará a partir
de las calificaciones.

### 15. actividad_academica

Representa las actividades evaluadas de una sección.

| Columna | Tipo | Restricción |
|---|---|---|
| id_actividad_academica | integer | PK, generado automáticamente |
| id_seccion | integer | FK → seccion |
| nombre | varchar(150) | Obligatorio |
| tipo | varchar(15) | Obligatorio |
| fecha | date | Obligatorio |
| puntaje_maximo | numeric(5,2) | CHECK > 0 y <= 100 |

Restricciones adicionales:

- CHECK: tipo en tarea, proyecto, examen u otra.
- La fecha debe estar dentro del período de la sección.
- Los puntajes máximos deben sumar 100 antes del cierre.

### 16. calificacion

Representa el puntaje de una asignación en una actividad.

| Columna | Tipo | Restricción |
|---|---|---|
| id_calificacion | integer | PK, generado automáticamente |
| id_actividad_academica | integer | FK → actividad_academica |
| id_asignacion_curso | integer | FK → asignacion_curso |
| puntaje_obtenido | numeric(5,2) | CHECK entre 0 y 100 |

Restricciones adicionales:

- UNIQUE (id_actividad_academica, id_asignacion_curso).
- El puntaje no puede superar el máximo de la actividad.
- La actividad y la asignación deben pertenecer a la misma sección.

Una calificación pendiente se representa con la ausencia de la fila.
Una actividad no entregada se registra con puntaje cero.

### 17. pago

Registra los pagos realizados para una inscripción.

| Columna | Tipo | Restricción |
|---|---|---|
| id_pago | integer | PK, generado automáticamente |
| id_inscripcion | integer | FK → inscripcion |
| numero_comprobante | varchar(50) | UNIQUE |
| concepto | varchar(15) | Obligatorio |
| monto | numeric(10,2) | CHECK > 0 |
| fecha_pago | date | DEFAULT CURRENT_DATE |
| estado | varchar(15) | DEFAULT 'registrado' |
| anio_mensualidad | smallint | Opcional, CHECK > 0 |
| mes_mensualidad | smallint | Opcional, CHECK entre 1 y 12 |

Restricciones adicionales:

- CHECK: concepto en `matricula` o `mensualidad`.
- CHECK: estado en registrado o anulado.
- Para el concepto `matricula`, año y mes deben ser NULL.
- Para el concepto `mensualidad`, año y mes deben tener valor.
- Un índice único parcial impedirá dos matrículas registradas
  para una misma inscripción.
- Un índice único parcial impedirá dos mensualidades registradas
  para la misma inscripción, año y mes.
- El mes de una mensualidad debe corresponder al período académico.

Los índices parciales permitirán conservar pagos anulados y registrar
un nuevo pago que los sustituya.

## 3. Relaciones principales

| Tabla principal | Tabla relacionada | Relación |
|---|---|---|
| facultad | carrera | Una facultad tiene muchas carreras |
| carrera | estudiante | Una carrera tiene muchos estudiantes |
| carrera | plan_estudio | Una carrera tiene muchos elementos del plan |
| curso | plan_estudio | Un curso aparece en varios planes |
| curso | prerrequisito | Un curso tiene varios requisitos |
| curso | prerrequisito | Un curso es requisito de otros cursos |
| sede | salon | Una sede tiene muchos salones |
| curso | seccion | Un curso tiene muchas secciones |
| periodo_academico | seccion | Un período tiene muchas secciones |
| docente | seccion | Un docente imparte muchas secciones |
| seccion | horario_seccion | Una sección tiene varios bloques |
| salon | horario_seccion | Un salón se utiliza en varios bloques |
| estudiante | inscripcion | Un estudiante tiene varias inscripciones |
| periodo_academico | inscripcion | Un período tiene muchas inscripciones |
| inscripcion | asignacion_curso | Una inscripción tiene varias asignaciones |
| seccion | asignacion_curso | Una sección tiene varias asignaciones |
| seccion | actividad_academica | Una sección tiene varias actividades |
| actividad_academica | calificacion | Una actividad tiene varias calificaciones |
| asignacion_curso | calificacion | Una asignación tiene varias calificaciones |
| inscripcion | pago | Una inscripción tiene varios pagos |

En las relaciones de uno a muchos, el lado de muchos puede tener
cero registros al crear el registro principal. Las reglas del negocio
establecen cuándo se necesita al menos uno, como los horarios
antes de permitir asignaciones.

## 4. Relaciones de muchos a muchos

Las relaciones de muchos a muchos se resuelven mediante tablas
intermedias:

- carrera y curso: plan_estudio.
- curso y curso: prerrequisito.
- estudiante y periodo_academico: inscripcion.
- inscripcion y seccion: asignacion_curso.
- asignacion_curso y actividad_academica: calificacion.

Estas tablas tienen una función dentro del sistema y no se agregan
únicamente para aumentar la cantidad.

## 5. Validaciones que requieren varios registros

Las siguientes reglas no se resuelven con un CHECK simple:

- Detectar ciclos de prerrequisitos.
- Verificar prerrequisitos dentro de cada plan.
- Evitar períodos con fechas superpuestas.
- Comprobar capacidad y sede de los salones.
- Detectar conflictos de horarios de salones, docentes y estudiantes.
- Comprobar cupos disponibles.
- Verificar coincidencia de períodos entre inscripción y sección.
- Verificar que el curso pertenezca a la carrera del estudiante.
- Comprobar aprobación previa de prerrequisitos.
- Impedir asignaciones de cursos ya aprobados.
- Impedir dos asignaciones vigentes del mismo curso en un período.
- Verificar fechas y suma de puntajes de las actividades.
- Verificar que actividad y asignación pertenezcan a la misma sección.
- Comparar el puntaje obtenido con el máximo de la actividad.
- Comprobar que todas las calificaciones estén registradas al cerrar.
- Actualizar aprobación y reprobación durante el cierre.
- Impedir cambios académicos después del cierre.
- Cancelar asignaciones al cancelar una inscripción.
- Validar el año y mes de los pagos contra el período académico.

Durante la implementación se definirán las validaciones mediante
consultas, transacciones y, cuando corresponda, funciones o triggers.

Las operaciones de asignación y cierre deben controlar la concurrencia
para que dos operaciones simultáneas no violen las reglas.

## 6. Historial académico

El historial se construirá consultando:

estudiante, inscripcion, periodo_academico, asignacion_curso,
seccion, curso y calificacion.

No se necesita una tabla adicional de historial.

La suma de calificaciones es definitiva únicamente cuando
calificaciones_cerradas es true.

Antes del cierre, una suma parcial no debe presentarse como nota final.

Las asignaciones canceladas no representan aprobación ni reprobación.

## 7. Decisiones de alcance

- PostgreSQL local, sin Supabase.
- Un estudiante pertenece a una carrera a la vez.
- Un solo plan vigente por carrera.
- Prerrequisitos comunes para todas las carreras.
- Un docente responsable por sección.
- Una sede por sección, identificada mediante sus salones.
- Períodos sin fechas superpuestas.
- Nota mínima de aprobación: 61 sobre 100.
- Pagos completos, sin abonos.
- Registro de pagos realizados, sin cálculo de deudas.
- Sin tabla adicional de historial académico.
