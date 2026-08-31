-- BattleGraph: seguimiento academico integral para el piloto.
-- Comparte datos entre el panel web, FastAPI y la aplicacion Flutter.

alter table public.staff_profiles
  add column if not exists membership_id uuid references public.memberships(id) on delete set null;

alter table public.sections
  add column if not exists tutor_staff_id uuid references public.staff_profiles(id) on delete set null;

create unique index if not exists uq_staff_profile_membership
  on public.staff_profiles(membership_id) where membership_id is not null;

-- Vincula perfiles creados antes de esta migracion por colegio y correo.
update public.staff_profiles sp
set membership_id = m.id
from public.memberships m
join auth.users u on u.id = m.user_id
where sp.membership_id is null
  and m.school_id = sp.school_id
  and lower(coalesce(sp.email, '')) = lower(coalesce(u.email, ''))
  and sp.email is not null;

update public.sections s
set tutor_staff_id = sp.id
from public.staff_profiles sp
where s.tutor_staff_id is null
  and sp.school_id = s.school_id
  and sp.role = 'tutor'
  and lower(trim(coalesce(sp.full_name, ''))) = lower(trim(coalesce(s.tutor_name, '')))
  and coalesce(s.tutor_name, '') <> '';

create table if not exists public.academic_periods (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  academic_year_id uuid references public.academic_years(id) on delete set null,
  name text not null,
  starts_on date not null,
  ends_on date not null,
  is_active boolean not null default true,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  constraint academic_period_dates check (ends_on >= starts_on),
  unique (school_id, name, starts_on)
);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_profile_id uuid not null references public.student_profiles(id) on delete cascade,
  section_id uuid references public.sections(id) on delete set null,
  attendance_date date not null,
  status text not null check (status in ('present','late','absent','excused')),
  minutes_late integer not null default 0 check (minutes_late between 0 and 600),
  note text,
  recorded_by_membership_id uuid references public.memberships(id) on delete set null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_profile_id, attendance_date)
);

