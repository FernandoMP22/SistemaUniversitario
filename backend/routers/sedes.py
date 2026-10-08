from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.sedes import (
    actualizar_sede,
    crear_sede,
    eliminar_sede,
    obtener_sede,
    obtener_sedes,
)

from backend.schemas.sede import (
    SedeActualizar,
    SedeCrear,
    SedeRespuesta,
)
from backend.database.transacciones import ejecutar_transaccion


router = APIRouter(
    prefix="/sedes",
    tags=["Sedes"],
)


@router.get("", response_model=list[SedeRespuesta])
def listar_sedes():
    with SessionLocal() as session:
        sedes = obtener_sedes(session)

        return sedes


@router.get("/{id_sede}", response_model=SedeRespuesta)
def consultar_sede(id_sede: int):
    with SessionLocal() as session:
        sede = obtener_sede(id_sede, session)

        if sede is None:
            raise HTTPException(
                status_code=404,
                detail="Sede no encontrada.",
            )

        return sede

@router.post(
    "",
    response_model=SedeRespuesta,
    status_code=201,
)
def registrar_sede(datos: SedeCrear):
    def operacion(session):
        return crear_sede(datos, session)

    try:
        sede = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return sede

@router.put("/{id_sede}", response_model=SedeRespuesta)
def modificar_sede(id_sede: int, datos: SedeActualizar):
    def operacion(session):
        sede = actualizar_sede(id_sede, datos, session)

        if sede is None:
            raise HTTPException(
                status_code=404,
                detail="Sede no encontrada.",
            )

        return sede

    try:
        sede = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return sede


@router.delete("/{id_sede}")
def borrar_sede(id_sede: int):
    def operacion(session):
        eliminada = eliminar_sede(id_sede, session)

        if eliminada is False:
            raise HTTPException(
                status_code=404,
                detail="Sede no encontrada.",
            )

        return eliminada

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Sede eliminada correctamente."}