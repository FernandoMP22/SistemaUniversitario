from fastapi import FastAPI

from backend.routers.salud import router as salud_router
from backend.routers.sedes import router as sedes_router


app = FastAPI(
    title="SistemaUniversitario API",
    description="API para la administración académica y de pagos.",
    version="0.1.0",
)

app.include_router(salud_router)
app.include_router(sedes_router)