from sqlalchemy import select

from backend.models.plan_estudio import PlanEstudio


def obtener_planes_estudio(session):
    consulta = select(PlanEstudio).order_by(PlanEstudio.id_plan_estudio)

    resultado = session.execute(consulta)

    planes_estudio = resultado.scalars().all()

    return planes_estudio


def obtener_plan_estudio(id_plan_estudio, session):
    consulta = select(PlanEstudio).where(
        PlanEstudio.id_plan_estudio == id_plan_estudio
    )

    resultado = session.execute(consulta)

    plan_estudio = resultado.scalars().first()

    return plan_estudio


def crear_plan_estudio(datos, session):
    plan_estudio = PlanEstudio(
        id_carrera=datos.id_carrera,
        id_curso=datos.id_curso,
        semestre_sugerido=datos.semestre_sugerido,
    )

    session.add(plan_estudio)

    session.flush()

    return plan_estudio


def actualizar_plan_estudio(id_plan_estudio, datos, session):
    plan_estudio = obtener_plan_estudio(id_plan_estudio, session)

    if plan_estudio is None:
        return None

    plan_estudio.id_carrera = datos.id_carrera
    plan_estudio.id_curso = datos.id_curso
    plan_estudio.semestre_sugerido = datos.semestre_sugerido

    session.flush()

    return plan_estudio


def eliminar_plan_estudio(id_plan_estudio, session):
    plan_estudio = obtener_plan_estudio(id_plan_estudio, session)

    if plan_estudio is None:
        return False

    session.delete(plan_estudio)

    session.flush()

    return True
