import os
import unittest
from datetime import date, timedelta
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
from backend.routers import (
    actividades_academicas, asignaciones_cursos, calificaciones,
    historial_academico, inscripciones, secciones,
)
from backend.schemas.actividad_academica import (
    ActividadAcademicaActualizar, ActividadAcademicaCrear, ActividadAcademicaRespuesta,
)
from backend.schemas.asignacion_curso import AsignacionCursoActualizar, AsignacionCursoCrear
from backend.schemas.calificacion import CalificacionActualizar, CalificacionCrear, CalificacionRespuesta
from backend.schemas.historial_academico import HistorialAcademicoRespuesta
from backend.schemas.inscripcion import InscripcionCrear
from backend.schemas.seccion import SeccionActualizar, SeccionCerrar, SeccionCrear, SeccionRespuesta


def tearDownModule():
    engine.dispose()


ACTIVIDAD = dict(id_seccion=1, nombre="Examen", tipo="examen",
                 fecha="2030-01-15", puntaje_maximo="100.00")
NOTA = dict(id_actividad_academica=1, id_asignacion_curso=1, puntaje_obtenido="61.00")


class EsquemasCalificacionesCierre(unittest.TestCase):
    def test_precision_escala_limites_y_valores_finitos(self):
        actividad_actualizar = {campo: valor for campo, valor in ACTIVIDAD.items()
                               if campo != "id_seccion"}
        for esquema, datos, campo, minimo in (
            (ActividadAcademicaCrear, ACTIVIDAD, "puntaje_maximo", "0.01"),
            (ActividadAcademicaActualizar, actividad_actualizar, "puntaje_maximo", "0.01"),
            (CalificacionCrear, NOTA, "puntaje_obtenido", "0.00"),
            (CalificacionActualizar, dict(puntaje_obtenido="61"), "puntaje_obtenido", "0.00"),
        ):
            for valor in (minimo, "100.00"):
                self.assertIsInstance(getattr(esquema(**{**datos, campo: valor}), campo), Decimal)
            for valor in ("-0.01", "100.01", "0.001", "123.456", "1000",
                          "NaN", "Infinity", True, None):
                with self.subTest(esquema=esquema.__name__, valor=valor):
                    with self.assertRaises(ValidationError):
                        esquema(**{**datos, campo: valor})
        with self.assertRaises(ValidationError):
            ActividadAcademicaCrear(**{**ACTIVIDAD, "puntaje_maximo": "0"})

    def test_longitud_catalogo_fecha_y_referencias(self):
        ActividadAcademicaCrear(**{**ACTIVIDAD, "nombre": "N" * 150})
        for nombre in ("", "N" * 151):
            with self.assertRaises(ValidationError):
                ActividadAcademicaCrear(**{**ACTIVIDAD, "nombre": nombre})
        for tipo in ("tarea", "proyecto", "examen", "otra"):
            ActividadAcademicaCrear(**{**ACTIVIDAD, "tipo": tipo})
        for tipo in ("Examen", "práctica", "otro"):
            with self.assertRaises(ValidationError):
                ActividadAcademicaCrear(**{**ACTIVIDAD, "tipo": tipo})
        with self.assertRaises(ValidationError):
            ActividadAcademicaCrear(**{**ACTIVIDAD, "fecha": "2030-02-30"})
        for esquema, datos in ((ActividadAcademicaCrear, ACTIVIDAD), (CalificacionCrear, NOTA)):
            for campo in datos:
                if campo.startswith("id_"):
                    esquema(**{**datos, campo: 2147483647})
                    for valor in (0, -1, 2147483648, True, "1", 1.5, None):
                        with self.assertRaises(ValidationError):
                            esquema(**{**datos, campo: valor})

    def test_actualizaciones_no_reciben_referencias_ni_resultados(self):
        editar_actividad = {campo: valor for campo, valor in ACTIVIDAD.items() if campo != "id_seccion"}
        for esquema, datos, prohibidos in (
            (ActividadAcademicaCrear, ACTIVIDAD, ("id_actividad_academica", "estado")),
            (ActividadAcademicaActualizar, editar_actividad, ("id_seccion", "id_actividad_academica")),
            (CalificacionCrear, NOTA, ("id_calificacion", "resultado")),
            (CalificacionActualizar, dict(puntaje_obtenido="61"),
             ("id_actividad_academica", "id_asignacion_curso", "id_calificacion")),
        ):
            for campo in (*prohibidos, "calificaciones_cerradas", "nota_final"):
                with self.assertRaises(ValidationError):
                    esquema(**datos, **{campo: 1})
            for campo in datos:
                incompletos = dict(datos)
                incompletos.pop(campo)
                with self.assertRaises(ValidationError):
                    esquema(**incompletos)
        for campo in ("calificaciones_cerradas", "aprobada", "puntaje_obtenido"):
            with self.assertRaises(ValidationError):
                SeccionCerrar(**{campo: True})
        SeccionCerrar()

    def test_openapi_rutas_y_cierre_sin_campos_editables(self):
        documento = app.openapi()
        rutas = documento["paths"]
        for ruta, identificador in (
            ("actividades-academicas", "id_actividad_academica"),
            ("calificaciones", "id_calificacion"),
        ):
            self.assertEqual(set(rutas[f"/{ruta}"]), {"get", "post"})
            self.assertEqual(set(rutas[f"/{ruta}/{{{identificador}}}"]), {"get", "put", "delete"})
        self.assertEqual(set(rutas["/secciones/{id_seccion}/cerrar-calificaciones"]), {"post"})
        self.assertEqual(set(rutas["/estudiantes/{id_estudiante}/historial-academico"]), {"get"})
        cierre = documento["components"]["schemas"]["SeccionCerrar"]
        self.assertFalse(cierre["additionalProperties"])
        self.assertEqual(cierre["properties"], {})
        for esquema in (SeccionCrear, SeccionActualizar):
            self.assertNotIn("calificaciones_cerradas", esquema.model_fields)


