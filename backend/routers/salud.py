from fastapi import APIRouter, HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from backend.database.conexion import engine


router = APIRouter(
    prefix="/salud",
    tags=["Estado del sistema"],
)


@router.get("")
def comprobar_api():
    return {"estado": "ok"}


@router.get("/database")
def comprobar_base_datos():
    try:
        with engine.connect() as conexion:
            resultado = conexion.execute(
                text("""
                    SELECT
                        current_database() AS base_datos,
                        current_setting('transaction_isolation') AS aislamiento
                """)
            ).mappings().one()

            base_datos = resultado["base_datos"]
            aislamiento = resultado["aislamiento"]

    except SQLAlchemyError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No se pudo comprobar la conexión con PostgreSQL.",
        ) from error

    return {
    "estado": "ok",
    "base_datos": base_datos,
    "aislamiento": aislamiento,
    }