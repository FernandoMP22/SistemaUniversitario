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