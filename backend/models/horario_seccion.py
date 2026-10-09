from datetime import time

from sqlalchemy import ForeignKey, Integer, SmallInteger, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class HorarioSeccion(Base):
    __tablename__ = "horario_seccion"
    __table_args__ = (
        UniqueConstraint("id_seccion", "dia_semana", "hora_inicio", "hora_fin"),
        {"schema": "public"},
    )

    id_horario_seccion: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_seccion: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.seccion.id_seccion", ondelete="RESTRICT"),
        nullable=False,
    )

    id_salon: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.salon.id_salon", ondelete="RESTRICT"),
        nullable=False,
    )

    dia_semana: Mapped[int] = mapped_column(
        SmallInteger,
        nullable=False,
    )

    hora_inicio: Mapped[time] = mapped_column(
        Time,
        nullable=False,
    )

    hora_fin: Mapped[time] = mapped_column(
        Time,
        nullable=False,
    )

