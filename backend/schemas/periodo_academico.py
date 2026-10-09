from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class PeriodoAcademicoRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_periodo_academico: int
    codigo: str
    nombre: str
    fecha_inicio: date
    fecha_fin: date


class PeriodoAcademicoCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    codigo: str = Field(min_length=1, max_length=20)
    nombre: str = Field(min_length=1, max_length=100)
    fecha_inicio: date
    fecha_fin: date


class PeriodoAcademicoActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    codigo: str = Field(min_length=1, max_length=20)
    nombre: str = Field(min_length=1, max_length=100)
    fecha_inicio: date
    fecha_fin: date

