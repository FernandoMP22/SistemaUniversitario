from sqlalchemy import select

from backend.models.salon import Salon


def obtener_salones(session):
    consulta = select(Salon).order_by(Salon.id_salon)

    resultado = session.execute(consulta)

    salones = resultado.scalars().all()

    return salones


def obtener_salon(id_salon, session):
    consulta = select(Salon).where(
        Salon.id_salon == id_salon
    )

    resultado = session.execute(consulta)

    salon = resultado.scalars().first()

    return salon


def crear_salon(datos, session):
    salon = Salon(
        id_sede=datos.id_sede,
        codigo=datos.codigo,
        capacidad=datos.capacidad,
    )

    session.add(salon)

    session.flush()

    return salon


def actualizar_salon(id_salon, datos, session):
    salon = obtener_salon(id_salon, session)

    if salon is None:
        return None

    salon.id_sede = datos.id_sede
    salon.codigo = datos.codigo
    salon.capacidad = datos.capacidad

    session.flush()

    return salon


def eliminar_salon(id_salon, session):
    salon = obtener_salon(id_salon, session)

    if salon is None:
        return False

    session.delete(salon)

    session.flush()

    return True

