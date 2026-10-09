from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.salones import (
    actualizar_salon,
    crear_salon,
    eliminar_salon,
    obtener_salon,
    obtener_salones,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.salon import (
    SalonActualizar,
    SalonCrear,
    SalonRespuesta,
)


router = APIRouter(
    prefix="/salones",
    tags=["Salones"],
)


@router.get("", response_model=list[SalonRespuesta])
def listar_salones():
    with SessionLocal() as session:
        salones = obtener_salones(session)

        return salones


@router.get("/{id_salon}", response_model=SalonRespuesta)
def consultar_salon(id_salon: int):
    with SessionLocal() as session:
        salon = obtener_salon(id_salon, session)

        if salon is None:
            raise HTTPException(
                status_code=404,
                detail="Salón no encontrado.",
            )

        return salon


@router.post(
    "",
    response_model=SalonRespuesta,
    status_code=201,
)
def registrar_salon(datos: SalonCrear):
    def operacion(session):
        return crear_salon(datos, session)

    try:
        salon = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return salon


@router.put("/{id_salon}", response_model=SalonRespuesta)
def modificar_salon(id_salon: int, datos: SalonActualizar):
    def operacion(session):
        salon = actualizar_salon(id_salon, datos, session)

        if salon is None:
            raise HTTPException(
                status_code=404,
                detail="Salón no encontrado.",
            )

        return salon

    try:
        salon = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return salon


@router.delete("/{id_salon}")
def borrar_salon(id_salon: int):
    def operacion(session):
        eliminado = eliminar_salon(id_salon, session)

        if eliminado is False:
            raise HTTPException(
                status_code=404,
                detail="Salón no encontrado.",
            )

        return eliminado

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Salón eliminado correctamente."}

