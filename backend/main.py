from fastapi import FastAPI

from backend.routers.carreras import router as carreras_router
from backend.routers.docentes import router as docentes_router
from backend.routers.estudiantes import router as estudiantes_router
from backend.routers.facultades import router as facultades_router
from backend.routers.salud import router as salud_router
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
