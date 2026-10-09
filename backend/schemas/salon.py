from pydantic import BaseModel, ConfigDict, Field


class SalonRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_salon: int
    id_sede: int
    codigo: str
    capacidad: int


class SalonCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_sede: int = Field(gt=0, le=2147483647, strict=True)
    codigo: str = Field(min_length=1, max_length=20)
    capacidad: int = Field(gt=0, le=2147483647, strict=True)


class SalonActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_sede: int = Field(gt=0, le=2147483647, strict=True)
    codigo: str = Field(min_length=1, max_length=20)
    capacidad: int = Field(gt=0, le=2147483647, strict=True)

