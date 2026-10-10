from sqlalchemy import select

from backend.models.pago import Pago


def obtener_pagos(session):
    consulta = select(Pago).order_by(Pago.id_pago)

    resultado = session.execute(consulta)

    pagos = resultado.scalars().all()

    return pagos


def obtener_pago(id_pago, session):
    consulta = select(Pago).where(
        Pago.id_pago == id_pago
    )

    resultado = session.execute(consulta)

    pago = resultado.scalars().first()

    return pago


def crear_pago(datos, session):
    pago = Pago(
        id_inscripcion=datos.id_inscripcion,
        numero_comprobante=datos.numero_comprobante,
        concepto=datos.concepto,
        monto=datos.monto,
        anio_mensualidad=datos.anio_mensualidad,
        mes_mensualidad=datos.mes_mensualidad,
    )

    if datos.fecha_pago is not None:
        pago.fecha_pago = datos.fecha_pago

    session.add(pago)

    session.flush()

    return pago


def actualizar_pago(id_pago, datos, session):
    pago = obtener_pago(id_pago, session)

    if pago is None:
        return None

    pago.estado = datos.estado

    session.flush()

    return pago
