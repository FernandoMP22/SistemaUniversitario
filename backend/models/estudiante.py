from datetime import date

from sqlalchemy import Date, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Estudiante(Base):
    __tablename__ = "estudiante"
    __table_args__ = {"schema": "public"}

    id_estudiante: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_carrera: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.carrera.id_carrera", ondelete="RESTRICT"),
        nullable=False,
    )

    carne: Mapped[str] = mapped_column(
        String(25),
        nullable=False,
    )

    nombres: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    apellidos: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    fecha_nacimiento: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    correo: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    telefono: Mapped[str | None] = mapped_column(
        String(25),
        nullable=True,
    )

    direccion: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )

