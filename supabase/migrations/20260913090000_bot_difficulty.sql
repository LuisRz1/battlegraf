-- ============================================================
-- Dificultad del bot en batallas alumno vs bot.
-- Valores: facil | balanced | hard | adaptive
-- El panel la configura al programar la batalla y la pasa al
-- juego (parametro bot_difficulty) al iniciar la partida.
-- ============================================================

alter table public.battle_events
  add column if not exists bot_difficulty text not null default 'balanced';
