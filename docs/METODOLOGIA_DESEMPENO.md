# Metodología de medición del desempeño — BattleGraph

**Índice de Desempeño BattleGraph (IDB)**
Versión 1.0 · Septiembre 2026
Ámbito: panel institucional (vistas Reportes) y API `/api/v1/panel/{school}/reports/*`.

---

## 1. Propósito

El IDB resume, en una escala de 0 a 100, el desempeño de un alumno, un aula, un
docente o del colegio completo, combinando las señales que la institución ya
registra en BattleGraph: calificaciones, asistencia, cumplimiento de tareas y
práctica (puntos de gamificación). Su objetivo es **acompañar decisiones
pedagógicas** —detectar brechas frente a una meta y priorizar refuerzos—, no
etiquetar ni sancionar a estudiantes o docentes.

## 2. Fórmula general

Para un conjunto de componentes `i` con valor normalizado `v_i ∈ [0, 100]` y
peso configurable `w_i`:

```
IDB = Σ (v_i · w_i) / Σ (w_i)        (solo componentes con datos disponibles)
```

- Los pesos por defecto son **notas 40 %, asistencia 20 %, tareas 20 %,
  práctica 20 %**.
- Si un componente no tiene datos (por ejemplo, un aula sin evaluaciones
  registradas), se excluye del numerador y del denominador: el índice se
  **renormaliza** con los componentes activos. Un IDB sin ningún componente es
  `null` (sin datos), nunca 0.
- Los pesos y la meta son configurables por colegio desde
  **Reportes → Ajustar meta** y se guardan en
  `school_settings.report_config` (`{"weights": {...}, "goal": 80}`).

## 3. Componentes y cómo se calculan

| Componente | Peso por defecto | Fórmula | Fuente de datos |
|---|---|---|---|
| **Notas** | 40 % | Promedio de `(score / max_score) · 100` de todas las evaluaciones calificadas del alumno | `student_grades` + `grade_items.max_score` |
| **Asistencia** | 20 % | `(presentes + tardanzas) / total de registros · 100` | `attendance_records` |
| **Tareas** | 20 % | `entregas del alumno en su aula / tareas publicadas para el aula · 100` (tope 100) | `assignment_submissions` + `assignments.section_id` |
| **Práctica** | 20 % | Puntos BattleGraph del alumno normalizados contra el máximo de su aula: `puntos / max(puntos del aula) · 100`. Si aún no hay puntos, se usan batallas jugadas con la misma normalización | `points_ledger` / `battle_results` |

### Agregaciones

- **Aula**: promedio simple del IDB de sus alumnos con datos; también se
  promedian notas, asistencia y tareas del aula.
- **Docente**: promedio del IDB de las aulas que tiene asignadas
  (`classes.teacher_membership_id`); se complementa con sus cursos, número de
  evaluaciones creadas y alumnos alcanzados.
- **Colegio**: promedio simple del IDB de todos los alumnos con datos.
- **Materia**: promedio de los porcentajes de notas del alumno/aula en esa
  materia (`grade_items.subject_id`).

## 4. Meta y brecha (cuán lejos está de cumplir)

Para una meta institucional `M` (por defecto **80/100**):

```
Brecha      = M − IDB
Progreso    = min(100, IDB / M · 100) %
Semáforo    = cumplida  si Brecha ≤ 5
              cerca     si 5 < Brecha ≤ 15
              lejos     si Brecha > 15
              sin-datos si no hay IDB
```

La barra de cada aula/alumno muestra el IDB y una **línea vertical en la meta**;
el color del relleno usa el semáforo. Las tablas incluyen la brecha numérica
para exportarla a CSV.

## 5. Justificación (por qué estos indicadores)

La combinación elegida sigue la práctica de *learning analytics* y de la
evaluación formativa: usar múltiples evidencias del proceso de aprendizaje en
lugar de una sola prueba, con transparencia de pesos y metas.

1. **Las notas son el mejor predictor disponible del rendimiento posterior, pero
   mejoran cuando se combinan con hábitos y actitudes.** Credé y Kuncel (2008)
   muestran que las medidas de hábitos, habilidades y actitudes añaden validez
   predictiva más allá de las pruebas estandarizadas; por eso notas (40 %) se
   complementan con asistencia, tareas y práctica.
2. **La retroalimentación y la práctica deliberada explican una parte
   significativa del logro.** Hattie (2009), en su síntesis de más de 800
   meta-análisis, identifica la retroalimentación y la práctica como factores de
   alto efecto; BattleGraph las operacionaliza como práctica gamificada
   (puntos/batallas) y cumplimiento de tareas.
3. **La asistencia es una señal temprana de riesgo y de compromiso.** Los
   sistemas de alerta escolar la usan como indicador preventivo; se pondera
   20 % y se mide como presentes + tardanzas sobre el total de registros para no
   castigar la puntualidad de forma binaria.
4. **La evaluación por competencias en el Perú exige varias evidencias y
   retroalimentación, no un único examen.** El Currículo Nacional de la
   Educación Básica (MINEDU, 2016) plantea la evaluación formativa con
   diversidad de evidencias; el IDB respeta ese enfoque al agregar cuatro
   fuentes y al ser configurable por colegio.
5. **Ponderación explícita y auditable.** Los pesos son parámetros abiertos
   (40/20/20/20 por defecto) y cada componente se calcula con una fórmula
   reproducible desde la base de datos; cualquier cambio queda en la
   configuración institucional.

> **Advertencia de uso justo.** El IDB no está diseñado para rankings públicos
> punitivos ni para decisiones de retención. Se recomienda visibilidad
> configurable, revisión docente de los casos en rojo y acompañamiento
> pedagógico antes que sanción. Las brechas se interpretan junto al contexto
> del aula (tamaño, materias, periodo).

## 6. Límites conocidos

- Sin evaluaciones registradas el componente de notas es `null` y el índice se
  renormaliza; en un aula sin ninguna evidencia el IDB es `sin-datos`.
- La práctica por puntos recién refleja actividad desde que se activaron los
  puntos BattleGraph; en su ausencia se usa el conteo de batallas.
- El periodo de cálculo es acumulado histórico. Una segmentación por bimestre
  requerirá filtrar por `academic_periods` (evolución futura).
- El IDB se calcula hoy en el servicio de panel con datos de Supabase
  (service role) y respeta el colegio del usuario autenticado.

## 7. Referencias

- Credé, M., & Kuncel, N. R. (2008). Study habits, skills, and attitudes: The
  third pillar supporting collegiate academic performance. *Perspectives on
  Psychological Science, 3*(6), 425–453.
- Hattie, J. (2009). *Visible Learning: A Synthesis of Over 800 Meta-Analyses
  Relating to Achievement*. Routledge.
- Ministerio de Educación del Perú (2016). *Currículo Nacional de la Educación
  Básica*. Lima: MINEDU.
- Romero, C., & Ventura, S. (2020). Educational data mining and learning
  analytics: A review. *WIREs Data Mining and Knowledge Discovery, 10*(3).
- Reid, K. (2008). The causes of non-attendance: An empirical study.
  *Educational Review, 60*(4), 345–357.

## 8. Trazabilidad en el producto

- Endpoint de datos: `GET /api/v1/panel/{school_id}/reports/overview`
  (JSON para gráficos y `?export=true` para CSV).
- Configuración: `POST /api/v1/panel/{school_id}/reports/config`.
- Panel: vista **Reportes** (colegio / aula / docente / alumno) con gráficos de
  IDB vs meta, comparativos por materia y tablas exportables.
- Almacenamiento de configuración: `school_settings.report_config` (JSONB).
