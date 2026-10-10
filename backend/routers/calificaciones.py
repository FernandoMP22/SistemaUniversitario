from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.calificaciones import (
    actualizar_calificacion,
    crear_calificacion,
    eliminar_calificacion,
    obtener_calificacion,
    obtener_calificaciones,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.calificacion import (
    CalificacionActualizar,
    CalificacionCrear,
    CalificacionRespuesta,
)


router = APIRouter(
    prefix="/calificaciones",
    tags=["Calificaciones"],
)


@router.get("", response_model=list[CalificacionRespuesta])
def listar_calificaciones():
    with SessionLocal() as session:
        calificaciones = obtener_calificaciones(session)

        return calificaciones


@router.get("/{id_calificacion}", response_model=CalificacionRespuesta)
def consultar_calificacion(id_calificacion: int):
    with SessionLocal() as session:
        calificacion = obtener_calificacion(id_calificacion, session)

        if calificacion is None:
            raise HTTPException(
                status_code=404,
                detail="Calificación no encontrada.",
            )

        return calificacion


@router.post(
    "",
    response_model=CalificacionRespuesta,
    status_code=201,
)
def registrar_calificacion(datos: CalificacionCrear):
    def operacion(session):
        return crear_calificacion(datos, session)

    try:
        calificacion = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return calificacion


@router.put("/{id_calificacion}", response_model=CalificacionRespuesta)
def modificar_calificacion(id_calificacion: int, datos: CalificacionActualizar):
    def operacion(session):
        calificacion = actualizar_calificacion(id_calificacion, datos, session)

        if calificacion is None:
            raise HTTPException(
                status_code=404,
                detail="Calificación no encontrada.",
            )

        return calificacion

    try:
        calificacion = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return calificacion


@router.delete("/{id_calificacion}")
def borrar_calificacion(id_calificacion: int):
    def operacion(session):
        eliminada = eliminar_calificacion(id_calificacion, session)

        if eliminada is False:
            raise HTTPException(
                status_code=404,
                detail="Calificación no encontrada.",
            )

        return eliminada

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Calificación eliminada correctamente."}
