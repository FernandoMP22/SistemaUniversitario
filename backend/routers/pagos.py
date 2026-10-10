from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal
from backend.database.errores import traducir_error_database
from backend.database.pagos import (
    actualizar_pago,
    crear_pago,
    obtener_pago,
    obtener_pagos,
)
from backend.database.transacciones import ejecutar_transaccion
from backend.schemas.pago import (
    PagoActualizar,
    PagoCrear,
    PagoRespuesta,
)


router = APIRouter(
    prefix="/pagos",
    tags=["Pagos"],
)


@router.get("", response_model=list[PagoRespuesta])
def listar_pagos():
    with SessionLocal() as session:
        pagos = obtener_pagos(session)

        return pagos


@router.get("/{id_pago}", response_model=PagoRespuesta)
def consultar_pago(id_pago: int):
    with SessionLocal() as session:
        pago = obtener_pago(id_pago, session)

        if pago is None:
            raise HTTPException(
                status_code=404,
                detail="Pago no encontrado.",
            )

        return pago


@router.post(
    "",
    response_model=PagoRespuesta,
    status_code=201,
)
def registrar_pago(datos: PagoCrear):
    def operacion(session):
        return crear_pago(datos, session)

    try:
        pago = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return pago


@router.put("/{id_pago}", response_model=PagoRespuesta)
def modificar_pago(id_pago: int, datos: PagoActualizar):
    def operacion(session):
        pago = actualizar_pago(id_pago, datos, session)

        if pago is None:
            raise HTTPException(
                status_code=404,
                detail="Pago no encontrado.",
            )

        return pago

    try:
        pago = ejecutar_transaccion(operacion)

    except DBAPIError as error:
        raise traducir_error_database(error) from error

    return pago
