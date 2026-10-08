from pydantic import BaseModel, ConfigDict, Field


class PrerrequisitoRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_prerrequisito: int
    id_curso: int
    id_curso_requisito: int


class PrerrequisitoCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_curso: int = Field(gt=0, le=2147483647, strict=True)
    id_curso_requisito: int = Field(gt=0, le=2147483647, strict=True)


class PrerrequisitoActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_curso: int = Field(gt=0, le=2147483647, strict=True)
    id_curso_requisito: int = Field(gt=0, le=2147483647, strict=True)
