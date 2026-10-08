from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.carreras import (
    actualizar_carrera,
    crear_carrera,
    eliminar_carrera,
    obtener_carrera,
    obtener_carreras,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.carrera import (
    CarreraActualizar,
    CarreraCrear,
    CarreraRespuesta,
)


router = APIRouter(
    prefix="/carreras",
    tags=["Carreras"],
)


@router.get("", response_model=list[CarreraRespuesta])
def listar_carreras():
    with SessionLocal() as session:
        carreras = obtener_carreras(session)

        return carreras


@router.get("/{id_carrera}", response_model=CarreraRespuesta)
def consultar_carrera(id_carrera: int):
    with SessionLocal() as session:
        carrera = obtener_carrera(id_carrera, session)

        if carrera is None:
            raise HTTPException(
                status_code=404,
                detail="Carrera no encontrada.",
            )

        return carrera


@router.post(
    "",
    response_model=CarreraRespuesta,
    status_code=201,
)
def registrar_carrera(datos: CarreraCrear):
    def operacion(session):
        return crear_carrera(datos, session)

    try:
        carrera = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return carrera


@router.put("/{id_carrera}", response_model=CarreraRespuesta)
def modificar_carrera(id_carrera: int, datos: CarreraActualizar):
    def operacion(session):
        carrera = actualizar_carrera(id_carrera, datos, session)

        if carrera is None:
            raise HTTPException(
                status_code=404,
                detail="Carrera no encontrada.",
            )

        return carrera

    try:
        carrera = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return carrera


@router.delete("/{id_carrera}")
def borrar_carrera(id_carrera: int):
    def operacion(session):
        eliminada = eliminar_carrera(id_carrera, session)

        if eliminada is False:
            raise HTTPException(
                status_code=404,
                detail="Carrera no encontrada.",
            )

        return eliminada

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Carrera eliminada correctamente."}

