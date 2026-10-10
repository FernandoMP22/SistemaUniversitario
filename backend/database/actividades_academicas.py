from sqlalchemy import select

from backend.models.actividad_academica import ActividadAcademica


def obtener_actividades_academicas(session):
    consulta = select(ActividadAcademica).order_by(ActividadAcademica.id_actividad_academica)

    resultado = session.execute(consulta)

    actividades_academicas = resultado.scalars().all()

    return actividades_academicas


def obtener_actividad_academica(id_actividad_academica, session):
    consulta = select(ActividadAcademica).where(
        ActividadAcademica.id_actividad_academica == id_actividad_academica
    )

    resultado = session.execute(consulta)

    actividad_academica = resultado.scalars().first()

    return actividad_academica


def crear_actividad_academica(datos, session):
    actividad_academica = ActividadAcademica(
        id_seccion=datos.id_seccion,
        nombre=datos.nombre,
        tipo=datos.tipo,
        fecha=datos.fecha,
        puntaje_maximo=datos.puntaje_maximo,
    )

    session.add(actividad_academica)

    session.flush()

    return actividad_academica


def actualizar_actividad_academica(id_actividad_academica, datos, session):
    actividad_academica = obtener_actividad_academica(id_actividad_academica, session)

    if actividad_academica is None:
        return None

    actividad_academica.nombre = datos.nombre
    actividad_academica.tipo = datos.tipo
    actividad_academica.fecha = datos.fecha
    actividad_academica.puntaje_maximo = datos.puntaje_maximo

    session.flush()

    return actividad_academica


def eliminar_actividad_academica(id_actividad_academica, session):
    actividad_academica = obtener_actividad_academica(id_actividad_academica, session)

    if actividad_academica is None:
        return False

    session.delete(actividad_academica)

    session.flush()

    return True