create table if not exists public.grade_items (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  academic_period_id uuid references public.academic_periods(id) on delete set null,
  section_id uuid references public.sections(id) on delete set null,
  subject_id uuid not null references public.subjects(id) on delete cascade,
  assignment_id uuid references public.assignments(id) on delete set null,
  title text not null,
  category text not null default 'assessment'
    check (category in ('assessment','task','battle','participation','project')),
  max_score numeric(8,2) not null default 20 check (max_score > 0),
  weight numeric(6,2) not null default 1 check (weight > 0),
  due_on date,
  status text not null default 'published' check (status in ('draft','published','closed')),
  created_by_membership_id uuid references public.memberships(id) on delete set null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.student_grades (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  grade_item_id uuid not null references public.grade_items(id) on delete cascade,
  student_profile_id uuid not null references public.student_profiles(id) on delete cascade,
  score numeric(8,2),
  status text not null default 'graded' check (status in ('pending','graded','missing','excused')),
  feedback text,
  graded_by_membership_id uuid references public.memberships(id) on delete set null,
  graded_at timestamptz,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (grade_item_id, student_profile_id)
);

create table if not exists public.student_observations (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_profile_id uuid not null references public.student_profiles(id) on delete cascade,
  category text not null default 'academic'
    check (category in ('academic','attendance','achievement','behavior','wellbeing','support')),
  note text not null check (char_length(note) between 3 and 2000),
  visibility text not null default 'academic_team'
    check (visibility in ('academic_team','student')),
  follow_up_on date,
  status text not null default 'open' check (status in ('open','resolved','archived')),
  author_membership_id uuid references public.memberships(id) on delete set null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_attendance_school_date on public.attendance_records(school_id, attendance_date desc);
create index if not exists idx_attendance_student_date on public.attendance_records(student_profile_id, attendance_date desc);
create index if not exists idx_grade_items_scope on public.grade_items(school_id, section_id, subject_id);
create index if not exists idx_student_grades_student on public.student_grades(student_profile_id, graded_at desc);
create index if not exists idx_observations_student on public.student_observations(student_profile_id, created_at desc);

create or replace function public.can_view_student_profile(p_student_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with target as (
    select sp.id, sp.school_id, sp.section_id, sp.membership_id
    from public.student_profiles sp where sp.id = p_student_profile_id
  ), me as (
    select m.id, m.school_id, m.role
    from public.memberships m
    where m.user_id = auth.uid() and m.status = 'active'
  ), my_staff as (
    select sf.id, sf.school_id, sf.role
    from public.staff_profiles sf
    join me on me.id = sf.membership_id
  )
  select exists (
    select 1 from target t
    join me on me.school_id = t.school_id
    where me.role in ('owner','director','subdirector','coordinator')
       or (me.role = 'student' and me.id = t.membership_id)
       or (me.role = 'tutor' and exists (
            select 1 from public.sections s
            join my_staff sf on sf.id = s.tutor_staff_id
            where s.id = t.section_id
          ))
       or (me.role = 'teacher' and exists (
            select 1
            from public.classes c
            join public.subject_teachers st on st.subject_id = c.subject_id
            join my_staff sf on sf.id = st.staff_id
            where c.school_id = t.school_id and c.section_id = t.section_id and c.is_active = true
          ))
  );
$$;

create or replace function public.can_manage_academic_student(p_student_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_view_student_profile(p_student_profile_id)
    and exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid() and m.status = 'active'
        and m.role in ('owner','director','subdirector','coordinator','tutor','teacher')
    );
$$;

alter table public.academic_periods enable row level security;
alter table public.attendance_records enable row level security;
alter table public.grade_items enable row level security;
alter table public.student_grades enable row level security;
alter table public.student_observations enable row level security;

create policy "members read academic periods" on public.academic_periods
  for select to authenticated using (public.is_school_member(school_id));
create policy "admins manage academic periods" on public.academic_periods
  for all to authenticated using (public.is_school_admin(school_id)) with check (public.is_school_admin(school_id));

create policy "scoped attendance read" on public.attendance_records
  for select to authenticated using (public.can_view_student_profile(student_profile_id));
create policy "scoped attendance manage" on public.attendance_records
  for all to authenticated using (public.can_manage_academic_student(student_profile_id))
  with check (public.can_manage_academic_student(student_profile_id));

create policy "members read grade items" on public.grade_items
  for select to authenticated using (public.is_school_member(school_id));
create policy "academic staff manage grade items" on public.grade_items
  for all to authenticated using (
    exists (select 1 from public.memberships m where m.user_id = auth.uid()
      and m.school_id = grade_items.school_id and m.status = 'active'
      and m.role in ('owner','director','subdirector','coordinator','tutor','teacher'))
  ) with check (
    exists (select 1 from public.memberships m where m.user_id = auth.uid()
      and m.school_id = grade_items.school_id and m.status = 'active'
      and m.role in ('owner','director','subdirector','coordinator','tutor','teacher'))
  );

create policy "scoped grades read" on public.student_grades
  for select to authenticated using (public.can_view_student_profile(student_profile_id));
create policy "scoped grades manage" on public.student_grades
  for all to authenticated using (public.can_manage_academic_student(student_profile_id))
  with check (public.can_manage_academic_student(student_profile_id));

create policy "scoped observations read" on public.student_observations
  for select to authenticated using (
    public.can_view_student_profile(student_profile_id)
    and (visibility = 'student' or exists (
      select 1 from public.memberships m where m.user_id = auth.uid()
        and m.school_id = student_observations.school_id and m.role <> 'student'))
  );
create policy "scoped observations manage" on public.student_observations
  for all to authenticated using (public.can_manage_academic_student(student_profile_id))
  with check (public.can_manage_academic_student(student_profile_id));

grant execute on function public.can_view_student_profile(uuid) to authenticated;

-- Alta móvil y web sobre la misma identidad de Supabase. La búsqueda del
-- colegio por código ocurre dentro de PostgreSQL para no exponer la service key.
create or replace function public.complete_mobile_onboarding(
  p_role text,
  p_school_code text default null,
  p_school_name text default null,
  p_region text default null,
  p_plan_slug text default 'explorador'
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_school_id uuid;
  v_membership_id uuid;
  v_name text;
  v_email text;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  if p_role not in ('director', 'teacher', 'student') then
    raise exception 'invalid role';
  end if;

  select school_id into v_school_id
  from public.memberships
  where user_id = v_user_id and status = 'active'
  order by created_at limit 1;
  if v_school_id is not null then return v_school_id; end if;

  select coalesce(nullif(full_name, ''), split_part(coalesce(email, 'Usuario'), '@', 1)), email
  into v_name, v_email
  from public.profiles where id = v_user_id;

  if p_role = 'director' then
    v_school_id := public.bootstrap_institution_account(p_plan_slug);
    update public.schools
    set name = coalesce(nullif(trim(p_school_name), ''), name),
        region = coalesce(nullif(trim(p_region), ''), region),
        updated_at = now()
    where id = v_school_id and created_by = v_user_id;
    return v_school_id;
  end if;

  select id into v_school_id
  from public.schools
  where upper(code) = upper(trim(p_school_code))
  limit 1;
  if v_school_id is null then raise exception 'school not found'; end if;

  insert into public.memberships (school_id, user_id, role, status)
  values (v_school_id, v_user_id, p_role, 'active')
  returning id into v_membership_id;

  if p_role = 'teacher' then
    insert into public.staff_profiles (
      school_id, membership_id, full_name, email, role, scope_label, status, is_demo
    ) values (
      v_school_id, v_membership_id, coalesce(v_name, 'Docente'), v_email,
      'teacher', 'Por asignar', 'active', false
    );
  else
    insert into public.student_profiles (
      school_id, membership_id, full_name, email, accessibility_preferences
    ) values (
      v_school_id, v_membership_id, coalesce(v_name, 'Estudiante'), v_email, '{}'::jsonb
    );
  end if;
  return v_school_id;
end;
$$;

grant execute on function public.complete_mobile_onboarding(text, text, text, text, text) to authenticated;
revoke all on function public.complete_mobile_onboarding(text, text, text, text, text) from public, anon;
grant execute on function public.can_manage_academic_student(uuid) to authenticated;
grant select on public.academic_periods, public.attendance_records, public.grade_items,
  public.student_grades, public.student_observations to authenticated;
grant insert, update, delete on public.academic_periods, public.attendance_records,
  public.grade_items, public.student_grades, public.student_observations to authenticated;

-- Datos claramente marcados como demo para probar todas las vistas sin tocar notas reales.
create or replace function public.seed_academic_pilot(p_school_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period uuid;
  v_membership uuid;
  v_item uuid;
  v_subject record;
  v_student record;
  v_day integer;
  v_count integer := 0;
begin
  select id into v_membership from public.memberships
  where user_id = auth.uid() and school_id = p_school_id and status = 'active'
    and role in ('owner','director','subdirector','coordinator') limit 1;
  if v_membership is null then raise exception 'insufficient permissions'; end if;

  insert into public.academic_periods
    (school_id, academic_year_id, name, starts_on, ends_on, is_active, is_demo)
  values (
    p_school_id,
    (select id from public.academic_years where school_id = p_school_id and is_active limit 1),
    'Bimestre 3 - piloto', current_date - 30, current_date + 30, true, true
  ) on conflict (school_id, name, starts_on) do update set is_active = true
  returning id into v_period;

  for v_subject in
    select id, name from public.subjects where school_id = p_school_id and is_enabled = true order by name limit 5
  loop
    insert into public.grade_items
      (school_id, academic_period_id, subject_id, title, category, max_score, weight,
       due_on, status, created_by_membership_id, is_demo)
    select p_school_id, v_period, v_subject.id, 'Diagnostico: ' || v_subject.name,
      'assessment', 20, 1, current_date - 5, 'published', v_membership, true
    where not exists (
      select 1 from public.grade_items gi where gi.school_id = p_school_id
        and gi.academic_period_id = v_period and gi.subject_id = v_subject.id and gi.is_demo
    ) returning id into v_item;
    if v_item is null then
      select id into v_item from public.grade_items where school_id = p_school_id
        and academic_period_id = v_period and subject_id = v_subject.id and is_demo limit 1;
    end if;
    for v_student in select id, section_id from public.student_profiles where school_id = p_school_id
    loop
      insert into public.student_grades
        (school_id, grade_item_id, student_profile_id, score, status, feedback,
         graded_by_membership_id, graded_at, is_demo)
      values (
        p_school_id, v_item, v_student.id,
        11 + (abs(hashtext(v_student.id::text || v_subject.id::text)) % 10),
        'graded', 'Resultado de prueba; reemplazar durante el piloto real.',
        v_membership, now(), true
      ) on conflict (grade_item_id, student_profile_id) do nothing;
      v_count := v_count + 1;
    end loop;
  end loop;

  for v_student in select id, section_id, full_name from public.student_profiles where school_id = p_school_id
  loop
    for v_day in 1..15 loop
      if extract(isodow from current_date - v_day) < 6 then
        insert into public.attendance_records
          (school_id, student_profile_id, section_id, attendance_date, status,
           minutes_late, note, recorded_by_membership_id, is_demo)
        values (
          p_school_id, v_student.id, v_student.section_id, current_date - v_day,
          case when (abs(hashtext(v_student.id::text)) + v_day) % 17 = 0 then 'absent'
               when (abs(hashtext(v_student.id::text)) + v_day) % 9 = 0 then 'late'
               else 'present' end,
          case when (abs(hashtext(v_student.id::text)) + v_day) % 9 = 0 then 8 else 0 end,
          'Registro de prueba', v_membership, true
        ) on conflict (student_profile_id, attendance_date) do nothing;
      end if;
    end loop;
    insert into public.student_observations
      (school_id, student_profile_id, category, note, visibility,
       author_membership_id, is_demo)
    select p_school_id, v_student.id, 'achievement',
      'Participa activamente en las actividades del piloto BattleGraph.',
      'student', v_membership, true
    where not exists (
      select 1 from public.student_observations so
      where so.student_profile_id = v_student.id and so.is_demo
    );
  end loop;

  return jsonb_build_object('ok', true, 'grades_attempted', v_count);
end;
$$;

grant execute on function public.seed_academic_pilot(uuid) to authenticated;
revoke all on function public.seed_academic_pilot(uuid) from anon;
