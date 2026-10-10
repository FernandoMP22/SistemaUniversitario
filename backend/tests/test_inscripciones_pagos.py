import os
import unittest
from datetime import date
from decimal import Decimal
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
from backend.routers import asignaciones_cursos, inscripciones, pagos
from backend.schemas.asignacion_curso import (
    AsignacionCursoActualizar, AsignacionCursoCrear, AsignacionCursoRespuesta,
)
from backend.schemas.inscripcion import (
    InscripcionActualizar, InscripcionCrear, InscripcionRespuesta,
)
from backend.schemas.pago import PagoActualizar, PagoCrear, PagoRespuesta


def tearDownModule():
    engine.dispose()


INSCRIPCION = dict(id_estudiante=1, id_periodo_academico=1)
ASIGNACION = dict(id_inscripcion=1, id_seccion=1)
PAGO = dict(id_inscripcion=1, numero_comprobante="COMP-1",
            concepto="matricula", monto="150.25")


class EsquemasInscripcionesPagos(unittest.TestCase):
    def test_referencias_enteras_y_fechas_validas(self):
        for esquema, datos, campo_fecha in (
            (InscripcionCrear, INSCRIPCION, "fecha_inscripcion"),
            (AsignacionCursoCrear, ASIGNACION, "fecha_asignacion"),
            (PagoCrear, PAGO, "fecha_pago"),
        ):
            self.assertIsNone(getattr(esquema(**datos), campo_fecha))
            self.assertEqual(getattr(esquema(**datos, **{campo_fecha: "2026-10-09"}),
                                     campo_fecha), date(2026, 10, 9))
            with self.assertRaises(ValidationError):
                esquema(**datos, **{campo_fecha: "2026-02-30"})
            for campo in datos:
                if campo.startswith("id_"):
                    esquema(**{**datos, campo: 2147483647})
                    for valor in (0, -1, 2147483648, True, "1", 1.5, None):
                        with self.assertRaises(ValidationError):
                            esquema(**{**datos, campo: valor})

    def test_monto_decimal_precision_escala_y_valores_finitos(self):
        for monto in ("0.01", "99999999.99", Decimal("150.25"), 150):
            self.assertIsInstance(PagoCrear(**{**PAGO, "monto": monto}).monto, Decimal)
        for monto in ("0", "-1", "0.001", "123.456", "100000000",
                      "NaN", "Infinity", "-Infinity", True, None):
            with self.subTest(monto=monto):
                with self.assertRaises(ValidationError):
                    PagoCrear(**{**PAGO, "monto": monto})

    def test_comprobante_y_catalogos_sin_tildes(self):
        PagoCrear(**{**PAGO, "numero_comprobante": "C" * 50})
        for comprobante in ("", "C" * 51, None):
            with self.assertRaises(ValidationError):
                PagoCrear(**{**PAGO, "numero_comprobante": comprobante})
        for concepto in ("matrícula", "Matricula", "otro", None):
            with self.assertRaises(ValidationError):
                PagoCrear(**{**PAGO, "concepto": concepto})

    def test_anio_mes_y_coherencia_del_concepto(self):
        mensualidad = {**PAGO, "concepto": "mensualidad",
                       "anio_mensualidad": 2027, "mes_mensualidad": 1}
        for anio in (1, 32767):
            PagoCrear(**{**mensualidad, "anio_mensualidad": anio})
        for mes in (1, 12):
            PagoCrear(**{**mensualidad, "mes_mensualidad": mes})
        for campo, valores in (
            ("anio_mensualidad", (0, -1, 32768, True, "2027", 1.5, None)),
            ("mes_mensualidad", (0, 13, True, "1", 1.5, None)),
        ):
            for valor in valores:
                with self.assertRaises(ValidationError):
                    PagoCrear(**{**mensualidad, campo: valor})
        for datos in ({**PAGO, "anio_mensualidad": 2027},
                      {**PAGO, "mes_mensualidad": 1},
                      {**PAGO, "concepto": "mensualidad"}):
            with self.assertRaises(ValidationError):
                PagoCrear(**datos)

    def test_campos_inmutables_y_estados_iniciales_no_recibidos(self):
        for esquema, datos in ((InscripcionCrear, INSCRIPCION),
                               (AsignacionCursoCrear, ASIGNACION), (PagoCrear, PAGO)):
            for campo in ("estado", "id_registro", "nota_final"):
                with self.assertRaises(ValidationError):
                    esquema(**datos, **{campo: "aprobada"})
        for esquema, datos in (
            (InscripcionActualizar, {**INSCRIPCION, "fecha_inscripcion": "2026-10-09"}),
            (AsignacionCursoActualizar, {**ASIGNACION, "fecha_asignacion": "2026-10-09"}),
            (PagoActualizar, {**PAGO, "fecha_pago": "2026-10-09",
                              "anio_mensualidad": 2027, "mes_mensualidad": 1}),
        ):
            estado = "anulado" if esquema is PagoActualizar else "cancelada"
            for campo, valor in datos.items():
                with self.assertRaises(ValidationError):
                    esquema(estado=estado, **{campo: valor})

    def test_actualizaciones_solo_con_estados_permitidos(self):
        for estado in ("activa", "cancelada", "finalizada"):
            InscripcionActualizar(estado=estado)
        for estado in ("cursando", "cancelada"):
            AsignacionCursoActualizar(estado=estado)
        PagoActualizar(estado="anulado")
        for esquema, estados in (
            (InscripcionActualizar, ("cursando", "aprobada", "Activa")),
            (AsignacionCursoActualizar, ("aprobada", "reprobada", "activa")),
            (PagoActualizar, ("registrado", "cancelada", "Anulado")),
        ):
            for estado in estados:
                with self.assertRaises(ValidationError):
                    esquema(estado=estado)
            with self.assertRaises(ValidationError):
                esquema()

    def test_openapi_no_expone_delete_ni_resultados_en_entrada(self):
        rutas = app.openapi()["paths"]
        for ruta, identificador in (
            ("inscripciones", "id_inscripcion"),
            ("asignaciones-cursos", "id_asignacion_curso"), ("pagos", "id_pago"),
        ):
            self.assertEqual(set(rutas[f"/{ruta}"]), {"get", "post"})
            self.assertEqual(set(rutas[f"/{ruta}/{{{identificador}}}"]), {"get", "put"})
        esquema = AsignacionCursoActualizar.model_json_schema()
        self.assertEqual(esquema["properties"]["estado"]["enum"], ["cursando", "cancelada"])
        self.assertFalse(esquema["additionalProperties"])


