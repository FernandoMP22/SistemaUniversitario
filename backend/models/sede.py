from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Sede(Base):
    __tablename__ = "sede"
    __table_args__ = {"schema": "public"}

    id_sede: Mapped[int] = mapped_column(
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

    direccion: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )