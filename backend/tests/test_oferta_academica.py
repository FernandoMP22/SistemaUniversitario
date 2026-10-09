import os
import unittest
from datetime import date, time, timedelta
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
from backend.routers import horarios_seccion, periodos_academicos, salones, secciones
from backend.schemas.horario_seccion import (
    HorarioSeccionActualizar, HorarioSeccionCrear, HorarioSeccionRespuesta,
)
from backend.schemas.periodo_academico import (
    PeriodoAcademicoActualizar, PeriodoAcademicoCrear, PeriodoAcademicoRespuesta,
)
from backend.schemas.salon import SalonActualizar, SalonCrear, SalonRespuesta
from backend.schemas.seccion import SeccionActualizar, SeccionCrear, SeccionRespuesta


def tearDownModule():
    engine.dispose()


PERIODO = dict(codigo="P", nombre="Periodo", fecha_inicio="2030-01-01",
               fecha_fin="2030-05-01")
SALON = dict(id_sede=1, codigo="S", capacidad=10)
SECCION = dict(id_curso=1, id_periodo_academico=1, id_docente=1,
               codigo="A", cupo_maximo=10)
HORARIO = dict(id_seccion=1, id_salon=1, dia_semana=1,
               hora_inicio="09:00:00", hora_fin="10:00:00")
ENTRADAS = (
    (PeriodoAcademicoCrear, PERIODO), (PeriodoAcademicoActualizar, PERIODO),
    (SalonCrear, SALON), (SalonActualizar, SALON),
    (SeccionCrear, SECCION), (SeccionActualizar, SECCION),
    (HorarioSeccionCrear, HORARIO), (HorarioSeccionActualizar, HORARIO),
)


class EsquemasOfertaAcademica(unittest.TestCase):
    def test_longitudes_y_campos_obligatorios(self):
        for esquema, datos in ENTRADAS:
            for campo in datos:
                with self.subTest(esquema=esquema.__name__, campo=campo):
                    incompletos = dict(datos)
                    incompletos.pop(campo)
                    with self.assertRaises(ValidationError):
                        esquema(**incompletos)
                    with self.assertRaises(ValidationError):
                        esquema(**{**datos, campo: None})
            for campo, limite in (("codigo", 20), ("nombre", 100)):
                if campo in datos:
                    esquema(**{**datos, campo: "X" * limite})
                    for valor in ("", "X" * (limite + 1)):
                        with self.assertRaises(ValidationError):
                            esquema(**{**datos, campo: valor})

    def test_enteros_estrictos_y_rangos_sql(self):
        for esquema, datos in ENTRADAS:
            for campo in datos:
                if campo.startswith("id_") or campo in ("capacidad", "cupo_maximo"):
                    esquema(**{**datos, campo: 2147483647})
                    for valor in (0, -1, 2147483648, True, "1", 1.5):
                        with self.subTest(esquema=esquema.__name__, campo=campo, valor=valor):
                            with self.assertRaises(ValidationError):
                                esquema(**{**datos, campo: valor})

    def test_dias_entre_lunes_y_domingo(self):
        for esquema in (HorarioSeccionCrear, HorarioSeccionActualizar):
            for dia in (1, 7):
                esquema(**{**HORARIO, "dia_semana": dia})
            for dia in (0, 8, 32768, True, "1", 1.5):
                with self.assertRaises(ValidationError):
                    esquema(**{**HORARIO, "dia_semana": dia})

    def test_fechas_y_horas_sin_zona_horaria(self):
        for esquema in (PeriodoAcademicoCrear, PeriodoAcademicoActualizar):
            self.assertIsInstance(esquema(**PERIODO).fecha_inicio, date)
            with self.assertRaises(ValidationError):
                esquema(**{**PERIODO, "fecha_fin": "2030-02-30"})
        for esquema in (HorarioSeccionCrear, HorarioSeccionActualizar):
            self.assertIsInstance(esquema(**HORARIO).hora_inicio, time)
            for hora in ("25:00:00", "09:00:00Z", "09:00:00-06:00"):
                with self.assertRaises(ValidationError):
                    esquema(**{**HORARIO, "hora_inicio": hora})

    def test_campos_adicionales_y_calificaciones_no_editables(self):
        for esquema, datos in ENTRADAS:
            for campo in ("identificador", "calificaciones_cerradas"):
                with self.assertRaises(ValidationError):
                    esquema(**datos, **{campo: True})
        for esquema, datos, identificador in (
            (PeriodoAcademicoActualizar, PERIODO, "id_periodo_academico"),
            (SalonActualizar, SALON, "id_salon"),
            (SeccionActualizar, SECCION, "id_seccion"),
            (HorarioSeccionActualizar, HORARIO, "id_horario_seccion"),
        ):
            with self.assertRaises(ValidationError):
                esquema(**datos, **{identificador: 2})

    def test_openapi_rutas_y_cierre_solo_consulta(self):
        documento = app.openapi()
        for ruta, identificador in (
            ("periodos-academicos", "id_periodo_academico"),
            ("salones", "id_salon"), ("secciones", "id_seccion"),
            ("horarios-seccion", "id_horario_seccion"),
        ):
            self.assertTrue({"get", "post"}.issubset(documento["paths"][f"/{ruta}"]))
            self.assertTrue({"get", "put", "delete"}.issubset(
                documento["paths"][f"/{ruta}/{{{identificador}}}"]))
        esquemas = documento["components"]["schemas"]
        for nombre in ("SeccionCrear", "SeccionActualizar"):
            self.assertNotIn("calificaciones_cerradas", esquemas[nombre]["properties"])
            self.assertFalse(esquemas[nombre]["additionalProperties"])
        self.assertTrue(esquemas["SeccionRespuesta"]["properties"][
            "calificaciones_cerradas"]["readOnly"])


