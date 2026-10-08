from sqlalchemy import select

from backend.models.facultad import Facultad


def obtener_facultades(session):
    consulta = select(Facultad).order_by(Facultad.id_facultad)

    resultado = session.execute(consulta)

    facultades = resultado.scalars().all()

    return facultades


def obtener_facultad(id_facultad, session):
    consulta = select(Facultad).where(
        Facultad.id_facultad == id_facultad
    )

    resultado = session.execute(consulta)

    facultad = resultado.scalars().first()

    return facultad


def crear_facultad(datos, session):
    facultad = Facultad(
        codigo=datos.codigo,
        nombre=datos.nombre,
        descripcion=datos.descripcion,
    )

    session.add(facultad)

    session.flush()

    return facultad


def actualizar_facultad(id_facultad, datos, session):
    facultad = obtener_facultad(id_facultad, session)

    if facultad is None:
        return None

    facultad.codigo = datos.codigo
    facultad.nombre = datos.nombre
    facultad.descripcion = datos.descripcion

    session.flush()

    return facultad


def eliminar_facultad(id_facultad, session):
    facultad = obtener_facultad(id_facultad, session)

    if facultad is None:
        return False

    session.delete(facultad)

    session.flush()

    return True

