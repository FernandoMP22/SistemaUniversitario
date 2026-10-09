from datetime import date

from sqlalchemy import Date, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class PeriodoAcademico(Base):
    __tablename__ = "periodo_academico"
    __table_args__ = {"schema": "public"}

    id_periodo_academico: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    codigo: Mapped[str] = mapped_column(
        String(20),
        unique=True,
        nullable=False,
    )

    nombre: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    fecha_inicio: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    fecha_fin: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

