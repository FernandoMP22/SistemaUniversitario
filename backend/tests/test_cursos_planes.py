import os
import unittest
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
from backend.routers import cursos, planes_estudio, prerrequisitos
from backend.schemas.curso import CursoActualizar, CursoCrear, CursoRespuesta
from backend.schemas.plan_estudio import (
    PlanEstudioActualizar, PlanEstudioCrear, PlanEstudioRespuesta,
)
from backend.schemas.prerrequisito import (
    PrerrequisitoActualizar, PrerrequisitoCrear, PrerrequisitoRespuesta,
)


def tearDownModule():
    engine.dispose()


class EsquemasCursosPlanes(unittest.TestCase):
    def test_longitudes_del_curso_y_descripcion_opcional(self):
        for esquema in (CursoCrear, CursoActualizar):
            curso = esquema(codigo="C" * 20, nombre="N" * 150)
            self.assertIsNone(curso.descripcion)
            esquema(codigo="C", nombre="N", descripcion="D" * 1000)
            for datos in (
                {"codigo": "C" * 21, "nombre": "N"},
                {"codigo": "C", "nombre": "N" * 151},
                {"codigo": "", "nombre": "N"},
                {"codigo": "C", "nombre": None},
            ):
                with self.subTest(esquema=esquema.__name__, datos=datos):
                    with self.assertRaises(ValidationError):
                        esquema(**datos)

    def test_semestre_respeta_smallint_positivo(self):
        for esquema in (PlanEstudioCrear, PlanEstudioActualizar):
            for valor in (1, 32767):
                esquema(id_carrera=1, id_curso=2, semestre_sugerido=valor)
            for valor in (0, -1, 32768, True, 1.5, "1", None):
                with self.subTest(esquema=esquema.__name__, valor=valor):
                    with self.assertRaises(ValidationError):
                        esquema(id_carrera=1, id_curso=2, semestre_sugerido=valor)

    def test_referencias_son_enteros_y_no_se_aceptan_campos_adicionales(self):
        entradas = (
            (CursoCrear, {"codigo": "C", "nombre": "N"}, []),
            (CursoActualizar, {"codigo": "C", "nombre": "N"}, []),
            (PlanEstudioCrear, {"id_carrera": 1, "id_curso": 2,
                               "semestre_sugerido": 1}, ["id_carrera", "id_curso"]),
            (PlanEstudioActualizar, {"id_carrera": 1, "id_curso": 2,
                                    "semestre_sugerido": 1}, ["id_carrera", "id_curso"]),
            (PrerrequisitoCrear, {"id_curso": 1, "id_curso_requisito": 2},
             ["id_curso", "id_curso_requisito"]),
            (PrerrequisitoActualizar, {"id_curso": 1, "id_curso_requisito": 2},
             ["id_curso", "id_curso_requisito"]),
        )
        for esquema, datos, campos in entradas:
            with self.subTest(esquema=esquema.__name__):
                with self.assertRaises(ValidationError):
                    esquema(**datos, identificador=1)
            for campo in campos:
                for valor in (0, -1, 2147483648, True, "1", 1.5, None):
                    with self.subTest(esquema=esquema.__name__, campo=campo, valor=valor):
                        with self.assertRaises(ValidationError):
                            esquema(**{**datos, campo: valor})

    def test_identificadores_primarios_no_son_editables(self):
        for esquema, datos, campo in (
            (CursoActualizar, {"codigo": "C", "nombre": "N"}, "id_curso"),
            (PlanEstudioActualizar, {"id_carrera": 1, "id_curso": 2,
                                    "semestre_sugerido": 1}, "id_plan_estudio"),
            (PrerrequisitoActualizar, {"id_curso": 1, "id_curso_requisito": 2},
             "id_prerrequisito"),
        ):
            with self.assertRaises(ValidationError):
                esquema(**{**datos, campo: 3})

    def test_openapi_incluye_los_tres_modulos(self):
        rutas = app.openapi()["paths"]
        for ruta, identificador in (
            ("cursos", "id_curso"), ("planes-estudio", "id_plan_estudio"),
            ("prerrequisitos", "id_prerrequisito"),
        ):
            self.assertTrue({"get", "post"}.issubset(rutas[f"/{ruta}"]))
            self.assertTrue({"get", "put", "delete"}.issubset(
                rutas[f"/{ruta}/{{{identificador}}}"]))


