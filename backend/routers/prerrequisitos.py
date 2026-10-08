from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.prerrequisitos import (
    actualizar_prerrequisito,
    crear_prerrequisito,
    eliminar_prerrequisito,
    obtener_prerrequisito,
    obtener_prerrequisitos,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.prerrequisito import (
    PrerrequisitoActualizar,
    PrerrequisitoCrear,
    PrerrequisitoRespuesta,
)


router = APIRouter(
    prefix="/prerrequisitos",
    tags=["Prerrequisitos"],
)


@router.get("", response_model=list[PrerrequisitoRespuesta])
def listar_prerrequisitos():
    with SessionLocal() as session:
        prerrequisitos = obtener_prerrequisitos(session)

        return prerrequisitos


@router.get("/{id_prerrequisito}", response_model=PrerrequisitoRespuesta)
def consultar_prerrequisito(id_prerrequisito: int):
    with SessionLocal() as session:
        prerrequisito = obtener_prerrequisito(id_prerrequisito, session)

        if prerrequisito is None:
            raise HTTPException(
                status_code=404,
                detail="Prerrequisito no encontrado.",
            )

        return prerrequisito


@router.post(
    "",
    response_model=PrerrequisitoRespuesta,
    status_code=201,
)
def registrar_prerrequisito(datos: PrerrequisitoCrear):
    def operacion(session):
        return crear_prerrequisito(datos, session)

    try:
        prerrequisito = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return prerrequisito


@router.put("/{id_prerrequisito}", response_model=PrerrequisitoRespuesta)
def modificar_prerrequisito(id_prerrequisito: int, datos: PrerrequisitoActualizar):
    def operacion(session):
        prerrequisito = actualizar_prerrequisito(id_prerrequisito, datos, session)

        if prerrequisito is None:
            raise HTTPException(
                status_code=404,
                detail="Prerrequisito no encontrado.",
            )

        return prerrequisito

    try:
        prerrequisito = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return prerrequisito


@router.delete("/{id_prerrequisito}")
def borrar_prerrequisito(id_prerrequisito: int):
    def operacion(session):
        eliminado = eliminar_prerrequisito(id_prerrequisito, session)

        if eliminado is False:
            raise HTTPException(
                status_code=404,
                detail="Prerrequisito no encontrado.",
            )

        return eliminado

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Prerrequisito eliminado correctamente."}
