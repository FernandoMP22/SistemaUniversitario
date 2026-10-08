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

Cada modulo mantiene archivos separados en models, schemas, database
y routers. Los cuatro routers estan registrados en main.py.

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
