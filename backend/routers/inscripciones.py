from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.inscripciones import (
    actualizar_inscripcion,
    crear_inscripcion,
    obtener_inscripcion,
    obtener_inscripciones,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.inscripcion import (
    InscripcionActualizar,
    InscripcionCrear,
    InscripcionRespuesta,
)


router = APIRouter(
    prefix="/inscripciones",
    tags=["Inscripciones"],
)


@router.get("", response_model=list[InscripcionRespuesta])
def listar_inscripciones():
    with SessionLocal() as session:
        inscripciones = obtener_inscripciones(session)

        return inscripciones


@router.get("/{id_inscripcion}", response_model=InscripcionRespuesta)
def consultar_inscripcion(id_inscripcion: int):
    with SessionLocal() as session:
        inscripcion = obtener_inscripcion(id_inscripcion, session)

        if inscripcion is None:
            raise HTTPException(
                status_code=404,
                detail="Inscripción no encontrada.",
            )

        return inscripcion


@router.post(
    "",
    response_model=InscripcionRespuesta,
    status_code=201,
)
def registrar_inscripcion(datos: InscripcionCrear):
    def operacion(session):
        return crear_inscripcion(datos, session)

    try:
        inscripcion = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return inscripcion


@router.put("/{id_inscripcion}", response_model=InscripcionRespuesta)
def modificar_inscripcion(id_inscripcion: int, datos: InscripcionActualizar):
    def operacion(session):
        inscripcion = actualizar_inscripcion(id_inscripcion, datos, session)

        if inscripcion is None:
            raise HTTPException(
                status_code=404,
                detail="Inscripción no encontrada.",
            )

        return inscripcion

    try:
        inscripcion = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return inscripcion
