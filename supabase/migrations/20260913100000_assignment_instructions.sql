-- ============================================================
-- Detalle de tareas al estilo aula virtual (Canvas):
--   instructions = consigna/descripcion para el alumno
--   points       = puntaje maximo de la tarea (calificacion)
-- El XP de gamificacion sigue en xp_reward.
-- ============================================================

alter table public.assignments
  add column if not exists instructions text,
  add column if not exists points numeric(8, 2) not null default 100;
