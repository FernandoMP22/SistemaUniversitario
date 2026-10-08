from pydantic import BaseModel, ConfigDict, Field


class DocenteRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_docente: int
    codigo: str
    nombres: str
    apellidos: str
    correo: str
    telefono: str | None


class DocenteCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    codigo: str = Field(min_length=1, max_length=20)
    nombres: str = Field(min_length=1, max_length=100)
    apellidos: str = Field(min_length=1, max_length=100)
    correo: str = Field(min_length=1, max_length=150)
    telefono: str | None = Field(default=None, max_length=25)


class DocenteActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    codigo: str = Field(min_length=1, max_length=20)
    nombres: str = Field(min_length=1, max_length=100)
    apellidos: str = Field(min_length=1, max_length=100)
    correo: str = Field(min_length=1, max_length=150)
    telefono: str | None = Field(default=None, max_length=25)

