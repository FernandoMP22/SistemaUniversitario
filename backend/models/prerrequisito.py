from sqlalchemy import ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Prerrequisito(Base):
    __tablename__ = "prerrequisito"
    __table_args__ = (
        UniqueConstraint("id_curso", "id_curso_requisito"),
        {"schema": "public"},
    )

    id_prerrequisito: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_curso: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.curso.id_curso", ondelete="RESTRICT"),
        nullable=False,
    )

    id_curso_requisito: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.curso.id_curso", ondelete="RESTRICT"),
        nullable=False,
    )
