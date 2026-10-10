from sqlalchemy import and_, case, func, select

from backend.models.asignacion_curso import AsignacionCurso
from backend.models.calificacion import Calificacion
from backend.models.curso import Curso
from backend.models.inscripcion import Inscripcion
from backend.models.periodo_academico import PeriodoAcademico
from backend.models.seccion import Seccion


def obtener_historial_academico(id_estudiante, session):
    # Una suma por intento evita duplicar filas al unir las calificaciones.
    notas = (
        select(
            Calificacion.id_asignacion_curso,
            func.sum(Calificacion.puntaje_obtenido).label("puntaje_total"),
        )
        .group_by(Calificacion.id_asignacion_curso)
        .subquery()
    )

    resultado_final = and_(
        Seccion.calificaciones_cerradas.is_(True),
        AsignacionCurso.estado.in_(("aprobada", "reprobada")),
    )

    # Las sumas de cursos en progreso o cancelados nunca son notas finales.
    nota_final = case(
        (resultado_final, func.coalesce(notas.c.puntaje_total, 0)),
        else_=None,
    ).label("nota_final")

    consulta = (
        select(
            Inscripcion.id_estudiante,
            Inscripcion.id_inscripcion,
            Inscripcion.estado.label("estado_inscripcion"),
            AsignacionCurso.id_asignacion_curso,
            Curso.id_curso,
            Curso.codigo.label("codigo_curso"),
            Curso.nombre.label("nombre_curso"),
            PeriodoAcademico.id_periodo_academico,
            PeriodoAcademico.codigo.label("codigo_periodo"),
            PeriodoAcademico.nombre.label("nombre_periodo"),
            PeriodoAcademico.fecha_inicio,
            PeriodoAcademico.fecha_fin,
            Seccion.id_seccion,
            Seccion.codigo.label("codigo_seccion"),
            Seccion.calificaciones_cerradas,
            nota_final,
            AsignacionCurso.estado.label("resultado"),
        )
        .select_from(AsignacionCurso)
        .join(Inscripcion, Inscripcion.id_inscripcion == AsignacionCurso.id_inscripcion)
        .join(Seccion, Seccion.id_seccion == AsignacionCurso.id_seccion)
        .join(Curso, Curso.id_curso == Seccion.id_curso)
        .join(PeriodoAcademico, PeriodoAcademico.id_periodo_academico == Seccion.id_periodo_academico)
        .outerjoin(notas, notas.c.id_asignacion_curso == AsignacionCurso.id_asignacion_curso)
        .where(Inscripcion.id_estudiante == id_estudiante)
        .order_by(PeriodoAcademico.fecha_inicio, AsignacionCurso.id_asignacion_curso)
    )

    resultado = session.execute(consulta)

    historial = resultado.mappings().all()

    return historial
