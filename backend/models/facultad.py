from sqlalchemy import Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Facultad(Base):
    __tablename__ = "facultad"
    __table_args__ = {"schema": "public"}

    id_facultad: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    codigo: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    nombre: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    descripcion: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

