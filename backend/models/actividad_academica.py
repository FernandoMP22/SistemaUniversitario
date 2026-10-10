from datetime import date
from decimal import Decimal

from sqlalchemy import Date, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class ActividadAcademica(Base):
    __tablename__ = "actividad_academica"
    __table_args__ = {"schema": "public"}

    id_actividad_academica: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_seccion: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.seccion.id_seccion", ondelete="RESTRICT"),
        nullable=False,
    )

    nombre: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    tipo: Mapped[str] = mapped_column(
        String(15),
        nullable=False,
    )

    fecha: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    puntaje_maximo: Mapped[Decimal] = mapped_column(
        Numeric(5, 2),
        nullable=False,
    )
