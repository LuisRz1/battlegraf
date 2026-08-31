-- Unifica las matrículas de clases con las identidades institucionales Supabase.
-- student_id se conserva para compatibilidad con el backend JWT anterior.
alter table public.class_enrollments
  alter column student_id drop not null;

create unique index if not exists uq_class_enrollment_student_profile
  on public.class_enrollments(class_id, student_profile_id)
  where student_profile_id is not null;

drop policy if exists "student read own enrollments" on public.class_enrollments;
create policy "student read own enrollments"
  on public.class_enrollments for select
  to authenticated
  using (
    student_id = auth.uid()
    or exists (
      select 1
      from public.student_profiles sp
      join public.memberships m on m.id = sp.membership_id
      where sp.id = class_enrollments.student_profile_id
        and m.user_id = auth.uid()
    )
    or exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid()
        and m.school_id = (
          select school_id from public.classes where id = class_enrollments.class_id
        )
        and m.role in ('owner','director','subdirector','coordinator','tutor','teacher')
    )
  );

drop policy if exists "student insert own enrollment" on public.class_enrollments;
create policy "student insert own enrollment"
  on public.class_enrollments for insert
  to authenticated
  with check (
    student_id = auth.uid()
    or exists (
      select 1
      from public.student_profiles sp
      join public.memberships m on m.id = sp.membership_id
      where sp.id = class_enrollments.student_profile_id
        and m.user_id = auth.uid()
        and m.role = 'student'
        and m.status = 'active'
    )
  );

create or replace function public.enroll_student_by_code(p_join_code text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_class_id uuid;
  v_school_id uuid;
  v_academic_year_id uuid;
  v_student_profile_id uuid;
  v_enrollment_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;

  select c.id, c.school_id, c.academic_year_id
  into v_class_id, v_school_id, v_academic_year_id
  from public.classes c
  where upper(c.code) = upper(trim(p_join_code))
    and c.is_active = true
    and exists (
      select 1 from public.academic_years ay
      where ay.id = c.academic_year_id and ay.is_active = true
    )
  limit 1;
  if v_class_id is null then raise exception 'class not found or not active for this year'; end if;

  select sp.id into v_student_profile_id
  from public.student_profiles sp
  join public.memberships m on m.id = sp.membership_id
  where m.user_id = auth.uid() and m.school_id = v_school_id
    and m.role = 'student' and m.status = 'active'
  limit 1;
  if v_student_profile_id is null then raise exception 'student profile not found'; end if;

  select id into v_enrollment_id from public.class_enrollments
  where class_id = v_class_id and student_profile_id = v_student_profile_id
  limit 1;
  if v_enrollment_id is null then
    insert into public.class_enrollments
      (id, class_id, student_profile_id, academic_year_id, status, is_active,
       enrolled_at, created_at, updated_at)
    values
      (gen_random_uuid(), v_class_id, v_student_profile_id, v_academic_year_id,
       'active', true, now(), now(), now())
    returning id into v_enrollment_id;
  end if;
  return v_enrollment_id;
end;
$$;

grant execute on function public.enroll_student_by_code(text) to authenticated;
revoke all on function public.enroll_student_by_code(text) from anon;
