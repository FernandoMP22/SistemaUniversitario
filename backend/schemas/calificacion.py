from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class CalificacionRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_calificacion: int
    id_actividad_academica: int
    id_asignacion_curso: int
    puntaje_obtenido: Decimal


class CalificacionCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_actividad_academica: int = Field(gt=0, le=2147483647, strict=True)
    id_asignacion_curso: int = Field(gt=0, le=2147483647, strict=True)
    puntaje_obtenido: Decimal = Field(ge=0, le=100, max_digits=5, decimal_places=2, allow_inf_nan=False)


class CalificacionActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    puntaje_obtenido: Decimal = Field(ge=0, le=100, max_digits=5, decimal_places=2, allow_inf_nan=False)
