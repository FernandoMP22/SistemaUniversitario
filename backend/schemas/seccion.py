from pydantic import BaseModel, ConfigDict, Field


class SeccionRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_seccion: int
    id_curso: int
    id_periodo_academico: int
    id_docente: int
    codigo: str
    cupo_maximo: int
    calificaciones_cerradas: bool = Field(json_schema_extra={"readOnly": True})


class SeccionCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_curso: int = Field(gt=0, le=2147483647, strict=True)
    id_periodo_academico: int = Field(gt=0, le=2147483647, strict=True)
    id_docente: int = Field(gt=0, le=2147483647, strict=True)
    codigo: str = Field(min_length=1, max_length=20)
    cupo_maximo: int = Field(gt=0, le=2147483647, strict=True)


class SeccionCerrar(BaseModel):
    # El cierre solo utiliza el identificador de la ruta, sin campos editables.
    model_config = ConfigDict(extra="forbid")


class SeccionActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_curso: int = Field(gt=0, le=2147483647, strict=True)
    id_periodo_academico: int = Field(gt=0, le=2147483647, strict=True)
    id_docente: int = Field(gt=0, le=2147483647, strict=True)
    codigo: str = Field(min_length=1, max_length=20)
    cupo_maximo: int = Field(gt=0, le=2147483647, strict=True)
