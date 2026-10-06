# Reglas de negocio — SistemaUniversitario

## Objetivo

Administrar la información académica y los pagos de una universidad
que puede operar en diferentes sedes.

## Alcance

El sistema permitirá gestionar:

- Sedes, facultades y carreras.
- Estudiantes y docentes.
- Cursos, planes de estudio y prerrequisitos.
- Períodos académicos, secciones, horarios y salones.
- Inscripciones y asignaciones de cursos.
- Actividades académicas y calificaciones.
- Historial académico y resultados de aprobación o reprobación.
- Pagos de matrícula y mensualidades.

## Tecnologías acordadas

- Base de datos: PostgreSQL local.
- Backend: FastAPI.
- Frontend: Angular.

## Convención para valores internos

- Los valores de estados, tipos y conceptos se escribirán en minúsculas
  y sin tildes, de forma consistente en PostgreSQL, FastAPI y Angular.
- Los nombres, descripciones y textos de la interfaz conservarán
  su ortografía y sus tildes.

## Tablas acordadas

1. sede
2. facultad
3. carrera
4. estudiante
5. docente
6. curso
7. plan_estudio
8. prerrequisito
9. periodo_academico
10. salon
11. seccion
12. horario_seccion
13. inscripcion
14. asignacion_curso
15. actividad_academica
16. calificacion
17. pago

## Reglas específicas

### 1. Organización universitaria

- Cada sede tiene un código único.
- Una facultad puede tener varias carreras.
- Cada carrera pertenece a una sola facultad.
- Cada carrera tiene un código único.
- Una sede puede tener varios salones.
- Cada salón pertenece a una sola sede.
- El código de un salón debe ser único dentro de su sede.
- La capacidad de un salón debe ser mayor que cero.
- La sede donde se imparte una sección se identifica mediante
  el salón asignado en sus horarios.

### 2. Carreras y estudiantes

- Cada estudiante tiene un carné único.
- Cada estudiante pertenece a una carrera a la vez.
- Una carrera puede tener varios estudiantes.
- Los cambios de carrera y las carreras simultáneas quedan fuera
  del alcance inicial.

### 3. Cursos y planes de estudio

- Cada curso tiene un código único.
- Una carrera incluye varios cursos en su plan de estudios.
- Un curso puede formar parte del plan de varias carreras.
- La tabla plan_estudio relaciona una carrera con un curso e indica
  el semestre sugerido para cursarlo.
- El semestre sugerido debe ser un número entero mayor que cero.
- Un curso no puede repetirse dentro del plan de una misma carrera.
- Se manejará un solo plan vigente por carrera, sin versiones
  históricas en el alcance inicial.

### 4. Prerrequisitos

- Un curso puede requerir uno o varios cursos como prerrequisitos.
- Un curso puede ser prerrequisito de varios cursos.
- Un curso no puede ser prerrequisito de sí mismo.
- No puede repetirse una misma relación de prerrequisito.
- No se permiten ciclos de prerrequisitos.
- Los prerrequisitos de un curso serán los mismos para todas
  las carreras que lo incluyan.
- Todos los prerrequisitos deben estar incluidos en el plan
  de la carrera que ofrece el curso.
- Para asignarse un curso, el estudiante debe haber aprobado
  todos sus prerrequisitos en períodos anteriores.

### 5. Períodos académicos

- Cada período académico tiene un código único, fecha de inicio
  y fecha de finalización.
- La fecha de finalización debe ser posterior a la fecha de inicio.
- Un período puede contener varias secciones.
- Cada sección pertenece a un solo período académico.
- Se podrán conservar períodos finalizados para consultar
  el historial académico.

### 6. Secciones y docentes

- Cada docente tiene un código único.
- Cada sección corresponde a un solo curso.
- Un curso puede tener varias secciones en un mismo período.
- El código de sección no puede repetirse para un mismo curso
  dentro del mismo período.
- Cada sección tiene un docente responsable.
- Un docente puede impartir varias secciones.
- Cada sección tiene un cupo máximo entero mayor que cero.
- Las asignaciones activas no pueden superar el cupo máximo
  de la sección.
