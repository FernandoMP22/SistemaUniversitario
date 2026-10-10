from sqlalchemy import select

from backend.models.inscripcion import Inscripcion


def obtener_inscripciones(session):
    consulta = select(Inscripcion).order_by(Inscripcion.id_inscripcion)

    resultado = session.execute(consulta)

    inscripciones = resultado.scalars().all()

    return inscripciones


def obtener_inscripcion(id_inscripcion, session):
    consulta = select(Inscripcion).where(
        Inscripcion.id_inscripcion == id_inscripcion
    )

    resultado = session.execute(consulta)

    inscripcion = resultado.scalars().first()

    return inscripcion


def crear_inscripcion(datos, session):
    inscripcion = Inscripcion(
        id_estudiante=datos.id_estudiante,
        id_periodo_academico=datos.id_periodo_academico,
    )

    if datos.fecha_inscripcion is not None:
        inscripcion.fecha_inscripcion = datos.fecha_inscripcion

    session.add(inscripcion)

    session.flush()

    return inscripcion


def actualizar_inscripcion(id_inscripcion, datos, session):
    inscripcion = obtener_inscripcion(id_inscripcion, session)

    if inscripcion is None:
        return None

    inscripcion.estado = datos.estado

    session.flush()

    return inscripcion
