from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.docentes import (
    actualizar_docente,
    crear_docente,
    eliminar_docente,
    obtener_docente,
    obtener_docentes,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.docente import (
    DocenteActualizar,
    DocenteCrear,
    DocenteRespuesta,
)


router = APIRouter(
    prefix="/docentes",
    tags=["Docentes"],
)


@router.get("", response_model=list[DocenteRespuesta])
def listar_docentes():
    with SessionLocal() as session:
        docentes = obtener_docentes(session)

        return docentes


@router.get("/{id_docente}", response_model=DocenteRespuesta)
def consultar_docente(id_docente: int):
    with SessionLocal() as session:
        docente = obtener_docente(id_docente, session)

        if docente is None:
            raise HTTPException(
                status_code=404,
                detail="Docente no encontrado.",
            )

        return docente


@router.post(
    "",
    response_model=DocenteRespuesta,
    status_code=201,
)
def registrar_docente(datos: DocenteCrear):
    def operacion(session):
        return crear_docente(datos, session)

    try:
        docente = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return docente


@router.put("/{id_docente}", response_model=DocenteRespuesta)
def modificar_docente(id_docente: int, datos: DocenteActualizar):
    def operacion(session):
        docente = actualizar_docente(id_docente, datos, session)

        if docente is None:
            raise HTTPException(
                status_code=404,
                detail="Docente no encontrado.",
            )

        return docente

    try:
        docente = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return docente


@router.delete("/{id_docente}")
def borrar_docente(id_docente: int):
    def operacion(session):
        eliminado = eliminar_docente(id_docente, session)

        if eliminado is False:
            raise HTTPException(
                status_code=404,
                detail="Docente no encontrado.",
            )

        return eliminado

    try:
        ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return {"mensaje": "Docente eliminado correctamente."}

