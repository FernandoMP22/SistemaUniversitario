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
