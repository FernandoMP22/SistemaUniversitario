from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.secciones import (
    actualizar_seccion,
    crear_seccion,
    eliminar_seccion,
    obtener_seccion,
    obtener_secciones,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.seccion import (
    SeccionActualizar,
    SeccionCrear,
    SeccionRespuesta,
)


router = APIRouter(
    prefix="/secciones",
    tags=["Secciones"],
)


@router.get("", response_model=list[SeccionRespuesta])
def listar_secciones():
    with SessionLocal() as session:
        secciones = obtener_secciones(session)

        return secciones


@router.get("/{id_seccion}", response_model=SeccionRespuesta)
def consultar_seccion(id_seccion: int):
    with SessionLocal() as session:
        seccion = obtener_seccion(id_seccion, session)

        if seccion is None:
            raise HTTPException(
                status_code=404,
                detail="Sección no encontrada.",
            )

        return seccion


@router.post(
    "",
    response_model=SeccionRespuesta,
    status_code=201,
)
def registrar_seccion(datos: SeccionCrear):
    def operacion(session):
        return crear_seccion(datos, session)

    try:
        seccion = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return seccion


@router.put("/{id_seccion}", response_model=SeccionRespuesta)
def modificar_seccion(id_seccion: int, datos: SeccionActualizar):
    def operacion(session):
        seccion = actualizar_seccion(id_seccion, datos, session)

        if seccion is None:
            raise HTTPException(
                status_code=404,
                detail="Sección no encontrada.",
            )

        return seccion

    try:
        seccion = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return seccion


@router.delete("/{id_seccion}")
def borrar_seccion(id_seccion: int):
    def operacion(session):
        eliminado = eliminar_seccion(id_seccion, session)

        if eliminado is False:
            raise HTTPException(
                status_code=404,
                detail="Sección no encontrada.",
            )

        return eliminado

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Sección eliminada correctamente."}