class ErroresSimuladosOfertaAcademica(unittest.TestCase):
    def test_commit_rechazado_hace_rollback_en_las_doce_escrituras(self):
        operaciones = (
            (periodos_academicos.registrar_periodo_academico, (PeriodoAcademicoCrear(**PERIODO),)),
            (periodos_academicos.modificar_periodo_academico, (1, PeriodoAcademicoActualizar(**PERIODO))),
            (periodos_academicos.borrar_periodo_academico, (1,)),
            (salones.registrar_salon, (SalonCrear(**SALON),)),
            (salones.modificar_salon, (1, SalonActualizar(**SALON))),
            (salones.borrar_salon, (1,)),
            (secciones.registrar_seccion, (SeccionCrear(**SECCION),)),
            (secciones.modificar_seccion, (1, SeccionActualizar(**SECCION))),
            (secciones.borrar_seccion, (1,)),
            (horarios_seccion.registrar_horario_seccion, (HorarioSeccionCrear(**HORARIO),)),
            (horarios_seccion.modificar_horario_seccion, (1, HorarioSeccionActualizar(**HORARIO))),
            (horarios_seccion.borrar_horario_seccion, (1,)),
        )
        for operacion, argumentos in operaciones:
            for codigo, estado in (("23505", 409), ("23503", 409),
                                   ("23514", 400), ("23P01", 409)):
                with self.subTest(operacion=operacion.__name__, codigo=codigo):
                    session = Mock()
                    session.commit.side_effect = DBAPIError(None, None, Mock(sqlstate=codigo))
                    with patch.object(transacciones, "SessionLocal", return_value=session):
                        with self.assertRaises(HTTPException) as resultado:
                            operacion(*argumentos)
                    self.assertEqual(resultado.exception.status_code, estado)
                    session.rollback.assert_called_once()
                    session.close.assert_called_once()

    def test_40001_agota_tres_intentos_y_devuelve_503(self):
        for operacion, datos in (
            (periodos_academicos.registrar_periodo_academico, PeriodoAcademicoCrear(**PERIODO)),
            (salones.registrar_salon, SalonCrear(**SALON)),
            (secciones.registrar_seccion, SeccionCrear(**SECCION)),
            (horarios_seccion.registrar_horario_seccion, HorarioSeccionCrear(**HORARIO)),
        ):
            sesiones = [Mock(), Mock(), Mock()]
            for session in sesiones:
                session.commit.side_effect = DBAPIError(None, None, Mock(sqlstate="40001"))
            with patch.object(transacciones, "SessionLocal", side_effect=sesiones):
                with patch.object(transacciones, "sleep"):
                    with self.assertRaises(HTTPException) as resultado:
                        operacion(datos)
            self.assertEqual(resultado.exception.status_code, 503)
            for session in sesiones:
                session.rollback.assert_called_once()
                session.close.assert_called_once()


