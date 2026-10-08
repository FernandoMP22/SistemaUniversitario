import importlib
import os
import unittest
from datetime import date
from unittest.mock import Mock, patch
from uuid import uuid4

from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import event, text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session

from backend.database import transacciones
from backend.database.conexion import engine
from backend.main import app
from backend.schemas.estudiante import EstudianteActualizar, EstudianteCrear


MODULOS = [
    ("facultad", "facultades", "Facultad", {
        "codigo": "F-PRUEBA", "nombre": "Facultad de prueba",
    }),
    ("carrera", "carreras", "Carrera", {
        "id_facultad": 1, "codigo": "C-PRUEBA", "nombre": "Carrera de prueba",
    }),
    ("docente", "docentes", "Docente", {
        "codigo": "D-PRUEBA", "nombres": "Ana", "apellidos": "Perez",
        "correo": "ana@example.com",
    }),
    ("estudiante", "estudiantes", "Estudiante", {
        "id_carrera": 1, "carne": "E-PRUEBA", "nombres": "Luis",
        "apellidos": "Perez", "fecha_nacimiento": "2001-05-20",
        "correo": "luis@example.com",
    }),
]


def obtener_esquema(singular, nombre, sufijo):
    modulo = importlib.import_module(f"backend.schemas.{singular}")
    return getattr(modulo, nombre + sufijo)


def crear_error(codigo):
    original = Mock(sqlstate=codigo)
    return DBAPIError(None, None, original)


def tearDownModule():
    engine.dispose()


class ValidacionEsquemas(unittest.TestCase):
    def test_carrera_del_estudiante_no_es_editable(self):
        datos = MODULOS[3][3].copy()
        with self.assertRaises(ValidationError):
            EstudianteActualizar(**datos)

        del datos["id_carrera"]
        estudiante = EstudianteActualizar(**datos)
        self.assertNotIn("id_carrera", estudiante.model_dump())

    def test_identificadores_primarios_no_se_aceptan(self):
        for singular, _, nombre, datos in MODULOS:
            for sufijo in ("Crear", "Actualizar"):
                with self.subTest(modulo=singular, esquema=sufijo):
                    entrada = datos.copy()
                    if singular == "estudiante" and sufijo == "Actualizar":
                        del entrada["id_carrera"]
                    entrada[f"id_{singular}"] = 1
                    esquema = obtener_esquema(singular, nombre, sufijo)
                    with self.assertRaises(ValidationError):
                        esquema(**entrada)

    def test_longitudes_del_ddl(self):
        limites = {
            "facultad": {"codigo": 20, "nombre": 100},
            "carrera": {"codigo": 20, "nombre": 150},
            "docente": {"codigo": 20, "nombres": 100, "apellidos": 100,
                        "correo": 150, "telefono": 25},
            "estudiante": {"carne": 25, "nombres": 100, "apellidos": 100,
                           "correo": 150, "telefono": 25, "direccion": 255},
        }
        for singular, _, nombre, datos in MODULOS:
            for sufijo in ("Crear", "Actualizar"):
                esquema = obtener_esquema(singular, nombre, sufijo)
                entrada = datos.copy()
                if singular == "estudiante" and sufijo == "Actualizar":
                    del entrada["id_carrera"]
                for campo, limite in limites[singular].items():
                    with self.subTest(modulo=singular, esquema=sufijo, campo=campo):
                        esquema(**{**entrada, campo: "x" * limite})
                        with self.assertRaises(ValidationError):
                            esquema(**{**entrada, campo: "x" * (limite + 1)})

    def test_referencias_son_enteros_postgresql(self):
        for singular, nombre, campo, indice in (
            ("carrera", "Carrera", "id_facultad", 1),
            ("estudiante", "Estudiante", "id_carrera", 3),
        ):
            esquema = obtener_esquema(singular, nombre, "Crear")
            for valor in (0, -1, True, 1.5, "1", 2147483648, None):
                with self.subTest(campo=campo, valor=valor):
                    with self.assertRaises(ValidationError):
                        esquema(**{**MODULOS[indice][3], campo: valor})

    def test_fecha_y_campos_opcionales(self):
        datos = MODULOS[3][3]
        estudiante = EstudianteCrear(**datos)
        self.assertEqual(estudiante.fecha_nacimiento, date(2001, 5, 20))
        self.assertIsNone(estudiante.telefono)
        self.assertIsNone(estudiante.direccion)
        with self.assertRaises(ValidationError):
            EstudianteCrear(**{**datos, "fecha_nacimiento": "2001-02-30"})

    def test_openapi_registra_las_operaciones(self):
        documento = app.openapi()
        for singular, plural, _, _ in MODULOS:
            self.assertIn("post", documento["paths"][f"/{plural}"])
            ruta = documento["paths"][f"/{plural}/{{id_{singular}}}"]
            self.assertTrue({"get", "put", "delete"}.issubset(ruta))
        campos = documento["components"]["schemas"]["EstudianteActualizar"]["properties"]
        self.assertNotIn("id_carrera", campos)


