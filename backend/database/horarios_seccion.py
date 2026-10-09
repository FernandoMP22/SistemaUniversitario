from sqlalchemy import select

from backend.models.horario_seccion import HorarioSeccion


def obtener_horarios_seccion(session):
    consulta = select(HorarioSeccion).order_by(HorarioSeccion.id_horario_seccion)

    resultado = session.execute(consulta)

    horarios_seccion = resultado.scalars().all()

    return horarios_seccion


def obtener_horario_seccion(id_horario_seccion, session):
    consulta = select(HorarioSeccion).where(
        HorarioSeccion.id_horario_seccion == id_horario_seccion
    )

    resultado = session.execute(consulta)

    horario_seccion = resultado.scalars().first()

    return horario_seccion


def crear_horario_seccion(datos, session):
    horario_seccion = HorarioSeccion(
        id_seccion=datos.id_seccion,
        id_salon=datos.id_salon,
        dia_semana=datos.dia_semana,
        hora_inicio=datos.hora_inicio,
        hora_fin=datos.hora_fin,
    )

    session.add(horario_seccion)

    session.flush()

    return horario_seccion


def actualizar_horario_seccion(id_horario_seccion, datos, session):
    horario_seccion = obtener_horario_seccion(id_horario_seccion, session)

    if horario_seccion is None:
        return None

    horario_seccion.id_seccion = datos.id_seccion
    horario_seccion.id_salon = datos.id_salon
    horario_seccion.dia_semana = datos.dia_semana
    horario_seccion.hora_inicio = datos.hora_inicio
    horario_seccion.hora_fin = datos.hora_fin

    session.flush()

    return horario_seccion


def eliminar_horario_seccion(id_horario_seccion, session):
    horario_seccion = obtener_horario_seccion(id_horario_seccion, session)

    if horario_seccion is None:
        return False

    session.delete(horario_seccion)

    session.flush()

    return True

