from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.periodos_academicos import (
    actualizar_periodo_academico,
    crear_periodo_academico,
    eliminar_periodo_academico,
    obtener_periodo_academico,
    obtener_periodos_academicos,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.periodo_academico import (
    PeriodoAcademicoActualizar,
    PeriodoAcademicoCrear,
    PeriodoAcademicoRespuesta,
)


router = APIRouter(
    prefix="/periodos-academicos",
    tags=["Periodos académicos"],
)


@router.get("", response_model=list[PeriodoAcademicoRespuesta])
def listar_periodos_academicos():
    with SessionLocal() as session:
        periodos_academicos = obtener_periodos_academicos(session)

        return periodos_academicos


@router.get("/{id_periodo_academico}", response_model=PeriodoAcademicoRespuesta)
def consultar_periodo_academico(id_periodo_academico: int):
    with SessionLocal() as session:
        periodo_academico = obtener_periodo_academico(id_periodo_academico, session)

        if periodo_academico is None:
            raise HTTPException(
                status_code=404,
                detail="Período académico no encontrado.",
            )

        return periodo_academico


@router.post(
    "",
    response_model=PeriodoAcademicoRespuesta,
    status_code=201,
)
def registrar_periodo_academico(datos: PeriodoAcademicoCrear):
    def operacion(session):
        return crear_periodo_academico(datos, session)

    try:
        periodo_academico = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return periodo_academico


@router.put("/{id_periodo_academico}", response_model=PeriodoAcademicoRespuesta)
def modificar_periodo_academico(id_periodo_academico: int, datos: PeriodoAcademicoActualizar):
    def operacion(session):
        periodo_academico = actualizar_periodo_academico(id_periodo_academico, datos, session)

        if periodo_academico is None:
            raise HTTPException(
                status_code=404,
                detail="Período académico no encontrado.",
            )

        return periodo_academico

    try:
        periodo_academico = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return periodo_academico


@router.delete("/{id_periodo_academico}")
def borrar_periodo_academico(id_periodo_academico: int):
    def operacion(session):
        eliminado = eliminar_periodo_academico(id_periodo_academico, session)

        if eliminado is False:
            raise HTTPException(
                status_code=404,
                detail="Período académico no encontrado.",
            )

        return eliminado

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Período académico eliminado correctamente."}

