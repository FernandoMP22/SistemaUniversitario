from sqlalchemy import select

from backend.models.asignacion_curso import AsignacionCurso


def obtener_asignaciones_cursos(session):
    consulta = select(AsignacionCurso).order_by(AsignacionCurso.id_asignacion_curso)

    resultado = session.execute(consulta)

    asignaciones_cursos = resultado.scalars().all()

    return asignaciones_cursos


def obtener_asignacion_curso(id_asignacion_curso, session):
    consulta = select(AsignacionCurso).where(
        AsignacionCurso.id_asignacion_curso == id_asignacion_curso
    )

    resultado = session.execute(consulta)

    asignacion_curso = resultado.scalars().first()

    return asignacion_curso


def crear_asignacion_curso(datos, session):
    asignacion_curso = AsignacionCurso(
        id_inscripcion=datos.id_inscripcion,
        id_seccion=datos.id_seccion,
    )

    if datos.fecha_asignacion is not None:
        asignacion_curso.fecha_asignacion = datos.fecha_asignacion

    session.add(asignacion_curso)

    session.flush()

    return asignacion_curso


def actualizar_asignacion_curso(id_asignacion_curso, datos, session):
    asignacion_curso = obtener_asignacion_curso(id_asignacion_curso, session)

    if asignacion_curso is None:
        return None

    asignacion_curso.estado = datos.estado

    session.flush()

    return asignacion_curso
