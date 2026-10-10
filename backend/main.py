from fastapi import FastAPI

from backend.routers.asignaciones_cursos import router as asignaciones_cursos_router
from backend.routers.carreras import router as carreras_router
from backend.routers.cursos import router as cursos_router
from backend.routers.docentes import router as docentes_router
from backend.routers.estudiantes import router as estudiantes_router
from backend.routers.facultades import router as facultades_router
from backend.routers.horarios_seccion import router as horarios_seccion_router
from backend.routers.inscripciones import router as inscripciones_router
from backend.routers.pagos import router as pagos_router
from backend.routers.periodos_academicos import router as periodos_academicos_router
from backend.routers.planes_estudio import router as planes_estudio_router
from backend.routers.prerrequisitos import router as prerrequisitos_router
from backend.routers.salud import router as salud_router
from backend.routers.salones import router as salones_router
from backend.routers.secciones import router as secciones_router
from backend.routers.sedes import router as sedes_router


app = FastAPI(
    title="SistemaUniversitario API",
    description="API para la administración académica y de pagos.",
    version="0.1.0",
)

app.include_router(salud_router)
app.include_router(sedes_router)
app.include_router(facultades_router)
app.include_router(carreras_router)
app.include_router(docentes_router)
app.include_router(estudiantes_router)
app.include_router(cursos_router)
app.include_router(planes_estudio_router)
app.include_router(prerrequisitos_router)
app.include_router(periodos_academicos_router)
app.include_router(salones_router)
app.include_router(secciones_router)
app.include_router(horarios_seccion_router)
app.include_router(inscripciones_router)
app.include_router(asignaciones_cursos_router)
app.include_router(pagos_router)