@unittest.skipUnless(os.getenv("PROBAR_POSTGRESQL") == "1", "Activar PROBAR_POSTGRESQL=1")
class OfertaAcademicaPostgreSQL(unittest.TestCase):
    """Cada prueba descarta sus filas con rollback externo; nunca borra datos de Swagger."""

    def setUp(self):
        self.conexion = engine.connect()
        self.transaccion = self.conexion.begin()
        self.addCleanup(self.conexion.close)
        self.addCleanup(self.transaccion.rollback)
        self.assertEqual(self.valor("SHOW transaction_isolation"), "serializable")
        self.parches = []
        self.addCleanup(self.cerrar_parches)
        for modulo in (periodos_academicos, salones, secciones, horarios_seccion, transacciones):
            parche = patch.object(modulo, "SessionLocal", side_effect=self.crear_sesion)
            parche.start()
            self.parches.append(parche)
        self.token = uuid4().hex[:10]
        self.sedes = []
        self.docentes = []
        self.cursos = []
        for letra in ("A", "B"):
            codigo = self.token + letra
            self.sedes.append(self.valor("""
                INSERT INTO public.sede (codigo, nombre, direccion)
                VALUES (:codigo, 'Sede temporal', 'Direccion') RETURNING id_sede
            """, codigo=codigo))
            self.docentes.append(self.valor("""
                INSERT INTO public.docente (codigo, nombres, apellidos, correo)
                VALUES (:codigo, 'Ana', 'Perez', 'test@example.com') RETURNING id_docente
            """, codigo=codigo))
            self.cursos.append(self.valor("""
                INSERT INTO public.curso (codigo, nombre)
                VALUES (:codigo, 'Curso temporal') RETURNING id_curso
            """, codigo=codigo))
        ultima_fecha = self.valor("SELECT max(fecha_fin) FROM public.periodo_academico")
        self.inicio = (ultima_fecha or date(2030, 1, 1)) + timedelta(days=10)
        self.fin = self.inicio + timedelta(days=90)
        self.periodo = self.nuevo_periodo("P", self.inicio, self.fin)
        self.otro_periodo = self.nuevo_periodo("Q", self.fin + timedelta(days=10),
                                             self.fin + timedelta(days=100))
        self.salon = salones.registrar_salon(SalonCrear(
            id_sede=self.sedes[0], codigo="A", capacidad=10)).id_salon
        self.otro_salon = salones.registrar_salon(SalonCrear(
            id_sede=self.sedes[0], codigo="B", capacidad=10)).id_salon
        self.salon_otra_sede = salones.registrar_salon(SalonCrear(
            id_sede=self.sedes[1], codigo="A", capacidad=10)).id_salon
        self.seccion = self.nueva_seccion(self.cursos[0], self.docentes[0])
        self.otra_seccion = self.nueva_seccion(self.cursos[1], self.docentes[1])
        self.horario = self.nuevo_horario(self.seccion, self.salon, "09:00", "10:00")
        self.otro_horario = self.nuevo_horario(self.otra_seccion, self.otro_salon, "11:00", "12:00")

    def valor(self, sql, **parametros):
        return self.conexion.execute(text(sql), parametros).scalar_one()

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
        # Un RELEASE SAVEPOINT no ejecuta las reglas diferidas del COMMIT.
        session.flush()
        session.execute(text("SET CONSTRAINTS ALL IMMEDIATE"))
        session.execute(text("SET CONSTRAINTS ALL DEFERRED"))

    def nuevo_periodo(self, codigo, inicio, fin):
        return periodos_academicos.registrar_periodo_academico(PeriodoAcademicoCrear(
            codigo=self.token + codigo, nombre="Periodo temporal",
            fecha_inicio=inicio, fecha_fin=fin)).id_periodo_academico

    def nueva_seccion(self, curso, docente, periodo=None, codigo="A", cupo=10):
        return secciones.registrar_seccion(SeccionCrear(
            id_curso=curso, id_docente=docente, id_periodo_academico=periodo or self.periodo,
            codigo=codigo, cupo_maximo=cupo)).id_seccion

    def nuevo_horario(self, seccion, salon, inicio, fin, dia=1):
        return horarios_seccion.registrar_horario_seccion(HorarioSeccionCrear(
            id_seccion=seccion, id_salon=salon, dia_semana=dia,
            hora_inicio=inicio, hora_fin=fin)).id_horario_seccion

    def cambiar_seccion(self, identificador=None, **cambios):
        identificador = identificador or self.seccion
        actual = SeccionRespuesta.model_validate(secciones.consultar_seccion(identificador))
        datos = actual.model_dump(exclude={"id_seccion", "calificaciones_cerradas"})
        return secciones.modificar_seccion(identificador, SeccionActualizar(**{**datos, **cambios}))

    def cambiar_horario(self, identificador=None, **cambios):
        identificador = identificador or self.horario
        actual = HorarioSeccionRespuesta.model_validate(
            horarios_seccion.consultar_horario_seccion(identificador))
        datos = actual.model_dump(exclude={"id_horario_seccion"})
        return horarios_seccion.modificar_horario_seccion(
            identificador, HorarioSeccionActualizar(**{**datos, **cambios}))

    def comprobar_rechazo(self, estado, operacion, *argumentos, regla=None, **opciones):
        with self.assertRaises(HTTPException) as resultado:
            operacion(*argumentos, **opciones)
        self.assertEqual(resultado.exception.status_code, estado)
        if regla is not None:
            self.assertEqual(resultado.exception.__cause__.orig.diag.constraint_name, regla)

    def preparar_asignaciones(self, cantidad=1, ambas_secciones=False):
        facultad = self.valor("""
            INSERT INTO public.facultad (codigo, nombre)
            VALUES (:codigo, 'Facultad temporal') RETURNING id_facultad
        """, codigo=self.token)
        carrera = self.valor("""
            INSERT INTO public.carrera (id_facultad, codigo, nombre)
            VALUES (:facultad, :codigo, 'Carrera temporal') RETURNING id_carrera
        """, facultad=facultad, codigo=self.token)
        for curso in self.cursos:
            self.conexion.execute(text("""
                INSERT INTO public.plan_estudio (id_carrera, id_curso, semestre_sugerido)
                VALUES (:carrera, :curso, 1)
            """), dict(carrera=carrera, curso=curso))
        asignaciones = []
        for numero in range(cantidad):
            estudiante = self.valor("""
                INSERT INTO public.estudiante
                    (id_carrera, carne, nombres, apellidos, fecha_nacimiento, correo)
                VALUES (:carrera, :carne, 'Luis', 'Perez', '2001-01-01', 'test@example.com')
                RETURNING id_estudiante
            """, carrera=carrera, carne=self.token + str(numero))
            inscripcion = self.valor("""
                INSERT INTO public.inscripcion (id_estudiante, id_periodo_academico)
                VALUES (:estudiante, :periodo) RETURNING id_inscripcion
            """, estudiante=estudiante, periodo=self.periodo)
            seleccion = (self.seccion, self.otra_seccion) if ambas_secciones else (self.seccion,)
            for seccion in seleccion:
                asignaciones.append(self.valor("""
                    INSERT INTO public.asignacion_curso (id_inscripcion, id_seccion)
                    VALUES (:inscripcion, :seccion) RETURNING id_asignacion_curso
                """, inscripcion=inscripcion, seccion=seccion))
        self.conexion.execute(text("SET CONSTRAINTS ALL IMMEDIATE"))
        self.conexion.execute(text("SET CONSTRAINTS ALL DEFERRED"))
        return asignaciones

    def cerrar_seccion_temporal(self):
        asignacion = self.preparar_asignaciones()[0]
        actividad = self.valor("""
            INSERT INTO public.actividad_academica
                (id_seccion, nombre, tipo, fecha, puntaje_maximo)
            VALUES (:seccion, 'Examen', 'examen', :fecha, 100)
            RETURNING id_actividad_academica
        """, seccion=self.seccion, fecha=self.inicio)
        self.conexion.execute(text("""
            INSERT INTO public.calificacion
                (id_actividad_academica, id_asignacion_curso, puntaje_obtenido)
            VALUES (:actividad, :asignacion, 80)
        """), dict(actividad=actividad, asignacion=asignacion))
        # Solo prepara historial para esta prueba; no agrega un endpoint de cierre.
        self.conexion.execute(text("SELECT public.cerrar_calificaciones(:seccion)"),
                              dict(seccion=self.seccion))
        self.conexion.execute(text("SET CONSTRAINTS ALL IMMEDIATE"))
        self.conexion.execute(text("SET CONSTRAINTS ALL DEFERRED"))
        return asignacion

    def test_crud_y_respuestas_de_los_cuatro_modulos(self):
        self.assertTrue(periodos_academicos.listar_periodos_academicos())
        self.assertTrue(salones.listar_salones())
        self.assertTrue(secciones.listar_secciones())
        self.assertTrue(horarios_seccion.listar_horarios_seccion())
        periodo = PeriodoAcademicoRespuesta.model_validate(
            periodos_academicos.consultar_periodo_academico(self.otro_periodo))
        cambiado = periodos_academicos.modificar_periodo_academico(self.otro_periodo,
            PeriodoAcademicoActualizar(**{**periodo.model_dump(exclude={"id_periodo_academico"}),
                                         "nombre": "Nuevo nombre"}))
        self.assertEqual(cambiado.nombre, "Nuevo nombre")
        salon = salones.modificar_salon(self.salon_otra_sede, SalonActualizar(
            id_sede=self.sedes[0], codigo="C", capacidad=2147483647))
        SalonRespuesta.model_validate(salon)
        self.assertEqual(salon.capacidad, 2147483647)
        self.assertFalse(SeccionRespuesta.model_validate(
            secciones.consultar_seccion(self.seccion)).calificaciones_cerradas)
        self.assertEqual(self.cambiar_seccion(codigo="B", cupo_maximo=9).codigo, "B")
        self.assertEqual(self.cambiar_horario(dia_semana=7).dia_semana, 7)
        horarios_seccion.borrar_horario_seccion(self.horario)
        secciones.borrar_seccion(self.seccion)
        salones.borrar_salon(self.salon)
        periodos_academicos.borrar_periodo_academico(self.otro_periodo)
        for consultar, identificador in (
            (horarios_seccion.consultar_horario_seccion, self.horario),
            (secciones.consultar_seccion, self.seccion),
            (salones.consultar_salon, self.salon),
            (periodos_academicos.consultar_periodo_academico, self.otro_periodo),
        ):
            self.comprobar_rechazo(404, consultar, identificador)

    def test_duplicados_compuestos_y_rollback(self):
        self.comprobar_rechazo(409, self.nuevo_periodo, "P",
                              self.fin + timedelta(days=110), self.fin + timedelta(days=120))
        actual = periodos_academicos.consultar_periodo_academico(self.otro_periodo)
        self.comprobar_rechazo(409, periodos_academicos.modificar_periodo_academico,
            self.otro_periodo, PeriodoAcademicoActualizar(
                codigo=self.token + "P", nombre="No guardar",
                fecha_inicio=actual.fecha_inicio, fecha_fin=actual.fecha_fin))
        self.assertEqual(periodos_academicos.consultar_periodo_academico(
            self.otro_periodo).nombre, actual.nombre)
        self.comprobar_rechazo(409, salones.registrar_salon,
                              SalonCrear(id_sede=self.sedes[0], codigo="A", capacidad=10))
        self.comprobar_rechazo(409, salones.modificar_salon, self.otro_salon,
                              SalonActualizar(id_sede=self.sedes[0], codigo="A", capacidad=20))
        self.assertEqual(salones.consultar_salon(self.otro_salon).capacidad, 10)
        self.comprobar_rechazo(409, self.nueva_seccion, self.cursos[0], self.docentes[1])
        self.comprobar_rechazo(409, self.cambiar_seccion, self.otra_seccion,
                              id_curso=self.cursos[0], cupo_maximo=20)
        self.assertEqual(secciones.consultar_seccion(self.otra_seccion).cupo_maximo, 10)
        self.comprobar_rechazo(409, self.nuevo_horario, self.seccion, self.otro_salon,
                              "09:00", "10:00")
        otro = self.nuevo_horario(self.seccion, self.salon, "10:00", "11:00")
        self.comprobar_rechazo(409, self.cambiar_horario, otro,
                              hora_inicio="09:00", hora_fin="10:00")
        self.assertEqual(horarios_seccion.consultar_horario_seccion(otro).hora_inicio, time(10))

    def test_fechas_ordenadas_y_periodos_sin_superposicion(self):
        self.comprobar_rechazo(400, self.nuevo_periodo, "R", self.inicio, self.inicio)
        self.comprobar_rechazo(400, self.nuevo_periodo, "R", self.fin, self.inicio)
        for inicio, fin in ((self.inicio, self.fin), (self.fin, self.fin + timedelta(days=1))):
            self.comprobar_rechazo(409, self.nuevo_periodo, "R", inicio, fin,
                                  regla="ex_periodo_academico_fechas")
        original = periodos_academicos.consultar_periodo_academico(self.otro_periodo)
        self.comprobar_rechazo(409, periodos_academicos.modificar_periodo_academico,
            self.otro_periodo, PeriodoAcademicoActualizar(
                codigo=original.codigo, nombre="No guardar", fecha_inicio=self.fin,
                fecha_fin=original.fecha_fin), regla="ex_periodo_academico_fechas")
        self.assertEqual(periodos_academicos.consultar_periodo_academico(
            self.otro_periodo).nombre, original.nombre)

    def test_referencias_inexistentes_en_creacion_y_actualizacion(self):
        ausente = 2147483647
        self.assertEqual(self.valor("""
            SELECT count(*) FROM public.sede WHERE id_sede = :id
        """, id=ausente), 0)
        self.comprobar_rechazo(409, salones.registrar_salon,
                              SalonCrear(id_sede=ausente, codigo="X", capacidad=10))
        self.comprobar_rechazo(409, salones.modificar_salon, self.salon,
                              SalonActualizar(id_sede=ausente, codigo="X", capacidad=20))
        for campo in ("id_curso", "id_periodo_academico", "id_docente"):
            datos = dict(id_curso=self.cursos[0], id_periodo_academico=self.periodo,
                         id_docente=self.docentes[0], codigo="X", cupo_maximo=10)
            datos[campo] = ausente
            self.comprobar_rechazo(409, secciones.registrar_seccion, SeccionCrear(**datos))
            self.comprobar_rechazo(409, self.cambiar_seccion, **{campo: ausente, "codigo": "X"})
        for campo in ("id_seccion", "id_salon"):
            datos = dict(id_seccion=self.seccion, id_salon=self.salon, dia_semana=2,
                         hora_inicio="09:00", hora_fin="10:00")
            datos[campo] = ausente
            self.comprobar_rechazo(409, horarios_seccion.registrar_horario_seccion,
                                  HorarioSeccionCrear(**datos))
            self.comprobar_rechazo(409, self.cambiar_horario, **{campo: ausente})
        self.assertEqual(salones.consultar_salon(self.salon).codigo, "A")
        self.assertEqual(secciones.consultar_seccion(self.seccion).codigo, "A")
        self.assertEqual(horarios_seccion.consultar_horario_seccion(
            self.horario).id_salon, self.salon)

    def test_registros_ausentes(self):
        ausente = 2147483647
        for consultar, modificar, borrar, datos in (
            (periodos_academicos.consultar_periodo_academico,
             periodos_academicos.modificar_periodo_academico,
             periodos_academicos.borrar_periodo_academico, PeriodoAcademicoActualizar(**PERIODO)),
            (salones.consultar_salon, salones.modificar_salon, salones.borrar_salon,
             SalonActualizar(**SALON)),
            (secciones.consultar_seccion, secciones.modificar_seccion,
             secciones.borrar_seccion, SeccionActualizar(**SECCION)),
            (horarios_seccion.consultar_horario_seccion, horarios_seccion.modificar_horario_seccion,
             horarios_seccion.borrar_horario_seccion, HorarioSeccionActualizar(**HORARIO)),
        ):
            self.comprobar_rechazo(404, consultar, ausente)
            self.comprobar_rechazo(404, modificar, ausente, datos)
            self.comprobar_rechazo(404, borrar, ausente)

    def test_eliminaciones_con_referencias(self):
        for borrar, identificador in (
            (periodos_academicos.borrar_periodo_academico, self.periodo),
            (salones.borrar_salon, self.salon),
            (secciones.borrar_seccion, self.seccion),
        ):
            self.comprobar_rechazo(409, borrar, identificador)

    def test_capacidad_del_salon_y_cupo_de_seccion(self):
        self.comprobar_rechazo(400, salones.modificar_salon, self.salon,
            SalonActualizar(id_sede=self.sedes[0], codigo="No guardar", capacidad=9),
            regla="regla_salon_capacidad_seccion")
        self.assertEqual(salones.consultar_salon(self.salon).codigo, "A")
        self.comprobar_rechazo(400, self.cambiar_seccion, cupo_maximo=11,
                              regla="regla_salon_capacidad_seccion")
        self.assertEqual(secciones.consultar_seccion(self.seccion).cupo_maximo, 10)
        pequeno = salones.registrar_salon(SalonCrear(
            id_sede=self.sedes[0], codigo="Pequeno", capacidad=5)).id_salon
        self.comprobar_rechazo(400, self.nuevo_horario, self.seccion, pequeno,
                              "14:00", "15:00", regla="regla_salon_capacidad_seccion")

    def test_sede_unica_y_rollback_del_salon(self):
        self.comprobar_rechazo(400, self.nuevo_horario, self.seccion, self.salon_otra_sede,
                              "14:00", "15:00", regla="regla_seccion_sede_unica")
        self.nuevo_horario(self.seccion, self.otro_salon, "14:00", "15:00")
        self.comprobar_rechazo(400, salones.modificar_salon, self.salon,
            SalonActualizar(id_sede=self.sedes[1], codigo="No guardar", capacidad=10),
            regla="regla_seccion_sede_unica")
        self.assertEqual(salones.consultar_salon(self.salon).id_sede, self.sedes[0])

    def test_cruces_de_la_misma_seccion(self):
        self.comprobar_rechazo(400, self.nuevo_horario, self.seccion, self.otro_salon,
                              "09:30", "10:30", regla="regla_horarios_sin_conflictos")

    def test_cruces_del_salon_y_rollback_de_horario(self):
        self.comprobar_rechazo(400, self.cambiar_horario, self.otro_horario,
                              id_salon=self.salon, hora_inicio="09:30", hora_fin="10:30",
                              regla="regla_horarios_sin_conflictos")
        conservado = horarios_seccion.consultar_horario_seccion(self.otro_horario)
        self.assertEqual(conservado.id_salon, self.otro_salon)
        self.assertEqual(conservado.hora_inicio, time(11))

    def test_cruces_del_docente_al_modificar_seccion(self):
        self.cambiar_horario(self.otro_horario, hora_inicio="09:30", hora_fin="10:30")
        self.comprobar_rechazo(400, self.cambiar_seccion, self.otra_seccion,
                              id_docente=self.docentes[0], codigo="No guardar",
                              regla="regla_horarios_sin_conflictos")
        self.assertEqual(secciones.consultar_seccion(
            self.otra_seccion).id_docente, self.docentes[1])
        self.assertEqual(secciones.consultar_seccion(self.otra_seccion).codigo, "A")

    def test_horas_ordenadas_contiguas_y_periodos_distintos(self):
        for inicio, fin in (("09:00", "09:00"), ("10:00", "09:00")):
            self.comprobar_rechazo(400, self.nuevo_horario, self.seccion,
                                  self.salon, inicio, fin, 2)
        self.nuevo_horario(self.seccion, self.salon, "10:00", "11:00")
        self.nuevo_horario(self.seccion, self.salon, "09:00", "10:00", 2)
        otra = self.nueva_seccion(self.cursos[0], self.docentes[0], self.otro_periodo)
        self.nuevo_horario(otra, self.salon, "09:00", "10:00")

    def test_cambios_de_relaciones_permitidos_sin_asignaciones(self):
        cambiada = self.cambiar_seccion(id_curso=self.cursos[1],
                                       id_periodo_academico=self.otro_periodo,
                                       id_docente=self.docentes[1])
        self.assertEqual(cambiada.id_curso, self.cursos[1])
        self.assertEqual(cambiada.id_periodo_academico, self.otro_periodo)
        movido = self.cambiar_horario(id_seccion=self.otra_seccion)
        self.assertEqual(movido.id_seccion, self.otra_seccion)
        self.assertEqual(self.cambiar_horario(id_salon=self.otro_salon).id_salon, self.otro_salon)

    def test_cupo_y_curso_periodo_inmutables_con_asignaciones(self):
        self.preparar_asignaciones(cantidad=2)
        self.comprobar_rechazo(400, self.cambiar_seccion, cupo_maximo=1,
                              regla="regla_asignacion_cupo")
        for cambios in (dict(id_curso=self.cursos[1]), dict(id_periodo_academico=self.otro_periodo)):
            self.comprobar_rechazo(400, self.cambiar_seccion, **cambios,
                                  regla="regla_seccion_identidad")
        self.assertEqual(self.cambiar_seccion(cupo_maximo=2).cupo_maximo, 2)
        self.assertEqual(secciones.consultar_seccion(self.seccion).id_curso, self.cursos[0])

    def test_asignaciones_canceladas_conservan_identidad(self):
        asignacion = self.preparar_asignaciones()[0]
        self.conexion.execute(text("""
            UPDATE public.asignacion_curso SET estado = 'cancelada'
            WHERE id_asignacion_curso = :id
        """), dict(id=asignacion))
        self.comprobar_rechazo(400, self.cambiar_seccion, id_curso=self.cursos[1],
                              regla="regla_seccion_identidad")
        horarios_seccion.borrar_horario_seccion(self.horario)
        self.comprobar_rechazo(409, secciones.borrar_seccion, self.seccion)

    def test_ultimo_horario_necesario_para_asignaciones(self):
        self.preparar_asignaciones()
        self.comprobar_rechazo(400, horarios_seccion.borrar_horario_seccion, self.horario,
                              regla="regla_asignacion_horario")
        self.comprobar_rechazo(400, self.cambiar_horario, id_seccion=self.otra_seccion,
                              regla="regla_asignacion_horario")
        self.assertEqual(horarios_seccion.consultar_horario_seccion(
            self.horario).id_seccion, self.seccion)
        reemplazo = self.nuevo_horario(self.seccion, self.salon, "14:00", "15:00")
        horarios_seccion.borrar_horario_seccion(self.horario)
        self.assertEqual(horarios_seccion.consultar_horario_seccion(
            reemplazo).id_seccion, self.seccion)

    def test_cruces_del_estudiante_con_distinto_salon_y_docente(self):
        self.preparar_asignaciones(ambas_secciones=True)
        self.comprobar_rechazo(400, self.cambiar_horario, self.otro_horario,
                              hora_inicio="09:30", hora_fin="10:30",
                              regla="regla_asignacion_horario_estudiante")
        self.assertEqual(horarios_seccion.consultar_horario_seccion(
            self.otro_horario).hora_inicio, time(11))

    def test_fechas_no_pueden_excluir_actividades_existentes(self):
        self.valor("""
            INSERT INTO public.actividad_academica
                (id_seccion, nombre, tipo, fecha, puntaje_maximo)
            VALUES (:seccion, 'Tarea', 'tarea', :fecha, 10)
            RETURNING id_actividad_academica
        """, seccion=self.seccion, fecha=self.inicio)
        self.comprobar_rechazo(400, self.cambiar_seccion, id_periodo_academico=self.otro_periodo)
        actual = periodos_academicos.consultar_periodo_academico(self.periodo)
        self.comprobar_rechazo(400, periodos_academicos.modificar_periodo_academico,
            self.periodo, PeriodoAcademicoActualizar(
                codigo=actual.codigo, nombre="No guardar",
                fecha_inicio=self.inicio + timedelta(days=1), fecha_fin=self.fin))
        self.assertEqual(periodos_academicos.consultar_periodo_academico(
            self.periodo).fecha_inicio, self.inicio)

    def test_historial_cerrado_y_datos_de_consulta(self):
        asignacion = self.cerrar_seccion_temporal()
        self.assertTrue(SeccionRespuesta.model_validate(
            secciones.consultar_seccion(self.seccion)).calificaciones_cerradas)
        self.comprobar_rechazo(400, self.cambiar_seccion, codigo="No guardar",
                              regla="regla_seccion_cerrada")
        self.comprobar_rechazo(400, secciones.borrar_seccion, self.seccion,
                              regla="regla_seccion_cerrada")
        self.comprobar_rechazo(400, self.nuevo_horario, self.seccion, self.salon,
                              "14:00", "15:00", regla="regla_horario_cerrado")
        self.comprobar_rechazo(400, self.cambiar_horario, dia_semana=2,
                              regla="regla_horario_cerrado")
        self.comprobar_rechazo(400, horarios_seccion.borrar_horario_seccion, self.horario,
                              regla="regla_horario_cerrado")
        self.comprobar_rechazo(400, self.cambiar_horario, self.otro_horario,
                              id_seccion=self.seccion, regla="regla_horario_cerrado")
        self.comprobar_rechazo(400, salones.modificar_salon, self.salon,
            SalonActualizar(id_sede=self.sedes[1], codigo="No guardar", capacidad=10),
            regla="regla_salon_historial")
        actual = periodos_academicos.consultar_periodo_academico(self.periodo)
        self.comprobar_rechazo(400, periodos_academicos.modificar_periodo_academico,
            self.periodo, PeriodoAcademicoActualizar(
                codigo=actual.codigo, nombre="No guardar",
                fecha_inicio=self.inicio + timedelta(days=1), fecha_fin=self.fin),
            regla="regla_periodo_historial")
        # El SQL permite nombre/codigo del periodo y capacidad/codigo del salon.
        periodos_academicos.modificar_periodo_academico(self.periodo, PeriodoAcademicoActualizar(
            codigo=actual.codigo, nombre="Nombre permitido",
            fecha_inicio=self.inicio, fecha_fin=self.fin))
        salones.modificar_salon(self.salon, SalonActualizar(
            id_sede=self.sedes[0], codigo="Permitido", capacidad=20))
        self.assertEqual(self.valor("""
            SELECT estado FROM public.asignacion_curso WHERE id_asignacion_curso = :id
        """, id=asignacion), "aprobada")
        self.assertEqual(self.valor("""
            SELECT puntaje_obtenido FROM public.calificacion WHERE id_asignacion_curso = :id
        """, id=asignacion), 80)
        self.assertEqual(secciones.consultar_seccion(self.seccion).codigo, "A")
