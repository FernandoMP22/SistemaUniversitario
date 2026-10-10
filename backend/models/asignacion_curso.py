from datetime import date

from sqlalchemy import Date, ForeignKey, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class AsignacionCurso(Base):
    __tablename__ = "asignacion_curso"
    __table_args__ = (
        UniqueConstraint("id_inscripcion", "id_seccion"),
        {"schema": "public"},
    )

    id_asignacion_curso: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_inscripcion: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.inscripcion.id_inscripcion", ondelete="RESTRICT"),
        nullable=False,
    )

    id_seccion: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.seccion.id_seccion", ondelete="RESTRICT"),
        nullable=False,
    )

    fecha_asignacion: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        server_default=text("CURRENT_DATE"),
    )

    estado: Mapped[str] = mapped_column(
        String(15),
        nullable=False,
        server_default=text("'cursando'"),
    )
