from datetime import date

from sqlalchemy import Date, ForeignKey, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Inscripcion(Base):
    __tablename__ = "inscripcion"
    __table_args__ = (
        UniqueConstraint("id_estudiante", "id_periodo_academico"),
        {"schema": "public"},
    )

    id_inscripcion: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_estudiante: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.estudiante.id_estudiante", ondelete="RESTRICT"),
        nullable=False,
    )

    id_periodo_academico: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.periodo_academico.id_periodo_academico", ondelete="RESTRICT"),
        nullable=False,
    )

    fecha_inscripcion: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        server_default=text("CURRENT_DATE"),
    )

    estado: Mapped[str] = mapped_column(
        String(15),
        nullable=False,
        server_default=text("'activa'"),
    )
