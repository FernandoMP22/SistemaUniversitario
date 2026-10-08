from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Docente(Base):
    __tablename__ = "docente"
    __table_args__ = {"schema": "public"}

    id_docente: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    codigo: Mapped[str] = mapped_column(
        String(20),
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

    correo: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    telefono: Mapped[str | None] = mapped_column(
        String(25),
        nullable=True,
    )

