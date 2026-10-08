from pydantic import BaseModel, ConfigDict, Field


class SedeRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_sede: int
    codigo: str
    nombre: str
    direccion: str

class SedeCrear(BaseModel):
    codigo: str = Field(min_length=1, max_length=20)
    nombre: str = Field(min_length=1, max_length=100)
    direccion: str = Field(min_length=1, max_length=255)

class SedeActualizar(BaseModel):
    codigo: str = Field(min_length=1, max_length=20)
    nombre: str = Field(min_length=1, max_length=100)
    direccion: str = Field(min_length=1, max_length=255)