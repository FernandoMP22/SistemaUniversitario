from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.horarios_seccion import (
    actualizar_horario_seccion,
    crear_horario_seccion,
    eliminar_horario_seccion,
    obtener_horario_seccion,
    obtener_horarios_seccion,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.horario_seccion import (
    HorarioSeccionActualizar,
    HorarioSeccionCrear,
    HorarioSeccionRespuesta,
)


router = APIRouter(
    prefix="/horarios-seccion",
    tags=["Horarios de sección"],
)


@router.get("", response_model=list[HorarioSeccionRespuesta])
def listar_horarios_seccion():
    with SessionLocal() as session:
        horarios_seccion = obtener_horarios_seccion(session)

        return horarios_seccion


@router.get("/{id_horario_seccion}", response_model=HorarioSeccionRespuesta)
def consultar_horario_seccion(id_horario_seccion: int):
    with SessionLocal() as session:
        horario_seccion = obtener_horario_seccion(id_horario_seccion, session)

        if horario_seccion is None:
            raise HTTPException(
                status_code=404,
                detail="Horario de sección no encontrado.",
            )

        return horario_seccion


@router.post(
    "",
    response_model=HorarioSeccionRespuesta,
    status_code=201,
)
def registrar_horario_seccion(datos: HorarioSeccionCrear):
    def operacion(session):
        return crear_horario_seccion(datos, session)

    try:
        horario_seccion = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return horario_seccion


@router.put("/{id_horario_seccion}", response_model=HorarioSeccionRespuesta)
def modificar_horario_seccion(id_horario_seccion: int, datos: HorarioSeccionActualizar):
    def operacion(session):
        horario_seccion = actualizar_horario_seccion(id_horario_seccion, datos, session)

        if horario_seccion is None:
            raise HTTPException(
                status_code=404,
                detail="Horario de sección no encontrado.",
            )

        return horario_seccion

    try:
        horario_seccion = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return horario_seccion


@router.delete("/{id_horario_seccion}")
def borrar_horario_seccion(id_horario_seccion: int):
    def operacion(session):
        eliminado = eliminar_horario_seccion(id_horario_seccion, session)

        if eliminado is False:
            raise HTTPException(
                status_code=404,
                detail="Horario de sección no encontrado.",
            )

        return eliminado

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Horario de sección eliminado correctamente."}