- Una sección debe tener al menos un bloque de horario
  antes de permitir asignaciones.

### 7. Horarios y salones

- Una sección puede tener varios bloques de horario.
- Cada bloque pertenece a una sola sección y tiene asignado
  un solo salón.
- Cada bloque registra día de la semana, hora de inicio
  y hora de finalización.
- El día de la semana se representará con números del 1 al 7:
  lunes = 1 y domingo = 7.
- La hora de finalización debe ser posterior a la hora de inicio.
- Los bloques no pueden extenderse de un día al siguiente.
- Los horarios se repetirán semanalmente durante el período.
- Todos los bloques de una sección se imparten en la misma sede.
- La capacidad del salón debe ser igual o mayor que el cupo
  máximo de la sección.
- Un salón no puede tener horarios superpuestos de distintas
  secciones dentro del mismo período académico.
- Un docente no puede impartir secciones con horarios superpuestos
  dentro del mismo período académico.
- Los bloques de horario de una misma sección no pueden superponerse.
- Dos bloques consecutivos pueden compartir la hora de finalización
  e inicio sin considerarse superpuestos.
- Los períodos académicos con clases se manejarán sin superposición
  de fechas en el alcance inicial.

### 8. Inscripciones

- Una inscripción relaciona a un estudiante con un período académico.
- Un estudiante puede tener inscripciones en diferentes períodos.
- Un estudiante solo puede tener una inscripción por período.
- Cada inscripción registra su fecha y estado.
- Los estados permitidos serán activa, cancelada y finalizada.
- Solo una inscripción activa permite nuevas asignaciones de cursos.
- Al cancelar una inscripción, sus asignaciones vigentes se cancelan.
- Una inscripción finalizada conserva sus asignaciones y resultados.

### 9. Asignaciones de cursos

- Una asignación relaciona una inscripción con una sección.
- La sección debe pertenecer al mismo período de la inscripción.
- El curso debe estar incluido en el plan de la carrera del estudiante.
- El estudiante debe cumplir todos los prerrequisitos del curso.
- Debe existir cupo disponible en la sección.
- Un estudiante no puede tener dos asignaciones vigentes del mismo
  curso dentro de un período.
- No puede repetirse la combinación de inscripción y sección.
- Si se reactiva una asignación cancelada, se utiliza el mismo registro
  y se vuelven a comprobar los requisitos.
- Un estudiante no puede tener asignaciones vigentes a secciones
  con horarios superpuestos.
- Un estudiante puede repetir un curso reprobado en un período posterior.
- Un estudiante no puede volver a asignarse un curso ya aprobado.
- Cada asignación registra su fecha y estado académico.
- Los estados permitidos serán cursando, aprobada, reprobada y cancelada.
- Una asignación nueva comienza en estado cursando.
- Las asignaciones canceladas liberan cupo y no cuentan como
  aprobación ni reprobación.
- Una sección con estudiantes asignados no puede cambiar de curso
  ni de período.
- Los cambios de horario, salón o docente deben volver a validar
  capacidad y ausencia de conflictos.

### 10. Actividades académicas

- Cada actividad académica pertenece a una sola sección.
- Una sección puede tener varias actividades académicas.
- Cada actividad registra nombre, tipo, fecha y puntaje máximo.
- Los tipos permitidos serán tarea, proyecto, examen y otra.
- El puntaje máximo debe ser mayor que cero y no superar 100.
- La fecha de la actividad debe estar dentro del período de la sección.
- La suma de los puntajes máximos de una sección no puede superar 100.
- Para cerrar las calificaciones de una sección, la suma de los
  puntajes máximos debe ser exactamente 100.
- Las actividades y sus puntajes máximos no pueden modificarse
  después del cierre de calificaciones.

### 11. Calificaciones

- Una calificación relaciona una actividad académica con una
  asignación de curso.
- La actividad y la asignación deben pertenecer a la misma sección.
- Solo puede existir una calificación por actividad y asignación.
- El puntaje obtenido debe estar entre cero y el puntaje máximo
  de la actividad.
