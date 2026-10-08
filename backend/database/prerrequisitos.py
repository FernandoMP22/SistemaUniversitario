from sqlalchemy import select

from backend.models.prerrequisito import Prerrequisito


def obtener_prerrequisitos(session):
    consulta = select(Prerrequisito).order_by(Prerrequisito.id_prerrequisito)

    resultado = session.execute(consulta)

    prerrequisitos = resultado.scalars().all()

    return prerrequisitos


def obtener_prerrequisito(id_prerrequisito, session):
    consulta = select(Prerrequisito).where(
        Prerrequisito.id_prerrequisito == id_prerrequisito
    )

    resultado = session.execute(consulta)

    prerrequisito = resultado.scalars().first()

    return prerrequisito


def crear_prerrequisito(datos, session):
    prerrequisito = Prerrequisito(
        id_curso=datos.id_curso,
        id_curso_requisito=datos.id_curso_requisito,
    )

    session.add(prerrequisito)

    session.flush()

    return prerrequisito


def actualizar_prerrequisito(id_prerrequisito, datos, session):
    prerrequisito = obtener_prerrequisito(id_prerrequisito, session)

    if prerrequisito is None:
        return None

    prerrequisito.id_curso = datos.id_curso
    prerrequisito.id_curso_requisito = datos.id_curso_requisito

    session.flush()

    return prerrequisito


def eliminar_prerrequisito(id_prerrequisito, session):
    prerrequisito = obtener_prerrequisito(id_prerrequisito, session)

    if prerrequisito is None:
        return False

    session.delete(prerrequisito)

    session.flush()

    return True
