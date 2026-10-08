from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.estudiantes import (
    actualizar_estudiante,
    crear_estudiante,
    eliminar_estudiante,
    obtener_estudiante,
    obtener_estudiantes,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.estudiante import (
    EstudianteActualizar,
    EstudianteCrear,
    EstudianteRespuesta,
)


router = APIRouter(
    prefix="/estudiantes",
    tags=["Estudiantes"],
)


@router.get("", response_model=list[EstudianteRespuesta])
def listar_estudiantes():
    with SessionLocal() as session:
        estudiantes = obtener_estudiantes(session)

        return estudiantes


@router.get("/{id_estudiante}", response_model=EstudianteRespuesta)
def consultar_estudiante(id_estudiante: int):
    with SessionLocal() as session:
        estudiante = obtener_estudiante(id_estudiante, session)

        if estudiante is None:
            raise HTTPException(
                status_code=404,
                detail="Estudiante no encontrado.",
            )

        return estudiante


@router.post(
    "",
    response_model=EstudianteRespuesta,
    status_code=201,
)
def registrar_estudiante(datos: EstudianteCrear):
    def operacion(session):
        return crear_estudiante(datos, session)

    try:
        estudiante = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return estudiante


@router.put("/{id_estudiante}", response_model=EstudianteRespuesta)
def modificar_estudiante(id_estudiante: int, datos: EstudianteActualizar):
    def operacion(session):
        estudiante = actualizar_estudiante(id_estudiante, datos, session)

        if estudiante is None:
            raise HTTPException(
                status_code=404,
                detail="Estudiante no encontrado.",
            )

        return estudiante

    try:
        estudiante = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return estudiante


@router.delete("/{id_estudiante}")
def borrar_estudiante(id_estudiante: int):
    def operacion(session):
        eliminado = eliminar_estudiante(id_estudiante, session)

        if eliminado is False:
            raise HTTPException(
                status_code=404,
                detail="Estudiante no encontrado.",
            )

        return eliminado

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Estudiante eliminado correctamente."}

