-- Preserve roster identity and section scope during student onboarding.

with student_candidates as (
  select
    sp.id as profile_id,
    m.id as membership_id,
    count(*) over (partition by sp.id) as profile_matches,
    count(*) over (partition by m.id) as membership_matches
  from public.student_profiles sp
  join public.memberships m
    on m.school_id = sp.school_id
   and m.role = 'student'
   and m.status = 'active'
  join auth.users u on u.id = m.user_id
  where sp.membership_id is null
    and coalesce(sp.is_demo, false) = false
    and nullif(btrim(sp.email), '') is not null
    and lower(btrim(sp.email)) = lower(btrim(coalesce(u.email, '')))
)
update public.student_profiles sp
set membership_id = candidates.membership_id
from student_candidates candidates
where sp.id = candidates.profile_id
  and candidates.profile_matches = 1
  and candidates.membership_matches = 1;

create index if not exists idx_student_profiles_school_normalized_email
  on public.student_profiles (school_id, lower(btrim(email)))
  where email is not null;

create or replace function public.link_or_create_student_profile(
  p_school_id uuid,
  p_membership_id uuid,
  p_full_name text,
  p_email text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_existing_membership_id uuid;
  v_profile_count integer;
  v_section_profile_count integer;
  v_conflicting_profile_count integer;
  v_email text := nullif(btrim(p_email), '');
begin
  if p_school_id is null or p_membership_id is null then
    raise exception 'school and membership are required';
  end if;

  if v_email is not null then
    select count(*) into v_conflicting_profile_count
    from public.student_profiles sp
    where sp.school_id = p_school_id
      and coalesce(sp.is_demo, false) = false
      and lower(btrim(sp.email)) = lower(v_email)
      and sp.membership_id is not null
      and sp.membership_id <> p_membership_id;
    if v_conflicting_profile_count > 0 then
      raise exception 'student profile is linked to another membership';
    end if;
  end if;

  select count(*) into v_profile_count
  from public.student_profiles sp
  where sp.school_id = p_school_id
    and (
      sp.membership_id = p_membership_id
      or (
        sp.membership_id is null
        and coalesce(sp.is_demo, false) = false
        and v_email is not null
        and lower(btrim(sp.email)) = lower(v_email)
      )
    );

  if v_profile_count > 0 then
    select count(*) into v_section_profile_count
    from public.student_profiles sp
    where sp.school_id = p_school_id
      and sp.section_id is not null
      and (
        sp.membership_id = p_membership_id
        or (
          sp.membership_id is null
          and coalesce(sp.is_demo, false) = false
          and v_email is not null
          and lower(btrim(sp.email)) = lower(v_email)
        )
      );

    if v_section_profile_count > 1 then
      raise exception 'student profile is ambiguous';
    elsif v_section_profile_count = 1 then
      select sp.id, sp.membership_id
      into v_profile_id, v_existing_membership_id
      from public.student_profiles sp
      where sp.school_id = p_school_id
        and sp.section_id is not null
        and (
          sp.membership_id = p_membership_id
          or (
            sp.membership_id is null
            and coalesce(sp.is_demo, false) = false
            and v_email is not null
            and lower(btrim(sp.email)) = lower(v_email)
          )
        );
    elsif v_profile_count = 1 then
      select sp.id, sp.membership_id
      into v_profile_id, v_existing_membership_id
      from public.student_profiles sp
      where sp.school_id = p_school_id
        and (
          sp.membership_id = p_membership_id
          or (
            sp.membership_id is null
            and coalesce(sp.is_demo, false) = false
            and v_email is not null
            and lower(btrim(sp.email)) = lower(v_email)
          )
        );
    else
      raise exception 'student profile is ambiguous';
    end if;

    if v_existing_membership_id is null then
      update public.student_profiles
      set membership_id = p_membership_id
      where id = v_profile_id;
    end if;
    return v_profile_id;
  end if;

  insert into public.student_profiles (
    school_id, membership_id, full_name, email, accessibility_preferences
  ) values (
    p_school_id,
    p_membership_id,
    coalesce(nullif(btrim(p_full_name), ''), 'Estudiante'),
    v_email,
    '{}'::jsonb
  )
  returning id into v_profile_id;
  return v_profile_id;
end;
$$;

create or replace function public.complete_mobile_onboarding(
  p_role text,
  p_school_code text default null,
  p_school_name text default null,
  p_region text default null,
  p_plan_slug text default 'explorador'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_role text := lower(btrim(coalesce(p_role, '')));
  v_school_code text := upper(btrim(coalesce(p_school_code, '')));
  v_school_count integer;
  v_school_id uuid;
  v_membership_id uuid;
  v_name text;
  v_email text;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  if v_role not in ('director', 'teacher', 'student') then
    raise exception 'invalid role';
  end if;

  perform 1 from auth.users where id = v_user_id for update;

  select school_id into v_school_id
  from public.memberships
  where user_id = v_user_id and status = 'active'
  order by created_at
  limit 1;
  if v_school_id is not null then return v_school_id; end if;

  select
    coalesce(nullif(full_name, ''), split_part(coalesce(email, 'Usuario'), '@', 1)),
    email
  into v_name, v_email
  from public.profiles
  where id = v_user_id;

  if v_role = 'director' then
    v_school_id := public.bootstrap_institution_account(p_plan_slug);
    update public.schools
    set name = coalesce(nullif(btrim(p_school_name), ''), name),
        region = coalesce(nullif(btrim(p_region), ''), region),
        updated_at = now()
    where id = v_school_id and created_by = v_user_id;
    return v_school_id;
  end if;

  if length(v_school_code) < 3 then raise exception 'invalid school code'; end if;
  select count(*) into v_school_count
  from public.schools
  where upper(btrim(code)) = v_school_code;
  if v_school_count = 0 then raise exception 'school not found'; end if;
  if v_school_count <> 1 then raise exception 'school code is ambiguous'; end if;

  select id into v_school_id
  from public.schools
  where upper(btrim(code)) = v_school_code;

  insert into public.memberships (school_id, user_id, role, status)
  values (v_school_id, v_user_id, v_role, 'active')
  returning id into v_membership_id;

  if v_role = 'teacher' then
    insert into public.staff_profiles (
      school_id, membership_id, full_name, email, role, scope_label, status, is_demo
    ) values (
      v_school_id, v_membership_id, coalesce(v_name, 'Docente'), v_email,
      'teacher', 'Por asignar', 'active', false
    );
  else
    perform public.link_or_create_student_profile(
      v_school_id, v_membership_id, v_name, v_email
    );
  end if;
  return v_school_id;
end;
$$;

create or replace function public.join_school_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_school_count integer;
  v_school_id uuid;
  v_membership_id uuid;
  v_membership_status text;
  v_name text;
  v_email text;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  if length(v_code) not between 3 and 64 then raise exception 'invalid school code'; end if;

  perform 1 from auth.users where id = v_user_id for update;

  select count(*) into v_school_count
  from public.schools s
  where upper(btrim(s.code)) = v_code;
  if v_school_count = 0 then raise exception 'school not found'; end if;
  if v_school_count <> 1 then raise exception 'school code is ambiguous'; end if;

  select s.id into v_school_id
  from public.schools s
  where upper(btrim(s.code)) = v_code;

  select m.status into v_membership_status
  from public.memberships m
  where m.user_id = v_user_id and m.school_id = v_school_id;
  if found then
    if v_membership_status = 'active' then raise exception 'membership already exists'; end if;
    raise exception 'membership is inactive';
  end if;

  insert into public.memberships (school_id, user_id, role, status)
  values (v_school_id, v_user_id, 'student', 'active')
  on conflict (school_id, user_id) do nothing
  returning id into v_membership_id;
  if v_membership_id is null then raise exception 'membership already exists'; end if;

  select
    coalesce(
      nullif(btrim(p.full_name), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
      nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
      'Estudiante'
    ),
    u.email
  into v_name, v_email
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = v_user_id;

  perform public.link_or_create_student_profile(
    v_school_id, v_membership_id, v_name, v_email
  );
  return v_membership_id;
end;
$$;

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
  join public.student_profiles sp on sp.id = ce.student_profile_id
  where ce.class_id = v_class_id
    and sp.membership_id = v_membership_id
  order by (ce.student_profile_id = v_student_profile_id) desc, ce.created_at
  limit 1;

  if v_enrollment_id is not null then
    update public.class_enrollments
    set academic_year_id = v_academic_year_id,
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

revoke all on function public.link_or_create_student_profile(uuid, uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.complete_mobile_onboarding(text, text, text, text, text)
  from public, anon;
revoke all on function public.join_school_by_code(text) from public, anon;
revoke all on function public.enroll_student_by_code(text) from public, anon;
grant execute on function public.complete_mobile_onboarding(text, text, text, text, text)
  to authenticated;
grant execute on function public.join_school_by_code(text) to authenticated;
grant execute on function public.enroll_student_by_code(text) to authenticated;
