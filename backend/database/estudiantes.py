from sqlalchemy import select

from backend.models.estudiante import Estudiante


def obtener_estudiantes(session):
    consulta = select(Estudiante).order_by(Estudiante.id_estudiante)

    resultado = session.execute(consulta)

    estudiantes = resultado.scalars().all()

    return estudiantes


def obtener_estudiante(id_estudiante, session):
    consulta = select(Estudiante).where(
        Estudiante.id_estudiante == id_estudiante
    )

    resultado = session.execute(consulta)

    estudiante = resultado.scalars().first()

    return estudiante


def crear_estudiante(datos, session):
    estudiante = Estudiante(
        id_carrera=datos.id_carrera,
        carne=datos.carne,
        nombres=datos.nombres,
        apellidos=datos.apellidos,
        fecha_nacimiento=datos.fecha_nacimiento,
        correo=datos.correo,
        telefono=datos.telefono,
        direccion=datos.direccion,
    )

    session.add(estudiante)

    session.flush()

    return estudiante


def actualizar_estudiante(id_estudiante, datos, session):
    estudiante = obtener_estudiante(id_estudiante, session)

    if estudiante is None:
        return None

    estudiante.carne = datos.carne
    estudiante.nombres = datos.nombres
    estudiante.apellidos = datos.apellidos
    estudiante.fecha_nacimiento = datos.fecha_nacimiento
    estudiante.correo = datos.correo
    estudiante.telefono = datos.telefono
    estudiante.direccion = datos.direccion

    session.flush()

    return estudiante


def eliminar_estudiante(id_estudiante, session):
    estudiante = obtener_estudiante(id_estudiante, session)

    if estudiante is None:
        return False

    session.delete(estudiante)

    session.flush()

    return True

