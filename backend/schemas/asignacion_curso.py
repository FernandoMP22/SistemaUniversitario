from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class AsignacionCursoRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_asignacion_curso: int
    id_inscripcion: int
    id_seccion: int
    fecha_asignacion: date
    estado: Literal["cursando", "aprobada", "reprobada", "cancelada"]


class AsignacionCursoCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_inscripcion: int = Field(gt=0, le=2147483647, strict=True)
    id_seccion: int = Field(gt=0, le=2147483647, strict=True)
    fecha_asignacion: date | None = None


class AsignacionCursoActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    # Las referencias y la fecha original se conservan.
    estado: Literal["cursando", "cancelada"]
