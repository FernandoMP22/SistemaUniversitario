from sqlalchemy import select

from backend.models.calificacion import Calificacion


def obtener_calificaciones(session):
    consulta = select(Calificacion).order_by(Calificacion.id_calificacion)

    resultado = session.execute(consulta)

    calificaciones = resultado.scalars().all()

    return calificaciones


def obtener_calificacion(id_calificacion, session):
    consulta = select(Calificacion).where(
        Calificacion.id_calificacion == id_calificacion
    )

    resultado = session.execute(consulta)

    calificacion = resultado.scalars().first()

    return calificacion


def crear_calificacion(datos, session):
    calificacion = Calificacion(
        id_actividad_academica=datos.id_actividad_academica,
        id_asignacion_curso=datos.id_asignacion_curso,
        puntaje_obtenido=datos.puntaje_obtenido,
    )

    session.add(calificacion)

    session.flush()

    return calificacion


def actualizar_calificacion(id_calificacion, datos, session):
    calificacion = obtener_calificacion(id_calificacion, session)

    if calificacion is None:
        return None

    calificacion.puntaje_obtenido = datos.puntaje_obtenido

    session.flush()

    return calificacion


def eliminar_calificacion(id_calificacion, session):
    calificacion = obtener_calificacion(id_calificacion, session)

    if calificacion is None:
        return False

    session.delete(calificacion)

    session.flush()

    return True