class TransaccionesYErrores(unittest.TestCase):
    def test_error_durante_commit_se_traduce_en_todos_los_routers(self):
        for singular, plural, nombre, datos in MODULOS:
            router = importlib.import_module(f"backend.routers.{plural}")
            esquema = obtener_esquema(singular, nombre, "Crear")
            for codigo, estado in (
                ("23505", 409), ("23503", 409), ("23001", 409), ("23514", 400),
            ):
                with self.subTest(modulo=singular, codigo=codigo):
                    session = Mock()
                    session.commit.side_effect = crear_error(codigo)
                    with patch.object(transacciones, "SessionLocal", return_value=session):
                        with self.assertRaises(HTTPException) as resultado:
                            getattr(router, f"registrar_{singular}")(esquema(**datos))
                    self.assertEqual(resultado.exception.status_code, estado)
                    session.rollback.assert_called_once()
                    session.close.assert_called_once()

    def test_reintenta_toda_la_operacion_despues_de_40001(self):
        sesiones = [Mock(), Mock(), Mock()]
        sesiones[0].commit.side_effect = crear_error("40001")
        sesiones[1].commit.side_effect = crear_error("40001")
        operacion = Mock(return_value="resultado")
        with patch.object(transacciones, "SessionLocal", side_effect=sesiones):
            with patch.object(transacciones, "sleep"):
                resultado = transacciones.ejecutar_transaccion(operacion)
        self.assertEqual(resultado, "resultado")
        self.assertEqual(operacion.call_count, 3)
        for session in sesiones[:2]:
            session.rollback.assert_called_once()
        for session in sesiones:
            session.close.assert_called_once()

    def test_tres_conflictos_agotan_los_reintentos(self):
        sesiones = [Mock(), Mock(), Mock()]
        for session in sesiones:
            session.commit.side_effect = crear_error("40001")
        with patch.object(transacciones, "SessionLocal", side_effect=sesiones):
            with patch.object(transacciones, "sleep"):
                with self.assertRaises(DBAPIError):
                    transacciones.ejecutar_transaccion(Mock())
        for session in sesiones:
            session.rollback.assert_called_once()
            session.close.assert_called_once()


