from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.planes_estudio import (
    actualizar_plan_estudio,
    crear_plan_estudio,
    eliminar_plan_estudio,
    obtener_plan_estudio,
    obtener_planes_estudio,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.plan_estudio import (
    PlanEstudioActualizar,
    PlanEstudioCrear,
    PlanEstudioRespuesta,
)


router = APIRouter(
    prefix="/planes-estudio",
    tags=["Planes de estudio"],
)


@router.get("", response_model=list[PlanEstudioRespuesta])
def listar_planes_estudio():
    with SessionLocal() as session:
        planes_estudio = obtener_planes_estudio(session)

        return planes_estudio


@router.get("/{id_plan_estudio}", response_model=PlanEstudioRespuesta)
def consultar_plan_estudio(id_plan_estudio: int):
    with SessionLocal() as session:
        plan_estudio = obtener_plan_estudio(id_plan_estudio, session)

        if plan_estudio is None:
            raise HTTPException(
                status_code=404,
                detail="Elemento del plan de estudio no encontrado.",
            )

        return plan_estudio


@router.post(
    "",
    response_model=PlanEstudioRespuesta,
    status_code=201,
)
def registrar_plan_estudio(datos: PlanEstudioCrear):
    def operacion(session):
        return crear_plan_estudio(datos, session)

    try:
        plan_estudio = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return plan_estudio


@router.put("/{id_plan_estudio}", response_model=PlanEstudioRespuesta)
def modificar_plan_estudio(id_plan_estudio: int, datos: PlanEstudioActualizar):
    def operacion(session):
        plan_estudio = actualizar_plan_estudio(id_plan_estudio, datos, session)

        if plan_estudio is None:
            raise HTTPException(
                status_code=404,
                detail="Elemento del plan de estudio no encontrado.",
            )

        return plan_estudio

    try:
        plan_estudio = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return plan_estudio


@router.delete("/{id_plan_estudio}")
def borrar_plan_estudio(id_plan_estudio: int):
    def operacion(session):
        eliminado = eliminar_plan_estudio(id_plan_estudio, session)

        if eliminado is False:
            raise HTTPException(
                status_code=404,
                detail="Elemento del plan de estudio no encontrado.",
            )

        return eliminado

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Elemento del plan de estudio eliminado correctamente."}
