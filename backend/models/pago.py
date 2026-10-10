from datetime import date
from decimal import Decimal

from sqlalchemy import Date, ForeignKey, Integer, Numeric, SmallInteger, String, text
from sqlalchemy.orm import Mapped, mapped_column

from backend.models.base import Base


class Pago(Base):
    __tablename__ = "pago"
    __table_args__ = {"schema": "public"}

    id_pago: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    id_inscripcion: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("public.inscripcion.id_inscripcion", ondelete="RESTRICT"),
        nullable=False,
    )

    numero_comprobante: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        nullable=False,
    )

    concepto: Mapped[str] = mapped_column(
        String(15),
        nullable=False,
    )

    monto: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
    )

    fecha_pago: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        server_default=text("CURRENT_DATE"),
    )

    anio_mensualidad: Mapped[int | None] = mapped_column(
        SmallInteger,
        nullable=True,
    )

    mes_mensualidad: Mapped[int | None] = mapped_column(
        SmallInteger,
        nullable=True,
    )

    estado: Mapped[str] = mapped_column(
        String(15),
        nullable=False,
        server_default=text("'registrado'"),
    )