@unittest.skipUnless(os.getenv("PROBAR_POSTGRESQL") == "1", "Activar PROBAR_POSTGRESQL=1")
class IntegracionPostgreSQL(unittest.TestCase):
    """Usa la base instalada y descarta los datos mediante una transacción externa."""

    def setUp(self):
        self.conexion = engine.connect()
        self.transaccion = self.conexion.begin()
        self.addCleanup(self.conexion.close)
        self.addCleanup(self.transaccion.rollback)
        self.assertEqual(self.conexion.execute(text("SHOW transaction_isolation")).scalar_one(),
                         "serializable")
        self.parches = []
        self.addCleanup(self.cerrar_parches)
        for _, plural, _, _ in MODULOS:
            router = importlib.import_module(f"backend.routers.{plural}")
            parche = patch.object(router, "SessionLocal", side_effect=self.crear_sesion)
            parche.start()
            self.parches.append(parche)
        parche = patch.object(transacciones, "SessionLocal", side_effect=self.crear_sesion)
        parche.start()
        self.parches.append(parche)

    def cerrar_parches(self):
        for parche in reversed(self.parches):
            parche.stop()

    def crear_sesion(self):
        session = Session(bind=self.conexion, expire_on_commit=False,
                          join_transaction_mode="create_savepoint")
        # RELEASE SAVEPOINT no dispara los triggers diferidos del COMMIT real.
        # Forzamos esas comprobaciones antes de liberar cada savepoint.
        event.listen(session, "before_commit", self.validar_reglas_diferidas)
        return session

    @staticmethod
    def validar_reglas_diferidas(session):
        session.flush()
        session.execute(text("SET CONSTRAINTS ALL IMMEDIATE"))
        session.execute(text("SET CONSTRAINTS ALL DEFERRED"))

    def test_crud_duplicados_referencias_y_rollback(self):
        identificadores = {}
        token = uuid4().hex[:10]
        orden = (MODULOS[0], MODULOS[1], MODULOS[2], MODULOS[3])
        for singular, plural, nombre, datos in orden:
            router = importlib.import_module(f"backend.routers.{plural}")
            entrada = datos.copy()
            campo_unico = "carne" if singular == "estudiante" else "codigo"
            entrada[campo_unico] = token + singular[:3]
            if singular == "carrera":
                entrada["id_facultad"] = identificadores["facultad"]
            if singular == "estudiante":
                entrada["id_carrera"] = identificadores["carrera"]
            crear = obtener_esquema(singular, nombre, "Crear")
            registro = getattr(router, f"registrar_{singular}")(crear(**entrada))
            id_registro = getattr(registro, f"id_{singular}")
            identificadores[singular] = id_registro
            respuesta = obtener_esquema(singular, nombre, "Respuesta")
            respuesta.model_validate(registro)
            consultado = getattr(router, f"consultar_{singular}")(id_registro)
            self.assertEqual(getattr(consultado, campo_unico), entrada[campo_unico])
            self.assertTrue(getattr(router, f"listar_{plural}")())
            with self.assertRaises(HTTPException) as error:
                getattr(router, f"registrar_{singular}")(crear(**entrada))
            self.assertEqual(error.exception.status_code, 409)

            actualizar = obtener_esquema(singular, nombre, "Actualizar")
            cambios = entrada.copy()
            if singular == "estudiante":
                del cambios["id_carrera"]
            campo_nombre = "nombre" if singular in ("facultad", "carrera") else "nombres"
            cambios[campo_nombre] = "Nombre modificado"
            actualizado = getattr(router, f"modificar_{singular}")(
                id_registro, actualizar(**cambios))
            self.assertEqual(getattr(actualizado, campo_nombre), "Nombre modificado")

            segundo = getattr(router, f"registrar_{singular}")(
                crear(**{**entrada, campo_unico: token + "otro" + singular[:2]}))
            id_segundo = getattr(segundo, f"id_{singular}")
            cambios[campo_nombre] = "Este cambio debe deshacerse"
            with self.assertRaises(HTTPException) as error:
                getattr(router, f"modificar_{singular}")(
                    id_segundo, actualizar(**cambios))
            self.assertEqual(error.exception.status_code, 409)
            despues = getattr(router, f"consultar_{singular}")(id_segundo)
            self.assertEqual(getattr(despues, campo_nombre), entrada[campo_nombre])
            getattr(router, f"borrar_{singular}")(id_segundo)

            # Una referencia positiva fuera de la tabla debe llegar a la FK.
            if singular in ("carrera", "estudiante"):
                campo_fk = "id_facultad" if singular == "carrera" else "id_carrera"
                with self.assertRaises(HTTPException) as error:
                    getattr(router, f"registrar_{singular}")(
                        crear(**{**entrada, campo_unico: token + "fk" + singular[:2],
                                 campo_fk: 2147483647}))
                self.assertEqual(error.exception.status_code, 409)

            for funcion, argumentos in (
                (f"consultar_{singular}", (-1,)),
                (f"modificar_{singular}", (-1, actualizar(**cambios))),
                (f"borrar_{singular}", (-1,)),
            ):
                with self.assertRaises(HTTPException) as error:
                    getattr(router, funcion)(*argumentos)
                self.assertEqual(error.exception.status_code, 404)

        facultades = importlib.import_module("backend.routers.facultades")
        carreras = importlib.import_module("backend.routers.carreras")
        for router, singular in ((facultades, "facultad"), (carreras, "carrera")):
            with self.assertRaises(HTTPException) as error:
                getattr(router, f"borrar_{singular}")(identificadores[singular])
            self.assertEqual(error.exception.status_code, 409)
            self.assertIsNotNone(getattr(router, f"consultar_{singular}")(
                identificadores[singular]))

        for singular in ("estudiante", "docente", "carrera", "facultad"):
            plural = next(m[1] for m in MODULOS if m[0] == singular)
            router = importlib.import_module(f"backend.routers.{plural}")
            getattr(router, f"borrar_{singular}")(identificadores[singular])
            with self.assertRaises(HTTPException) as error:
                getattr(router, f"consultar_{singular}")(identificadores[singular])
            self.assertEqual(error.exception.status_code, 404)

    def test_el_historial_existente_impide_eliminar_personas(self):
        consultas = {
            "docente": "SELECT id_docente FROM public.seccion LIMIT 1",
            "estudiante": "SELECT id_estudiante FROM public.inscripcion LIMIT 1",
        }
        for singular, consulta in consultas.items():
            id_registro = self.conexion.execute(text(consulta)).scalar()
            if id_registro is None:
                self.skipTest("Faltan secciones o inscripciones para comprobar el historial")
            router = importlib.import_module(f"backend.routers.{singular}s")
            with self.assertRaises(HTTPException) as error:
                getattr(router, f"borrar_{singular}")(id_registro)
            self.assertEqual(error.exception.status_code, 409)
            self.assertIsNotNone(getattr(router, f"consultar_{singular}")(id_registro))


    def test_postgresql_impide_cambiar_la_carrera_del_estudiante(self):
        fila = self.conexion.execute(text("""
            SELECT e.id_estudiante, c.id_carrera
            FROM public.estudiante e
            JOIN public.carrera c ON c.id_carrera <> e.id_carrera
            LIMIT 1
        """)).first()
        if fila is None:
            self.skipTest("Se necesitan un estudiante y una segunda carrera")
        with self.assertRaises(DBAPIError) as resultado:
            with self.conexion.begin_nested():
                self.conexion.execute(text("""
                    UPDATE public.estudiante SET id_carrera = :carrera
                    WHERE id_estudiante = :estudiante
                """), {"carrera": fila.id_carrera, "estudiante": fila.id_estudiante})
        self.assertEqual(resultado.exception.orig.sqlstate, "23514")
        self.assertEqual(resultado.exception.orig.diag.constraint_name,
                         "regla_estudiante_carrera")


if __name__ == "__main__":
    unittest.main()