- La ausencia de una calificación significa que está pendiente
  de registrar; no equivale automáticamente a cero.
- Antes del cierre, todas las asignaciones en estado cursando deben
  tener calificaciones en todas las actividades de su sección.
- Si un estudiante no entrega una actividad, se registra explícitamente
  una calificación de cero.
- No se registran nuevas calificaciones en asignaciones canceladas.
- La nota final se obtiene sumando los puntajes de las actividades.
- La nota final estará entre cero y 100.
- Se utilizarán valores decimales con hasta dos posiciones
  para los puntajes.

### 12. Aprobación e historial académico

- Para este proyecto, la nota mínima de aprobación será 61 sobre 100.
- Al cerrar calificaciones, una asignación con nota final igual
  o mayor que 61 cambia a aprobada.
- Una asignación con nota final menor que 61 cambia a reprobada.
- Antes del cierre, el estado permanece como cursando, aunque
  ya existan calificaciones.
- El historial académico se obtiene de las inscripciones,
  asignaciones, secciones, cursos, períodos y calificaciones.
- No se creará una tabla adicional para el historial académico.
- Los intentos reprobados se conservarán aunque el estudiante
  apruebe el curso posteriormente.
- La nota final se calculará desde las calificaciones para evitar
  mantener dos valores que puedan contradecirse.
- Una inscripción solo puede finalizar cuando no tenga asignaciones
  en estado cursando.
- Los resultados finalizados no podrán modificarse mediante
  las operaciones normales del sistema.

### 13. Pagos

- Cada pago pertenece a una inscripción.
- Una inscripción puede tener varios pagos.
- Cada pago registra concepto, monto, fecha y estado.
- Los valores internos permitidos para concepto serán `matricula` y
  `mensualidad`. En la interfaz se mostrarán como Matrícula y Mensualidad.
- El monto debe ser mayor que cero.
- Los estados permitidos serán registrado y anulado.
- Cada pago tendrá un número de comprobante único.
- Para una inscripción solo puede existir un pago de matrícula
  no anulado.
- Los pagos de mensualidad deben indicar el año y mes al que corresponden.
- El mes debe estar entre 1 y 12.
- Para una inscripción solo puede existir un pago de mensualidad
  no anulado por cada combinación de año y mes.
- El año y mes de una mensualidad deben corresponder a un mes
  comprendido en el período académico.
- Los pagos de matrícula no tendrán año y mes de mensualidad.
- Un pago anulado se conserva para mantener el historial.
- Para este alcance se registrarán pagos completos, sin abonos,
  becas, recargos ni devoluciones monetarias.
- Los pagos se registrarán de manera independiente de las asignaciones;
  no bloquearán automáticamente la inscripción ni los cursos.
- La tabla pago registra pagos realizados; no representa por sí sola
  las cuotas pendientes ni calcula deudas.

### 14. Conservación e integridad de los datos

- Las llaves foráneas deben impedir referencias a registros inexistentes.
- No se eliminarán estudiantes, cursos, secciones u otros registros
  que formen parte del historial académico o financiero.
- La cancelación de inscripciones y asignaciones se representará
  mediante estados, conservando los registros.
- La anulación de pagos conservará el registro original.
- Las restricciones que involucren varios registros deben validarse
  antes de confirmar la operación.
- Las operaciones que modifiquen varios registros relacionados
  deben ejecutarse dentro de una transacción.

## Límites del alcance inicial

- Un estudiante pertenece a una carrera a la vez.
- Se maneja un solo plan vigente por carrera.
- No se conserva historial de cambios de carrera o versiones del plan.
- Cada sección tiene un solo docente responsable.
- Las secciones se imparten presencialmente en una sola sede.
- Los prerrequisitos de un curso no varían entre carreras.
- No se administran equivalencias, correquisitos ni cursos de vacaciones
  con períodos superpuestos.
- No se administran abonos, becas, recargos ni devoluciones monetarias.
- La nota mínima de aprobación de 61 es una decisión del proyecto.
