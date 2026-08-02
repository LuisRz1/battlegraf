-- Centro de mando institucional: directorio, tareas, batallas, rangos y auditoria.

alter table public.schools
  add column if not exists ugel text,
  add column if not exists address text;

create table if not exists public.staff_profiles (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  full_name text not null,
  email text,
  role text not null check (role in ('director','subdirector','coordinator','tutor','teacher')),
  scope_label text,
  status text not null default 'active' check (status in ('invited','active','suspended')),
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  section_id uuid references public.sections(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  title text not null,
  delivery_type text not null default 'quiz' check (delivery_type in ('quiz','written','document')),
  due_at timestamptz,
  xp_reward integer not null default 80 check (xp_reward between 0 and 10000),
  status text not null default 'draft' check (status in ('draft','scheduled','published','closed')),
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.battle_events (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  title text not null,
  battle_type text not null default 'student_vs_bot' check (battle_type in ('student_vs_bot','student_vs_student','section_vs_section','tournament')),
  opponent_a text not null,
  opponent_b text not null,
  scheduled_at timestamptz,
  status text not null default 'scheduled' check (status in ('draft','scheduled','live','finished')),
  graph_layers integer not null default 4 check (graph_layers between 4 and 7),
  nodes_per_layer integer not null default 4 check (nodes_per_layer between 3 and 4),
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.rank_definitions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,
  min_xp integer not null default 0 check (min_xp >= 0),
  position integer not null default 1,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  unique (school_id, name)
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  actor_name text not null,
  action text not null,
  target_label text,
  category text not null default 'configuration',
  created_at timestamptz not null default now()
);

create or replace function public.seed_command_center(p_school_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_section_a uuid;
  v_section_b uuid;
  v_math uuid;
  v_science uuid;
begin
  select id into v_section_a from public.sections where school_id = p_school_id order by display_name limit 1;
  select id into v_section_b from public.sections where school_id = p_school_id order by display_name offset 1 limit 1;
  select id into v_math from public.subjects where school_id = p_school_id and slug = 'matematica' limit 1;
  select id into v_science from public.subjects where school_id = p_school_id and slug = 'ciencia' limit 1;

  if not exists (select 1 from public.staff_profiles where school_id = p_school_id) then
    insert into public.staff_profiles (school_id, full_name, email, role, scope_label, is_demo) values
      (p_school_id, 'Lucia Vargas', 'lucia@battlegraf.demo', 'tutor', '5. Primaria A', true),
      (p_school_id, 'Diego Ramos', 'diego@battlegraf.demo', 'teacher', 'Matematica', true),
      (p_school_id, 'Ana Torres', 'ana@battlegraf.demo', 'teacher', 'Ciencia y Tecnologia', true),
      (p_school_id, 'Marco Salas', 'marco@battlegraf.demo', 'subdirector', 'Gestion academica', true);
  end if;

  if not exists (select 1 from public.assignments where school_id = p_school_id) then
    insert into public.assignments (school_id, section_id, subject_id, title, delivery_type, due_at, xp_reward, status, is_demo) values
      (p_school_id, v_section_a, v_math, 'Fracciones equivalentes', 'quiz', now() + interval '1 day', 80, 'published', true),
      (p_school_id, v_section_b, v_science, 'Informe del sistema solar', 'document', now() + interval '4 days', 120, 'scheduled', true);
  end if;

  if not exists (select 1 from public.battle_events where school_id = p_school_id) then
    insert into public.battle_events (school_id, title, battle_type, opponent_a, opponent_b, scheduled_at, status, is_demo) values
      (p_school_id, 'Duelo de practica', 'student_vs_bot', 'Alumno invitado', 'BOT Centinela', now(), 'live', true),
      (p_school_id, 'Copa entre secciones', 'section_vs_section', '5. Primaria A', '6. Primaria A', now() + interval '3 days', 'scheduled', true);
  end if;

  insert into public.rank_definitions (school_id, name, min_xp, position, is_demo) values
    (p_school_id, 'Aprendiz', 0, 1, true),
    (p_school_id, 'Explorador', 500, 2, true),
    (p_school_id, 'Estratega', 1200, 3, true),
    (p_school_id, 'Comandante', 2500, 4, true),
    (p_school_id, 'Maestro', 5000, 5, true)
  on conflict (school_id, name) do nothing;

  if not exists (select 1 from public.audit_logs where school_id = p_school_id) then
    insert into public.audit_logs (school_id, actor_name, action, target_label, category) values
      (p_school_id, 'Sistema BattleGraph', 'Creo la configuracion inicial', 'Centro de mando', 'system'),
      (p_school_id, 'Direccion', 'Habilito la prueba Red Educativa', '7 dias', 'subscription'),
      (p_school_id, 'Ana Torres', 'Aprobo preguntas de muestra', 'Banco de Ciencia', 'content');
  end if;
end;
$$;

do $$ declare v_school_id uuid; begin
  for v_school_id in select id from public.schools loop perform public.seed_command_center(v_school_id); end loop;
end $$;

alter table public.staff_profiles enable row level security;
alter table public.assignments enable row level security;
alter table public.battle_events enable row level security;
alter table public.rank_definitions enable row level security;
alter table public.audit_logs enable row level security;

create policy "members read staff" on public.staff_profiles for select using (public.is_school_member(school_id));
create policy "admins manage staff" on public.staff_profiles for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "members read assignments" on public.assignments for select using (public.is_school_member(school_id));
create policy "admins manage assignments" on public.assignments for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "members read battles" on public.battle_events for select using (public.is_school_member(school_id));
create policy "admins manage battles" on public.battle_events for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "members read ranks" on public.rank_definitions for select using (public.is_school_member(school_id));
create policy "admins manage ranks" on public.rank_definitions for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "members read audit" on public.audit_logs for select using (public.is_school_member(school_id));
create policy "admins create audit" on public.audit_logs for insert with check (public.is_school_admin(school_id));

grant select, insert, update, delete on public.staff_profiles, public.assignments, public.battle_events, public.rank_definitions to authenticated;
grant select, insert on public.audit_logs to authenticated;
revoke all on function public.seed_command_center(uuid) from public, anon, authenticated;

-- Las cuentas nuevas reciben tambien los modulos completos del centro de mando.
create or replace function public.bootstrap_institution_account(p_plan_slug text default 'explorador')
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_school_id uuid;
  v_plan public.plans%rowtype;
  v_name text;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  select school_id into v_school_id from public.memberships where user_id = v_user_id and role = 'owner' order by created_at limit 1;
  if v_school_id is not null then return v_school_id; end if;
  select * into v_plan from public.plans where slug = p_plan_slug;
  if not found then select * into v_plan from public.plans where slug = 'explorador'; end if;
  select coalesce(nullif(full_name, ''), split_part(coalesce(email, 'BattleGraph'), '@', 1)) into v_name from public.profiles where id = v_user_id;
  insert into public.schools (name, created_by, onboarding_complete) values ('Academia BattleGraph de ' || coalesce(v_name, 'Administrador'), v_user_id, true) returning id into v_school_id;
  update public.schools set code = 'BG-' || upper(substr(replace(v_school_id::text, '-', ''), 1, 8)) where id = v_school_id;
  insert into public.memberships (school_id, user_id, role) values (v_school_id, v_user_id, 'owner');
  insert into public.subscriptions (school_id, plan_slug, status, student_limit, ai_credits_monthly, current_period_end, trial_plan_slug, trial_started_at, trial_ends_at)
  values (v_school_id, v_plan.slug, case when v_plan.slug = 'explorador' then 'trialing' else 'active' end, v_plan.student_limit, v_plan.ai_credits_monthly, case when v_plan.slug = 'explorador' then now() + interval '7 days' else null end, case when v_plan.slug = 'explorador' then 'red' else null end, case when v_plan.slug = 'explorador' then now() else null end, case when v_plan.slug = 'explorador' then now() + interval '7 days' else null end);
  perform public.seed_school_defaults(v_school_id);
  perform public.seed_command_center(v_school_id);
  return v_school_id;
end;
$$;

grant execute on function public.bootstrap_institution_account(text) to authenticated;
