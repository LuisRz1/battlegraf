-- ============================================================
-- BattleGraph: metas de estudio, materiales persistentes,
-- insignias, poderes, puntos, misiones y memoria por cuenta.
-- ============================================================

-- ---------- Metas de estudio por grado/materia/periodo ----------
create table if not exists public.study_goals (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  grade text not null,
  subject_id uuid references public.subjects(id) on delete set null,
  academic_period_id uuid references public.academic_periods(id) on delete set null,
  title text not null,
  objectives jsonb not null default '[]'::jsonb,
  topics jsonb not null default '[]'::jsonb,
  competences jsonb not null default '[]'::jsonb,
  status text not null default 'active' check (status in ('active','archived')),
  created_by_membership_id uuid references public.memberships(id) on delete set null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, grade, subject_id, academic_period_id)
);
create index if not exists idx_study_goals_school on public.study_goals (school_id, grade, subject_id);

-- ---------- Materiales persistentes (archivo real + texto extraido) ----------
alter table public.learning_materials
  add column if not exists storage_path text,
  add column if not exists extracted_text text,
  add column if not exists grade text,
  add column if not exists uploaded_by_membership_id uuid references public.memberships(id) on delete set null,
  add column if not exists char_count integer not null default 0,
  add column if not exists updated_at timestamptz not null default now();
create index if not exists idx_learning_materials_school on public.learning_materials (school_id, subject_id);

-- ---------- Insignias ----------
create table if not exists public.badges (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  icon_code text default 'M',
  category text not null default 'general',
  criteria jsonb not null default '{}'::jsonb,
  points integer not null default 0,
  is_active boolean not null default true,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  unique (school_id, code)
);

create table if not exists public.student_badges (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_profile_id uuid not null references public.student_profiles(id) on delete cascade,
  badge_id uuid not null references public.badges(id) on delete cascade,
  source_type text,
  source_id text,
  note text,
  awarded_by_membership_id uuid references public.memberships(id) on delete set null,
  awarded_at timestamptz not null default now(),
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  unique (student_profile_id, badge_id)
);
create index if not exists idx_student_badges_student on public.student_badges (student_profile_id, awarded_at desc);

-- ---------- Poderes (inventario de la cuenta) ----------
create table if not exists public.reward_powerups (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  icon_code text default 'icon_half',
  effect text not null default 'half',
  duration_seconds integer not null default 0,
  rarity text not null default 'tactico',
  cost_points integer not null default 0,
  is_active boolean not null default true,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  unique (school_id, code)
);

create table if not exists public.student_powerups (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_profile_id uuid not null references public.student_profiles(id) on delete cascade,
  powerup_id uuid not null references public.reward_powerups(id) on delete cascade,
  quantity integer not null default 0,
  source_type text,
  source_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_profile_id, powerup_id)
);

