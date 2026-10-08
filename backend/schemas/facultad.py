from pydantic import BaseModel, ConfigDict, Field


class FacultadRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_facultad: int
    codigo: str
    nombre: str
    descripcion: str | None


class FacultadCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    codigo: str = Field(min_length=1, max_length=20)
    nombre: str = Field(min_length=1, max_length=100)
    descripcion: str | None = None


class FacultadActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    codigo: str = Field(min_length=1, max_length=20)
    nombre: str = Field(min_length=1, max_length=100)
    descripcion: str | None = None

