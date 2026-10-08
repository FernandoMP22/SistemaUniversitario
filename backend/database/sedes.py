from sqlalchemy import select

from backend.models.sede import Sede


def obtener_sedes(session):
    consulta = select(Sede).order_by(Sede.id_sede)

    resultado = session.execute(consulta)

    sedes = resultado.scalars().all()

    return sedes


def obtener_sede(id_sede, session):
    consulta = select(Sede).where(
        Sede.id_sede == id_sede
    )

    resultado = session.execute(consulta)

    sede = resultado.scalars().first()

    return sede

def crear_sede(datos, session):
    sede = Sede(
        codigo=datos.codigo,
        nombre=datos.nombre,
        direccion=datos.direccion,
    )

    session.add(sede)

    session.flush()

    return sede

def actualizar_sede(id_sede, datos, session):
    sede = obtener_sede(id_sede, session)

    if sede is None:
        return None

    sede.codigo = datos.codigo
    sede.nombre = datos.nombre
    sede.direccion = datos.direccion

    session.flush()

    return sede


def eliminar_sede(id_sede, session):
    sede = obtener_sede(id_sede, session)

    if sede is None:
        return False

    session.delete(sede)

    session.flush()

    return True 