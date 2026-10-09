from sqlalchemy import select

from backend.models.periodo_academico import PeriodoAcademico


def obtener_periodos_academicos(session):
    consulta = select(PeriodoAcademico).order_by(PeriodoAcademico.id_periodo_academico)

    resultado = session.execute(consulta)

    periodos_academicos = resultado.scalars().all()

    return periodos_academicos


def obtener_periodo_academico(id_periodo_academico, session):
    consulta = select(PeriodoAcademico).where(
        PeriodoAcademico.id_periodo_academico == id_periodo_academico
    )

    resultado = session.execute(consulta)

    periodo_academico = resultado.scalars().first()

    return periodo_academico


def crear_periodo_academico(datos, session):
    periodo_academico = PeriodoAcademico(
        codigo=datos.codigo,
        nombre=datos.nombre,
        fecha_inicio=datos.fecha_inicio,
        fecha_fin=datos.fecha_fin,
    )

    session.add(periodo_academico)

    session.flush()

    return periodo_academico


def actualizar_periodo_academico(id_periodo_academico, datos, session):
    periodo_academico = obtener_periodo_academico(id_periodo_academico, session)

    if periodo_academico is None:
        return None

    periodo_academico.codigo = datos.codigo
    periodo_academico.nombre = datos.nombre
    periodo_academico.fecha_inicio = datos.fecha_inicio
    periodo_academico.fecha_fin = datos.fecha_fin

    session.flush()

    return periodo_academico


def eliminar_periodo_academico(id_periodo_academico, session):
    periodo_academico = obtener_periodo_academico(id_periodo_academico, session)

    if periodo_academico is None:
        return False

    session.delete(periodo_academico)

    session.flush()

    return True

