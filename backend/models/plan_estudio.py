from sqlalchemy import ForeignKey, Integer, SmallInteger, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class PlanEstudio(Base):
    __tablename__ = "plan_estudio"
    __table_args__ = (
        UniqueConstraint("id_carrera", "id_curso"),
        {"schema": "public"},
    )

    id_plan_estudio: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_carrera: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.carrera.id_carrera", ondelete="RESTRICT"),
        nullable=False,
    )

    id_curso: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.curso.id_curso", ondelete="RESTRICT"),
        nullable=False,
    )

    semestre_sugerido: Mapped[int] = mapped_column(
        SmallInteger,
        nullable=False,
    )
