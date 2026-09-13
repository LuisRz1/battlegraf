-- ============================================================
-- Entregas de tareas y resultados de batallas del alumno (móvil)
-- Permite el dashboard del alumno: tareas pendientes/entregadas e
-- historial de batallas por estudiante.
-- ============================================================

create table if not exists public.assignment_submissions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_profile_id uuid not null references public.student_profiles(id) on delete cascade,
  answer text,
  file_url text,
  is_graded boolean not null default false,
  score numeric,
  xp_awarded integer not null default 0,
  feedback text,
  submitted_at timestamptz not null default now(),
  graded_at timestamptz,
  graded_by_membership_id uuid references public.memberships(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assignment_id, student_profile_id)
);

create index if not exists idx_assignment_submissions_student
  on public.assignment_submissions (student_profile_id, submitted_at desc);
create index if not exists idx_assignment_submissions_school
  on public.assignment_submissions (school_id);

create table if not exists public.battle_results (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_profile_id uuid not null references public.student_profiles(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  subject text,
  mode text not null default 'bot',
  result text not null default 'finished',
  score integer not null default 0,
  opponent_score integer not null default 0,
  nodes_owned integer not null default 0,
  played_at timestamptz not null default now(),
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_battle_results_student
  on public.battle_results (student_profile_id, played_at desc);
create index if not exists idx_battle_results_school
  on public.battle_results (school_id);

alter table public.assignment_submissions enable row level security;
alter table public.battle_results enable row level security;

-- El alumno ve y crea lo suyo; el equipo academico con alcance ve y gestiona.
drop policy if exists assignment_submissions_select on public.assignment_submissions;
create policy assignment_submissions_select on public.assignment_submissions
  for select to authenticated
  using (
    exists (
      select 1 from public.student_profiles sp
      where sp.id = student_profile_id
        and sp.membership_id in (
          select id from public.memberships where user_id = auth.uid()
        )
    )
    or public.can_view_student_profile(student_profile_id)
  );

drop policy if exists assignment_submissions_insert on public.assignment_submissions;
create policy assignment_submissions_insert on public.assignment_submissions
  for insert to authenticated
  with check (
    exists (
      select 1 from public.student_profiles sp
      where sp.id = student_profile_id
        and sp.membership_id in (
          select id from public.memberships where user_id = auth.uid()
        )
    )
    or public.can_manage_academic_student(student_profile_id)
  );

drop policy if exists assignment_submissions_update on public.assignment_submissions;
create policy assignment_submissions_update on public.assignment_submissions
  for update to authenticated
  using (public.can_manage_academic_student(student_profile_id))
  with check (public.can_manage_academic_student(student_profile_id));

drop policy if exists battle_results_select on public.battle_results;
create policy battle_results_select on public.battle_results
  for select to authenticated
  using (
    exists (
      select 1 from public.student_profiles sp
      where sp.id = student_profile_id
        and sp.membership_id in (
          select id from public.memberships where user_id = auth.uid()
        )
    )
    or public.can_view_student_profile(student_profile_id)
  );

drop policy if exists battle_results_insert on public.battle_results;
create policy battle_results_insert on public.battle_results
  for insert to authenticated
  with check (
    exists (
      select 1 from public.student_profiles sp
      where sp.id = student_profile_id
        and sp.membership_id in (
          select id from public.memberships where user_id = auth.uid()
        )
    )
    or public.can_manage_academic_student(student_profile_id)
  );

grant select, insert, update, delete on public.assignment_submissions to authenticated;
grant select, insert, update, delete on public.battle_results to authenticated;
