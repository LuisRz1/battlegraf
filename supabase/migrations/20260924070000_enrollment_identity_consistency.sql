-- Never reassign an enrollment whose legacy user key conflicts with its profile.

create or replace function public.enroll_student_by_code(p_join_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_class_id uuid;
  v_school_id uuid;
  v_academic_year_id uuid;
  v_class_section_id uuid;
  v_membership_id uuid;
  v_student_profile_id uuid;
  v_student_section_id uuid;
  v_profile_count integer;
  v_section_profile_count integer;
  v_enrollment_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;

  select c.id, c.school_id, c.academic_year_id, c.section_id
  into v_class_id, v_school_id, v_academic_year_id, v_class_section_id
  from public.classes c
  join public.academic_years ay
    on ay.id = c.academic_year_id and ay.school_id = c.school_id
  where upper(c.code) = upper(trim(p_join_code))
    and c.is_active = true
    and ay.is_active = true
  limit 1;
  if v_class_id is null then raise exception 'class not found or not active for this year'; end if;

  select m.id into v_membership_id
  from public.memberships m
  where m.user_id = auth.uid()
    and m.school_id = v_school_id
    and m.role = 'student'
    and m.status = 'active';
  if v_membership_id is null then raise exception 'active student membership not found'; end if;

  select count(*) into v_profile_count
  from public.student_profiles sp
  where sp.membership_id = v_membership_id
    and sp.school_id = v_school_id;
  if v_profile_count = 0 then raise exception 'student profile not found'; end if;

  select count(*) into v_section_profile_count
  from public.student_profiles sp
  where sp.membership_id = v_membership_id
    and sp.school_id = v_school_id
    and sp.section_id is not null;
  if v_section_profile_count > 1 then
    raise exception 'student profile is ambiguous';
  elsif v_section_profile_count = 1 then
    select sp.id, sp.section_id
    into v_student_profile_id, v_student_section_id
    from public.student_profiles sp
    where sp.membership_id = v_membership_id
      and sp.school_id = v_school_id
      and sp.section_id is not null;
  elsif v_profile_count = 1 then
    select sp.id, sp.section_id
    into v_student_profile_id, v_student_section_id
    from public.student_profiles sp
    where sp.membership_id = v_membership_id
      and sp.school_id = v_school_id;
  else
    raise exception 'student profile is ambiguous';
  end if;

  if v_class_section_id is not null
     and v_student_section_id is distinct from v_class_section_id then
    raise exception 'class is not available for this section';
  end if;

  select ce.id into v_enrollment_id
  from public.class_enrollments ce
  left join public.student_profiles sp on sp.id = ce.student_profile_id
  where ce.class_id = v_class_id
    and (
      (
        sp.membership_id = v_membership_id
        and sp.school_id = v_school_id
        and (ce.student_id is null or ce.student_id = auth.uid())
      )
      or (ce.student_profile_id is null and ce.student_id = auth.uid())
    )
  order by (ce.student_profile_id = v_student_profile_id) desc nulls last,
    ce.created_at
  limit 1;

  if v_enrollment_id is not null then
    update public.class_enrollments
    set student_profile_id = v_student_profile_id,
        student_id = null,
        academic_year_id = v_academic_year_id,
        status = 'active',
        is_active = true,
        enrolled_at = now(),
        updated_at = now()
    where id = v_enrollment_id;
    return v_enrollment_id;
  end if;

  insert into public.class_enrollments (
    id, class_id, student_profile_id, student_id, academic_year_id,
    status, is_active, enrolled_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_class_id, v_student_profile_id, null, v_academic_year_id,
    'active', true, now(), now(), now()
  )
  on conflict (class_id, student_profile_id) where student_profile_id is not null
  do update set
    academic_year_id = excluded.academic_year_id,
    status = 'active',
    is_active = true,
    enrolled_at = now(),
    updated_at = now()
  returning id into v_enrollment_id;

  return v_enrollment_id;
end;
$$;

revoke all on function public.enroll_student_by_code(text) from public, anon;
grant execute on function public.enroll_student_by_code(text) to authenticated;