class ErroresSimuladosInscripcionesPagos(unittest.TestCase):
    def test_errores_en_commit_hacen_rollback_en_las_seis_escrituras(self):
        operaciones = (
            (inscripciones.registrar_inscripcion, (InscripcionCrear(**INSCRIPCION),)),
            (inscripciones.modificar_inscripcion, (1, InscripcionActualizar(estado="cancelada"))),
            (asignaciones_cursos.registrar_asignacion_curso, (AsignacionCursoCrear(**ASIGNACION),)),
            (asignaciones_cursos.modificar_asignacion_curso,
             (1, AsignacionCursoActualizar(estado="cancelada"))),
            (pagos.registrar_pago, (PagoCrear(**PAGO),)),
            (pagos.modificar_pago, (1, PagoActualizar(estado="anulado"))),
        )
        for operacion, argumentos in operaciones:
            for codigo, estado in (("23503", 409), ("23505", 409), ("23514", 400)):
                with self.subTest(operacion=operacion.__name__, codigo=codigo):
                    session = Mock()
                    session.commit.side_effect = DBAPIError(None, None, Mock(sqlstate=codigo))
                    with patch.object(transacciones, "SessionLocal", return_value=session):
                        with self.assertRaises(HTTPException) as resultado:
                            operacion(*argumentos)
                    self.assertEqual(resultado.exception.status_code, estado)
                    session.rollback.assert_called_once()
                    session.close.assert_called_once()

    def test_reintentos_40001_limitados_y_operacion_completa(self):
        for operacion, datos in (
            (inscripciones.registrar_inscripcion, InscripcionCrear(**INSCRIPCION)),
            (asignaciones_cursos.registrar_asignacion_curso, AsignacionCursoCrear(**ASIGNACION)),
            (pagos.registrar_pago, PagoCrear(**PAGO)),
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
                session.add.assert_called_once()
                session.rollback.assert_called_once()
                session.close.assert_called_once()


@unittest.skipUnless(os.getenv("PROBAR_POSTGRESQL") == "1", "Activar PROBAR_POSTGRESQL=1")
class InscripcionesPagosPostgreSQL(unittest.TestCase):
    """Filas propias en una transaccion externa que siempre termina en rollback."""

    def setUp(self):
        self.conexion = engine.connect()
        self.transaccion = self.conexion.begin()
        self.addCleanup(self.conexion.close)
        self.addCleanup(self.transaccion.rollback)
        self.assertEqual(self.valor("SHOW transaction_isolation"), "serializable")
        self.parches = []
        self.addCleanup(self.cerrar_parches)
        for modulo in (inscripciones, asignaciones_cursos, pagos, transacciones):
            parche = patch.object(modulo, "SessionLocal", side_effect=self.crear_sesion)
            parche.start()
            self.parches.append(parche)
        self.token = uuid4().hex[:10]
        facultad = self.valor("""
            INSERT INTO public.facultad (codigo, nombre)
            VALUES (:codigo, 'Facultad temporal') RETURNING id_facultad
        """, codigo=self.token)
        self.carrera = self.valor("""
            INSERT INTO public.carrera (id_facultad, codigo, nombre)
            VALUES (:facultad, :codigo, 'Carrera temporal') RETURNING id_carrera
        """, facultad=facultad, codigo=self.token)
        self.estudiantes = []
        self.cursos = []
        self.docentes = []
        for numero in range(3):
            codigo = self.token + str(numero)
            self.estudiantes.append(self.valor("""
                INSERT INTO public.estudiante
                    (id_carrera, carne, nombres, apellidos, fecha_nacimiento, correo)
                VALUES (:carrera, :codigo, 'Luis', 'Perez', '2001-01-01', 'test@example.com')
                RETURNING id_estudiante
            """, carrera=self.carrera, codigo=codigo))
            self.cursos.append(self.valor("""
                INSERT INTO public.curso (codigo, nombre)
                VALUES (:codigo, 'Curso temporal') RETURNING id_curso
            """, codigo=codigo))
            self.docentes.append(self.valor("""
                INSERT INTO public.docente (codigo, nombres, apellidos, correo)
                VALUES (:codigo, 'Ana', 'Perez', 'test@example.com') RETURNING id_docente
            """, codigo=codigo))
        for curso in self.cursos[:2]:
            self.conexion.execute(text("""
                INSERT INTO public.plan_estudio (id_carrera, id_curso, semestre_sugerido)
                VALUES (:carrera, :curso, 1)
            """), dict(carrera=self.carrera, curso=curso))
        ultima_fecha = self.valor("SELECT max(fecha_fin) FROM public.periodo_academico")
        anio = max(2030, ultima_fecha.year + 1 if ultima_fecha else 2030)
        self.inicio_anterior = date(anio, 1, 15)
        self.inicio = date(anio, 6, 15)
        self.fin = date(anio, 9, 15)
        self.periodo_anterior = self.valor("""
            INSERT INTO public.periodo_academico (codigo, nombre, fecha_inicio, fecha_fin)
            VALUES (:codigo, 'Anterior temporal', :inicio, :fin) RETURNING id_periodo_academico
        """, codigo=self.token + "P", inicio=self.inicio_anterior, fin=date(anio, 5, 15))
        self.periodo = self.valor("""
            INSERT INTO public.periodo_academico (codigo, nombre, fecha_inicio, fecha_fin)
            VALUES (:codigo, 'Actual temporal', :inicio, :fin) RETURNING id_periodo_academico
        """, codigo=self.token + "Q", inicio=self.inicio, fin=self.fin)
        sede = self.valor("""
            INSERT INTO public.sede (codigo, nombre, direccion)
            VALUES (:codigo, 'Sede temporal', 'Direccion') RETURNING id_sede
        """, codigo=self.token)
        self.salones = []
        for numero in range(3):
            self.salones.append(self.valor("""
                INSERT INTO public.salon (id_sede, codigo, capacidad)
                VALUES (:sede, :codigo, 10) RETURNING id_salon
            """, sede=sede, codigo=str(numero)))
        self.seccion = self.nueva_seccion(0, 0, "A")
        self.seccion_alternativa = self.nueva_seccion(0, 1, "B")
        self.seccion_cruce = self.nueva_seccion(1, 1, "A")
        self.seccion_fuera_plan = self.nueva_seccion(2, 2, "A")
        self.seccion_anterior = self.nueva_seccion(0, 0, "A", self.periodo_anterior)
        self.agregar_horario(self.seccion, 0, "09:00", "10:00")
        self.agregar_horario(self.seccion_alternativa, 1, "11:00", "12:00")
        self.agregar_horario(self.seccion_cruce, 1, "09:30", "10:30")
        self.agregar_horario(self.seccion_fuera_plan, 2, "14:00", "15:00")
        self.agregar_horario(self.seccion_anterior, 0, "09:00", "10:00")
        self.comprobar_reglas()
        self.inscripcion = self.inscribir(self.estudiantes[0])

    def valor(self, sql, **parametros):
        return self.conexion.execute(text(sql), parametros).scalar_one()

    def crear_sesion(self):
        session = Session(bind=self.conexion, expire_on_commit=False,
                          join_transaction_mode="create_savepoint")
        event.listen(session, "before_commit", self.comprobar_reglas_diferidas)
        return session

    @staticmethod
    def comprobar_reglas_diferidas(session):
        # RELEASE SAVEPOINT no ejecuta las reglas diferidas del COMMIT.
        session.flush()
        session.execute(text("SET CONSTRAINTS ALL IMMEDIATE"))
        session.execute(text("SET CONSTRAINTS ALL DEFERRED"))

    def cerrar_parches(self):
        for parche in reversed(self.parches):
            parche.stop()

    def comprobar_reglas(self):
        self.conexion.execute(text("SET CONSTRAINTS ALL IMMEDIATE"))
        self.conexion.execute(text("SET CONSTRAINTS ALL DEFERRED"))

    def nueva_seccion(self, curso, docente, codigo, periodo=None):
        return self.valor("""
            INSERT INTO public.seccion
                (id_curso, id_periodo_academico, id_docente, codigo, cupo_maximo)
            VALUES (:curso, :periodo, :docente, :codigo, 1) RETURNING id_seccion
        """, curso=self.cursos[curso], periodo=periodo or self.periodo,
            docente=self.docentes[docente], codigo=codigo)

    def agregar_horario(self, seccion, salon, inicio, fin):
        self.conexion.execute(text("""
            INSERT INTO public.horario_seccion
                (id_seccion, id_salon, dia_semana, hora_inicio, hora_fin)
            VALUES (:seccion, :salon, 1, :inicio, :fin)
        """), dict(seccion=seccion, salon=self.salones[salon], inicio=inicio, fin=fin))

    def inscribir(self, estudiante, periodo=None):
        return inscripciones.registrar_inscripcion(InscripcionCrear(
            id_estudiante=estudiante, id_periodo_academico=periodo or self.periodo)).id_inscripcion

    def asignar(self, seccion=None, inscripcion=None):
        return asignaciones_cursos.registrar_asignacion_curso(AsignacionCursoCrear(
            id_inscripcion=inscripcion or self.inscripcion,
            id_seccion=seccion or self.seccion)).id_asignacion_curso

    def cambiar_inscripcion(self, estado, identificador=None):
        return inscripciones.modificar_inscripcion(
            identificador or self.inscripcion, InscripcionActualizar(estado=estado))

    def cambiar_asignacion(self, identificador, estado):
        return asignaciones_cursos.modificar_asignacion_curso(
            identificador, AsignacionCursoActualizar(estado=estado))

    def registrar_pago(self, **cambios):
        datos = dict(id_inscripcion=self.inscripcion, numero_comprobante=uuid4().hex,
                     concepto="matricula", monto="150.25")
        return pagos.registrar_pago(PagoCrear(**{**datos, **cambios}))

    def anular_pago(self, identificador):
        return pagos.modificar_pago(identificador, PagoActualizar(estado="anulado"))

    def comprobar_rechazo(self, estado, operacion, *argumentos, regla=None, **opciones):
        with self.assertRaises(HTTPException) as resultado:
            operacion(*argumentos, **opciones)
        self.assertEqual(resultado.exception.status_code, estado)
        if regla is not None:
            self.assertEqual(resultado.exception.__cause__.orig.diag.constraint_name, regla)

    def comprobar_rechazo_sql(self, sql, regla, **parametros):
        def operacion(session):
            session.execute(text(sql), parametros)
        with self.assertRaises(DBAPIError) as resultado:
            transacciones.ejecutar_transaccion(operacion)
        self.assertEqual(resultado.exception.orig.sqlstate, "23514")
        self.assertEqual(resultado.exception.orig.diag.constraint_name, regla)

    def cerrar_historial_temporal(self, seccion, asignaciones, puntajes, fecha):
        actividad = self.valor("""
            INSERT INTO public.actividad_academica
                (id_seccion, nombre, tipo, fecha, puntaje_maximo)
            VALUES (:seccion, 'Examen', 'examen', :fecha, 100)
            RETURNING id_actividad_academica
        """, seccion=seccion, fecha=fecha)
        for asignacion, puntaje in zip(asignaciones, puntajes):
            self.conexion.execute(text("""
                INSERT INTO public.calificacion
                    (id_actividad_academica, id_asignacion_curso, puntaje_obtenido)
                VALUES (:actividad, :asignacion, :puntaje)
            """), dict(actividad=actividad, asignacion=asignacion, puntaje=puntaje))
        # La funcion existente solo prepara historial; no se agrega API de cierre.
        self.conexion.execute(text("SELECT public.cerrar_calificaciones(:seccion)"),
                              dict(seccion=seccion))
        self.comprobar_reglas()

    def test_creacion_consulta_defaults_y_decimal(self):
        asignacion = self.asignar()
        pago = self.registrar_pago(monto="99999999.99")
        hoy_sql = self.valor("SELECT CURRENT_DATE")
        inscripcion = InscripcionRespuesta.model_validate(
            inscripciones.consultar_inscripcion(self.inscripcion))
        respuesta = AsignacionCursoRespuesta.model_validate(
            asignaciones_cursos.consultar_asignacion_curso(asignacion))
        respuesta_pago = PagoRespuesta.model_validate(pago)
        self.assertEqual(inscripcion.estado, "activa")
        self.assertEqual(respuesta.estado, "cursando")
        self.assertEqual(respuesta_pago.estado, "registrado")
        self.assertEqual(inscripcion.fecha_inscripcion, hoy_sql)
        self.assertEqual(respuesta.fecha_asignacion, hoy_sql)
        self.assertEqual(respuesta_pago.fecha_pago, hoy_sql)
        self.assertEqual(respuesta_pago.monto, Decimal("99999999.99"))
        self.assertEqual(respuesta_pago.model_dump(mode="json")["monto"], "99999999.99")
        self.assertTrue(inscripciones.listar_inscripciones())
        self.assertTrue(asignaciones_cursos.listar_asignaciones_cursos())
        self.assertTrue(pagos.listar_pagos())
        PagoRespuesta.model_validate(pagos.consultar_pago(pago.id_pago))

    def test_fechas_explicitas_se_conservan(self):
        inscripcion = inscripciones.registrar_inscripcion(InscripcionCrear(
            id_estudiante=self.estudiantes[1], id_periodo_academico=self.periodo,
            fecha_inscripcion="2026-01-01"))
        asignacion = asignaciones_cursos.registrar_asignacion_curso(AsignacionCursoCrear(
            id_inscripcion=inscripcion.id_inscripcion, id_seccion=self.seccion,
            fecha_asignacion="2026-01-02"))
        pago = self.registrar_pago(fecha_pago="2026-01-03")
        self.assertEqual(self.cambiar_inscripcion("cancelada",
            inscripcion.id_inscripcion).fecha_inscripcion, date(2026, 1, 1))
        self.assertEqual(self.cambiar_asignacion(
            asignacion.id_asignacion_curso, "cancelada").fecha_asignacion, date(2026, 1, 2))
        self.assertEqual(self.anular_pago(pago.id_pago).fecha_pago, date(2026, 1, 3))

    def test_referencias_inexistentes_y_filas_ausentes(self):
        ausente = 2147483647
        for datos in ({**INSCRIPCION, "id_estudiante": ausente,
                       "id_periodo_academico": self.periodo},
                      {**INSCRIPCION, "id_estudiante": self.estudiantes[0],
                       "id_periodo_academico": ausente}):
            self.comprobar_rechazo(409, inscripciones.registrar_inscripcion,
                                  InscripcionCrear(**datos))
        self.comprobar_rechazo(409, self.asignar, inscripcion=ausente)
        self.comprobar_rechazo(409, self.asignar, seccion=ausente)
        self.comprobar_rechazo(409, self.registrar_pago, id_inscripcion=ausente)
        for consultar, modificar, esquema, estado in (
            (inscripciones.consultar_inscripcion, inscripciones.modificar_inscripcion,
             InscripcionActualizar, "cancelada"),
            (asignaciones_cursos.consultar_asignacion_curso,
             asignaciones_cursos.modificar_asignacion_curso, AsignacionCursoActualizar, "cancelada"),
            (pagos.consultar_pago, pagos.modificar_pago, PagoActualizar, "anulado"),
        ):
            self.comprobar_rechazo(404, consultar, ausente)
            self.comprobar_rechazo(404, modificar, ausente, esquema(estado=estado))

    def test_duplicados_inscripcion_asignacion_y_comprobante(self):
        self.comprobar_rechazo(409, self.inscribir, self.estudiantes[0])
        asignacion = self.asignar()
        self.comprobar_rechazo(409, self.asignar)
        self.cambiar_asignacion(asignacion, "cancelada")
        self.comprobar_rechazo(409, self.asignar)
        pago = self.registrar_pago()
        self.anular_pago(pago.id_pago)
        self.comprobar_rechazo(409, self.registrar_pago,
                              numero_comprobante=pago.numero_comprobante)
        self.cambiar_inscripcion("cancelada")
        self.comprobar_rechazo(409, self.inscribir, self.estudiantes[0])

    def test_unicidad_parcial_y_reemplazos_tras_anulacion(self):
        matricula = self.registrar_pago()
        self.comprobar_rechazo(409, self.registrar_pago)
        self.anular_pago(matricula.id_pago)
        reemplazo = self.registrar_pago()
        self.assertNotEqual(reemplazo.id_pago, matricula.id_pago)
        mensualidad = dict(concepto="mensualidad", anio_mensualidad=self.inicio.year,
                           mes_mensualidad=self.inicio.month)
        pago = self.registrar_pago(**mensualidad)
        self.comprobar_rechazo(409, self.registrar_pago, **mensualidad)
        self.anular_pago(pago.id_pago)
        self.registrar_pago(**mensualidad)
        self.registrar_pago(**{**mensualidad, "mes_mensualidad": 7})
        self.assertEqual(pagos.consultar_pago(pago.id_pago).estado, "anulado")

    def test_mes_del_periodo_incluye_limites_parciales_y_rechaza_fuera(self):
        for mes in (6, 9):
            self.registrar_pago(concepto="mensualidad",
                                anio_mensualidad=self.inicio.year, mes_mensualidad=mes)
        for anio, mes in ((self.inicio.year, 5), (self.inicio.year, 10),
                          (self.inicio.year + 1, 6)):
            self.comprobar_rechazo(400, self.registrar_pago, concepto="mensualidad",
                anio_mensualidad=anio, mes_mensualidad=mes, regla="regla_pago_periodo")
        self.assertEqual(self.valor("""
            SELECT count(*) FROM public.pago WHERE id_inscripcion = :id
        """, id=self.inscripcion), 2)

    def test_cancelacion_y_reactivacion_de_inscripcion_y_asignacion(self):
        asignacion = self.asignar()
        self.cambiar_inscripcion("cancelada")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(asignacion).estado, "cancelada")
        self.comprobar_rechazo(400, self.cambiar_asignacion, asignacion, "cursando",
                              regla="regla_asignacion_inscripcion_activa")
        self.comprobar_rechazo(400, self.asignar, self.seccion_alternativa,
                              regla="regla_asignacion_inscripcion_activa")
        self.cambiar_inscripcion("activa")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(asignacion).estado, "cancelada")
        self.assertEqual(self.cambiar_asignacion(asignacion, "cursando").estado, "cursando")

    def test_finalizacion_rechazada_y_finalizada_inmutable(self):
        asignacion = self.asignar()
        self.comprobar_rechazo(400, self.cambiar_inscripcion, "finalizada",
                              regla="regla_inscripcion_finalizar")
        self.assertEqual(inscripciones.consultar_inscripcion(self.inscripcion).estado, "activa")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(asignacion).estado, "cursando")
        self.cambiar_asignacion(asignacion, "cancelada")
        self.assertEqual(self.cambiar_inscripcion("finalizada").estado, "finalizada")
        for estado in ("activa", "cancelada"):
            self.comprobar_rechazo(400, self.cambiar_inscripcion, estado,
                                  regla="regla_inscripcion_finalizada")
        self.comprobar_rechazo(400, self.cambiar_asignacion, asignacion, "cursando")
        self.comprobar_rechazo(400, self.asignar, self.seccion_alternativa)

    def test_cancelar_libera_cupo_y_reactivar_revalida(self):
        primera = self.asignar()
        otra_inscripcion = self.inscribir(self.estudiantes[1])
        self.comprobar_rechazo(400, self.asignar, inscripcion=otra_inscripcion,
                              regla="regla_asignacion_cupo")
        self.cambiar_asignacion(primera, "cancelada")
        segunda = self.asignar(inscripcion=otra_inscripcion)
        self.comprobar_rechazo(400, self.cambiar_asignacion, primera, "cursando",
                              regla="regla_asignacion_cupo")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(primera).estado, "cancelada")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(segunda).estado, "cursando")

    def test_mismo_curso_en_dos_secciones_y_rollback(self):
        primera = self.asignar()
        self.comprobar_rechazo(400, self.asignar, self.seccion_alternativa,
                              regla="regla_asignacion_curso_unico")
        self.cambiar_asignacion(primera, "cancelada")
        self.asignar(self.seccion_alternativa)
        self.comprobar_rechazo(400, self.cambiar_asignacion, primera, "cursando",
                              regla="regla_asignacion_curso_unico")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(primera).estado, "cancelada")

    def test_periodo_plan_y_horario_obligatorios(self):
        self.comprobar_rechazo(400, self.asignar, self.seccion_anterior,
                              regla="regla_asignacion_periodo")
        self.comprobar_rechazo(400, self.asignar, self.seccion_fuera_plan,
                              regla="regla_asignacion_plan")
        sin_horario = self.nueva_seccion(1, 2, "Sin horario")
        self.comprobar_rechazo(400, self.asignar, sin_horario,
                              regla="regla_asignacion_horario")
        self.assertEqual(self.valor("""
            SELECT count(*) FROM public.asignacion_curso WHERE id_inscripcion = :id
        """, id=self.inscripcion), 0)

    def test_cruce_del_estudiante_y_reactivacion(self):
        primera = self.asignar()
        self.comprobar_rechazo(400, self.asignar, self.seccion_cruce,
                              regla="regla_asignacion_horario_estudiante")
        self.cambiar_asignacion(primera, "cancelada")
        self.asignar(self.seccion_cruce)
        self.comprobar_rechazo(400, self.cambiar_asignacion, primera, "cursando",
                              regla="regla_asignacion_horario_estudiante")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(primera).estado, "cancelada")

    def test_prerrequisitos_aprobados_antes_y_curso_ya_aprobado(self):
        self.conexion.execute(text("""
            INSERT INTO public.prerrequisito (id_curso, id_curso_requisito)
            VALUES (:curso, :requisito)
        """), dict(curso=self.cursos[1], requisito=self.cursos[0]))
        self.comprobar_rechazo(400, self.asignar, self.seccion_cruce,
                              regla="regla_prerrequisitos_aprobados")
        anterior = self.inscribir(self.estudiantes[0], self.periodo_anterior)
        asignacion = self.asignar(self.seccion_anterior, anterior)
        self.cerrar_historial_temporal(self.seccion_anterior, [asignacion], [80], self.inicio_anterior)
        self.asignar(self.seccion_cruce)
        self.comprobar_rechazo(400, self.asignar, regla="regla_curso_ya_aprobado")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(asignacion).estado, "aprobada")

    def test_aprobacion_en_mismo_periodo_no_satisface_prerrequisito(self):
        self.conexion.execute(text("""
            INSERT INTO public.prerrequisito (id_curso, id_curso_requisito)
            VALUES (:curso, :requisito)
        """), dict(curso=self.cursos[1], requisito=self.cursos[0]))
        asignacion = self.asignar()
        self.cerrar_historial_temporal(self.seccion, [asignacion], [80], self.inicio)
        self.comprobar_rechazo(400, self.asignar, self.seccion_cruce,
                              regla="regla_prerrequisitos_aprobados")

    def test_reprobacion_anterior_permite_repetir_y_no_aprobar_requisito(self):
        anterior = self.inscribir(self.estudiantes[0], self.periodo_anterior)
        asignacion = self.asignar(self.seccion_anterior, anterior)
        self.cerrar_historial_temporal(self.seccion_anterior, [asignacion], [40], self.inicio_anterior)
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(asignacion).estado, "reprobada")
        for estado in ("cursando", "cancelada"):
            self.comprobar_rechazo(400, self.cambiar_asignacion, asignacion, estado,
                                  regla="regla_resultado_inmutable")
        self.asignar()
        self.conexion.execute(text("""
            INSERT INTO public.prerrequisito (id_curso, id_curso_requisito)
            VALUES (:curso, :requisito)
        """), dict(curso=self.cursos[1], requisito=self.cursos[0]))
        self.comprobar_rechazo(400, self.asignar, self.seccion_cruce,
                              regla="regla_prerrequisitos_aprobados")

    def test_reactivacion_revalida_plan_y_horario(self):
        asignacion = self.asignar()
        self.cambiar_asignacion(asignacion, "cancelada")
        self.conexion.execute(text("""
            DELETE FROM public.plan_estudio WHERE id_carrera = :carrera AND id_curso = :curso
        """), dict(carrera=self.carrera, curso=self.cursos[0]))
        self.comprobar_rechazo(400, self.cambiar_asignacion, asignacion, "cursando",
                              regla="regla_asignacion_plan")
        self.conexion.execute(text("""
            INSERT INTO public.plan_estudio (id_carrera, id_curso, semestre_sugerido)
            VALUES (:carrera, :curso, 1)
        """), dict(carrera=self.carrera, curso=self.cursos[0]))
        self.conexion.execute(text("DELETE FROM public.horario_seccion WHERE id_seccion = :id"),
                              dict(id=self.seccion))
        self.comprobar_rechazo(400, self.cambiar_asignacion, asignacion, "cursando",
                              regla="regla_asignacion_horario")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(asignacion).estado, "cancelada")

    def test_reactivacion_revalida_nuevos_prerrequisitos(self):
        asignacion = self.asignar(self.seccion_cruce)
        self.cambiar_asignacion(asignacion, "cancelada")
        self.conexion.execute(text("""
            INSERT INTO public.prerrequisito (id_curso, id_curso_requisito)
            VALUES (:curso, :requisito)
        """), dict(curso=self.cursos[1], requisito=self.cursos[0]))
        self.comprobar_rechazo(400, self.cambiar_asignacion, asignacion, "cursando",
                              regla="regla_prerrequisitos_aprobados")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(asignacion).estado, "cancelada")

    def test_resultados_y_secciones_cerradas_se_conservan(self):
        otra = self.asignar(self.seccion_cruce)
        self.cambiar_asignacion(otra, "cancelada")
        asignacion = self.asignar()
        self.cerrar_historial_temporal(self.seccion, [asignacion], [80], self.inicio)
        self.cerrar_historial_temporal(self.seccion_cruce, [], [], self.inicio)
        for estado in ("cursando", "cancelada"):
            self.comprobar_rechazo(400, self.cambiar_asignacion, asignacion, estado,
                                  regla="regla_resultado_inmutable")
        self.comprobar_rechazo(400, self.cambiar_asignacion, otra, "cursando",
                              regla="regla_asignacion_seccion_cerrada")
        nueva_inscripcion = self.inscribir(self.estudiantes[1])
        self.comprobar_rechazo(400, self.asignar, inscripcion=nueva_inscripcion,
                              regla="regla_asignacion_seccion_cerrada")
        self.cambiar_inscripcion("cancelada")
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(asignacion).estado, "aprobada")
        self.assertEqual(self.cambiar_inscripcion("finalizada").estado, "finalizada")
        self.assertEqual(self.valor("""
            SELECT puntaje_obtenido FROM public.calificacion WHERE id_asignacion_curso = :id
        """, id=asignacion), 80)

    def test_pagos_no_bloquean_asignaciones_ni_cambian_resultados(self):
        asignacion = self.asignar()
        self.assertEqual(self.valor("""
            SELECT count(*) FROM public.pago WHERE id_inscripcion = :id
        """, id=self.inscripcion), 0)
        pago = self.registrar_pago()
        self.anular_pago(pago.id_pago)
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(asignacion).estado, "cursando")
        self.cambiar_inscripcion("cancelada")
        self.registrar_pago()
        self.cambiar_inscripcion("finalizada")
        self.registrar_pago(concepto="mensualidad",
                            anio_mensualidad=self.inicio.year, mes_mensualidad=6)

    def test_identidad_y_eliminaciones_protegidas_directamente_en_postgresql(self):
        asignacion = self.asignar()
        pago = self.registrar_pago()
        for sql, regla, parametros in (
            ("DELETE FROM public.inscripcion WHERE id_inscripcion = :id",
             "regla_inscripcion_conservar", dict(id=self.inscripcion)),
            ("DELETE FROM public.asignacion_curso WHERE id_asignacion_curso = :id",
             "regla_asignacion_conservar", dict(id=asignacion)),
            ("DELETE FROM public.pago WHERE id_pago = :id",
             "regla_pago_conservar", dict(id=pago.id_pago)),
            ("UPDATE public.inscripcion SET fecha_inscripcion = fecha_inscripcion + 1 WHERE id_inscripcion = :id",
             "regla_inscripcion_identidad", dict(id=self.inscripcion)),
            ("UPDATE public.asignacion_curso SET fecha_asignacion = fecha_asignacion + 1 WHERE id_asignacion_curso = :id",
             "regla_asignacion_fecha", dict(id=asignacion)),
            ("UPDATE public.asignacion_curso SET id_seccion = :seccion WHERE id_asignacion_curso = :id",
             "regla_asignacion_identidad", dict(id=asignacion, seccion=self.seccion_alternativa)),
            ("UPDATE public.asignacion_curso SET estado = 'aprobada' WHERE id_asignacion_curso = :id",
             "regla_resultado_cierre", dict(id=asignacion)),
            ("UPDATE public.pago SET monto = 100 WHERE id_pago = :id",
             "regla_pago_identidad", dict(id=pago.id_pago)),
        ):
            self.comprobar_rechazo_sql(sql, regla, **parametros)
        self.anular_pago(pago.id_pago)
        self.comprobar_rechazo_sql(
            "UPDATE public.pago SET estado = 'registrado' WHERE id_pago = :id",
            "regla_pago_anulado", id=pago.id_pago)
        self.assertEqual(pagos.consultar_pago(pago.id_pago).monto, Decimal("150.25"))
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(asignacion).estado, "cursando")
