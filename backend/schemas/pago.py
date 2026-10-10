from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class PagoRespuesta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_pago: int
    id_inscripcion: int
    numero_comprobante: str
    concepto: Literal["matricula", "mensualidad"]
    monto: Decimal
    fecha_pago: date
    anio_mensualidad: int | None
    mes_mensualidad: int | None
    estado: Literal["registrado", "anulado"]


class PagoCrear(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id_inscripcion: int = Field(gt=0, le=2147483647, strict=True)
    numero_comprobante: str = Field(min_length=1, max_length=50)
    concepto: Literal["matricula", "mensualidad"]
    monto: Decimal = Field(gt=0, max_digits=10, decimal_places=2, allow_inf_nan=False)
    fecha_pago: date | None = None
    anio_mensualidad: int | None = Field(default=None, gt=0, le=32767, strict=True)
    mes_mensualidad: int | None = Field(default=None, ge=1, le=12, strict=True)

    @model_validator(mode="after")
    def validar_mes_del_concepto(self):
        if self.concepto == "matricula":
            if self.anio_mensualidad is not None or self.mes_mensualidad is not None:
                raise ValueError("La matricula no recibe anio ni mes de mensualidad.")
        elif self.anio_mensualidad is None or self.mes_mensualidad is None:
            raise ValueError("La mensualidad requiere anio y mes.")
        return self


class PagoActualizar(BaseModel):
    model_config = ConfigDict(extra="forbid")

    # Las referencias y la fecha original se conservan.
    estado: Literal["anulado"]
