from sqlalchemy import select

from backend.models.docente import Docente


def obtener_docentes(session):
    consulta = select(Docente).order_by(Docente.id_docente)

    resultado = session.execute(consulta)

    docentes = resultado.scalars().all()

    return docentes


def obtener_docente(id_docente, session):
    consulta = select(Docente).where(
        Docente.id_docente == id_docente
    )

    resultado = session.execute(consulta)

    docente = resultado.scalars().first()

    return docente


def crear_docente(datos, session):
    docente = Docente(
        codigo=datos.codigo,
        nombres=datos.nombres,
        apellidos=datos.apellidos,
        correo=datos.correo,
        telefono=datos.telefono,
    )

    session.add(docente)

    session.flush()

    return docente


def actualizar_docente(id_docente, datos, session):
    docente = obtener_docente(id_docente, session)

    if docente is None:
        return None

    docente.codigo = datos.codigo
    docente.nombres = datos.nombres
    docente.apellidos = datos.apellidos
    docente.correo = datos.correo
    docente.telefono = datos.telefono

    session.flush()

    return docente


def eliminar_docente(id_docente, session):
    docente = obtener_docente(id_docente, session)

    if docente is None:
        return False

    session.delete(docente)

    session.flush()

    return True

