from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Salon(Base):
    __tablename__ = "salon"
    __table_args__ = (
        UniqueConstraint("id_sede", "codigo"),
        {"schema": "public"},
    )

    id_salon: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_sede: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.sede.id_sede", ondelete="RESTRICT"),
        nullable=False,
    )

    codigo: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    capacidad: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

