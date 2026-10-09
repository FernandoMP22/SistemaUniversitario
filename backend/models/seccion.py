from sqlalchemy import Boolean, ForeignKey, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Seccion(Base):
    __tablename__ = "seccion"
    __table_args__ = (
        UniqueConstraint("id_curso", "id_periodo_academico", "codigo"),
        {"schema": "public"},
    )

    id_seccion: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_curso: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.curso.id_curso", ondelete="RESTRICT"),
        nullable=False,
    )

    id_periodo_academico: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.periodo_academico.id_periodo_academico", ondelete="RESTRICT"),
        nullable=False,
    )

    id_docente: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.docente.id_docente", ondelete="RESTRICT"),
        nullable=False,
    )

    codigo: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    cupo_maximo: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    calificaciones_cerradas: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=text("false"),
    )

