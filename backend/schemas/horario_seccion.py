from datetime import time

from pydantic import BaseModel, ConfigDict, Field, field_validator


class HorarioSeccionRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_horario_seccion: int
    id_seccion: int
    id_salon: int
    dia_semana: int
    hora_inicio: time
    hora_fin: time


class HorarioSeccionCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_seccion: int = Field(gt=0, le=2147483647, strict=True)
    id_salon: int = Field(gt=0, le=2147483647, strict=True)
    dia_semana: int = Field(ge=1, le=7, strict=True)
    hora_inicio: time
    hora_fin: time

    @field_validator("hora_inicio", "hora_fin")
    @classmethod
    def validar_hora_sin_zona(cls, valor):
        if valor.tzinfo is not None:
            raise ValueError("La hora debe enviarse sin zona horaria.")
        return valor


class HorarioSeccionActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_seccion: int = Field(gt=0, le=2147483647, strict=True)
    id_salon: int = Field(gt=0, le=2147483647, strict=True)
    dia_semana: int = Field(ge=1, le=7, strict=True)
    hora_inicio: time
    hora_fin: time

    @field_validator("hora_inicio", "hora_fin")
    @classmethod
    def validar_hora_sin_zona(cls, valor):
        if valor.tzinfo is not None:
            raise ValueError("La hora debe enviarse sin zona horaria.")
        return valor

