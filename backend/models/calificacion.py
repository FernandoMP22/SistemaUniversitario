from decimal import Decimal

from sqlalchemy import ForeignKey, Integer, Numeric, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Calificacion(Base):
    __tablename__ = "calificacion"
    __table_args__ = (
        UniqueConstraint("id_actividad_academica", "id_asignacion_curso"),
        {"schema": "public"},
    )

    id_calificacion: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_actividad_academica: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.actividad_academica.id_actividad_academica", ondelete="RESTRICT"),
        nullable=False,
    )

    id_asignacion_curso: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.asignacion_curso.id_asignacion_curso", ondelete="RESTRICT"),
        nullable=False,
    )

    puntaje_obtenido: Mapped[Decimal] = mapped_column(
        Numeric(5, 2),
        nullable=False,
    )
