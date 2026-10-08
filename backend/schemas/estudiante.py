from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class EstudianteRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_estudiante: int
    id_carrera: int
    carne: str
    nombres: str
    apellidos: str
    fecha_nacimiento: date
    correo: str
    telefono: str | None
    direccion: str | None


class EstudianteCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_carrera: int = Field(gt=0, le=2147483647, strict=True)
    carne: str = Field(min_length=1, max_length=25)
    nombres: str = Field(min_length=1, max_length=100)
    apellidos: str = Field(min_length=1, max_length=100)
    fecha_nacimiento: date
    correo: str = Field(min_length=1, max_length=150)
    telefono: str | None = Field(default=None, max_length=25)
    direccion: str | None = Field(default=None, max_length=255)


class EstudianteActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    # La carrera original se conserva por las reglas del historial.
    carne: str = Field(min_length=1, max_length=25)
    nombres: str = Field(min_length=1, max_length=100)
    apellidos: str = Field(min_length=1, max_length=100)
    fecha_nacimiento: date
    correo: str = Field(min_length=1, max_length=150)
    telefono: str | None = Field(default=None, max_length=25)
    direccion: str | None = Field(default=None, max_length=255)

