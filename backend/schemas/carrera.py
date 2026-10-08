from pydantic import BaseModel, ConfigDict, Field


class CarreraRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_carrera: int
    id_facultad: int
    codigo: str
    nombre: str
    descripcion: str | None


class CarreraCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_facultad: int = Field(gt=0, le=2147483647, strict=True)
    codigo: str = Field(min_length=1, max_length=20)
    nombre: str = Field(min_length=1, max_length=150)
    descripcion: str | None = None


class CarreraActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_facultad: int = Field(gt=0, le=2147483647, strict=True)
    codigo: str = Field(min_length=1, max_length=20)
    nombre: str = Field(min_length=1, max_length=150)
    descripcion: str | None = None

