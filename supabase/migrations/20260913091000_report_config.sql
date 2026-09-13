-- ============================================================
-- Configuracion de reportes por colegio: pesos del Indice de
-- Desempeno BattleGraph (IDB) y meta institucional.
-- Formato: {"weights": {"grades":40,"attendance":20,"tasks":20,"practice":20},
--           "goal": 80}
-- ============================================================

alter table public.school_settings
  add column if not exists report_config jsonb not null default '{}'::jsonb;
