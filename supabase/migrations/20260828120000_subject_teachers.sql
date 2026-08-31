-- ============================================================
-- Trazabilidad: profesores asignados por curso (materia)
-- Un curso puede tener varios profesores (ej: Trigonometria: 2)
-- y un profesor puede estar en varios cursos.
-- ============================================================
create table if not exists public.subject_teachers (
    id uuid primary key default gen_random_uuid(),
    school_id uuid not null references public.schools(id) on delete cascade,
    subject_id uuid not null references public.subjects(id) on delete cascade,
    staff_id uuid not null references public.staff_profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    unique (subject_id, staff_id)
);

comment on table public.subject_teachers is
  'Profesores asignados a un curso (materia). Varios por curso, varios cursos por profesor.';

alter table public.subject_teachers enable row level security;

create policy "subject_teachers_select" on public.subject_teachers
  for select using (school_id = auth.uid()::text::uuid or exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid() and m.school_id = subject_teachers.school_id));

create policy "subject_teachers_insert" on public.subject_teachers
  for insert with check (exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid() and m.school_id = subject_teachers.school_id
      and m.role in ('owner', 'director', 'subdirector', 'coordinator', 'tutor')));

create policy "subject_teachers_delete" on public.subject_teachers
  for delete using (exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid() and m.school_id = subject_teachers.school_id
      and m.role in ('owner', 'director', 'subdirector', 'coordinator', 'tutor')));

-- Indice para consultas por curso y por profesor
create index if not exists idx_subject_teachers_subject on public.subject_teachers(subject_id);
create index if not exists idx_subject_teachers_staff on public.subject_teachers(staff_id);
create index if not exists idx_subject_teachers_school on public.subject_teachers(school_id);