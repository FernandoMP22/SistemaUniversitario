from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.cursos import (
    actualizar_curso,
    crear_curso,
    eliminar_curso,
    obtener_curso,
    obtener_cursos,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.curso import (
    CursoActualizar,
    CursoCrear,
    CursoRespuesta,
)


router = APIRouter(
    prefix="/cursos",
    tags=["Cursos"],
)


@router.get("", response_model=list[CursoRespuesta])
def listar_cursos():
    with SessionLocal() as session:
        cursos = obtener_cursos(session)

        return cursos


@router.get("/{id_curso}", response_model=CursoRespuesta)
def consultar_curso(id_curso: int):
    with SessionLocal() as session:
        curso = obtener_curso(id_curso, session)

        if curso is None:
            raise HTTPException(
                status_code=404,
                detail="Curso no encontrado.",
            )

        return curso


@router.post(
    "",
    response_model=CursoRespuesta,
    status_code=201,
)
def registrar_curso(datos: CursoCrear):
    def operacion(session):
        return crear_curso(datos, session)

    try:
        curso = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return curso


@router.put("/{id_curso}", response_model=CursoRespuesta)
def modificar_curso(id_curso: int, datos: CursoActualizar):
    def operacion(session):
        curso = actualizar_curso(id_curso, datos, session)

        if curso is None:
            raise HTTPException(
                status_code=404,
                detail="Curso no encontrado.",
            )

        return curso

    try:
        curso = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return curso


@router.delete("/{id_curso}")
def borrar_curso(id_curso: int):
    def operacion(session):
        eliminado = eliminar_curso(id_curso, session)

        if eliminado is False:
            raise HTTPException(
                status_code=404,
                detail="Curso no encontrado.",
            )

        return eliminado

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Curso eliminado correctamente."}
