from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Carrera(Base):
    __tablename__ = "carrera"
    __table_args__ = {"schema": "public"}

    id_carrera: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_facultad: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.facultad.id_facultad", ondelete="RESTRICT"),
        nullable=False,
    )

    codigo: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    nombre: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    descripcion: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

