"""Ejecuta los bloques automáticos disponibles; excluye la concurrencia manual."""

import re
from pathlib import Path

from backend.database.conexion import engine


RAIZ = Path(__file__).resolve().parents[2]


def consumir_resultados(cursor):
    resultados = []
    while True:
        if cursor.description is not None:
            columnas = [columna.name for columna in cursor.description]
            filas = cursor.fetchall()
            resultados.append((columnas, filas))
        if not cursor.nextset():
            break
    return resultados


def verificar_sql():
    conexion_pool = engine.raw_connection()
    conexion = conexion_pool.driver_connection
    conexion.autocommit = True
    avisos = []
    conexion.add_notice_handler(lambda aviso: avisos.append(aviso.message_primary))
    fallos = 0
    try:
        # El primer script usa BEGIN sin declarar el aislamiento.
        conexion.execute("SET default_transaction_isolation = 'serializable'")
        conexion.execute("SET statement_timeout = '30s'")
        for nombre in ("01_validacion_base_datos.sql", "02_validacion_reglas_negocio.sql"):
            contenido = (RAIZ / "database" / "tests" / nombre).read_text(encoding="utf-8")
            contenido = contenido.split("-- CONCURRENCIA C1:")[0]
            bloques = re.findall(
                r"^BEGIN(?: ISOLATION LEVEL SERIALIZABLE)?;.*?^ROLLBACK;",
                contenido, flags=re.MULTILINE | re.DOTALL,
            )
            for numero, bloque in enumerate(bloques, 1):
                assert not re.search(r"^COMMIT;", bloque, flags=re.MULTILINE)
                inicio_avisos = len(avisos)
                try:
                    with conexion.cursor() as cursor:
                        cursor.execute(bloque)
                        consumir_resultados(cursor)
                    comprobaciones = len(avisos) - inicio_avisos
                    print(f"OK {nombre}, bloque {numero}: {comprobaciones} avisos")
                except Exception as error:
                    fallos += 1
                    codigo = getattr(error, "sqlstate", None)
                    print(f"FALLO {nombre}, bloque {numero}: SQLSTATE {codigo}")
                    # Los mensajes PostgreSQL de estas pruebas no contienen configuración.
                    print(getattr(getattr(error, "diag", None), "message_primary", "Error SQL"))
                finally:
                    conexion.execute("ROLLBACK")

        contenido = (RAIZ / "database/tests/04_verificacion_poblado.sql").read_text(
            encoding="utf-8")
        with conexion.cursor() as cursor:
            cursor.execute(contenido)
            resultados = consumir_resultados(cursor)
        for columnas, filas in resultados:
            if "coincide" in columnas:
                indice = columnas.index("coincide")
                diferencias = sum(fila[indice] is not True for fila in filas)
                print(f"04_verificacion_poblado.sql: {len(filas)} conteos, {diferencias} diferencias")
                for fila in filas:
                    if fila[indice] is not True:
                        print(f"  {fila[0]}: esperado={fila[1]}, actual={fila[2]}")
                fallos += diferencias
            if "id_asignacion_curso" in columnas and "nota" in columnas:
                print(f"Resultados cerrados incoherentes: {len(filas)}")
                fallos += bool(filas)
        print("Pendientes: C1, C2 y 03_concurrencia_prerrequisitos.sql (sesiones independientes).")
    finally:
        conexion.execute("ROLLBACK")
        conexion.execute("RESET default_transaction_isolation")
        conexion.execute("RESET statement_timeout")
        conexion_pool.close()
        engine.dispose()
    return fallos


if __name__ == "__main__":
    raise SystemExit(bool(verificar_sql()))
