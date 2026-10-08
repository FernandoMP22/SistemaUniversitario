from sqlalchemy import select

from backend.models.carrera import Carrera


def obtener_carreras(session):
    consulta = select(Carrera).order_by(Carrera.id_carrera)

    resultado = session.execute(consulta)

    carreras = resultado.scalars().all()

    return carreras


def obtener_carrera(id_carrera, session):
    consulta = select(Carrera).where(
        Carrera.id_carrera == id_carrera
    )

    resultado = session.execute(consulta)

    carrera = resultado.scalars().first()

    return carrera


def crear_carrera(datos, session):
    carrera = Carrera(
        id_facultad=datos.id_facultad,
        codigo=datos.codigo,
        nombre=datos.nombre,
        descripcion=datos.descripcion,
    )

    session.add(carrera)

    session.flush()

    return carrera


def actualizar_carrera(id_carrera, datos, session):
    carrera = obtener_carrera(id_carrera, session)

    if carrera is None:
        return None

    carrera.id_facultad = datos.id_facultad
    carrera.codigo = datos.codigo
    carrera.nombre = datos.nombre
    carrera.descripcion = datos.descripcion

    session.flush()

    return carrera


def eliminar_carrera(id_carrera, session):
    carrera = obtener_carrera(id_carrera, session)

    if carrera is None:
        return False

    session.delete(carrera)

    session.flush()

    return True

