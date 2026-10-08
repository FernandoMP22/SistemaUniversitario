from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.facultades import (
    actualizar_facultad,
    crear_facultad,
    eliminar_facultad,
    obtener_facultad,
    obtener_facultades,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.facultad import (
    FacultadActualizar,
    FacultadCrear,
    FacultadRespuesta,
)


router = APIRouter(
    prefix="/facultades",
    tags=["Facultades"],
)


@router.get("", response_model=list[FacultadRespuesta])
def listar_facultades():
    with SessionLocal() as session:
        facultades = obtener_facultades(session)

        return facultades


@router.get("/{id_facultad}", response_model=FacultadRespuesta)
def consultar_facultad(id_facultad: int):
    with SessionLocal() as session:
        facultad = obtener_facultad(id_facultad, session)

        if facultad is None:
            raise HTTPException(
                status_code=404,
                detail="Facultad no encontrada.",
            )

        return facultad


@router.post(
    "",
    response_model=FacultadRespuesta,
    status_code=201,
)
def registrar_facultad(datos: FacultadCrear):
    def operacion(session):
        return crear_facultad(datos, session)

    try:
        facultad = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return facultad


@router.put("/{id_facultad}", response_model=FacultadRespuesta)
def modificar_facultad(id_facultad: int, datos: FacultadActualizar):
    def operacion(session):
        facultad = actualizar_facultad(id_facultad, datos, session)

        if facultad is None:
            raise HTTPException(
                status_code=404,
                detail="Facultad no encontrada.",
            )

        return facultad

    try:
        facultad = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return facultad


@router.delete("/{id_facultad}")
def borrar_facultad(id_facultad: int):
    def operacion(session):
        eliminada = eliminar_facultad(id_facultad, session)

        if eliminada is False:
            raise HTTPException(
                status_code=404,
                detail="Facultad no encontrada.",
            )

        return eliminada

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Facultad eliminada correctamente."}