class ErroresSimuladosCursosPlanes(unittest.TestCase):
    def test_errores_en_commit_hacen_rollback_en_todas_las_escrituras(self):
        operaciones = (
            (cursos.registrar_curso, (CursoCrear(codigo="C", nombre="N"),)),
            (cursos.modificar_curso, (1, CursoActualizar(codigo="C", nombre="N"))),
            (cursos.borrar_curso, (1,)),
            (planes_estudio.registrar_plan_estudio, (PlanEstudioCrear(
                id_carrera=1, id_curso=2, semestre_sugerido=1),)),
            (planes_estudio.modificar_plan_estudio, (1, PlanEstudioActualizar(
                id_carrera=1, id_curso=2, semestre_sugerido=1))),
            (planes_estudio.borrar_plan_estudio, (1,)),
            (prerrequisitos.registrar_prerrequisito, (PrerrequisitoCrear(
                id_curso=1, id_curso_requisito=2),)),
            (prerrequisitos.modificar_prerrequisito, (1, PrerrequisitoActualizar(
                id_curso=1, id_curso_requisito=2))),
            (prerrequisitos.borrar_prerrequisito, (1,)),
        )
        for operacion, argumentos in operaciones:
            for codigo, estado in (("23505", 409), ("23503", 409), ("23514", 400)):
                with self.subTest(operacion=operacion.__name__, codigo=codigo):
                    session = Mock()
                    session.commit.side_effect = DBAPIError(None, None, Mock(sqlstate=codigo))
                    with patch.object(transacciones, "SessionLocal", return_value=session):
                        with self.assertRaises(HTTPException) as resultado:
                            operacion(*argumentos)
                    self.assertEqual(resultado.exception.status_code, estado)
                    session.rollback.assert_called_once()
                    session.close.assert_called_once()

    def test_curso_agota_tres_reintentos_40001_y_devuelve_503(self):
        sesiones = [Mock(), Mock(), Mock()]
        for session in sesiones:
            session.commit.side_effect = DBAPIError(None, None, Mock(sqlstate="40001"))
        with patch.object(transacciones, "SessionLocal", side_effect=sesiones):
            with patch.object(transacciones, "sleep"):
                with self.assertRaises(HTTPException) as resultado:
                    cursos.registrar_curso(CursoCrear(codigo="C", nombre="N"))
        self.assertEqual(resultado.exception.status_code, 503)
        for session in sesiones:
            session.add.assert_called_once()
            session.rollback.assert_called_once()
            session.close.assert_called_once()


