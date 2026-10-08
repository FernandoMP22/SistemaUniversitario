from pydantic import BaseModel, ConfigDict, Field


class PlanEstudioRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_plan_estudio: int
    id_carrera: int
    id_curso: int
    semestre_sugerido: int


class PlanEstudioCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_carrera: int = Field(gt=0, le=2147483647, strict=True)
    id_curso: int = Field(gt=0, le=2147483647, strict=True)
    semestre_sugerido: int = Field(gt=0, le=32767, strict=True)


class PlanEstudioActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_carrera: int = Field(gt=0, le=2147483647, strict=True)
    id_curso: int = Field(gt=0, le=2147483647, strict=True)
    semestre_sugerido: int = Field(gt=0, le=32767, strict=True)
