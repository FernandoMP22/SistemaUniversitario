# Backend de SistemaUniversitario

## Tecnologias

- Python 3.14
- FastAPI
- SQLAlchemy
- Psycopg 3
- PostgreSQL local

## Preparacion

Desde la raiz del proyecto, en PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
```

La copia de `.env.example` se realiza solo si no existe `.env`.

Completar en `.env` el servidor, puerto, base de datos,
usuario y contrasena de PostgreSQL.

La base sistema_universitario debe estar creada y tener
instalados el DDL y las reglas de negocio.

## Ejecucion

Desde la raiz del proyecto, con el entorno activado:

```powershell
python -m uvicorn backend.main:app --reload
```

Swagger: http://127.0.0.1:8000/docs

## Organizacion

- config.py: lectura y validacion de configuracion.
- database/: conexion, consultas, transacciones y errores.
- models/: modelos SQLAlchemy de las tablas existentes.
- schemas/: validacion de entradas y respuestas.
- routers/: endpoints.
- services/: reservado para operaciones que coordinen varios pasos.
- main.py: aplicacion y registro de routers.

## Modulos disponibles

- Salud: comprobacion de API y conexion con PostgreSQL.
- Sedes: listado, busqueda, creacion, actualizacion y eliminacion.
- Facultades: listado, busqueda, creacion, actualizacion y eliminacion
  si no existen carreras relacionadas.
- Carreras: listado, busqueda, creacion, actualizacion y eliminacion
  si no existen estudiantes ni cursos del plan relacionados.
- Docentes: listado, busqueda, creacion, actualizacion y eliminacion
  si no existen secciones relacionadas.
- Estudiantes: listado, busqueda, creacion, actualizacion de datos
  personales y eliminacion si no existen inscripciones relacionadas.
- Cursos: listado, busqueda, creacion, actualizacion y eliminacion
  cuando no existen planes, prerrequisitos ni secciones relacionados.
- Planes de estudio: gestion de los cursos de cada carrera y su semestre,
  respetando los requisitos completos y las asignaciones existentes.
- Prerrequisitos: gestion de requisitos directos entre cursos,
  sin autorreferencias, ciclos ni cambios incompatibles con planes o historial.
- Periodos academicos: fechas sin superposiciones y proteccion del historial cerrado.
- Salones: sede, codigo y capacidad compatibles con sus secciones.
- Secciones: oferta de cursos por periodo y docente, cupos e historial protegido.
- Horarios de seccion: bloques por dia y salon, sin cruces ni cambios sobre cierres.
- Inscripciones: registro por estudiante y periodo, consulta y cambios de estado.
- Asignaciones de cursos: registro y cancelacion/reactivacion, conservando resultados.
- Pagos: registro de matriculas/mensualidades, consulta y anulacion sin borrar historial.

Cada modulo mantiene archivos separados en models, schemas, database
y routers. Los routers de los modulos estan registrados en main.py.

## Facultades, carreras, docentes y estudiantes

| Modulo | Ruta | Campos de creacion y actualizacion |
| --- | --- | --- |
| Facultades | `/facultades` | codigo (20), nombre (100), descripcion opcional (TEXT) |
| Carreras | `/carreras` | id_facultad, codigo (20), nombre (150), descripcion opcional (TEXT) |
| Docentes | `/docentes` | codigo (20), nombres (100), apellidos (100), correo (150), telefono opcional (25) |
| Estudiantes | `/estudiantes` | id_carrera solo al crear; carne (25), nombres (100), apellidos (100), fecha_nacimiento (DATE), correo (150), telefono opcional (25), direccion opcional (255) |

Los numeros entre parentesis indican el maximo de caracteres del DDL.
Los textos obligatorios deben tener al menos un caracter. Las descripciones
TEXT no tienen un limite adicional. Los campos opcionales aceptan null.
El correo se valida como texto de hasta 150 caracteres; el DDL no exige
un formato de correo ni unicidad. La fecha de nacimiento debe ser una fecha
valida; no se agregaron reglas de edad que no existen en la base.

Las referencias de entrada deben ser enteros positivos hasta 2147483647,
sin aceptar booleanos, decimales ni numeros enviados como texto.
PostgreSQL comprueba que la facultad o carrera referenciada exista.

Los esquemas de creacion y actualizacion rechazan campos adicionales.
Los identificadores primarios los genera PostgreSQL y no se reciben en
las solicitudes. Las respuestas incluyen todos los campos de la tabla,
incluido el identificador primario y los valores opcionales null.

Los cambios de carrera del estudiante estan fuera del alcance:
`EstudianteActualizar` no incluye `id_carrera` y cualquier intento de
enviarlo devuelve 422, incluso si se envia la carrera actual. El trigger
`regla_estudiante_carrera` tambien impide cambiarla directamente en SQL.
La carrera si permite modificar `id_facultad`, pues las reglas instaladas
no prohiben ese cambio.

### Operaciones

Para cada ruta se ofrecen:

- GET sin identificador: lista ordenada por identificador, o lista vacia.
- GET `/{id}`: consulta de un registro; 404 si no existe.
- POST: creacion; 201 si se confirma la transaccion.
- PUT `/{id}`: actualizacion completa de los campos editables; 200 o 404.
- DELETE `/{id}`: eliminacion de un registro sin referencias; 200 o 404.

PUT requiere todos los campos obligatorios editables. Los opcionales
omitidos toman null, por lo que deben enviarse para conservar su valor.
Para estudiantes, PUT conserva siempre la carrera original.

Las eliminaciones dependen de las FK ON DELETE RESTRICT, sin cascadas.
Una carrera con estudiantes o plan de estudios, un docente con secciones
y un estudiante con inscripciones conservan sus registros. Esto incluye
inscripciones canceladas o finalizadas y secciones de periodos anteriores.
No se agregaron operaciones para borrar historial o ejecutar TRUNCATE.

### Solicitudes de ejemplo para Swagger

Crear primero la facultad, luego la carrera y finalmente el estudiante.
Sustituir los identificadores de ejemplo por los devueltos por la API.

POST `/facultades`:

```json
{
  "codigo": "F-SW-01",
  "nombre": "Facultad de prueba",
  "descripcion": "Prueba desde Swagger"
}
```

POST `/carreras`:

```json
{
  "id_facultad": 1,
  "codigo": "C-SW-01",
  "nombre": "Carrera de prueba",
  "descripcion": null
}
```

POST `/docentes`:

```json
{
  "codigo": "D-SW-01",
  "nombres": "Ana",
  "apellidos": "Perez",
  "correo": "ana@example.com",
  "telefono": null
}
```

POST `/estudiantes`:

```json
{
  "id_carrera": 1,
  "carne": "E-SW-01",
  "nombres": "Luis",
  "apellidos": "Perez",
  "fecha_nacimiento": "2001-05-20",
  "correo": "luis@example.com",
  "telefono": null,
  "direccion": null
}
```

Para PUT usar los mismos campos editables. En estudiantes, quitar
`id_carrera` del cuerpo. Usar codigos y carnes nuevos si los ejemplos
ya fueron registrados.

### Tabla de pruebas manuales en Swagger

Estos casos siguen pendientes de ejecucion interactiva en Swagger.
Los resultados esperados se apoyan en las pruebas automaticas descritas abajo.

| Modulo | Caso | Solicitud o preparacion | Resultado esperado |
| --- | --- | --- | --- |
| Los cuatro | Crear datos validos | POST con los ejemplos y referencias existentes | 201 y registro con identificador |
| Los cuatro | Listar y consultar | GET a la ruta y GET por el identificador creado | 200 y datos del registro |
| Los cuatro | Actualizar campos autorizados | PUT completo con nombre o contacto cambiado | 200; GET confirma el cambio |
| Los cuatro | Duplicado al crear | Repetir codigo o carne en POST | 409; no se crea otro registro |
| Los cuatro | Duplicado al actualizar | Crear dos registros y usar en PUT el codigo o carne del otro, junto con otro cambio | 409; GET conserva todos los datos anteriores |
| Carreras | Facultad inexistente | POST o PUT con id_facultad positivo que no exista | 409; no se guardan cambios |
| Estudiantes | Carrera inexistente | POST con id_carrera positivo que no exista | 409; no se crea el estudiante |
| Los cuatro | Registro inexistente | GET, PUT completo o DELETE con identificador ausente | 404 |
| Los cuatro | Longitud, tipo o dato obligatorio invalido | Exceder un maximo, omitir un obligatorio o enviar null en el | 422 |
| Estudiantes | Fecha invalida | POST o PUT con fecha_nacimiento 2001-02-30 | 422 |
| Los cuatro | Identificador o campo adicional | Agregar id primario u otro campo no definido a POST o PUT | 422 |
| Estudiantes | Intento de cambiar carrera | PUT con todos los datos personales e id_carrera | 422; carrera y datos originales conservados |
| Facultades | Facultad con carreras | DELETE de una facultad referenciada | 409; facultad conservada |
| Carreras | Carrera con estudiantes o plan | DELETE de una carrera referenciada por cualquiera de esas tablas | 409; carrera conservada |
| Docentes | Docente con secciones | DELETE de un docente referenciado, incluso en periodos anteriores | 409; docente conservado |
| Estudiantes | Estudiante con historial | DELETE de un estudiante con inscripciones activas, canceladas o finalizadas | 409; estudiante e historial conservados |
| Los cuatro | Eliminar sin relaciones | DELETE de registros temporales; estudiante y docente primero, carrera despues y facultad al final | 200; GET posterior devuelve 404 |

## Cursos, planes de estudio y prerrequisitos

### Endpoints y columnas

| Modulo | Ruta de coleccion | Identificador de la ruta individual | Campos de POST y PUT |
| --- | --- | --- | --- |
| Cursos | `/cursos` | `id_curso` | codigo (1 a 20 caracteres), nombre (1 a 150), descripcion opcional TEXT |
| Planes de estudio | `/planes-estudio` | `id_plan_estudio` | id_carrera, id_curso, semestre_sugerido |
| Prerrequisitos | `/prerrequisitos` | `id_prerrequisito` | id_curso, id_curso_requisito |

Cada modulo tiene modelos, esquemas Crear/Actualizar/Respuesta, funciones
database y router propio. Cada fila del plan representa un curso de una
carrera, no un plan completo ni una version historica del plan.

Para las tres colecciones: GET lista en orden del identificador y POST
crea una fila (201). En `/{identificador}`: GET consulta (200), PUT
actualiza todos los campos editables (200) y DELETE elimina (200).
GET, PUT y DELETE devuelven 404 si la fila no existe.

Las respuestas contienen todas las columnas de la fila, incluido el
identificador. Los identificadores de entrada son enteros estrictos entre
1 y 2147483647; no se aceptan booleanos, decimales ni numeros como texto.
El semestre es un entero estricto entre 1 y 32767, segun SMALLINT y CHECK > 0.
Los campos adicionales y los identificadores primarios en POST/PUT se
rechazan con 422. PUT requiere todos los obligatorios; omitir la descripcion
del curso la establece en null, como en los modulos existentes.

### Operaciones permitidas y restricciones

Las llaves primarias son los identificadores propios de cada tabla.
`(id_carrera, id_curso)` en plan_estudio y `(id_curso, id_curso_requisito)`
en prerrequisito son restricciones UNIQUE compuestas, no llaves primarias.
Las solicitudes repetidas sobre esas combinaciones devuelven 409; tambien
se comprueba la unicidad al actualizar.

- Curso: se permiten cambios de codigo, nombre y descripcion. El codigo
  debe ser unico. DELETE devuelve 409 si existen planes, secciones o
  prerrequisitos donde el curso aparezca en cualquiera de los dos lados.
- Plan: se permite modificar carrera, curso y semestre. Las reglas actuales
  no declaran inmutables esas referencias; PostgreSQL valida el estado final.
  INSERT, UPDATE y DELETE no pueden dejar cursos sin sus requisitos en el
  mismo plan ni quitar un curso necesario para una asignacion no cancelada,
  incluyendo resultados aprobados o reprobados. Esos rechazos devuelven 400.
- Prerrequisito: se permite editar ambos cursos y eliminar la relacion.
  Se rechazan autorreferencias y ciclos directos o indirectos con 400.
  Cada requisito debe estar en todos los planes que ofrecen el curso.
  Agregar o cambiar requisitos tampoco puede dejar una asignacion no
  cancelada sin la aprobacion previa del requisito en un periodo anterior;
  PostgreSQL rechaza estos cambios con 400.

La eliminacion de un prerrequisito no esta prohibida por el mero hecho de
existir historial: se permite si el estado resultante cumple las reglas.
No se agregaron prohibiciones generales que no aparecen en el SQL.
Las referencias inexistentes producen 409 y las FK no usan cascadas.
Los identificadores primarios permanecen inmutables. No se exponen
operaciones TRUNCATE ni operaciones para borrar el historial.

La API no duplica en Python el recorrido de ciclos ni la comprobacion
global de planes e historial. Todas las escrituras usan ejecutar_transaccion
y los errores se traducen con traducir_error_database. Las reglas diferidas
se comprueban durante COMMIT; un fallo deshace todos los cambios del intento.
No se crean ni alteran tablas, triggers o reglas desde los modelos ORM.

Cada escritura corresponde a una fila. Para preparar un plan, agregar los
cursos base antes de los cursos que los requieren. Para agregar un nuevo
prerrequisito a un curso ya ofrecido, incluir primero el requisito en todos
los planes correspondientes. No se ofrece una operacion por lotes que
cambie varias filas del plan y los requisitos en una misma solicitud.

### Ejemplos JSON

POST `/cursos` y PUT `/cursos/{id_curso}`:

```json
{
  "codigo": "CUR-SW-01",
  "nombre": "Programacion inicial",
  "descripcion": "Curso base"
}
```

POST `/planes-estudio` y PUT `/planes-estudio/{id_plan_estudio}`:

```json
{
  "id_carrera": 1,
  "id_curso": 1,
  "semestre_sugerido": 1
}
```

POST `/prerrequisitos` y PUT `/prerrequisitos/{id_prerrequisito}`:

```json
{
  "id_curso": 2,
  "id_curso_requisito": 1
}
```

Sustituir los identificadores por registros existentes. El ultimo ejemplo
significa que el curso 2 requiere aprobar previamente el curso 1.
Los requisitos son comunes a todas las carreras que ofrecen el curso.

### Tabla de pruebas para Swagger

La ejecucion interactiva en Swagger esta pendiente. Preparar cursos
temporales A, B y C, y una carrera de prueba; A -> B significa que A requiere B.
Para casos de historial, usar relaciones existentes sin eliminar sus datos.

| Modulo | Caso y preparacion | Resultado esperado |
| --- | --- | --- |
| Todos | POST valido; luego GET de coleccion y GET individual | 201 al crear; 200 al consultar |
| Todos | PUT completo con cambios permitidos | 200; GET confirma los cambios |
| Todos | DELETE sin referencias ni reglas que dependan de la fila | 200; GET posterior devuelve 404 |
| Cursos | POST o PUT con codigo de otro curso | 409; rollback de los demas campos |
| Planes | Repetir carrera y curso en POST o PUT | 409, aunque el semestre sea distinto |
| Prerrequisitos | Repetir curso y requisito en POST o PUT | 409 |
| Planes | Carrera o curso positivo inexistente en POST o PUT | 409 |
| Prerrequisitos | Cualquiera de los dos cursos inexistente en POST o PUT | 409 |
| Todos | GET, PUT completo o DELETE de identificador ausente | 404 |
| Todos | Campo adicional, identificador primario o tipo invalido en POST/PUT | 422 |
| Cursos | Codigo de 21 caracteres o nombre de 151 | 422 |
| Planes | Semestre 0, 32768, booleano, decimal o texto | 422 |
| Prerrequisitos | A -> A en POST o PUT | 400; relacion anterior conservada en PUT |
| Prerrequisitos | Crear A -> B y luego B -> A | 400 para la segunda relacion |
| Prerrequisitos | Crear A -> B, B -> C y luego C -> A; o formar un ciclo mediante PUT | 400 |
| Planes | Con A -> B, agregar A a un plan que no tiene B | 400; no se guarda la fila |
| Planes | Agregar B y luego A al mismo plan | 201 en ambas solicitudes |
| Planes | Con A y B en el plan y A -> B, eliminar B o cambiar su carrera/curso | 400; fila y semestre anteriores conservados |
| Prerrequisitos | Agregar o cambiar A -> C cuando falta C en uno de los planes de A | 400; ningun requisito nuevo se conserva |
| Prerrequisitos | Incluir C en todos los planes de A y agregar A -> C, sin historial incompatible | 201 |
| Planes | Eliminar o cambiar un curso del plan usado por asignaciones no canceladas | 400; asignaciones y plan conservados |
| Prerrequisitos | Agregar o cambiar un requisito sin aprobacion previa para una asignacion existente, con planes completos | 400 por proteccion del historial |
| Cursos | Eliminar un curso con plan, secciones o cualquiera de los lados de un prerrequisito | 409 |
| Prerrequisitos | Eliminar una relacion dejando un estado valido | 200; no hay prohibicion general de eliminacion |

## Periodos academicos, salones, secciones y horarios

### Endpoints y campos editables

| Modulo | Coleccion | Identificador individual | Campos de POST y PUT |
| --- | --- | --- | --- |
| Periodos academicos | `/periodos-academicos` | id_periodo_academico | codigo (1 a 20), nombre (1 a 100), fecha_inicio, fecha_fin |
| Salones | `/salones` | id_salon | id_sede, codigo (1 a 20), capacidad |
| Secciones | `/secciones` | id_seccion | id_curso, id_periodo_academico, id_docente, codigo (1 a 20), cupo_maximo |
| Horarios de seccion | `/horarios-seccion` | id_horario_seccion | id_seccion, id_salon, dia_semana, hora_inicio, hora_fin |

En cada coleccion, GET lista por identificador y POST crea (201).
En `/{identificador}`, GET consulta (200), PUT actualiza todos los
campos editables (200) y DELETE elimina cuando las reglas lo permiten (200).
GET individual, PUT y DELETE devuelven 404 para un registro ausente.
Cada modulo separa modelo, esquemas Crear/Actualizar/Respuesta, database
y router, siguiendo sedes. Los cuatro routers estan registrados en main.py.

Todos los campos de entrada son obligatorios. PUT es completo.
Los identificadores primarios no son editables y se generan en PostgreSQL.
POST y PUT rechazan campos adicionales con 422. Referencias, capacidad
y cupo son enteros estrictos entre 1 y 2147483647, segun INTEGER y CHECK > 0;
no aceptan booleanos, decimales ni numeros enviados como texto.
dia_semana es un entero estricto entre 1 y 7: lunes, martes, miercoles,
jueves, viernes, sabado y domingo, respectivamente. No se agregan catalogos
con tildes ni nombres de dias al almacenamiento.

Las fechas se envian como DATE en formato YYYY-MM-DD. Las horas se envian
como HH:MM:SS, con fraccion opcional de segundos y sin zona horaria,
segun TIME del DDL. Fechas imposibles, horas invalidas o con zona producen 422.
PostgreSQL valida que fecha_fin sea posterior a fecha_inicio y hora_fin
posterior a hora_inicio; si no lo son, la API responde 400. No se permiten
bloques que atraviesen la medianoche.

### Operaciones permitidas y restricciones

- Periodos: codigo, nombre y fechas son editables si se mantiene la
  integridad. El codigo es unico (409). Los intervalos de fechas incluyen
  ambos extremos: superponerse o compartir una fecha limite con otro periodo
  produce 409 por la exclusion 23P01. No se cambian fechas de un periodo
  con alguna seccion cerrada (400); su codigo y nombre siguen editables.
  Los cambios de fechas tambien deben conservar actividades dentro del
  periodo, pagos mensuales y la coherencia de aprobaciones y prerrequisitos.
  DELETE queda restringido por secciones o inscripciones relacionadas (409).
- Salones: se pueden editar sede, codigo y capacidad. El codigo es unico
  dentro de cada sede (409), no en toda la universidad. La capacidad debe
  cubrir el cupo_maximo de todas las secciones que lo usan, no solo las
  asignaciones actuales (400). Todos los horarios de una seccion deben
  pertenecer a una sola sede (400). Un salon utilizado por una seccion
  cerrada conserva su sede (400); codigo y capacidad pueden cambiar si
  cumplen las demas reglas. DELETE con horarios relacionados devuelve 409.
- Secciones: las nuevas comienzan con calificaciones_cerradas=false,
  utilizando el valor predeterminado de PostgreSQL. La combinacion
  curso, periodo y codigo es unica (409). Curso y periodo pueden cambiar
  solo si no existe ninguna asignacion, incluyendo canceladas (400).
  Docente, codigo y cupo son editables mientras la seccion este abierta
  y el resultado cumpla las reglas de capacidad, horarios e historial.
  El cupo no puede bajar del numero de asignaciones no canceladas,
  incluyendo aprobadas y reprobadas (400). Una seccion cerrada no admite
  cambios de datos ni eliminacion (400). Una abierta con horarios,
  actividades o asignaciones relacionados no puede eliminarse (409).
- Horarios: los cinco campos son editables entre secciones abiertas.
  La combinacion seccion, dia, hora_inicio y hora_fin es unica (409),
  aunque se cambie el salon. En el mismo periodo y dia, no pueden cruzarse
  bloques de una misma seccion, salon o docente (400). Tampoco se permiten
  cruces para un estudiante con asignaciones no canceladas, aunque sean
  docentes y salones distintos (400). Los bloques contiguos se permiten;
  los bloques en distintos dias o periodos tambien, si cumplen las otras
  reglas. Un cambio de docente o periodo en secciones vuelve a comprobar
  los cruces. Crear, modificar, mover o eliminar horarios de una seccion
  cerrada produce 400. Eliminar o mover el ultimo horario de una seccion
  con asignaciones no canceladas produce 400.

Las FK inexistentes producen 409 y las eliminaciones no usan cascadas.
Las validaciones globales permanecen en PostgreSQL y se comprueban incluso
si el rechazo aparece al confirmar la transaccion. Todas las escrituras
usan ejecutar_transaccion y traducir_error_database, con SERIALIZABLE,
rollback y un maximo de tres intentos para 40001. No se ejecuta DDL desde
SQLAlchemy ni se modifican triggers o reglas.

calificaciones_cerradas aparece en SeccionRespuesta como dato de consulta,
marcado readOnly en OpenAPI. SeccionCrear y SeccionActualizar no lo reciben:
enviarlo, incluso como false, produce 422. No hay endpoint de cierre en
este CRUD; esa operacion academica corresponde a un bloque posterior.

### Ejemplos JSON

Los siguientes cuerpos sirven para POST y PUT completo. Sustituir los
identificadores por los existentes. Antes de crear el periodo, consultar
los periodos actuales y elegir fechas sin superposiciones; las fechas del
ejemplo no garantizan disponibilidad. Crear periodo y salon antes de la
seccion; crear el horario al final.

POST `/periodos-academicos`:

```json
{
  "codigo": "P-SW-2027",
  "nombre": "Primer periodo 2027",
  "fecha_inicio": "2027-01-11",
  "fecha_fin": "2027-05-28"
}
```

POST `/salones`:

```json
{
  "id_sede": 1,
  "codigo": "S-SW-01",
  "capacidad": 30
}
```

POST `/secciones`:

```json
{
  "id_curso": 1,
  "id_periodo_academico": 3,
  "id_docente": 1,
  "codigo": "SEC-SW-01",
  "cupo_maximo": 30
}
```

POST `/horarios-seccion`:

```json
{
  "id_seccion": 6,
  "id_salon": 3,
  "dia_semana": 1,
  "hora_inicio": "08:00:00",
  "hora_fin": "09:30:00"
}
```

Para actualizar, usar la ruta individual con los mismos campos editables.
No copiar identificadores primarios ni calificaciones_cerradas desde la
respuesta al cuerpo de PUT. Elegir codigos nuevos si los ejemplos ya existen.

### Tabla de pruebas de Swagger

La ejecucion HTTP interactiva sigue pendiente. Preparar dos secciones
abiertas con cursos y docentes distintos, salones suficientes en la misma
sede y un periodo libre. Para probar protecciones, consultar secciones con
asignaciones o cierres existentes. Conservar los registros temporales de
Swagger y el poblado; las eliminaciones exitosas de esta tabla corresponden
solo a filas nuevas creadas expresamente para ese caso.

| Modulo | Caso y preparacion | Resultado esperado |
| --- | --- | --- |
| Todos | POST valido, GET de coleccion y GET individual | 201 al crear; 200 al consultar |
| Todos | PUT completo con cambios autorizados | 200; GET confirma los cambios |
| Todos | DELETE de una fila nueva sin dependencias ni cierre | 200; GET devuelve 404 |
| Todos | GET, PUT o DELETE de un identificador ausente | 404 |
| Todos | Campo adicional, ID primario, longitud excesiva o tipo/rango invalido | 422 |
| Periodos | Repetir codigo en POST o PUT, usando fechas libres | 409; rollback de otros campos |
| Periodos | fecha_fin igual o anterior a fecha_inicio | 400 |
| Periodos | Solapar fechas o empezar en la fecha_fin de otro periodo, en POST o PUT | 409; periodo anterior conservado |
| Periodos | Cambiar fechas con una seccion cerrada | 400; fechas y nombre anteriores conservados |
| Periodos | Excluir una actividad existente al cambiar fechas | 400; rollback |
| Periodos | Cambiar solo codigo/nombre manteniendo fechas del historial cerrado | 200 si el codigo es unico |
| Salones | Repetir sede y codigo en POST o PUT | 409; capacidad anterior conservada |
| Salones | Usar el mismo codigo en otra sede existente | 201 si cumple las reglas |
| Salones | id_sede positivo inexistente en POST o PUT | 409; rollback |
| Salones | Bajar capacidad por debajo del cupo de una seccion con horario | 400; codigo y capacidad originales conservados |
| Salones | Mover un salon de una seccion cerrada a otra sede | 400; sede original conservada |
| Secciones | Repetir curso, periodo y codigo en POST o PUT | 409 aunque el docente sea distinto |
| Secciones | Curso, periodo o docente inexistente en POST o PUT | 409; rollback |
| Secciones | Enviar calificaciones_cerradas=true o false en POST o PUT | 422; cierre y datos originales conservados |
| Secciones | Cambiar curso/periodo sin asignaciones y con estado final valido | 200 |
| Secciones | Cambiar curso/periodo con asignaciones, incluso canceladas | 400; identidad conservada |
| Secciones | Bajar cupo por debajo de asignaciones no canceladas | 400; cupo original conservado |
| Secciones | Aumentar cupo por encima de la capacidad del salon | 400 |
| Secciones | PUT con un cambio o DELETE de una seccion cerrada | 400; historial conservado |
| Horarios | Seccion o salon inexistente en POST o PUT | 409 |
| Horarios | Repetir seccion, dia, inicio y fin en POST o PUT | 409 aunque el salon sea distinto |
| Horarios | hora_fin igual o anterior a hora_inicio | 400 |
| Horarios | dia 0/8, hora imposible o con zona horaria | 422 |
| Horarios | Bloques contiguos o en dias/periodos distintos | 201/200 si cumplen las otras reglas |
| Horarios | Solapar bloques de la misma seccion en salones distintos | 400 |
| Horarios | Solapar bloques de secciones distintas en el mismo salon | 400; PUT conserva el horario anterior |
| Horarios/Secciones | Crear cruce del docente mediante horario o cambio de docente/periodo | 400; rollback |
| Horarios | Crear cruce del estudiante entre secciones con docentes y salones distintos | 400 |
| Horarios/Salones | Agregar bloque o cambiar sede del salon dejando una seccion en dos sedes | 400 |
| Horarios | Crear, modificar, mover hacia/desde o borrar horario de una seccion cerrada | 400 |
| Horarios | Borrar o mover el ultimo bloque con asignaciones no canceladas | 400; bloque conservado |
| Horarios | Agregar otro bloque valido y luego borrar el bloque anterior de una fila de prueba | 201 y 200 |
| Periodos/Salones/Secciones | DELETE con secciones/inscripciones, horarios o asignaciones/actividades relacionados | 409; filas relacionadas conservadas |

## Inscripciones, asignaciones de cursos y pagos

### Endpoints y esquemas

Los tres modulos mantienen models, schemas, database y routers separados,
con esquemas Crear/Actualizar/Respuesta. Estan registrados en main.py.

| Modulo | Coleccion | Ruta individual | Campos de creacion |
| --- | --- | --- | --- |
| Inscripciones | `/inscripciones` | `/inscripciones/{id_inscripcion}` | id_estudiante, id_periodo_academico, fecha_inscripcion opcional |
| Asignaciones | `/asignaciones-cursos` | `/asignaciones-cursos/{id_asignacion_curso}` | id_inscripcion, id_seccion, fecha_asignacion opcional |
| Pagos | `/pagos` | `/pagos/{id_pago}` | id_inscripcion, numero_comprobante, concepto, monto, fecha_pago opcional, anio_mensualidad y mes_mensualidad segun concepto |

GET en la coleccion lista por identificador; POST crea y devuelve 201.
GET individual consulta y PUT individual actualiza solo el estado (200).
GET individual y PUT devuelven 404 para un identificador ausente.
No se ofrecen DELETE ni operaciones para trasladar registros, cambiar notas
finales o cerrar calificaciones. Una solicitud DELETE a una ruta individual
existente devuelve 405 porque ese metodo no forma parte de la API.

Las respuestas incluyen todas las columnas de cada tabla. En asignaciones,
aprobada y reprobada son resultados de consulta; no son opciones de entrada.
No se agrega ni almacena nota_final en asignacion_curso.

Todos los esquemas de entrada rechazan campos adicionales (422).
Los identificadores primarios se generan en PostgreSQL. Las referencias
son enteros estrictos de 1 a 2147483647, sin booleanos, decimales o textos.
Las fechas usan YYYY-MM-DD. Omitir la fecha al crear, o enviarla como null,
utiliza CURRENT_DATE de PostgreSQL; tambien puede indicarse una fecha valida
al crear. La fecha almacenada siempre tiene valor y luego es inmutable.
El SQL actual no obliga a que estas fechas de registro esten dentro del
periodo ni impide fechas futuras; no se agregan esas restricciones.

No se recibe estado en POST, ni siquiera el estado inicial correcto:
PostgreSQL establece activa, cursando o registrado segun la tabla.
PUT recibe un unico campo obligatorio, estado. Los valores de catalogo se
escriben en minusculas y sin tildes.

### Estados y campos inmutables

| Modulo | Estados que acepta PUT | Campos conservados |
| --- | --- | --- |
| Inscripciones | activa, cancelada, finalizada | identificador, estudiante, periodo y fecha_inscripcion |
| Asignaciones | cursando, cancelada | identificador, inscripcion, seccion y fecha_asignacion |
| Pagos | anulado | identificador y todos los datos originales del pago |

Las opciones del esquema son estados solicitables, no permisos para saltar
las transiciones SQL. PostgreSQL comprueba el estado original y la integridad
de los registros relacionados antes de confirmar.

- Inscripcion: la combinacion estudiante/periodo es unica, incluso si la
  fila anterior esta cancelada o finalizada (409). Se puede cancelar una
  inscripcion no finalizada: el trigger cancela atomicamente sus asignaciones
  cursando. Los resultados aprobados/reprobados y los pagos se conservan.
  Una cancelada puede volver a activa; sus cursos permanecen cancelados
  hasta reactivarlos individualmente. Se puede finalizar cuando no hay
  cursos cursando; no se exige tener cursos ni que termine el calendario
  del periodo. Finalizar con cursos pendientes devuelve 400. Una finalizada
  no puede cambiar a activa ni cancelada (400).
- Asignacion: comienza cursando y requiere inscripcion activa y seccion
  abierta. Cancelar conserva la fila y sus calificaciones existentes,
  libera cupo y deja de contar para cruces y duplicidad de curso vigente.
  Reactivar utiliza la misma fila; vuelve a exigir inscripcion activa,
  curso en el plan, prerrequisitos aprobados en periodos anteriores,
  curso no aprobado previamente, cupo, horario y ausencia de cruces.
  La combinacion inscripcion/seccion sigue siendo unica al cancelar (409);
  no se crea otra fila para reactivarla. Se conservan los intentos reprobados.
  Las asignaciones aprobadas/reprobadas no cambian de estado (400) y las
  canceladas de secciones cerradas no se reactivan (400).
- Pago: comienza registrado. Solo se permite anularlo y conservar sus
  datos; para corregir importe, concepto, comprobante, fecha o inscripcion,
  anular y registrar otro pago con un comprobante nuevo. No hay reactivacion
  de pagos anulados. Repetir la anulacion de una fila ya anulada devuelve 200
  sin cambiar su contenido, igual que repetir el estado actual permitido
  en una inscripcion o asignacion sin modificar sus datos.

Enviar referencias, fechas u otros campos inmutables en PUT devuelve 422,
incluso si coinciden con los actuales. Enviar aprobada/reprobada en el CRUD
de asignaciones tambien devuelve 422. El cierre academico se implementara
en un bloque posterior; no hay ningun endpoint que lo invoque aqui.
PostgreSQL tambien impide borrados directos de inscripciones, asignaciones
y pagos, incluso sin relaciones, para conservar el historial.

### Reglas academicas y financieras

La seccion y la inscripcion deben tener el mismo periodo. El curso debe
estar en el plan de la carrera del estudiante y tener horario. No se permite
superar el cupo, asignar dos secciones vigentes del mismo curso en un periodo
ni cruzar horarios del estudiante. Las asignaciones aprobadas/reprobadas
tambien cuentan como no canceladas para cupos y conflictos.
Los prerrequisitos deben estar aprobados con notas cerradas y fecha_fin
anterior a fecha_inicio del periodo de la nueva seccion; aprobar en el mismo
periodo no basta. Los intentos reprobados permiten repetir el curso, mientras
que un curso ya aprobado no vuelve a asignarse. Estos rechazos SQL producen 400.

Los pagos son independientes de las asignaciones: ni el DDL ni las reglas
instaladas exigen matricula pagada para inscribir, asignar o reactivar cursos.
Anular una matricula tampoco cancela cursos ni modifica resultados.
El SQL permite registrar pagos para inscripciones canceladas o finalizadas.
No se agregaron bloqueos por deudas ni calculos de cuotas pendientes.

numero_comprobante exige de 1 a 50 caracteres y es unico entre todos los
pagos, incluidos anulados (409). monto usa Decimal y NUMERIC(10,2):
debe ser mayor que cero y no superar 99999999.99, con hasta dos posiciones
decimales; excesos de precision/escala y valores no finitos producen 422.
No se redondean importes invalidos para hacerlos aceptables. Para conservar
la precision al enviar JSON se recomienda usar una cadena, por ejemplo
"150.25". La respuesta JSON tambien representa monto como cadena decimal.

concepto acepta matricula o mensualidad. Para matricula, anio_mensualidad y
mes_mensualidad deben ser null u omitirse. Para mensualidad, ambos son
obligatorios: anio es entero estricto de 1 a 32767 y mes de 1 a 12.
La incoherencia del concepto con estos campos produce 422; PostgreSQL
conserva tambien su CHECK. El mes de la mensualidad debe intersectar las
fechas del periodo de la inscripcion; los meses inicial y final pueden ser
parciales. Un mes ajeno al periodo produce 400, incluso para datos que luego
se anulan. No se impone una relacion adicional entre fecha_pago y dicho mes.

Solo existe una matricula registrada por inscripcion y una mensualidad
registrada por inscripcion/anio/mes. Los indices unicos parciales producen
409 si se repiten. Anular permite un reemplazo con comprobante nuevo,
conservando la fila anulada. Referencias inexistentes producen 409.
Los modelos no crean esos indices, tablas ni triggers.

Las escrituras usan ejecutar_transaccion con SERIALIZABLE, rollback y
hasta tres intentos por 40001. Los routers traducen errores de flush y
commit mediante traducir_error_database. Las validaciones diferidas y la
cancelacion de cursos se confirman o se deshacen junto con la operacion.

### Ejemplos JSON

Sustituir los identificadores por los devueltos por la API. Preparar un
estudiante cuya carrera incluya el curso, un periodo y una seccion abierta
con horario, cupo y prerrequisitos satisfechos. No reutilizar comprobantes.

POST `/inscripciones`:

```json
{
  "id_estudiante": 1,
  "id_periodo_academico": 3
}
```

POST `/asignaciones-cursos`:

```json
{
  "id_inscripcion": 10,
  "id_seccion": 6
}
```

POST `/pagos`, matricula:

```json
{
  "id_inscripcion": 10,
  "numero_comprobante": "MAT-SW-01",
  "concepto": "matricula",
  "monto": "150.25"
}
```

POST `/pagos`, mensualidad de un periodo que incluya junio de 2027:

```json
{
  "id_inscripcion": 10,
  "numero_comprobante": "MEN-SW-01",
  "concepto": "mensualidad",
  "monto": "350.00",
  "fecha_pago": "2027-06-20",
  "anio_mensualidad": 2027,
  "mes_mensualidad": 6
}
```

PUT `/inscripciones/{id_inscripcion}` o
`/asignaciones-cursos/{id_asignacion_curso}` para cancelar:

```json
{"estado": "cancelada"}
```

Para reactivar una inscripcion usar activa; para reactivar su asignacion
cancelada usar cursando. Para finalizar una inscripcion sin cursos pendientes
usar finalizada. PUT `/pagos/{id_pago}`:

```json
{"estado": "anulado"}
```

### Conjunto minimo de pruebas en Swagger

Estos casos HTTP interactivos quedan pendientes. La matriz academica y
financiera completa se comprueba automaticamente; aqui se revisa el contrato
HTTP y los flujos principales. Utilizar registros nuevos para las escrituras
exitosas; conservar los registros anteriores de Swagger y el poblado.

| Caso | Solicitudes | Resultado esperado |
| --- | --- | --- |
| Flujo principal | POST inscripcion, asignacion sin pago previo y matricula; GET de coleccion e individual | 201 al crear, 200 al consultar; estados y fechas iniciales; monto decimal como cadena |
| Rechazos de contrato | POST con monto 0 o 1.001; PUT de asignacion con aprobada o un campo inmutable | 422; datos originales conservados |
| Referencia ausente y duplicado | POST con referencia positiva inexistente; repetir inscripcion o comprobante | 409 |
| Estado y efectos relacionados | Cancelar inscripcion, consultarla y consultar su asignacion; reactivar inscripcion y luego asignacion | 200; cursos cancelados al cancelar; reactivacion del curso individual |
| Finalizacion protegida | PUT finalizada mientras exista un curso cursando | 400; inscripcion y asignacion conservadas |
| Regla diferida y rollback | Registrar mensualidad de un mes ajeno al periodo; GET pagos | 400; no aparece el pago rechazado |
| Anulacion y reemplazo | Anular matricula de prueba y registrar otra con comprobante nuevo | 200 y 201; ambas filas conservadas |
| Historial y metodos restringidos | PUT cancelada sobre resultado final cerrado; DELETE individual de cualquiera de los tres modulos | 400 para resultado protegido; 405 para DELETE |

## Transacciones

El motor utiliza aislamiento SERIALIZABLE.

Las escrituras se ejecutan mediante ejecutar_transaccion:

- COMMIT si la operacion termina correctamente.
- ROLLBACK ante errores.
- Cierre de la sesion en todos los casos.
- Hasta tres intentos cuando PostgreSQL devuelve 40001.
- Repeticion de la operacion completa en cada intento.

Las restricciones y reglas permanecen en PostgreSQL.
Los modelos ORM no crean las tablas.

La capa database agrega, modifica o elimina y llama session.flush;
no confirma transacciones ni captura errores para devolver False.
False en una eliminacion significa unicamente que el registro no existe.
Los routers llaman ejecutar_transaccion y traducir_error_database,
incluidos los errores que aparecen al confirmar reglas diferidas.

Errores comunes: 23505 (duplicado) devuelve 409; 23503 (referencia
inexistente) y 23001 (eliminacion restringida) devuelven 409;
23P01 (exclusion por periodos superpuestos) devuelve 409;
23514 (regla incumplida) devuelve 400; 23502 (dato obligatorio)
devuelve 400. Un 40001 persistente devuelve 503 despues de tres intentos.
Los demas errores de base de datos devuelven 500 sin detalles internos.

## Verificaciones realizadas

- Endpoints de salud y conexion.
- Operaciones del modulo de sedes.
- Validacion de solicitudes.
- Rechazo de codigos duplicados.
- Rollback de una actualizacion rechazada.
- Rechazo de eliminacion de una sede con salones.
- Recuperacion tras dos errores 40001 provocados.
- Limite de tres intentos ante errores 40001 persistentes.

Los errores 40001 de la prueba del backend se provocaron
deliberadamente; no fueron una prueba de concurrencia real.

### Verificacion de organizacion y personas

- Las 12 pruebas del backend terminaron correctamente, incluidas las tres
  pruebas de integracion activadas con PROBAR_POSTGRESQL=1.
- Sintaxis Python y carga de la API/OpenAPI comprobadas.
- Dependencias instaladas coinciden con requirements.txt y pip check
  no detecto incompatibilidades. Las pruebas usan unittest, sin requerir pytest.
- Pruebas de esquemas: longitudes, fecha, tipos de referencias,
  campos adicionales e inmutabilidad de la carrera del estudiante.
- Pruebas del manejo de errores durante commit, rollback y reintentos
  limitados de 40001. Los 40001 fueron simulados.
- Integracion con PostgreSQL mediante los routers: CRUD de los cuatro
  modulos, duplicados en creacion y actualizacion, rollback, referencias
  inexistentes, registros ausentes y eliminaciones restringidas.
- Protecciones reales de docentes con secciones y estudiantes con
  inscripciones; rechazo directo por PostgreSQL del cambio de carrera.
- Bloque de integridad de 01_validacion_base_datos.sql y los 13 bloques
  automaticos de 02_validacion_reglas_negocio.sql aprobados. El primer
  archivo se ejecuto con aislamiento SERIALIZABLE configurado para la sesion.
- 04_verificacion_poblado.sql ejecutado: 17 conteos coincidentes y cero
  resultados cerrados incoherentes.

Las pruebas de integracion utilizan una transaccion externa con savepoints
y fuerzan las reglas diferidas antes de cada confirmacion de prueba.
La transaccion externa se descarta mediante rollback; no se conservan
registros de prueba. Las secuencias de identidad pueden avanzar y dejar saltos.
Estas pruebas invocan los routers directamente: la interaccion HTTP desde
Swagger sigue pendiente, igual que las pruebas manuales de concurrencia
C1, C2 y 03_concurrencia_prerrequisitos.sql en sesiones independientes.

Para repetir las comprobaciones desde PowerShell:

```powershell
.\.venv\Scripts\python.exe -m compileall -q backend
.\.venv\Scripts\python.exe -m pip check
.\.venv\Scripts\python.exe -m unittest discover -s backend/tests -v
$env:PROBAR_POSTGRESQL = '1'
.\.venv\Scripts\python.exe -m unittest discover -s backend/tests -v
Remove-Item Env:\PROBAR_POSTGRESQL
.\.venv\Scripts\python.exe -m backend.tests.verificar_sql
```

Sin PROBAR_POSTGRESQL=1, las pruebas que usan la base se omiten.
El ejecutor SQL selecciona solo bloques completos BEGIN/ROLLBACK;
no ejecuta las secciones manuales de concurrencia ni instala DDL o reglas.

### Verificacion de cursos, planes y prerrequisitos

- Sintaxis de backend y carga de OpenAPI comprobadas; pip check no detecto
  dependencias incompatibles.
- Suite completa: 30 pruebas aprobadas, sin omisiones al activar PostgreSQL.
  Las 18 nuevas incluyen 5 de esquemas/OpenAPI, 2 con errores simulados y
  11 contra PostgreSQL real. Las 12 anteriores tambien pasaron.
- Contra PostgreSQL: CRUD, unicidad compuesta al crear y actualizar,
  referencias inexistentes, autorreferencias, ciclos directos e indirectos,
  requisitos en todos los planes, rechazos de UPDATE/DELETE del plan,
  y proteccion de asignaciones e historial ante nuevos requisitos.
- La integracion usa una transaccion externa y savepoints. Antes de liberar
  cada savepoint se fuerzan las comprobaciones diferidas de PostgreSQL.
  El rollback externo descarta los datos; los conteos de las 17 tablas
  permanecieron iguales antes y despues de repetir las 11 pruebas nuevas.
- Los 14 bloques SQL automaticos de 01 y 02 aprobaron.
- La verificacion 04 reporto cuatro diferencias respecto a la carga inicial:
  facultad 3 frente a 2, carrera 3 frente a 2, docente 3 frente a 2 y
  estudiante 9 frente a 8. No se corrigieron ni eliminaron esos datos.
  Los otros 13 conteos coinciden y no hay resultados cerrados incoherentes.
  El ejecutor SQL termina con codigo 1 por esas diferencias de conteo.

Los errores en COMMIT y los 40001 de las pruebas unitarias se simulan;
no son concurrencia real. Las pruebas con PostgreSQL comprueban sus
restricciones reales, pero usan savepoints y no confirman datos permanentes.
La interaccion HTTP desde Swagger y las pruebas manuales de concurrencia
C1, C2 y 03_concurrencia_prerrequisitos.sql siguen pendientes.

Para ejecutar solo las nuevas pruebas:

```powershell
$env:PROBAR_POSTGRESQL = '1'
.\.venv\Scripts\python.exe -m unittest backend.tests.test_cursos_planes -v
Remove-Item Env:\PROBAR_POSTGRESQL
```

Si PostgreSQL no esta disponible, omitir PROBAR_POSTGRESQL: las 11 pruebas
de integracion nuevas quedan pendientes y se ejecutan las de esquemas y
errores simulados. Los cambios no requieren modificar .env ni instalar DDL.

### Verificacion de oferta academica

- Suite completa actual: 57 pruebas aprobadas, sin omisiones con
  PROBAR_POSTGRESQL=1. Las 30 anteriores pasaron junto con las 27 nuevas:
  6 de esquemas/OpenAPI, 2 de errores simulados y 19 contra PostgreSQL real.
- Sintaxis de Python y carga de OpenAPI comprobadas. Las seis dependencias
  coinciden con requirements.txt y pip check no detecto incompatibilidades.
  Las pruebas usan unittest y no agregan dependencias.
- Contra PostgreSQL: CRUD y respuestas de los cuatro modulos, duplicados
  en INSERT/UPDATE, referencias inexistentes, filas ausentes y rollback
  de cambios rechazados. Se comprobaron la exclusion de periodos
  superpuestos, fechas de actividades, capacidad, sede unica, cupos,
  curso/periodo con asignaciones activas y canceladas y eliminaciones
  restringidas. Tambien se verificaron cambios de relaciones permitidos
  cuando no existen asignaciones.
- Cruces reales comprobados: misma seccion, salon, docente y estudiante.
  Se probaron cambios de docente que crean conflictos, bloques contiguos
  y bloques iguales en distintos dias o periodos.
- El historial cerrado de prueba bloquea cambios y eliminaciones de
  secciones, inserciones/actualizaciones/eliminaciones de horarios,
  movimientos hacia secciones cerradas, cambios de fechas del periodo y
  de sede del salon. Las notas y el resultado aprobado se conservaron.
  La funcion SQL existente de cierre se utiliza solo para preparar ese
  historial temporal; no se implementa su endpoint.
- Los tests de integracion invocan los routers dentro de savepoints de una
  transaccion SERIALIZABLE externa. Se fuerzan SET CONSTRAINTS ALL IMMEDIATE
  antes de liberar cada savepoint para ejecutar las reglas diferidas reales.
  El rollback externo descarta los datos: los conteos de las 17 tablas
  permanecieron iguales antes y despues de la suite completa.
  No se borraron registros conservados de Swagger. Las identidades pueden
  avanzar y dejar saltos aunque las filas se descarten.
- Los errores de COMMIT y los reintentos 40001 de las pruebas unitarias
  son simulados. No constituyen concurrencia real ni una prueba de COMMIT
  permanente; la integracion real valida restricciones con savepoints.
- Los 14 bloques SQL automaticos de 01 y 02 aprobaron. La verificacion 04
  sigue mostrando cuatro diferencias del poblado: facultad 3 frente a 2,
  carrera 3 frente a 2, docente 3 frente a 2 y estudiante 9 frente a 8.
  Los otros 13 conteos coinciden; hay cero resultados cerrados incoherentes.
  Por esas diferencias existentes, el ejecutor SQL termina con codigo 1.
  No se modificaron sus conteos esperados ni los datos conservados.

Quedan pendientes las solicitudes HTTP interactivas de la tabla de Swagger
y las pruebas de concurrencia C1, C2 y 03 en sesiones independientes.
Los resultados de verificacion de bloques anteriores son historicos;
la suite actual y el estado del poblado son los indicados en esta seccion.

Para repetir solo las pruebas de oferta academica:

```powershell
$env:PROBAR_POSTGRESQL = '1'
.\.venv\Scripts\python.exe -m unittest backend.tests.test_oferta_academica -v
Remove-Item Env:\PROBAR_POSTGRESQL
```

Si PostgreSQL no esta disponible, ejecutar sin PROBAR_POSTGRESQL:
las 19 pruebas nuevas de integracion y los bloques SQL quedan pendientes;
las 8 nuevas de esquemas y errores simulados pueden ejecutarse sin conexion.

### Verificacion de inscripciones, asignaciones y pagos

- Suite completa: 86 pruebas aprobadas sin omisiones con PostgreSQL activo,
  incluidas las 57 anteriores y 29 nuevas. Las nuevas son 7 de esquemas y
  OpenAPI, 2 de errores simulados y 20 contra PostgreSQL real.
- Sintaxis Python, carga de la API/OpenAPI y git diff --check comprobados.
  Las seis versiones instaladas coinciden con requirements.txt; pip check
  no detecto incompatibilidades. No se agregaron dependencias.
- Contra PostgreSQL se comprobaron creacion/consulta, referencias ausentes,
  defaults de fechas y estados, fechas explicitas, duplicados, indices
  parciales de pagos, meses del periodo y anulacion con reemplazo.
  El importe limite NUMERIC(10,2) conserva su valor Decimal y su representacion
  JSON como cadena. La validacion de importes invalidos se prueba en esquemas.
- Estados reales comprobados: cancelacion de inscripcion y sus cursos,
  reactivacion individual, finalizacion sin cursos pendientes y rechazo de
  cambios de inscripciones finalizadas. Tambien se verificaron cupos liberados,
  duplicidad de curso, cruces del estudiante y rollback de reactivaciones
  rechazadas, dejando el estado cancelada original.
- Requisitos academicos reales comprobados: mismo periodo, pertenencia
  al plan, horario obligatorio, prerrequisitos cerrados en periodos anteriores,
  insuficiencia de una aprobacion en el mismo periodo, rechazo de cursos ya
  aprobados y repeticion de intentos reprobados. Reactivar revalida tambien
  planes, horarios y prerrequisitos modificados mientras la fila esta cancelada.
- Se comprobaron resultados aprobados/reprobados inmutables, secciones
  cerradas y notas conservadas. La funcion SQL existente de cierre solo
  prepara ese historial dentro de las pruebas, sin agregar un endpoint.
  El SQL directo tambien rechazo cambios de identidad y eliminaciones de
  inscripciones, asignaciones y pagos, asi como reactivacion de pagos anulados.
- Se comprobo que asignar no exige pagos de matricula, que anular pagos
  no altera asignaciones y que una inscripcion cancelada/finalizada admite
  pagos segun las reglas actuales.
- La integracion invoca los routers con savepoints dentro de una transaccion
  SERIALIZABLE externa. Antes de liberar cada savepoint se fuerzan las
  restricciones diferidas mediante SET CONSTRAINTS ALL IMMEDIATE.
  La transaccion externa siempre termina en rollback. Los conteos de las
  17 tablas permanecieron iguales antes y despues de la suite completa.
  No se eliminaron registros conservados de Swagger; las identidades pueden
  avanzar y dejar saltos por las pruebas, aunque las filas se descarten.
- Los fallos de commit y los 40001 de los tests unitarios son simulados;
  no prueban concurrencia real. Las pruebas reales validan las reglas de
  PostgreSQL con savepoints, sin confirmar datos permanentes.
- Los 14 bloques SQL automaticos de 01 y 02 aprobaron. El verificador 04
  mantiene cuatro diferencias anteriores: carrera, docente y facultad tienen
  3 registros frente a 2 esperados, y estudiante tiene 9 frente a 8.
  Los otros 13 conteos coinciden y hay cero resultados cerrados incoherentes.
  El ejecutor termina con codigo 1 por esas diferencias del poblado.
  No se modificaron los registros ni los conteos esperados.

La ejecucion interactiva HTTP del conjunto minimo de Swagger y las pruebas
de concurrencia C1, C2 y 03 en sesiones independientes siguen pendientes.
Los resultados de secciones anteriores corresponden a sus respectivos
bloques; la suite actual es la de 86 pruebas indicada aqui.

Para repetir solo las pruebas nuevas:

```powershell
$env:PROBAR_POSTGRESQL = '1'
.\.venv\Scripts\python.exe -m unittest backend.tests.test_inscripciones_pagos -v
Remove-Item Env:\PROBAR_POSTGRESQL
```

Sin PostgreSQL, ejecutar sin PROBAR_POSTGRESQL: pasan a pendientes las
20 pruebas nuevas de integracion y los bloques SQL. Las 9 nuevas de
esquemas y errores simulados pueden ejecutarse sin conexion.
