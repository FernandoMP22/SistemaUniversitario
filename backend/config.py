import os
from pathlib import Path

from dotenv import load_dotenv


RAIZ_PROYECTO = Path(__file__).resolve().parent.parent

load_dotenv(RAIZ_PROYECTO / ".env")


def obtener_variable(nombre: str) -> str:
    valor = os.getenv(nombre)

    if valor is None or not valor.strip():
        raise RuntimeError(
            f"Falta configurar la variable {nombre} en el archivo .env."
        )

    return valor


DB_HOST = obtener_variable("DB_HOST")
DB_NAME = obtener_variable("DB_NAME")
DB_USER = obtener_variable("DB_USER")
DB_PASSWORD = obtener_variable("DB_PASSWORD")

try:
    DB_PORT = int(obtener_variable("DB_PORT"))
except ValueError as error:
    raise RuntimeError("DB_PORT debe ser un número entero.") from error

if not 1 <= DB_PORT <= 65535:
    raise RuntimeError("DB_PORT debe estar entre 1 y 65535.")