-- ============================================================
-- Batallas con tema (materia del curso) y grados participantes
-- Regla de roles:
--   - Profesor: crea la batalla eligiendo UNA materia de su curso
--     (subject_id) -> las preguntas del juego seran de ese tema.
--   - Tutor / Director: activan/desactivan cursos (subjects.is_enabled
--     ya existe) desde la vista de materias.
--   - Director: define ademas que grados participan (battle_grades).
-- ============================================================

alter table public.battle_events
  add column if not exists subject_id uuid references public.subjects(id) on delete set null,
  add column if not exists grade text;

-- Grados habilitados para batallas por colegio (config del director)
alter table public.school_settings
  add column if not exists battle_grades jsonb not null default '[]'::jsonb;