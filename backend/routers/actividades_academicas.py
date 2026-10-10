from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.actividades_academicas import (
    actualizar_actividad_academica,
    crear_actividad_academica,
    eliminar_actividad_academica,
    obtener_actividad_academica,
    obtener_actividades_academicas,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.actividad_academica import (
    ActividadAcademicaActualizar,
    ActividadAcademicaCrear,
    ActividadAcademicaRespuesta,
)


router = APIRouter(
    prefix="/actividades-academicas",
    tags=["Actividades académicas"],
)


@router.get("", response_model=list[ActividadAcademicaRespuesta])
def listar_actividades_academicas():
    with SessionLocal() as session:
        actividades_academicas = obtener_actividades_academicas(session)

        return actividades_academicas


@router.get("/{id_actividad_academica}", response_model=ActividadAcademicaRespuesta)
def consultar_actividad_academica(id_actividad_academica: int):
    with SessionLocal() as session:
        actividad_academica = obtener_actividad_academica(id_actividad_academica, session)

        if actividad_academica is None:
            raise HTTPException(
                status_code=404,
                detail="Actividad académica no encontrada.",
            )

        return actividad_academica


@router.post(
    "",
    response_model=ActividadAcademicaRespuesta,
    status_code=201,
)
def registrar_actividad_academica(datos: ActividadAcademicaCrear):
    def operacion(session):
        return crear_actividad_academica(datos, session)

    try:
        actividad_academica = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return actividad_academica


@router.put("/{id_actividad_academica}", response_model=ActividadAcademicaRespuesta)
def modificar_actividad_academica(id_actividad_academica: int, datos: ActividadAcademicaActualizar):
    def operacion(session):
        actividad_academica = actualizar_actividad_academica(id_actividad_academica, datos, session)

        if actividad_academica is None:
            raise HTTPException(
                status_code=404,
                detail="Actividad académica no encontrada.",
            )

        return actividad_academica

    try:
        actividad_academica = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return actividad_academica


@router.delete("/{id_actividad_academica}")
def borrar_actividad_academica(id_actividad_academica: int):
    def operacion(session):
        eliminada = eliminar_actividad_academica(id_actividad_academica, session)

        if eliminada is False:
            raise HTTPException(
                status_code=404,
                detail="Actividad académica no encontrada.",
            )

        return eliminada

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Actividad académica eliminada correctamente."}
