-- BattleGraph: prueba Red Educativa por 7 dias y colegio inicial listo para usar.

alter table public.subscriptions
  add column if not exists trial_plan_slug text references public.plans(slug),
  add column if not exists trial_started_at timestamptz,
  add column if not exists trial_ends_at timestamptz;

alter table public.student_profiles
  add column if not exists email text,
  add column if not exists status text not null default 'active'
    check (status in ('invited', 'active', 'suspended')),
  add column if not exists is_demo boolean not null default false;

create table if not exists public.academic_years (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  label text not null,
  starts_on date,
  ends_on date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (school_id, label)
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  slug text not null,
  name text not null,
  color text not null default '#e6b84d',
  icon_code text not null default 'LIB',
  is_enabled boolean not null default true,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  unique (school_id, slug)
);

create table if not exists public.sections (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid references public.academic_years(id) on delete set null,
  level text not null default 'Primaria',
  grade text not null,
  section_label text not null,
  code text not null,
  display_name text not null,
  tutor_name text,
  max_students integer not null default 30 check (max_students between 1 and 100),
  status text not null default 'active' check (status in ('active', 'archived')),
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  unique (school_id, code)
);

create table if not exists public.section_subjects (
  section_id uuid not null references public.sections(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  teacher_name text,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (section_id, subject_id)
);

create table if not exists public.clans (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  section_id uuid references public.sections(id) on delete cascade,
  name text not null,
  color text not null,
  rank_name text not null default 'Aprendiz',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  unique (section_id, name)
);

create table if not exists public.learning_materials (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  title text not null,
  file_name text,
  file_type text not null default 'manual',
  processing_status text not null default 'ready'
    check (processing_status in ('pending', 'processing', 'ready', 'failed')),
  is_demo boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.question_bank (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  question text not null,
  options jsonb not null,
  correct_index integer not null check (correct_index between 0 and 3),
  status text not null default 'approved' check (status in ('draft', 'review', 'approved', 'archived')),
  source text not null default 'manual',
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.school_settings (
  school_id uuid primary key references public.schools(id) on delete cascade,
  battle_rules jsonb not null default '{}'::jsonb,
  rank_rules jsonb not null default '{}'::jsonb,
  ai_preferences jsonb not null default '{}'::jsonb,
  accessibility jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.seed_school_defaults(p_school_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_year_id uuid;
  v_section_a uuid;
  v_section_b uuid;
  v_math uuid;
  v_com uuid;
  v_sci uuid;
  v_history uuid;
  v_art uuid;
begin
  if not exists (select 1 from public.schools where id = p_school_id) then
    raise exception 'school not found';
  end if;

  insert into public.academic_years (school_id, label, starts_on, ends_on, is_active)
  values (p_school_id, extract(year from now())::text, make_date(extract(year from now())::int, 3, 1), make_date(extract(year from now())::int, 12, 20), true)
  on conflict (school_id, label) do update set is_active = true
  returning id into v_year_id;

  insert into public.subjects (school_id, slug, name, color, icon_code, is_demo)
  values
    (p_school_id, 'matematica', 'Matematica', '#e6b84d', 'MAT', true),
    (p_school_id, 'comunicacion', 'Comunicacion', '#9d55f5', 'COM', true),
    (p_school_id, 'ciencia', 'Ciencia y Tecnologia', '#28c9d7', 'CIE', true),
    (p_school_id, 'personal-social', 'Personal Social', '#ef4d5f', 'HIS', true),
    (p_school_id, 'arte', 'Arte y Cultura', '#e58f3d', 'ART', true)
  on conflict (school_id, slug) do nothing;

  select id into v_math from public.subjects where school_id = p_school_id and slug = 'matematica';
  select id into v_com from public.subjects where school_id = p_school_id and slug = 'comunicacion';
  select id into v_sci from public.subjects where school_id = p_school_id and slug = 'ciencia';
  select id into v_history from public.subjects where school_id = p_school_id and slug = 'personal-social';
  select id into v_art from public.subjects where school_id = p_school_id and slug = 'arte';

  insert into public.sections (school_id, academic_year_id, level, grade, section_label, code, display_name, tutor_name, is_demo)
  values
    (p_school_id, v_year_id, 'Primaria', '5', 'A', '5P-A', '5. Primaria A', 'Tutor por asignar', true),
    (p_school_id, v_year_id, 'Primaria', '6', 'A', '6P-A', '6. Primaria A', 'Tutor por asignar', true)
  on conflict (school_id, code) do nothing;

  select id into v_section_a from public.sections where school_id = p_school_id and code = '5P-A';
  select id into v_section_b from public.sections where school_id = p_school_id and code = '6P-A';

  insert into public.section_subjects (section_id, subject_id)
  select s.id, m.id
  from public.sections s cross join public.subjects m
  where s.school_id = p_school_id and m.school_id = p_school_id
  on conflict do nothing;

  insert into public.clans (school_id, section_id, name, color, rank_name, is_demo)
  values
    (p_school_id, v_section_a, 'Guardianes Rojos', '#ef3340', 'Escudero', true),
    (p_school_id, v_section_a, 'Sabios Morados', '#9d55f5', 'Escudero', true),
    (p_school_id, v_section_b, 'Torres Carmesi', '#d5233f', 'Escudero', true),
    (p_school_id, v_section_b, 'Cronistas Violetas', '#7c3ed6', 'Escudero', true)
  on conflict do nothing;

  if not exists (select 1 from public.student_profiles where school_id = p_school_id) then
    insert into public.student_profiles (school_id, full_name, section_id, accessibility_preferences, is_demo)
    values
      (p_school_id, 'Ana Torres', v_section_a, '{"demo":true}', true),
      (p_school_id, 'Diego Ramos', v_section_a, '{"demo":true}', true),
      (p_school_id, 'Lucia Vargas', v_section_a, '{"demo":true,"focus_mode":true}', true),
      (p_school_id, 'Marco Salas', v_section_a, '{"demo":true}', true),
      (p_school_id, 'Camila Rios', v_section_b, '{"demo":true}', true),
      (p_school_id, 'Jose Medina', v_section_b, '{"demo":true}', true),
      (p_school_id, 'Valeria Cruz', v_section_b, '{"demo":true,"reduced_motion":true}', true),
      (p_school_id, 'Bruno Leon', v_section_b, '{"demo":true}', true);
  end if;

  insert into public.learning_materials (school_id, subject_id, title, file_name, file_type, processing_status, is_demo)
  select p_school_id, v_math, 'Fracciones y operaciones', 'fracciones-demo.pdf', 'pdf', 'ready', true
  where not exists (select 1 from public.learning_materials where school_id = p_school_id and title = 'Fracciones y operaciones');
  insert into public.learning_materials (school_id, subject_id, title, file_name, file_type, processing_status, is_demo)
  select p_school_id, v_com, 'Comprension lectora', 'lectura-demo.docx', 'docx', 'ready', true
  where not exists (select 1 from public.learning_materials where school_id = p_school_id and title = 'Comprension lectora');
  insert into public.learning_materials (school_id, subject_id, title, file_name, file_type, processing_status, is_demo)
  select p_school_id, v_sci, 'El ciclo del agua', 'ciclo-agua-demo.pptx', 'pptx', 'ready', true
  where not exists (select 1 from public.learning_materials where school_id = p_school_id and title = 'El ciclo del agua');

  if not exists (select 1 from public.question_bank where school_id = p_school_id) then
    insert into public.question_bank (school_id, subject_id, question, options, correct_index, source, is_demo)
    values
      (p_school_id, v_math, 'Cuanto es 3/4 de 20?', '["10","12","15","18"]', 2, 'demo', true),
      (p_school_id, v_math, 'Cual es el resultado de 8 x 7?', '["54","56","58","64"]', 1, 'demo', true),
      (p_school_id, v_com, 'Cual es el sinonimo de rapido?', '["Lento","Veloz","Lejano","Debil"]', 1, 'demo', true),
      (p_school_id, v_com, 'Que palabra es un sustantivo?', '["Correr","Azul","Escuela","Rapidamente"]', 2, 'demo', true),
      (p_school_id, v_sci, 'En que estado se encuentra el hielo?', '["Liquido","Gaseoso","Solido","Plasma"]', 2, 'demo', true),
      (p_school_id, v_sci, 'Que organo bombea la sangre?', '["Pulmon","Corazon","Rinon","Estomago"]', 1, 'demo', true),
      (p_school_id, v_history, 'Cual es la capital del Peru?', '["Cusco","Arequipa","Lima","Piura"]', 2, 'demo', true),
      (p_school_id, v_history, 'Que oceano limita con el Peru?', '["Atlantico","Pacifico","Indico","Artico"]', 1, 'demo', true),
      (p_school_id, v_art, 'Que colores forman el verde?', '["Rojo y azul","Azul y amarillo","Rojo y blanco","Negro y amarillo"]', 1, 'demo', true),
      (p_school_id, v_art, 'Que elemento pertenece al ritmo musical?', '["Compas","Perspectiva","Textura","Volumen"]', 0, 'demo', true);
  end if;

  insert into public.school_settings (school_id, battle_rules, rank_rules, ai_preferences, accessibility)
  values (
    p_school_id,
    '{"mode":"turn_based","first_team":"red","min_layers":4,"max_layers":7,"nodes_per_layer":{"min":3,"max":4},"capture_rule":"fastest_correct_time","base_rounds":3}',
    '{"starting_rank":"Aprendiz","xp_per_correct_answer":10,"xp_per_task":20,"clans_enabled":true}',
    '{"question_review_required":true,"post_battle_summary":true,"teacher_assistant":true,"student_assistant":true}',
    '{"focus_mode":true,"reduced_motion":true,"extended_time":true,"tdah_support":true}'
  ) on conflict (school_id) do nothing;
end;
$$;

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

  select school_id into v_school_id
  from public.memberships
  where user_id = v_user_id and role = 'owner'
  order by created_at asc limit 1;

  if v_school_id is not null then return v_school_id; end if;

  select * into v_plan from public.plans where slug = p_plan_slug;
  if not found then select * into v_plan from public.plans where slug = 'explorador'; end if;

  select coalesce(nullif(full_name, ''), split_part(coalesce(email, 'BattleGraph'), '@', 1))
  into v_name from public.profiles where id = v_user_id;

  insert into public.schools (name, created_by, onboarding_complete)
  values ('Academia BattleGraph de ' || coalesce(v_name, 'Administrador'), v_user_id, true)
  returning id into v_school_id;

  update public.schools set code = 'BG-' || upper(substr(replace(v_school_id::text, '-', ''), 1, 8)) where id = v_school_id;

  insert into public.memberships (school_id, user_id, role)
  values (v_school_id, v_user_id, 'owner');

  insert into public.subscriptions (
    school_id, plan_slug, status, student_limit, ai_credits_monthly,
    current_period_end, trial_plan_slug, trial_started_at, trial_ends_at
  ) values (
    v_school_id,
    v_plan.slug,
    case when v_plan.slug = 'explorador' then 'trialing' else 'active' end,
    v_plan.student_limit,
    v_plan.ai_credits_monthly,
    case when v_plan.slug = 'explorador' then now() + interval '7 days' else null end,
    case when v_plan.slug = 'explorador' then 'red' else null end,
    case when v_plan.slug = 'explorador' then now() else null end,
    case when v_plan.slug = 'explorador' then now() + interval '7 days' else null end
  );

  perform public.seed_school_defaults(v_school_id);
  return v_school_id;
end;
$$;

update public.subscriptions
set status = case when created_at + interval '7 days' > now() then 'trialing' else 'active' end,
    trial_plan_slug = 'red',
    trial_started_at = created_at,
    trial_ends_at = created_at + interval '7 days',
    current_period_end = created_at + interval '7 days'
where plan_slug = 'explorador' and trial_started_at is null;

do $$
declare v_school_id uuid;
begin
  for v_school_id in select id from public.schools loop
    perform public.seed_school_defaults(v_school_id);
  end loop;
end $$;

alter table public.academic_years enable row level security;
alter table public.subjects enable row level security;
alter table public.sections enable row level security;
alter table public.section_subjects enable row level security;
alter table public.clans enable row level security;
alter table public.learning_materials enable row level security;
alter table public.question_bank enable row level security;
alter table public.school_settings enable row level security;

create policy "members read academic years" on public.academic_years for select using (public.is_school_member(school_id));
create policy "admins manage academic years" on public.academic_years for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "members read subjects" on public.subjects for select using (public.is_school_member(school_id));
create policy "admins manage subjects" on public.subjects for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "members read sections" on public.sections for select using (public.is_school_member(school_id));
create policy "admins manage sections" on public.sections for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "members read section subjects" on public.section_subjects for select using (public.is_school_member((select school_id from public.sections where id = section_id)));
create policy "admins manage section subjects" on public.section_subjects for all using (public.is_school_admin((select school_id from public.sections where id = section_id))) with check (public.is_school_admin((select school_id from public.sections where id = section_id)));
create policy "members read clans" on public.clans for select using (public.is_school_member(school_id));
create policy "admins manage clans" on public.clans for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "members read materials" on public.learning_materials for select using (public.is_school_member(school_id));
create policy "admins manage materials" on public.learning_materials for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "members read questions" on public.question_bank for select using (public.is_school_member(school_id));
create policy "admins manage questions" on public.question_bank for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "members read school settings" on public.school_settings for select using (public.is_school_member(school_id));
create policy "admins manage school settings" on public.school_settings for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));
create policy "admins manage student profiles" on public.student_profiles for all using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));

grant select, insert, update, delete on public.academic_years, public.subjects, public.sections,
  public.section_subjects, public.clans, public.learning_materials, public.question_bank,
  public.school_settings, public.student_profiles to authenticated;
grant execute on function public.bootstrap_institution_account(text) to authenticated;
revoke all on function public.seed_school_defaults(uuid) from public, anon, authenticated;