@unittest.skipUnless(os.getenv("PROBAR_POSTGRESQL") == "1", "Activar PROBAR_POSTGRESQL=1")
class CursosPlanesPostgreSQL(unittest.TestCase):
    """Datos temporales, savepoints por operacion y rollback externo al terminar."""

    def setUp(self):
        self.conexion = engine.connect()
        self.transaccion = self.conexion.begin()
        self.addCleanup(self.conexion.close)
        self.addCleanup(self.transaccion.rollback)
        aislamiento = self.conexion.execute(text("SHOW transaction_isolation")).scalar_one()
        self.assertEqual(aislamiento, "serializable")
        self.parches = []
        self.addCleanup(self.cerrar_parches)
        for modulo in (cursos, planes_estudio, prerrequisitos, transacciones):
            parche = patch.object(modulo, "SessionLocal", side_effect=self.crear_sesion)
            parche.start()
            self.parches.append(parche)
        self.token = uuid4().hex[:10]
        facultad = self.conexion.execute(text("""
            INSERT INTO public.facultad (codigo, nombre)
            VALUES (:codigo, 'Facultad temporal') RETURNING id_facultad
        """), {"codigo": self.token + "F"}).scalar_one()
        self.carreras = []
        for numero in (1, 2):
            carrera = self.conexion.execute(text("""
                INSERT INTO public.carrera (id_facultad, codigo, nombre)
                VALUES (:facultad, :codigo, 'Carrera temporal') RETURNING id_carrera
            """), {"facultad": facultad, "codigo": self.token + str(numero)}).scalar_one()
            self.carreras.append(carrera)
        self.cursos = []
        for letra in ("A", "B", "C"):
            curso = cursos.registrar_curso(CursoCrear(
                codigo=self.token + letra, nombre="Curso temporal " + letra))
            self.cursos.append(curso.id_curso)

    def cerrar_parches(self):
        for parche in reversed(self.parches):
            parche.stop()

    def crear_sesion(self):
        session = Session(bind=self.conexion, expire_on_commit=False,
                          join_transaction_mode="create_savepoint")
        event.listen(session, "before_commit", self.comprobar_reglas_diferidas)
        return session

    @staticmethod
    def comprobar_reglas_diferidas(session):
        # RELEASE SAVEPOINT no comprueba los triggers diferidos del COMMIT real.
        session.flush()
        session.execute(text("SET CONSTRAINTS ALL IMMEDIATE"))
        session.execute(text("SET CONSTRAINTS ALL DEFERRED"))

    def agregar_plan(self, carrera, curso, semestre=1):
        return planes_estudio.registrar_plan_estudio(PlanEstudioCrear(
            id_carrera=carrera, id_curso=curso, semestre_sugerido=semestre))

    def agregar_prerrequisito(self, curso, requisito):
        return prerrequisitos.registrar_prerrequisito(PrerrequisitoCrear(
            id_curso=curso, id_curso_requisito=requisito))

    def comprobar_rechazo(self, estado, operacion, *argumentos, regla=None):
        with self.assertRaises(HTTPException) as resultado:
            operacion(*argumentos)
        self.assertEqual(resultado.exception.status_code, estado)
        if regla is not None:
            original = resultado.exception.__cause__.orig
            self.assertEqual(original.diag.constraint_name, regla)

    def test_cursos_crud_duplicados_y_rollback(self):
        primero, segundo, _ = self.cursos
        self.assertTrue(cursos.listar_cursos())
        original = cursos.consultar_curso(primero)
        CursoRespuesta.model_validate(original)
        self.comprobar_rechazo(409, cursos.registrar_curso,
                              CursoCrear(codigo=original.codigo, nombre="Duplicado"))
        otro = cursos.consultar_curso(segundo)
        self.comprobar_rechazo(409, cursos.modificar_curso, segundo,
                              CursoActualizar(codigo=original.codigo, nombre="No guardar"))
        self.assertEqual(cursos.consultar_curso(segundo).nombre, otro.nombre)
        actualizado = cursos.modificar_curso(primero, CursoActualizar(
            codigo=original.codigo, nombre="Nombre nuevo", descripcion="Descripcion nueva"))
        self.assertEqual(actualizado.descripcion, "Descripcion nueva")
        cursos.borrar_curso(primero)
        self.comprobar_rechazo(404, cursos.consultar_curso, primero)

    def test_planes_crud_y_unicidad_compuesta(self):
        carrera, otra_carrera = self.carreras
        curso, otro_curso, _ = self.cursos
        plan = self.agregar_plan(carrera, curso)
        PlanEstudioRespuesta.model_validate(plan)
        self.assertTrue(planes_estudio.listar_planes_estudio())
        self.comprobar_rechazo(409, self.agregar_plan, carrera, curso)
        otro = self.agregar_plan(carrera, otro_curso)
        self.comprobar_rechazo(409, planes_estudio.modificar_plan_estudio,
                              otro.id_plan_estudio, PlanEstudioActualizar(
                                  id_carrera=carrera, id_curso=curso, semestre_sugerido=2))
        self.assertEqual(planes_estudio.consultar_plan_estudio(
            otro.id_plan_estudio).id_curso, otro_curso)
        cambiado = planes_estudio.modificar_plan_estudio(plan.id_plan_estudio,
            PlanEstudioActualizar(id_carrera=otra_carrera, id_curso=otro_curso,
                                  semestre_sugerido=32767))
        self.assertEqual(cambiado.id_carrera, otra_carrera)
        self.assertEqual(cambiado.semestre_sugerido, 32767)
        planes_estudio.borrar_plan_estudio(plan.id_plan_estudio)
        self.comprobar_rechazo(404, planes_estudio.consultar_plan_estudio,
                              plan.id_plan_estudio)

    def test_prerrequisitos_crud_y_unicidad_compuesta(self):
        curso, requisito, otro_requisito = self.cursos
        registro = self.agregar_prerrequisito(curso, requisito)
        PrerrequisitoRespuesta.model_validate(registro)
        self.assertTrue(prerrequisitos.listar_prerrequisitos())
        self.comprobar_rechazo(409, self.agregar_prerrequisito, curso, requisito)
        otro = self.agregar_prerrequisito(curso, otro_requisito)
        self.comprobar_rechazo(409, prerrequisitos.modificar_prerrequisito,
                              otro.id_prerrequisito, PrerrequisitoActualizar(
                                  id_curso=curso, id_curso_requisito=requisito))
        self.assertEqual(prerrequisitos.consultar_prerrequisito(
            otro.id_prerrequisito).id_curso_requisito, otro_requisito)
        prerrequisitos.borrar_prerrequisito(otro.id_prerrequisito)
        cambiado = prerrequisitos.modificar_prerrequisito(registro.id_prerrequisito,
            PrerrequisitoActualizar(id_curso=curso, id_curso_requisito=otro_requisito))
        self.assertEqual(cambiado.id_curso_requisito, otro_requisito)
        cambiado = prerrequisitos.modificar_prerrequisito(registro.id_prerrequisito,
            PrerrequisitoActualizar(id_curso=requisito, id_curso_requisito=otro_requisito))
        self.assertEqual(cambiado.id_curso, requisito)
        prerrequisitos.borrar_prerrequisito(registro.id_prerrequisito)
        self.comprobar_rechazo(404, prerrequisitos.consultar_prerrequisito,
                              registro.id_prerrequisito)

    def test_autorreferencia_y_ciclos_directos_indirectos_y_actualizacion(self):
        curso_a, curso_b, curso_c = self.cursos
        self.comprobar_rechazo(400, self.agregar_prerrequisito, curso_a, curso_a)
        relacion_a = self.agregar_prerrequisito(curso_a, curso_b)
        self.comprobar_rechazo(400, self.agregar_prerrequisito, curso_b, curso_a,
                              regla="regla_prerrequisito_sin_ciclos")
        relacion_b = self.agregar_prerrequisito(curso_b, curso_c)
        self.comprobar_rechazo(400, self.agregar_prerrequisito, curso_c, curso_a,
                              regla="regla_prerrequisito_sin_ciclos")
        self.comprobar_rechazo(400, prerrequisitos.modificar_prerrequisito,
                              relacion_b.id_prerrequisito, PrerrequisitoActualizar(
                                  id_curso=curso_b, id_curso_requisito=curso_a),
                              regla="regla_prerrequisito_sin_ciclos")
        self.comprobar_rechazo(400, prerrequisitos.modificar_prerrequisito,
                              relacion_a.id_prerrequisito, PrerrequisitoActualizar(
                                  id_curso=curso_a, id_curso_requisito=curso_a))
        self.assertEqual(prerrequisitos.consultar_prerrequisito(
            relacion_b.id_prerrequisito).id_curso_requisito, curso_c)

    def test_plan_exige_requisitos_y_protege_cambios_y_eliminaciones(self):
        carrera = self.carreras[0]
        curso, requisito, otro_requisito = self.cursos
        relacion = self.agregar_prerrequisito(curso, requisito)
        self.comprobar_rechazo(400, self.agregar_plan, carrera, curso,
                              regla="regla_prerrequisitos_en_planes")
        plan_requisito = self.agregar_plan(carrera, requisito)
        plan_curso = self.agregar_plan(carrera, curso)
        self.comprobar_rechazo(400, planes_estudio.borrar_plan_estudio,
                              plan_requisito.id_plan_estudio,
                              regla="regla_prerrequisitos_en_planes")
        self.comprobar_rechazo(400, planes_estudio.modificar_plan_estudio,
                              plan_requisito.id_plan_estudio, PlanEstudioActualizar(
                                  id_carrera=carrera, id_curso=otro_requisito,
                                  semestre_sugerido=3), regla="regla_prerrequisitos_en_planes")
        self.comprobar_rechazo(400, self.agregar_prerrequisito, curso, otro_requisito,
                              regla="regla_prerrequisitos_en_planes")
        self.comprobar_rechazo(400, prerrequisitos.modificar_prerrequisito,
                              relacion.id_prerrequisito, PrerrequisitoActualizar(
                                  id_curso=curso, id_curso_requisito=otro_requisito),
                              regla="regla_prerrequisitos_en_planes")
        conservado = planes_estudio.consultar_plan_estudio(plan_requisito.id_plan_estudio)
        self.assertEqual(conservado.id_curso, requisito)
        self.assertEqual(conservado.semestre_sugerido, 1)
        prerrequisitos.borrar_prerrequisito(relacion.id_prerrequisito)
        planes_estudio.borrar_plan_estudio(plan_requisito.id_plan_estudio)
        planes_estudio.borrar_plan_estudio(plan_curso.id_plan_estudio)

    def test_requisito_debe_estar_en_todas_las_carreras_que_ofrecen_el_curso(self):
        curso, requisito, _ = self.cursos
        for carrera in self.carreras:
            self.agregar_plan(carrera, curso)
        self.agregar_plan(self.carreras[0], requisito)
        self.comprobar_rechazo(400, self.agregar_prerrequisito, curso, requisito,
                              regla="regla_prerrequisitos_en_planes")
        self.agregar_plan(self.carreras[1], requisito)
        registro = self.agregar_prerrequisito(curso, requisito)
        self.assertEqual(registro.id_curso_requisito, requisito)

    def test_referencias_inexistentes_en_creacion_y_actualizacion(self):
        # Elegir un identificador positivo libre sin asumir el contenido de la base.
        consulta = text("""
            SELECT candidato FROM generate_series(2147483600, 2147483647) candidato
            WHERE NOT EXISTS (SELECT 1 FROM public.curso WHERE id_curso=candidato)
              AND NOT EXISTS (SELECT 1 FROM public.carrera WHERE id_carrera=candidato)
            LIMIT 1
        """)
        inexistente = self.conexion.execute(consulta).scalar_one()
        carrera = self.carreras[0]
        curso, requisito, _ = self.cursos
        plan = self.agregar_plan(carrera, curso)
        for id_carrera, id_curso in ((inexistente, curso), (carrera, inexistente)):
            datos = {"id_carrera": id_carrera, "id_curso": id_curso, "semestre_sugerido": 1}
            self.comprobar_rechazo(409, planes_estudio.registrar_plan_estudio,
                                  PlanEstudioCrear(**datos))
            self.comprobar_rechazo(409, planes_estudio.modificar_plan_estudio,
                                  plan.id_plan_estudio, PlanEstudioActualizar(**datos))
        relacion = self.agregar_prerrequisito(requisito, curso)
        for id_curso, id_requisito in ((inexistente, curso), (requisito, inexistente)):
            datos = {"id_curso": id_curso, "id_curso_requisito": id_requisito}
            self.comprobar_rechazo(409, prerrequisitos.registrar_prerrequisito,
                                  PrerrequisitoCrear(**datos))
            self.comprobar_rechazo(409, prerrequisitos.modificar_prerrequisito,
                                  relacion.id_prerrequisito, PrerrequisitoActualizar(**datos))
        self.assertEqual(planes_estudio.consultar_plan_estudio(plan.id_plan_estudio).id_curso,
                         curso)

    def test_cursos_referenciados_no_se_eliminan(self):
        curso, requisito, _ = self.cursos
        plan = self.agregar_plan(self.carreras[0], curso)
        self.comprobar_rechazo(409, cursos.borrar_curso, curso)
        planes_estudio.borrar_plan_estudio(plan.id_plan_estudio)
        self.agregar_prerrequisito(curso, requisito)
        for identificador in (curso, requisito):
            self.comprobar_rechazo(409, cursos.borrar_curso, identificador)
            self.assertIsNotNone(cursos.consultar_curso(identificador))

    def test_registros_inexistentes_devuelven_404(self):
        for consultar, modificar, borrar, datos in (
            (cursos.consultar_curso, cursos.modificar_curso, cursos.borrar_curso,
             CursoActualizar(codigo="A", nombre="B")),
            (planes_estudio.consultar_plan_estudio, planes_estudio.modificar_plan_estudio,
             planes_estudio.borrar_plan_estudio, PlanEstudioActualizar(
                 id_carrera=self.carreras[0], id_curso=self.cursos[0], semestre_sugerido=1)),
            (prerrequisitos.consultar_prerrequisito, prerrequisitos.modificar_prerrequisito,
             prerrequisitos.borrar_prerrequisito, PrerrequisitoActualizar(
                 id_curso=self.cursos[0], id_curso_requisito=self.cursos[1])),
        ):
            self.comprobar_rechazo(404, consultar, -1)
            self.comprobar_rechazo(404, modificar, -1, datos)
            self.comprobar_rechazo(404, borrar, -1)

    def test_plan_y_curso_del_historial_conservan_sus_relaciones(self):
        fila = self.conexion.execute(text("""
            SELECT DISTINCT p.id_plan_estudio, p.id_carrera, p.id_curso, p.semestre_sugerido
            FROM public.plan_estudio p
            JOIN public.estudiante e USING (id_carrera)
            JOIN public.inscripcion i USING (id_estudiante)
            JOIN public.asignacion_curso a USING (id_inscripcion)
            JOIN public.seccion s ON s.id_seccion=a.id_seccion AND s.id_curso=p.id_curso
            WHERE a.estado <> 'cancelada'
              AND NOT EXISTS (SELECT 1 FROM public.prerrequisito r
                              WHERE r.id_curso_requisito=p.id_curso)
            LIMIT 1
        """)).first()
        if fila is None:
            self.skipTest("Falta un curso asignado que no sea requisito de otro")
        actualizado = planes_estudio.modificar_plan_estudio(fila.id_plan_estudio,
            PlanEstudioActualizar(id_carrera=fila.id_carrera, id_curso=fila.id_curso,
                                  semestre_sugerido=2))
        self.assertEqual(actualizado.semestre_sugerido, 2)
        self.comprobar_rechazo(400, planes_estudio.borrar_plan_estudio,
                              fila.id_plan_estudio, regla="regla_asignacion_plan")
        self.comprobar_rechazo(400, planes_estudio.modificar_plan_estudio,
                              fila.id_plan_estudio, PlanEstudioActualizar(
                                  id_carrera=fila.id_carrera, id_curso=self.cursos[0],
                                  semestre_sugerido=2), regla="regla_asignacion_plan")
        self.assertEqual(planes_estudio.consultar_plan_estudio(
            fila.id_plan_estudio).id_curso, fila.id_curso)
        self.comprobar_rechazo(409, cursos.borrar_curso, fila.id_curso)

    def test_nuevo_requisito_no_puede_invalidar_aprobaciones_previas(self):
        fila = self.conexion.execute(text("""
            SELECT r.id_prerrequisito, r.id_curso
            FROM public.prerrequisito r
            JOIN public.seccion s USING (id_curso)
            JOIN public.asignacion_curso a USING (id_seccion)
            WHERE a.estado <> 'cancelada' LIMIT 1
        """)).first()
        if fila is None:
            self.skipTest("Falta un curso asignado con prerrequisitos")
        nuevo_requisito = self.cursos[0]
        carreras = self.conexion.execute(text("""
            SELECT id_carrera FROM public.plan_estudio WHERE id_curso=:curso
        """), {"curso": fila.id_curso}).scalars().all()
        for carrera in carreras:
            self.agregar_plan(carrera, nuevo_requisito)
        self.comprobar_rechazo(400, self.agregar_prerrequisito, fila.id_curso,
                              nuevo_requisito, regla="regla_historial_prerrequisitos")
        original = prerrequisitos.consultar_prerrequisito(fila.id_prerrequisito)
        self.comprobar_rechazo(400, prerrequisitos.modificar_prerrequisito,
                              fila.id_prerrequisito, PrerrequisitoActualizar(
                                  id_curso=fila.id_curso, id_curso_requisito=nuevo_requisito),
                              regla="regla_historial_prerrequisitos")
        self.assertEqual(prerrequisitos.consultar_prerrequisito(
            fila.id_prerrequisito).id_curso_requisito, original.id_curso_requisito)


if __name__ == "__main__":
    unittest.main()
