from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.asignaciones_cursos import (
    actualizar_asignacion_curso,
    crear_asignacion_curso,
    obtener_asignacion_curso,
    obtener_asignaciones_cursos,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.asignacion_curso import (
    AsignacionCursoActualizar,
    AsignacionCursoCrear,
    AsignacionCursoRespuesta,
)


router = APIRouter(
    prefix="/asignaciones-cursos",
    tags=["Asignaciones de cursos"],
)


@router.get("", response_model=list[AsignacionCursoRespuesta])
def listar_asignaciones_cursos():
    with SessionLocal() as session:
        asignaciones_cursos = obtener_asignaciones_cursos(session)

        return asignaciones_cursos


@router.get("/{id_asignacion_curso}", response_model=AsignacionCursoRespuesta)
def consultar_asignacion_curso(id_asignacion_curso: int):
    with SessionLocal() as session:
        asignacion_curso = obtener_asignacion_curso(id_asignacion_curso, session)

        if asignacion_curso is None:
            raise HTTPException(
                status_code=404,
                detail="Asignación de curso no encontrada.",
            )

        return asignacion_curso


@router.post(
    "",
    response_model=AsignacionCursoRespuesta,
    status_code=201,
)
def registrar_asignacion_curso(datos: AsignacionCursoCrear):
    def operacion(session):
        return crear_asignacion_curso(datos, session)

    try:
        asignacion_curso = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return asignacion_curso


@router.put("/{id_asignacion_curso}", response_model=AsignacionCursoRespuesta)
def modificar_asignacion_curso(id_asignacion_curso: int, datos: AsignacionCursoActualizar):
    def operacion(session):
        asignacion_curso = actualizar_asignacion_curso(id_asignacion_curso, datos, session)

        if asignacion_curso is None:
            raise HTTPException(
                status_code=404,
                detail="Asignación de curso no encontrada.",
            )

        return asignacion_curso

    try:
        asignacion_curso = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return asignacion_curso
