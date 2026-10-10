from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class InscripcionRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_inscripcion: int
    id_estudiante: int
    id_periodo_academico: int
    fecha_inscripcion: date
    estado: Literal["activa", "cancelada", "finalizada"]


class InscripcionCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_estudiante: int = Field(gt=0, le=2147483647, strict=True)
    id_periodo_academico: int = Field(gt=0, le=2147483647, strict=True)
    fecha_inscripcion: date | None = None


class InscripcionActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    # Las referencias y la fecha original se conservan.
    estado: Literal["activa", "cancelada", "finalizada"]
