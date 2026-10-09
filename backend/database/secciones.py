from sqlalchemy import select

from backend.models.seccion import Seccion


def obtener_secciones(session):
    consulta = select(Seccion).order_by(Seccion.id_seccion)

    resultado = session.execute(consulta)

    secciones = resultado.scalars().all()

    return secciones


def obtener_seccion(id_seccion, session):
    consulta = select(Seccion).where(
        Seccion.id_seccion == id_seccion
    )

    resultado = session.execute(consulta)

    seccion = resultado.scalars().first()

    return seccion


def crear_seccion(datos, session):
    seccion = Seccion(
        id_curso=datos.id_curso,
        id_periodo_academico=datos.id_periodo_academico,
        id_docente=datos.id_docente,
        codigo=datos.codigo,
        cupo_maximo=datos.cupo_maximo,
    )

    session.add(seccion)

    session.flush()

    return seccion


def actualizar_seccion(id_seccion, datos, session):
    seccion = obtener_seccion(id_seccion, session)

    if seccion is None:
        return None

    seccion.id_curso = datos.id_curso
    seccion.id_periodo_academico = datos.id_periodo_academico
    seccion.id_docente = datos.id_docente
    seccion.codigo = datos.codigo
    seccion.cupo_maximo = datos.cupo_maximo

    session.flush()

    return seccion


def eliminar_seccion(id_seccion, session):
    seccion = obtener_seccion(id_seccion, session)

    if seccion is None:
        return False

    session.delete(seccion)

    session.flush()

    return True

