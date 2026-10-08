from time import sleep

from sqlalchemy.exc import DBAPIError

from backend.database.conexion import SessionLocal


def ejecutar_transaccion(operacion):
    for intento in range(1, 4):
        session = SessionLocal()

        try:
            resultado = operacion(session)

            session.commit()

            return resultado

        except DBAPIError as error:
            session.rollback()

            if error.orig.sqlstate != "40001":
                raise

            if intento == 3:
                raise

        except Exception:
            session.rollback()
            raise

        finally:
            session.close()

        sleep(0.1 * intento)