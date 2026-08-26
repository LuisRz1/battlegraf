-- ============================================================
-- Clases multicolegio v2: EXTENDER el esquema existente (classes
-- + class_enrollments) con vigencia anual y vínculos de contenido.
-- Un profesor puede pertenecer a varios colegios (memberships:
-- unique school_id+user_id). Cada CLASE (classes) tiene código
-- propio; los alumnos se enrolan por ese código. Las clases del
-- año se archivan al pasar de año (is_active=false / año nuevo).
-- ============================================================

-- 1) classes: vigencia anual + vínculos de contenido
alter table public.classes
  add column if not exists academic_year_id uuid
    references public.academic_years(id) on delete set null;

alter table public.classes
  add column if not exists section_id uuid
    references public.sections(id) on delete set null;

alter table public.classes
  add column if not exists subject_id uuid
    references public.subjects(id) on delete set null;

comment on column public.classes.academic_year_id is 'Año lectivo de la clase (vigencia anual: al pasar de año se archiva y se crea la nueva).';
comment on column public.classes.code is 'Código público de la clase: los alumnos lo usan para enrolarse.';

-- 2) class_enrollments: vigencia + estado
alter table public.class_enrollments
  add column if not exists academic_year_id uuid
    references public.academic_years(id) on delete set null;

alter table public.class_enrollments
  add column if not exists status text not null default 'active'
    check (status in ('active','dropped','completed'));

-- 3) RLS: miembros del colegio leen sus clases
drop policy if exists "members read classes" on public.classes;
create policy "members read classes"
  on public.classes for select
  to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid() and m.school_id = classes.school_id
    )
  );

drop policy if exists "manage classes" on public.classes;
create policy "manage classes"
  on public.classes for all
  to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid() and m.school_id = classes.school_id
        and m.role in ('director','subdirector','coordinator','tutor','teacher')
    )
  )
  with check (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid() and m.school_id = classes.school_id
        and m.role in ('director','subdirector','coordinator','tutor','teacher')
    )
  );

-- 4) RLS enrolamientos: el alumno lee/inserta los propios; el staff del colegio lee todos
drop policy if exists "student read own enrollments" on public.class_enrollments;
create policy "student read own enrollments"
  on public.class_enrollments for select
  to authenticated
  using (
    class_enrollments.student_id = auth.uid()
    or exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid() and m.school_id = (
        select school_id from public.classes where id = class_enrollments.class_id
      ) and m.role in ('director','subdirector','coordinator','tutor','teacher')
    )
  );

drop policy if exists "student insert own enrollment" on public.class_enrollments;
create policy "student insert own enrollment"
  on public.class_enrollments for insert
  to authenticated
  with check (class_enrollments.student_id = auth.uid());

-- 5) Función: enrolarse por código de clase (solo clases activas del año lectivo vigente)
create or replace function public.enroll_student_by_code(p_join_code text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_class_id uuid;
  v_academic_year_id uuid;
  v_enrollment_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;

  select c.id, c.academic_year_id into v_class_id, v_academic_year_id
  from public.classes c
  where upper(c.code) = upper(p_join_code)
    and c.is_active = true
    and exists (
      select 1 from public.academic_years ay
      where ay.id = c.academic_year_id and ay.is_active = true
    )
  limit 1;
  if v_class_id is null then raise exception 'class not found or not active for this year'; end if;

  insert into public.class_enrollments (class_id, student_id, academic_year_id, status)
  values (v_class_id, auth.uid(), v_academic_year_id, 'active')
  on conflict (class_id, student_id) do nothing
  returning id into v_enrollment_id;

  return coalesce(v_enrollment_id, gen_random_uuid());
end;
$$;

grant execute on function public.enroll_student_by_code(text) to authenticated;
revoke all on function public.enroll_student_by_code(text) from anon;