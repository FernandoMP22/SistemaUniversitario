from pydantic import BaseModel, ConfigDict, Field


class CursoRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_curso: int
    codigo: str
    nombre: str
    descripcion: str | None


class CursoCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    codigo: str = Field(min_length=1, max_length=20)
    nombre: str = Field(min_length=1, max_length=150)
    descripcion: str | None = None


class CursoActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    codigo: str = Field(min_length=1, max_length=20)
    nombre: str = Field(min_length=1, max_length=150)
    descripcion: str | None = None
