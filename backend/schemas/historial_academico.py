from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict


class HistorialAcademicoRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_estudiante: int
    id_inscripcion: int
    estado_inscripcion: Literal["activa", "cancelada", "finalizada"]
    id_asignacion_curso: int
    id_curso: int
    codigo_curso: str
    nombre_curso: str
    id_periodo_academico: int
    codigo_periodo: str
    nombre_periodo: str
    fecha_inicio: date
    fecha_fin: date
    id_seccion: int
    codigo_seccion: str
    calificaciones_cerradas: bool
    nota_final: Decimal | None
    resultado: Literal["cursando", "aprobada", "reprobada", "cancelada"]
