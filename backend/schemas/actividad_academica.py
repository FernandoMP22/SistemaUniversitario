from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ActividadAcademicaRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_actividad_academica: int
    id_seccion: int
    nombre: str
    tipo: Literal["tarea", "proyecto", "examen", "otra"]
    fecha: date
    puntaje_maximo: Decimal


class ActividadAcademicaCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_seccion: int = Field(gt=0, le=2147483647, strict=True)
    nombre: str = Field(min_length=1, max_length=150)
    tipo: Literal["tarea", "proyecto", "examen", "otra"]
    fecha: date
    puntaje_maximo: Decimal = Field(gt=0, le=100, max_digits=5, decimal_places=2, allow_inf_nan=False)


class ActividadAcademicaActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre: str = Field(min_length=1, max_length=150)
    tipo: Literal["tarea", "proyecto", "examen", "otra"]
    fecha: date
    puntaje_maximo: Decimal = Field(gt=0, le=100, max_digits=5, decimal_places=2, allow_inf_nan=False)