-- ---------- Puntos (saldo + libro mayor) ----------
create table if not exists public.points_ledger (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_profile_id uuid not null references public.student_profiles(id) on delete cascade,
  amount integer not null,
  reason text not null default 'general',
  source_type text,
  source_id text,
  created_by_membership_id uuid references public.memberships(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (student_profile_id, source_type, source_id)
);
create index if not exists idx_points_ledger_student on public.points_ledger (student_profile_id, created_at desc);

-- ---------- Misiones ----------
create table if not exists public.missions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  title text not null,
  description text,
  scope text not null default 'section' check (scope in ('school','grade','section','subject')),
  grade text,
  section_id uuid references public.sections(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  goal_type text not null default 'tasks_completed'
    check (goal_type in ('tasks_completed','tasks_graded','battles_won','battles_played','attendance_streak','grade_average','xp_earned','correct_answers')),
  goal_value numeric not null default 1,
  reward_points integer not null default 0,
  reward_badge_id uuid references public.badges(id) on delete set null,
  reward_powerup_id uuid references public.reward_powerups(id) on delete set null,
  reward_powerup_qty integer not null default 0,
  starts_on date,
  ends_on date,
  status text not null default 'draft' check (status in ('draft','active','closed')),
  created_by_membership_id uuid references public.memberships(id) on delete set null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_missions_school on public.missions (school_id, status);

create table if not exists public.student_missions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_profile_id uuid not null references public.student_profiles(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  progress numeric not null default 0,
  completed boolean not null default false,
  completed_at timestamptz,
  claimed boolean not null default false,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_profile_id, mission_id)
);
create index if not exists idx_student_missions_student on public.student_missions (student_profile_id, completed);

-- ---------- Reglas de recompensa en settings ----------
alter table public.school_settings
  add column if not exists reward_rules jsonb not null default
    '{"points_per_correct_answer":5,"points_per_task":20,"points_per_battle_win":30,"points_per_battle_played":10,"points_per_badge":15}'::jsonb;

-- ---------- Memoria persistente por cuenta ----------
create table if not exists public.account_memory (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  membership_id uuid not null references public.memberships(id) on delete cascade,
  kind text not null default 'student' check (kind in ('student','teacher','tutor','director','coordinator','owner')),
  context jsonb not null default '{}'::jsonb,
  summary text,
  last_interaction_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (membership_id)
);

-- ============================================================
-- RLS
-- ============================================================
alter table public.study_goals enable row level security;
alter table public.badges enable row level security;
alter table public.student_badges enable row level security;
alter table public.reward_powerups enable row level security;
alter table public.student_powerups enable row level security;
alter table public.points_ledger enable row level security;
alter table public.missions enable row level security;
alter table public.student_missions enable row level security;
alter table public.account_memory enable row level security;

-- Catalogos: lectura para miembros, gestion para staff academico.
do $$
declare t text;
begin
  foreach t in array array['study_goals','badges','reward_powerups','missions']
  loop
    execute format('drop policy if exists %I_select on public.%I', t, t);
    execute format('create policy %I_select on public.%I for select to authenticated using (public.is_school_member(school_id))', t, t);
    execute format('drop policy if exists %I_manage on public.%I', t, t);
    execute format('create policy %I_manage on public.%I for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id))', t, t);
  end loop;
end $$;

-- Fichas del alumno: self o alcance academico.
do $$
declare t text;
begin
  foreach t in array array['student_badges','student_powerups','points_ledger','student_missions']
  loop
    execute format('drop policy if exists %I_select on public.%I', t, t);
    execute format($f$create policy %I_select on public.%I for select to authenticated
      using (exists (select 1 from public.student_profiles sp where sp.id = student_profile_id and sp.membership_id in (select id from public.memberships where user_id = auth.uid())) or public.can_view_student_profile(student_profile_id))$f$, t, t);
    execute format('drop policy if exists %I_manage on public.%I', t, t);
    execute format($f$create policy %I_manage on public.%I for all to authenticated
      using (public.can_manage_academic_student(student_profile_id)) with check (public.can_manage_academic_student(student_profile_id))$f$, t, t);
  end loop;
end $$;

drop policy if exists account_memory_self on public.account_memory;
create policy account_memory_self on public.account_memory
  for all to authenticated
  using (membership_id in (select id from public.memberships where user_id = auth.uid()))
  with check (membership_id in (select id from public.memberships where user_id = auth.uid()));

grant select, insert, update, delete on
  public.study_goals, public.badges, public.student_badges, public.reward_powerups,
  public.student_powerups, public.points_ledger, public.missions, public.student_missions,
  public.account_memory
  to authenticated;

-- ============================================================
-- Semilla de insignias y poderes por defecto (por colegio, idempotente)
-- ============================================================
create or replace function public.seed_rewards(p_school_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  insert into public.badges (school_id, code, name, description, icon_code, category, points, is_demo)
  values
    (p_school_id, 'primer_paso', 'Primer Paso', 'Completa tu primera tarea.', 'P', 'inicio', 15, true),
    (p_school_id, 'racha_5', 'Racha de 5', 'Asiste 5 días seguidos.', 'R', 'asistencia', 20, true),
    (p_school_id, 'conquistador', 'Conquistador', 'Gana tu primera batalla.', 'C', 'batalla', 25, true),
    (p_school_id, 'mente_brillante', 'Mente Brillante', 'Promedio mayor o igual a 90%.', 'M', 'academico', 40, true),
    (p_school_id, 'estratega', 'Estratega', 'Gana 5 batallas.', 'E', 'batalla', 60, true)
  on conflict (school_id, code) do nothing;

  insert into public.reward_powerups (school_id, code, name, description, icon_code, effect, duration_seconds, rarity, cost_points, is_demo)
  values
    (p_school_id, 'half', 'Mitad de Opciones', 'Elimina dos respuestas incorrectas.', 'icon_half', 'half', 0, 'tactico', 20, true),
    (p_school_id, 'invuln', 'Escudo Absoluto', 'Blinda un nodo 30 segundos.', 'icon_shield', 'invuln', 30, 'defensivo', 35, true),
    (p_school_id, 'fortify', 'Fortificación', 'Refuerza la resistencia del nodo.', 'icon_fortify', 'fortify', 0, 'defensivo', 30, true),
    (p_school_id, 'retopic', 'Cambio de Tema', 'Cambia la materia del nodo.', 'icon_retopic', 'retopic', 0, 'tactico', 25, true),
    (p_school_id, 'double', 'Doble Oportunidad', 'Falla una vez sin bloquearte.', 'icon_double', 'double', 0, 'raro', 45, true),
    (p_school_id, 'alarm', 'Alarma Temprana', 'Aviso previo antes del ataque.', 'icon_alarm', 'alarm', 5, 'radar', 40, true),
    (p_school_id, 'chest', 'Cofre del Nodo', 'Recompensa extra al conquistar.', 'icon_chest', 'chest', 0, 'bonus', 50, true),
    (p_school_id, 'clock', 'Control del Reloj', 'Más tiempo por duelo y bono de puntos.', 'icon_clock', 'clock', 0, 'pasivo', 55, true)
  on conflict (school_id, code) do nothing;
end $$;

comment on function public.seed_rewards(uuid) is 'Crea insignias y poderes por defecto para un colegio.';
