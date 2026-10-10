from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.estudiantes import obtener_estudiante
from backend.database.historial_academico import obtener_historial_academico
from backend.schemas.historial_academico import HistorialAcademicoRespuesta


router = APIRouter(
    prefix="/estudiantes",
    tags=["Historial académico"],
)


@router.get(
    "/{id_estudiante}/historial-academico",
    response_model=list[HistorialAcademicoRespuesta],
)
def consultar_historial_academico(id_estudiante: int):
    try:
        with SessionLocal() as session:
            estudiante = obtener_estudiante(id_estudiante, session)

            if estudiante is None:
                raise HTTPException(
                    status_code=404,
                    detail="Estudiante no encontrado.",
                )

            historial = obtener_historial_academico(id_estudiante, session)

            return historial

    except DBAPIError as error:
        raise traducir_error_database(error) from error