class ErroresSimuladosCalificacionesCierre(unittest.TestCase):
    def test_commit_rechazado_hace_rollback_en_siete_escrituras(self):
        datos_actualizar = {campo: valor for campo, valor in ACTIVIDAD.items() if campo != "id_seccion"}
        operaciones = (
            (actividades_academicas.registrar_actividad_academica, (ActividadAcademicaCrear(**ACTIVIDAD),)),
            (actividades_academicas.modificar_actividad_academica,
             (1, ActividadAcademicaActualizar(**datos_actualizar))),
            (actividades_academicas.borrar_actividad_academica, (1,)),
            (calificaciones.registrar_calificacion, (CalificacionCrear(**NOTA),)),
            (calificaciones.modificar_calificacion, (1, CalificacionActualizar(puntaje_obtenido="60"))),
            (calificaciones.borrar_calificacion, (1,)),
            (secciones.cerrar_calificaciones_seccion, (1,)),
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

    def test_cierre_reintenta_funcion_completa_y_agota_tres_intentos(self):
        sesiones = [Mock(), Mock(), Mock()]
        for session in sesiones:
            session.commit.side_effect = DBAPIError(None, None, Mock(sqlstate="40001"))
        with patch.object(transacciones, "SessionLocal", side_effect=sesiones):
            with patch.object(transacciones, "sleep"):
                with self.assertRaises(HTTPException) as resultado:
                    secciones.cerrar_calificaciones_seccion(1)
        self.assertEqual(resultado.exception.status_code, 503)
        for session in sesiones:
            llamadas_sql = [str(llamada.args[0]) for llamada in session.execute.call_args_list]
            self.assertIn("SELECT public.cerrar_calificaciones(:id_seccion)", llamadas_sql)
            session.refresh.assert_called_once()
            session.rollback.assert_called_once()
            session.close.assert_called_once()


@unittest.skipUnless(os.getenv("PROBAR_POSTGRESQL") == "1", "Activar PROBAR_POSTGRESQL=1")
class CalificacionesCierrePostgreSQL(unittest.TestCase):
    """Cada caso trabaja con filas propias y termina en rollback externo."""

    def setUp(self):
        self.conexion = engine.connect()
        self.transaccion = self.conexion.begin()
        self.addCleanup(self.conexion.close)
        self.addCleanup(self.transaccion.rollback)
        self.assertEqual(self.valor("SHOW transaction_isolation"), "serializable")
        self.parches = []
        self.addCleanup(self.cerrar_parches)
        for modulo in (actividades_academicas, calificaciones, historial_academico,
                       secciones, inscripciones, asignaciones_cursos, transacciones):
            parche = patch.object(modulo, "SessionLocal", side_effect=self.crear_sesion)
            parche.start()
            self.parches.append(parche)
        self.token = uuid4().hex[:10]
        facultad = self.valor("""
            INSERT INTO public.facultad (codigo, nombre)
            VALUES (:codigo, 'Facultad temporal') RETURNING id_facultad
        """, codigo=self.token)
        carrera = self.valor("""
            INSERT INTO public.carrera (id_facultad, codigo, nombre)
            VALUES (:facultad, :codigo, 'Carrera temporal') RETURNING id_carrera
        """, facultad=facultad, codigo=self.token)
        self.estudiantes = []
        for numero in range(4):
            self.estudiantes.append(self.valor("""
                INSERT INTO public.estudiante
                    (id_carrera, carne, nombres, apellidos, fecha_nacimiento, correo)
                VALUES (:carrera, :carne, 'Luis', 'Perez', '2001-01-01', 'test@example.com')
                RETURNING id_estudiante
            """, carrera=carrera, carne=self.token + str(numero)))
        self.cursos = []
        docentes = []
        for letra in ("A", "B"):
            curso = self.valor("""
                INSERT INTO public.curso (codigo, nombre)
                VALUES (:codigo, :nombre) RETURNING id_curso
            """, codigo=self.token + letra, nombre="Curso " + letra)
            self.cursos.append(curso)
            self.conexion.execute(text("""
                INSERT INTO public.plan_estudio (id_carrera, id_curso, semestre_sugerido)
                VALUES (:carrera, :curso, 1)
            """), dict(carrera=carrera, curso=curso))
            docentes.append(self.valor("""
                INSERT INTO public.docente (codigo, nombres, apellidos, correo)
                VALUES (:codigo, 'Ana', 'Perez', 'test@example.com') RETURNING id_docente
            """, codigo=self.token + letra))
        ultima_fecha = self.valor("SELECT max(fecha_fin) FROM public.periodo_academico")
        anio = max(2030, ultima_fecha.year + 1 if ultima_fecha else 2030)
        self.inicio = date(anio, 1, 15)
        self.fin = date(anio, 5, 15)
        self.inicio_siguiente = date(anio, 6, 15)
        self.periodo = self.nuevo_periodo("P", self.inicio, self.fin)
        self.periodo_siguiente = self.nuevo_periodo(
            "Q", self.inicio_siguiente, date(anio, 9, 15))
        sede = self.valor("""
            INSERT INTO public.sede (codigo, nombre, direccion)
            VALUES (:codigo, 'Sede temporal', 'Direccion') RETURNING id_sede
        """, codigo=self.token)
        salon = self.valor("""
            INSERT INTO public.salon (id_sede, codigo, capacidad)
            VALUES (:sede, 'A', 10) RETURNING id_salon
        """, sede=sede)
        self.seccion = self.nueva_seccion(self.cursos[0], docentes[0], self.periodo, "A")
        self.otra_seccion = self.nueva_seccion(self.cursos[1], docentes[1], self.periodo, "A")
        self.seccion_siguiente = self.nueva_seccion(
            self.cursos[0], docentes[0], self.periodo_siguiente, "A")
        for seccion, inicio, fin in (
            (self.seccion, "09:00", "10:00"), (self.otra_seccion, "11:00", "12:00"),
            (self.seccion_siguiente, "09:00", "10:00"),
        ):
            self.conexion.execute(text("""
                INSERT INTO public.horario_seccion
                    (id_seccion, id_salon, dia_semana, hora_inicio, hora_fin)
                VALUES (:seccion, :salon, 1, :inicio, :fin)
            """), dict(seccion=seccion, salon=salon, inicio=inicio, fin=fin))
        self.inscripciones = []
        self.asignaciones = []
        for estudiante in self.estudiantes[:2]:
            inscripcion = self.inscribir(estudiante, self.periodo)
            self.inscripciones.append(inscripcion)
            self.asignaciones.append(self.asignar(inscripcion, self.seccion))
        self.asignacion_otra_seccion = self.asignar(self.inscripciones[0], self.otra_seccion)

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
        # RELEASE SAVEPOINT no ejecuta las restricciones diferidas del COMMIT.
        session.flush()
        session.execute(text("SET CONSTRAINTS ALL IMMEDIATE"))
        session.execute(text("SET CONSTRAINTS ALL DEFERRED"))

    def nuevo_periodo(self, codigo, inicio, fin):
        return self.valor("""
            INSERT INTO public.periodo_academico (codigo, nombre, fecha_inicio, fecha_fin)
            VALUES (:codigo, 'Periodo temporal', :inicio, :fin) RETURNING id_periodo_academico
        """, codigo=self.token + codigo, inicio=inicio, fin=fin)

    def nueva_seccion(self, curso, docente, periodo, codigo):
        return self.valor("""
            INSERT INTO public.seccion
                (id_curso, id_periodo_academico, id_docente, codigo, cupo_maximo)
            VALUES (:curso, :periodo, :docente, :codigo, 5) RETURNING id_seccion
        """, curso=curso, periodo=periodo, docente=docente, codigo=codigo)

    def inscribir(self, estudiante, periodo):
        return inscripciones.registrar_inscripcion(InscripcionCrear(
            id_estudiante=estudiante, id_periodo_academico=periodo)).id_inscripcion

    def asignar(self, inscripcion, seccion):
        return asignaciones_cursos.registrar_asignacion_curso(AsignacionCursoCrear(
            id_inscripcion=inscripcion, id_seccion=seccion)).id_asignacion_curso

    def actividad(self, maximo="100", seccion=None, **cambios):
        datos = dict(id_seccion=seccion or self.seccion, nombre="Examen",
                     tipo="examen", fecha=self.inicio, puntaje_maximo=maximo)
        return actividades_academicas.registrar_actividad_academica(
            ActividadAcademicaCrear(**{**datos, **cambios}))

    def nota(self, actividad, asignacion=None, puntaje="61"):
        return calificaciones.registrar_calificacion(CalificacionCrear(
            id_actividad_academica=actividad,
            id_asignacion_curso=asignacion or self.asignaciones[0],
            puntaje_obtenido=puntaje))

    def cambiar_actividad(self, identificador, **cambios):
        actual = ActividadAcademicaRespuesta.model_validate(
            actividades_academicas.consultar_actividad_academica(identificador))
        datos = actual.model_dump(exclude={"id_actividad_academica", "id_seccion"})
        return actividades_academicas.modificar_actividad_academica(
            identificador, ActividadAcademicaActualizar(**{**datos, **cambios}))

    def cambiar_nota(self, identificador, puntaje):
        return calificaciones.modificar_calificacion(
            identificador, CalificacionActualizar(puntaje_obtenido=puntaje))

    def cancelar(self, asignacion):
        return asignaciones_cursos.modificar_asignacion_curso(
            asignacion, AsignacionCursoActualizar(estado="cancelada"))

    def historial(self, estudiante=None):
        filas = historial_academico.consultar_historial_academico(
            estudiante or self.estudiantes[0])
        return [HistorialAcademicoRespuesta.model_validate(fila) for fila in filas]

    def preparar_notas_completas(self):
        primera = self.actividad("60")
        segunda = self.actividad("40", nombre="Proyecto", tipo="proyecto")
        notas = []
        for asignacion, puntaje_a, puntaje_b in (
            (self.asignaciones[0], "40", "21"),
            (self.asignaciones[1], "30", "30.99"),
        ):
            notas.append(self.nota(primera.id_actividad_academica, asignacion, puntaje_a))
            notas.append(self.nota(segunda.id_actividad_academica, asignacion, puntaje_b))
        return primera, segunda, notas

    def comprobar_rechazo(self, estado, operacion, *argumentos, regla=None, **opciones):
        with self.assertRaises(HTTPException) as resultado:
            operacion(*argumentos, **opciones)
        self.assertEqual(resultado.exception.status_code, estado)
        if regla is not None:
            self.assertEqual(resultado.exception.__cause__.orig.diag.constraint_name, regla)

    def comprobar_seccion_abierta(self):
        self.assertFalse(secciones.consultar_seccion(self.seccion).calificaciones_cerradas)
        for identificador in self.asignaciones:
            self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(identificador).estado, "cursando")

    def test_actividades_crud_y_nombre_repetido_permitido(self):
        primera = self.actividad("20")
        segunda = self.actividad("20")
        ActividadAcademicaRespuesta.model_validate(primera)
        self.assertNotEqual(primera.id_actividad_academica, segunda.id_actividad_academica)
        self.assertTrue(actividades_academicas.listar_actividades_academicas())
        cambiada = self.cambiar_actividad(primera.id_actividad_academica,
                                         nombre="Tarea", tipo="tarea", puntaje_maximo="25.25")
        self.assertEqual(cambiada.puntaje_maximo, Decimal("25.25"))
        self.assertEqual(cambiada.id_seccion, self.seccion)
        actividades_academicas.borrar_actividad_academica(segunda.id_actividad_academica)
        self.comprobar_rechazo(404, actividades_academicas.consultar_actividad_academica,
                              segunda.id_actividad_academica)

    def test_calificaciones_crud_duplicado_cero_y_reemplazo(self):
        actividad = self.actividad()
        nota = self.nota(actividad.id_actividad_academica, puntaje="0")
        CalificacionRespuesta.model_validate(nota)
        self.assertTrue(calificaciones.listar_calificaciones())
        self.comprobar_rechazo(409, self.nota, actividad.id_actividad_academica, puntaje="20")
        self.assertEqual(calificaciones.consultar_calificacion(nota.id_calificacion).puntaje_obtenido, 0)
        cambiada = self.cambiar_nota(nota.id_calificacion, "61.25")
        self.assertEqual(cambiada.puntaje_obtenido, Decimal("61.25"))
        self.assertEqual(CalificacionRespuesta.model_validate(cambiada).model_dump(
            mode="json")["puntaje_obtenido"], "61.25")
        calificaciones.borrar_calificacion(nota.id_calificacion)
        self.comprobar_rechazo(404, calificaciones.consultar_calificacion, nota.id_calificacion)
        self.nota(actividad.id_actividad_academica, puntaje="62")

    def test_referencias_inexistentes_y_filas_ausentes(self):
        ausente = 2147483647
        self.comprobar_rechazo(409, self.actividad, seccion=ausente)
        actividad = self.actividad()
        self.comprobar_rechazo(409, self.nota, ausente)
        self.comprobar_rechazo(409, self.nota, actividad.id_actividad_academica, asignacion=ausente)
        for consultar, modificar, borrar, datos in (
            (actividades_academicas.consultar_actividad_academica,
             actividades_academicas.modificar_actividad_academica,
             actividades_academicas.borrar_actividad_academica,
             ActividadAcademicaActualizar(nombre="N", tipo="otra", fecha=self.inicio, puntaje_maximo="10")),
            (calificaciones.consultar_calificacion, calificaciones.modificar_calificacion,
             calificaciones.borrar_calificacion, CalificacionActualizar(puntaje_obtenido="0")),
        ):
            self.comprobar_rechazo(404, consultar, ausente)
            self.comprobar_rechazo(404, modificar, ausente, datos)
            self.comprobar_rechazo(404, borrar, ausente)
        self.comprobar_rechazo(404, secciones.cerrar_calificaciones_seccion, ausente)

    def test_actividad_y_asignacion_de_distinta_seccion(self):
        actividad = self.actividad()
        self.comprobar_rechazo(400, self.nota, actividad.id_actividad_academica,
                              self.asignacion_otra_seccion, regla="regla_calificacion_seccion")
        self.assertEqual(self.valor("""
            SELECT count(*) FROM public.calificacion WHERE id_actividad_academica = :id
        """, id=actividad.id_actividad_academica), 0)

    def test_puntaje_superior_al_maximo_y_rollback_de_actualizacion(self):
        actividad = self.actividad("20")
        nota = self.nota(actividad.id_actividad_academica, puntaje="10")
        self.comprobar_rechazo(400, self.nota, actividad.id_actividad_academica,
                              self.asignaciones[1], "21", regla="regla_calificacion_maximo")
        self.comprobar_rechazo(400, self.cambiar_nota, nota.id_calificacion, "21",
                              regla="regla_calificacion_maximo")
        self.assertEqual(calificaciones.consultar_calificacion(nota.id_calificacion).puntaje_obtenido, 10)
        self.comprobar_rechazo(400, self.cambiar_actividad, actividad.id_actividad_academica,
                              nombre="No guardar", puntaje_maximo="9",
                              regla="regla_calificacion_maximo")
        conservada = actividades_academicas.consultar_actividad_academica(actividad.id_actividad_academica)
        self.assertEqual(conservada.nombre, "Examen")
        self.assertEqual(conservada.puntaje_maximo, 20)

    def test_suma_de_actividades_no_supera_100_y_rollback(self):
        self.actividad("70")
        segunda = self.actividad("20")
        self.comprobar_rechazo(400, self.actividad, "20", regla="regla_actividad_suma")
        self.comprobar_rechazo(400, self.cambiar_actividad, segunda.id_actividad_academica,
                              nombre="No guardar", puntaje_maximo="40",
                              regla="regla_actividad_suma")
        conservada = actividades_academicas.consultar_actividad_academica(segunda.id_actividad_academica)
        self.assertEqual(conservada.nombre, "Examen")
        self.assertEqual(conservada.puntaje_maximo, 20)

    def test_fechas_inclusivas_y_rechazo_fuera_del_periodo(self):
        primera = self.actividad("20", fecha=self.inicio)
        self.actividad("20", fecha=self.fin)
        for fecha in (self.inicio - timedelta(days=1), self.fin + timedelta(days=1)):
            self.comprobar_rechazo(400, self.actividad, "20", fecha=fecha,
                                  regla="regla_actividad_fecha")
        self.comprobar_rechazo(400, self.cambiar_actividad, primera.id_actividad_academica,
                              nombre="No guardar", fecha=self.inicio - timedelta(days=1),
                              regla="regla_actividad_fecha")
        self.assertEqual(actividades_academicas.consultar_actividad_academica(
            primera.id_actividad_academica).fecha, self.inicio)

    def test_actividad_con_notas_no_se_elimina_y_asignacion_cancelada(self):
        actividad = self.actividad()
        nota = self.nota(actividad.id_actividad_academica, puntaje="20")
        self.comprobar_rechazo(409, actividades_academicas.borrar_actividad_academica,
                              actividad.id_actividad_academica)
        self.cancelar(self.asignaciones[0])
        self.comprobar_rechazo(400, self.cambiar_nota, nota.id_calificacion, "21",
                              regla="regla_calificacion_cancelada")
        calificaciones.borrar_calificacion(nota.id_calificacion)
        self.comprobar_rechazo(400, self.nota, actividad.id_actividad_academica,
                              regla="regla_calificacion_cancelada")
        actividades_academicas.borrar_actividad_academica(actividad.id_actividad_academica)

    def test_cierre_rechaza_suma_distinta_de_100_y_preserva_estado(self):
        self.comprobar_rechazo(400, secciones.cerrar_calificaciones_seccion,
                              self.seccion, regla="regla_cierre_suma")
        self.actividad("80")
        self.comprobar_rechazo(400, secciones.cerrar_calificaciones_seccion,
                              self.seccion, regla="regla_cierre_suma")
        self.comprobar_seccion_abierta()

    def test_cierre_rechaza_notas_pendientes_y_no_las_convierte_en_cero(self):
        actividad = self.actividad()
        self.nota(actividad.id_actividad_academica)
        self.comprobar_rechazo(400, secciones.cerrar_calificaciones_seccion,
                              self.seccion, regla="regla_cierre_completo")
        self.comprobar_seccion_abierta()
        fila = self.historial(self.estudiantes[1])[0]
        self.assertIsNone(fila.nota_final)
        self.assertEqual(fila.resultado, "cursando")
        self.assertEqual(self.valor("""
            SELECT count(*) FROM public.calificacion WHERE id_asignacion_curso = :id
        """, id=self.asignaciones[1]), 0)

    def test_cierre_valido_aprobacion_61_reprobacion_60_99_y_respuesta(self):
        self.preparar_notas_completas()
        cerrada = secciones.cerrar_calificaciones_seccion(self.seccion, SeccionCerrar())
        self.assertTrue(SeccionRespuesta.model_validate(cerrada).calificaciones_cerradas)
        aprobada = self.historial()[0]
        reprobada = self.historial(self.estudiantes[1])[0]
        self.assertEqual((aprobada.nota_final, aprobada.resultado), (Decimal("61.00"), "aprobada"))
        self.assertEqual((reprobada.nota_final, reprobada.resultado), (Decimal("60.99"), "reprobada"))
        self.assertEqual(aprobada.model_dump(mode="json")["nota_final"], "61.00")
        self.assertEqual(aprobada.id_asignacion_curso, self.asignaciones[0])
        self.assertEqual(aprobada.id_curso, self.cursos[0])
        self.assertEqual(aprobada.id_periodo_academico, self.periodo)
        self.assertEqual(aprobada.id_seccion, self.seccion)
        self.assertEqual(aprobada.estado_inscripcion, "activa")
        self.comprobar_rechazo(400, secciones.cerrar_calificaciones_seccion,
                              self.seccion, regla="regla_seccion_cerrada")

    def test_cero_explicito_y_cancelacion_no_exige_notas_al_cerrar(self):
        actividad = self.actividad()
        self.nota(actividad.id_actividad_academica, puntaje="0")
        self.cancelar(self.asignaciones[1])
        secciones.cerrar_calificaciones_seccion(self.seccion)
        self.assertEqual(self.historial()[0].nota_final, Decimal("0.00"))
        self.assertEqual(self.historial()[0].resultado, "reprobada")
        cancelada = self.historial(self.estudiantes[1])[0]
        self.assertTrue(cancelada.calificaciones_cerradas)
        self.assertEqual(cancelada.resultado, "cancelada")
        self.assertIsNone(cancelada.nota_final)

    def test_cierre_sin_estudiantes_permitido_con_100_puntos(self):
        self.actividad(seccion=self.seccion_siguiente, fecha=self.inicio_siguiente)
        cerrada = secciones.cerrar_calificaciones_seccion(self.seccion_siguiente)
        self.assertTrue(cerrada.calificaciones_cerradas)

    def test_inmutabilidad_de_actividades_notas_y_resultados_cerrados(self):
        primera, _, notas = self.preparar_notas_completas()
        secciones.cerrar_calificaciones_seccion(self.seccion)
        self.comprobar_rechazo(400, self.actividad, "1", regla="regla_actividad_cerrada")
        self.comprobar_rechazo(400, self.cambiar_actividad, primera.id_actividad_academica,
                              nombre="No guardar", regla="regla_actividad_cerrada")
        self.comprobar_rechazo(400, actividades_academicas.borrar_actividad_academica,
                              primera.id_actividad_academica, regla="regla_actividad_cerrada")
        inscripcion = self.inscribir(self.estudiantes[2], self.periodo)
        cancelada = self.asignar(inscripcion, self.otra_seccion)
        self.comprobar_rechazo(400, self.nota, primera.id_actividad_academica,
                              cancelada, "0", regla="regla_calificacion_cerrada")
        self.comprobar_rechazo(400, self.cambiar_nota, notas[0].id_calificacion, "39",
                              regla="regla_calificacion_cerrada")
        self.comprobar_rechazo(400, calificaciones.borrar_calificacion,
                              notas[0].id_calificacion, regla="regla_calificacion_cerrada")
        for asignacion in self.asignaciones:
            self.comprobar_rechazo(400, self.cancelar, asignacion, regla="regla_resultado_inmutable")
        self.assertEqual(self.historial()[0].nota_final, Decimal("61.00"))

    def test_historial_vacio_inexistente_y_sin_notas(self):
        self.assertEqual(self.historial(self.estudiantes[2]), [])
        self.inscribir(self.estudiantes[2], self.periodo)
        self.assertEqual(self.historial(self.estudiantes[2]), [])
        self.comprobar_rechazo(404, historial_academico.consultar_historial_academico, 2147483647)
        filas = self.historial()
        self.assertEqual(len(filas), 2)
        self.assertEqual({fila.id_asignacion_curso for fila in filas},
                         {self.asignaciones[0], self.asignacion_otra_seccion})
        self.assertTrue(all(fila.nota_final is None for fila in filas))
        self.assertTrue(all(fila.resultado == "cursando" for fila in filas))

    def test_historial_no_publica_suma_parcial_ni_completa_sin_cierre(self):
        self.preparar_notas_completas()
        for fila in self.historial():
            self.assertIsNone(fila.nota_final)
            self.assertFalse(fila.calificaciones_cerradas)
        self.cancelar(self.asignaciones[0])
        fila = self.historial()[0]
        self.assertEqual(fila.resultado, "cancelada")
        self.assertIsNone(fila.nota_final)
        self.assertEqual(self.valor("""
            SELECT sum(puntaje_obtenido) FROM public.calificacion WHERE id_asignacion_curso = :id
        """, id=self.asignaciones[0]), 61)

    def test_historial_conserva_intentos_y_ordena_periodos(self):
        self.preparar_notas_completas()
        secciones.cerrar_calificaciones_seccion(self.seccion)
        siguiente = self.inscribir(self.estudiantes[1], self.periodo_siguiente)
        intento = self.asignar(siguiente, self.seccion_siguiente)
        actividad = self.actividad(seccion=self.seccion_siguiente, fecha=self.inicio_siguiente)
        self.nota(actividad.id_actividad_academica, intento, "30")
        filas = self.historial(self.estudiantes[1])
        self.assertEqual(len(filas), 2)
        self.assertEqual([fila.id_periodo_academico for fila in filas],
                         [self.periodo, self.periodo_siguiente])
        self.assertEqual(filas[0].resultado, "reprobada")
        self.assertEqual(filas[0].nota_final, Decimal("60.99"))
        self.assertEqual(filas[1].resultado, "cursando")
        self.assertIsNone(filas[1].nota_final)
        self.assertEqual(filas[0].id_curso, filas[1].id_curso)

    def test_fallo_diferido_del_cierre_revierte_indicador_y_resultados(self):
        self.preparar_notas_completas()
        siguiente = self.inscribir(self.estudiantes[0], self.periodo_siguiente)
        futuro = self.asignar(siguiente, self.seccion_siguiente)
        # Aprobar el intento anterior dejaria un intento posterior de un curso aprobado.
        self.comprobar_rechazo(400, secciones.cerrar_calificaciones_seccion,
                              self.seccion, regla="regla_historial_curso_aprobado")
        self.comprobar_seccion_abierta()
        self.assertEqual(asignaciones_cursos.consultar_asignacion_curso(futuro).estado, "cursando")
        self.assertTrue(all(fila.nota_final is None for fila in self.historial()))
        self.assertEqual(self.valor("""
            SELECT sum(puntaje_obtenido) FROM public.calificacion WHERE id_asignacion_curso = :id
        """, id=self.asignaciones[0]), 61)
        self.cancelar(futuro)
        cerrada = secciones.cerrar_calificaciones_seccion(self.seccion)
        self.assertTrue(cerrada.calificaciones_cerradas)
        self.assertEqual(self.historial()[0].resultado, "aprobada")
