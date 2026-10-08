from sqlalchemy import select

from backend.models.curso import Curso


def obtener_cursos(session):
    consulta = select(Curso).order_by(Curso.id_curso)

    resultado = session.execute(consulta)

    cursos = resultado.scalars().all()

    return cursos


def obtener_curso(id_curso, session):
    consulta = select(Curso).where(
        Curso.id_curso == id_curso
    )

    resultado = session.execute(consulta)

    curso = resultado.scalars().first()

    return curso


def crear_curso(datos, session):
    curso = Curso(
        codigo=datos.codigo,
        nombre=datos.nombre,
        descripcion=datos.descripcion,
    )

    session.add(curso)

    session.flush()

    return curso


def actualizar_curso(id_curso, datos, session):
    curso = obtener_curso(id_curso, session)

    if curso is None:
        return None

    curso.codigo = datos.codigo
    curso.nombre = datos.nombre
    curso.descripcion = datos.descripcion

    session.flush()

    return curso


def eliminar_curso(id_curso, session):
    curso = obtener_curso(id_curso, session)

    if curso is None:
        return False

    session.delete(curso)

    session.flush()

    return True
