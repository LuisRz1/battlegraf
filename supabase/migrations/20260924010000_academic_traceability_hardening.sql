-- Repair legacy profile links and enforce identity-scoped academic access.

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
    and nullif(trim(sp.email), '') is not null
    and lower(trim(sp.email)) = lower(trim(coalesce(u.email, '')))
)
update public.student_profiles sp
set membership_id = candidates.membership_id
from student_candidates candidates
where sp.id = candidates.profile_id
  and candidates.profile_matches = 1
  and candidates.membership_matches = 1;

with staff_candidates as (
  select
    sf.id as profile_id,
    m.id as membership_id,
    count(*) over (partition by sf.id) as profile_matches,
    count(*) over (partition by m.id) as membership_matches
  from public.staff_profiles sf
  join public.memberships m
    on m.school_id = sf.school_id
   and m.role in ('teacher', 'tutor')
   and m.status = 'active'
  join auth.users u on u.id = m.user_id
  where sf.membership_id is null
    and nullif(trim(sf.email), '') is not null
    and lower(trim(sf.email)) = lower(trim(coalesce(u.email, '')))
)
update public.staff_profiles sf
set membership_id = candidates.membership_id
from staff_candidates candidates
where sf.id = candidates.profile_id
  and candidates.profile_matches = 1
  and candidates.membership_matches = 1;

drop policy if exists "member insert own student profile" on public.student_profiles;
create policy "member insert own student profile"
  on public.student_profiles for insert to authenticated
  with check (
    exists (
      select 1 from public.memberships m
      where m.id = student_profiles.membership_id
        and m.user_id = auth.uid()
        and m.school_id = student_profiles.school_id
        and m.role = 'student'
        and m.status = 'active'
    )
  );

drop policy if exists "member read own student profile" on public.student_profiles;
create policy "member read own student profile"
  on public.student_profiles for select to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where m.id = student_profiles.membership_id
        and m.user_id = auth.uid()
        and m.school_id = student_profiles.school_id
        and m.role = 'student'
        and m.status = 'active'
    )
  );

drop policy if exists "member insert own staff profile" on public.staff_profiles;
create policy "member insert own staff profile"
  on public.staff_profiles for insert to authenticated
  with check (
    exists (
      select 1 from public.memberships m
      where m.id = staff_profiles.membership_id
        and m.user_id = auth.uid()
        and m.school_id = staff_profiles.school_id
        and m.role in ('teacher', 'tutor')
        and m.status = 'active'
    )
  );

-- The earlier school-member policy exposed every staff row, including email.
-- Admin reads remain covered by "admins manage staff"; staff retain own-row reads.
drop policy if exists "members read staff" on public.staff_profiles;

drop policy if exists "member read own staff profile" on public.staff_profiles;
create policy "member read own staff profile"
  on public.staff_profiles for select to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where m.id = staff_profiles.membership_id
        and m.user_id = auth.uid()
        and m.school_id = staff_profiles.school_id
        and m.role in ('teacher', 'tutor')
        and m.status = 'active'
    )
  );

drop policy if exists "subject_teachers_select" on public.subject_teachers;
create policy "subject_teachers_select" on public.subject_teachers
  for select to authenticated
  using (
    public.is_school_member(school_id)
    and exists (
      select 1 from public.subjects s
      where s.id = subject_teachers.subject_id and s.school_id = subject_teachers.school_id
    )
    and exists (
      select 1 from public.staff_profiles sf
      where sf.id = subject_teachers.staff_id and sf.school_id = subject_teachers.school_id
    )
  );

drop policy if exists "subject_teachers_insert" on public.subject_teachers;
create policy "subject_teachers_insert" on public.subject_teachers
  for insert to authenticated
  with check (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid()
        and m.school_id = subject_teachers.school_id
        and m.status = 'active'
        and m.role in ('owner', 'director', 'subdirector', 'coordinator', 'tutor')
    )
    and exists (
      select 1 from public.subjects s
      where s.id = subject_teachers.subject_id and s.school_id = subject_teachers.school_id
    )
    and exists (
      select 1 from public.staff_profiles sf
      where sf.id = subject_teachers.staff_id and sf.school_id = subject_teachers.school_id
    )
  );

drop policy if exists "subject_teachers_delete" on public.subject_teachers;
create policy "subject_teachers_delete" on public.subject_teachers
  for delete to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid()
        and m.school_id = subject_teachers.school_id
        and m.status = 'active'
        and m.role in ('owner', 'director', 'subdirector', 'coordinator', 'tutor')
    )
    and exists (
      select 1 from public.subjects s
      where s.id = subject_teachers.subject_id and s.school_id = subject_teachers.school_id
    )
    and exists (
      select 1 from public.staff_profiles sf
      where sf.id = subject_teachers.staff_id and sf.school_id = subject_teachers.school_id
    )
  );

drop policy if exists "members read classes" on public.classes;
create policy "members read classes" on public.classes
  for select to authenticated
  using (public.is_school_member(school_id));

drop policy if exists "manage classes" on public.classes;
create policy "manage classes" on public.classes
  for all to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid()
        and m.school_id = classes.school_id
        and m.status = 'active'
        and (
          m.role in ('owner', 'director', 'subdirector', 'coordinator')
          or (m.role = 'tutor' and exists (
            select 1
            from public.staff_profiles sf
          join public.sections s
            on s.tutor_staff_id = sf.id and s.school_id = sf.school_id
          where sf.membership_id = m.id
            and sf.school_id = m.school_id
            and sf.status = 'active'
            and s.id = classes.section_id
          ))
          or (m.role = 'teacher' and exists (
            select 1
            from public.staff_profiles sf
            join public.subject_teachers st
              on st.staff_id = sf.id and st.school_id = sf.school_id
            join public.section_subjects ss
              on ss.section_id = classes.section_id
             and ss.subject_id = classes.subject_id
             and ss.is_enabled = true
            where sf.membership_id = m.id
              and sf.school_id = m.school_id
              and sf.status = 'active'
              and st.subject_id = classes.subject_id
          ))
        )
    )
    and (
      classes.section_id is null
      or exists (
        select 1 from public.sections s
        where s.id = classes.section_id and s.school_id = classes.school_id
      )
    )
    and (
      classes.subject_id is null
      or exists (
        select 1 from public.subjects s
        where s.id = classes.subject_id and s.school_id = classes.school_id
      )
    )
    and (
      classes.section_id is null
      or classes.subject_id is null
      or exists (
        select 1 from public.section_subjects ss
        where ss.section_id = classes.section_id
          and ss.subject_id = classes.subject_id
          and ss.is_enabled = true
      )
    )
    and (
      classes.academic_year_id is null
      or exists (
        select 1 from public.academic_years ay
        where ay.id = classes.academic_year_id and ay.school_id = classes.school_id
      )
    )
  )
  with check (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid()
        and m.school_id = classes.school_id
        and m.status = 'active'
        and (
          m.role in ('owner', 'director', 'subdirector', 'coordinator')
          or (m.role = 'tutor' and exists (
            select 1
            from public.staff_profiles sf
          join public.sections s
            on s.tutor_staff_id = sf.id and s.school_id = sf.school_id
          where sf.membership_id = m.id
            and sf.school_id = m.school_id
            and sf.status = 'active'
            and s.id = classes.section_id
          ))
          or (m.role = 'teacher' and exists (
            select 1
            from public.staff_profiles sf
            join public.subject_teachers st
              on st.staff_id = sf.id and st.school_id = sf.school_id
            join public.section_subjects ss
              on ss.section_id = classes.section_id
             and ss.subject_id = classes.subject_id
             and ss.is_enabled = true
            where sf.membership_id = m.id
              and sf.school_id = m.school_id
              and sf.status = 'active'
              and st.subject_id = classes.subject_id
          ))
        )
    )
    and (
      classes.section_id is null
      or exists (
        select 1 from public.sections s
        where s.id = classes.section_id and s.school_id = classes.school_id
      )
    )
    and (
      classes.subject_id is null
      or exists (
        select 1 from public.subjects s
        where s.id = classes.subject_id and s.school_id = classes.school_id
      )
    )
    and (
      classes.section_id is null
      or classes.subject_id is null
      or exists (
        select 1 from public.section_subjects ss
        where ss.section_id = classes.section_id
          and ss.subject_id = classes.subject_id
          and ss.is_enabled = true
      )
    )
    and (
      classes.academic_year_id is null
      or exists (
        select 1 from public.academic_years ay
        where ay.id = classes.academic_year_id and ay.school_id = classes.school_id
      )
    )
  );

drop policy if exists "members read section subjects" on public.section_subjects;
create policy "members read section subjects" on public.section_subjects
  for select to authenticated
  using (
    exists (
      select 1 from public.sections s
      where s.id = section_subjects.section_id
        and public.is_school_member(s.school_id)
        and exists (
          select 1 from public.subjects subj
          where subj.id = section_subjects.subject_id and subj.school_id = s.school_id
        )
    )
  );

drop policy if exists "admins manage section subjects" on public.section_subjects;
create policy "admins manage section subjects" on public.section_subjects
  for all to authenticated
  using (
    exists (
      select 1 from public.sections s
      where s.id = section_subjects.section_id
        and public.is_school_admin(s.school_id)
        and exists (
          select 1 from public.subjects subj
          where subj.id = section_subjects.subject_id and subj.school_id = s.school_id
        )
    )
  )
  with check (
    exists (
      select 1 from public.sections s
      where s.id = section_subjects.section_id
        and public.is_school_admin(s.school_id)
        and exists (
          select 1 from public.subjects subj
          where subj.id = section_subjects.subject_id and subj.school_id = s.school_id
        )
    )
  );

create or replace function public.can_view_student_profile(p_student_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with target as (
    select sp.id, sp.school_id, sp.section_id, sp.membership_id
    from public.student_profiles sp
    where sp.id = p_student_profile_id
  ), me as (
    select m.id, m.school_id, m.role
    from public.memberships m
    where m.user_id = auth.uid() and m.status = 'active'
  ), my_staff as (
    select sf.id, sf.school_id, sf.role
    from public.staff_profiles sf
    join me on me.id = sf.membership_id and me.school_id = sf.school_id
    where sf.status = 'active'
  )
  select exists (
    select 1 from target t
    join me on me.school_id = t.school_id
    where me.role in ('owner', 'director', 'subdirector', 'coordinator')
       or (me.role = 'student' and me.id = t.membership_id)
       or (me.role = 'tutor' and exists (
            select 1 from public.sections s
            join my_staff sf on sf.id = s.tutor_staff_id and sf.school_id = s.school_id
            where s.id = t.section_id and s.school_id = t.school_id
          ))
       or (me.role = 'teacher' and exists (
             select 1
             from public.classes c
            join public.subjects subject_row
              on subject_row.id = c.subject_id and subject_row.school_id = c.school_id
             join public.subject_teachers st
              on st.school_id = c.school_id and st.subject_id = c.subject_id
            join public.section_subjects ss
              on ss.section_id = c.section_id and ss.subject_id = c.subject_id
             and ss.is_enabled = true
            join my_staff sf
              on sf.id = st.staff_id and sf.school_id = st.school_id
            where c.school_id = t.school_id
              and c.section_id = t.section_id
              and c.is_active = true
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
      select 1
      from public.student_profiles sp
      join public.memberships m on m.school_id = sp.school_id
      where sp.id = p_student_profile_id
        and m.user_id = auth.uid()
        and m.status = 'active'
        and m.role in ('owner', 'director', 'subdirector', 'coordinator', 'tutor', 'teacher')
    );
$$;

create or replace function public.can_manage_grade_item(p_grade_item_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.grade_items gi
    join public.memberships m
      on m.school_id = gi.school_id
     and m.user_id = auth.uid()
     and m.status = 'active'
    where gi.id = p_grade_item_id
      and exists (
        select 1 from public.subjects subj
        where subj.id = gi.subject_id and subj.school_id = gi.school_id
      )
      and (
        gi.section_id is null
        or exists (
          select 1 from public.sections sec
          where sec.id = gi.section_id and sec.school_id = gi.school_id
        )
      )
      and (
        gi.section_id is null
        or exists (
          select 1 from public.section_subjects ss
          where ss.section_id = gi.section_id
            and ss.subject_id = gi.subject_id
            and ss.is_enabled = true
        )
      )
      and (
        gi.academic_period_id is null
        or exists (
          select 1 from public.academic_periods ap
          where ap.id = gi.academic_period_id and ap.school_id = gi.school_id
        )
      )
      and (
        gi.assignment_id is null
        or exists (
          select 1 from public.assignments a
          where a.id = gi.assignment_id
            and a.school_id = gi.school_id
            and (a.section_id is null or a.section_id = gi.section_id)
            and (a.subject_id is null or a.subject_id = gi.subject_id)
        )
      )
      and (
        m.role in ('owner', 'director', 'subdirector', 'coordinator')
        or (m.role = 'tutor' and exists (
          select 1
          from public.staff_profiles sf
          join public.sections s
            on s.tutor_staff_id = sf.id and s.school_id = sf.school_id
          where sf.membership_id = m.id
            and sf.school_id = m.school_id
            and sf.status = 'active'
            and s.id = gi.section_id
        ))
        or (m.role = 'teacher' and exists (
          select 1
          from public.staff_profiles sf
          join public.subject_teachers st
            on st.staff_id = sf.id and st.school_id = sf.school_id
          join public.section_subjects ss
            on ss.section_id = gi.section_id and ss.subject_id = gi.subject_id
           and ss.is_enabled = true
          join public.classes c
            on c.school_id = gi.school_id
           and c.section_id = gi.section_id
           and c.subject_id = gi.subject_id
           and c.is_active = true
          join public.subjects subject_row
            on subject_row.id = gi.subject_id and subject_row.school_id = gi.school_id
          where sf.membership_id = m.id
            and sf.school_id = m.school_id
            and sf.status = 'active'
            and st.subject_id = gi.subject_id
        ))
      )
  );
$$;

create or replace function public.can_manage_student_grade(
  p_grade_item_id uuid,
  p_student_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.grade_items gi
    join public.student_profiles sp
      on sp.id = p_student_profile_id and sp.school_id = gi.school_id
    where gi.id = p_grade_item_id
      and (gi.section_id is null or gi.section_id = sp.section_id)
      and public.can_manage_grade_item(gi.id)
  );
$$;

drop policy if exists "academic staff manage grade items" on public.grade_items;
create policy "academic staff manage grade items" on public.grade_items
  for all to authenticated
  using (public.can_manage_grade_item(id))
  with check (public.can_manage_grade_item(id));

drop policy if exists "scoped attendance read" on public.attendance_records;
create policy "scoped attendance read" on public.attendance_records
  for select to authenticated
  using (
    public.can_view_student_profile(student_profile_id)
    and school_id = (
      select sp.school_id from public.student_profiles sp
      where sp.id = attendance_records.student_profile_id
    )
    and (
      attendance_records.section_id is null
      or exists (
        select 1 from public.sections s
        where s.id = attendance_records.section_id and s.school_id = attendance_records.school_id
      )
    )
  );

drop policy if exists "scoped attendance manage" on public.attendance_records;
create policy "scoped attendance manage" on public.attendance_records
  for all to authenticated
  using (
    public.can_manage_academic_student(student_profile_id)
    and school_id = (
      select sp.school_id from public.student_profiles sp
      where sp.id = attendance_records.student_profile_id
    )
    and (
      attendance_records.section_id is null
      or exists (
        select 1 from public.sections s
        where s.id = attendance_records.section_id and s.school_id = attendance_records.school_id
      )
    )
  )
  with check (
    public.can_manage_academic_student(student_profile_id)
    and school_id = (
      select sp.school_id from public.student_profiles sp
      where sp.id = attendance_records.student_profile_id
    )
    and (
      attendance_records.section_id is null
      or exists (
        select 1 from public.sections s
        where s.id = attendance_records.section_id and s.school_id = attendance_records.school_id
      )
    )
  );

drop policy if exists "scoped grades read" on public.student_grades;
create policy "scoped grades read" on public.student_grades
  for select to authenticated
  using (
    public.can_view_student_profile(student_profile_id)
    and school_id = (
      select sp.school_id from public.student_profiles sp
      where sp.id = student_grades.student_profile_id
    )
  );

drop policy if exists "scoped grades manage" on public.student_grades;
create policy "scoped grades manage" on public.student_grades
  for all to authenticated
  using (
    public.can_manage_student_grade(grade_item_id, student_profile_id)
    and school_id = (
      select sp.school_id from public.student_profiles sp
      where sp.id = student_grades.student_profile_id
    )
  )
  with check (
    public.can_manage_student_grade(grade_item_id, student_profile_id)
    and school_id = (
      select sp.school_id from public.student_profiles sp
      where sp.id = student_grades.student_profile_id
    )
  );

drop policy if exists "scoped observations read" on public.student_observations;
create policy "scoped observations read" on public.student_observations
  for select to authenticated
  using (
    public.can_view_student_profile(student_profile_id)
    and school_id = (
      select sp.school_id from public.student_profiles sp
      where sp.id = student_observations.student_profile_id
    )
    and (
      visibility = 'student'
      or exists (
        select 1 from public.memberships m
        where m.user_id = auth.uid()
          and m.school_id = student_observations.school_id
          and m.status = 'active'
          and m.role <> 'student'
      )
    )
  );

drop policy if exists "scoped observations manage" on public.student_observations;
create policy "scoped observations manage" on public.student_observations
  for all to authenticated
  using (
    public.can_manage_academic_student(student_profile_id)
    and school_id = (
      select sp.school_id from public.student_profiles sp
      where sp.id = student_observations.student_profile_id
    )
  )
  with check (
    public.can_manage_academic_student(student_profile_id)
    and school_id = (
      select sp.school_id from public.student_profiles sp
      where sp.id = student_observations.student_profile_id
    )
  );

drop policy if exists "student read own enrollments" on public.class_enrollments;
create policy "student read own enrollments"
  on public.class_enrollments for select to authenticated
  using (
    exists (
      select 1
      from public.memberships m
      join public.classes c on c.school_id = m.school_id
      where m.user_id = auth.uid()
        and m.role = 'student'
        and m.status = 'active'
        and c.id = class_enrollments.class_id
        and (
          class_enrollments.academic_year_id is null
          or class_enrollments.academic_year_id = c.academic_year_id
        )
        and (
          exists (
            select 1 from public.student_profiles sp
            where sp.id = class_enrollments.student_profile_id
              and sp.membership_id = m.id
              and (
                class_enrollments.student_id is null
                or class_enrollments.student_id = auth.uid()
              )
          )
          or (
            class_enrollments.student_profile_id is null
            and class_enrollments.student_id = auth.uid()
          )
        )
    )
    or exists (
      select 1
      from public.memberships m
      join public.classes c on c.school_id = m.school_id
      where m.user_id = auth.uid()
        and m.status = 'active'
        and c.id = class_enrollments.class_id
        and (
          class_enrollments.academic_year_id is null
          or class_enrollments.academic_year_id = c.academic_year_id
        )
        and (
          m.role in ('owner', 'director', 'subdirector', 'coordinator')
          or (m.role = 'tutor' and exists (
            select 1
            from public.staff_profiles sf
            join public.sections s
              on s.tutor_staff_id = sf.id and s.school_id = sf.school_id
            where sf.membership_id = m.id
              and sf.school_id = m.school_id
              and sf.status = 'active'
              and s.id = c.section_id
          ))
          or (m.role = 'teacher' and exists (
            select 1
            from public.staff_profiles sf
            join public.subject_teachers st
              on st.staff_id = sf.id and st.school_id = sf.school_id
            join public.section_subjects ss
              on ss.section_id = c.section_id and ss.subject_id = c.subject_id
             and ss.is_enabled = true
            where sf.membership_id = m.id
              and sf.school_id = m.school_id
              and sf.status = 'active'
              and st.subject_id = c.subject_id
              and exists (
                select 1 from public.subjects s
                where s.id = c.subject_id and s.school_id = c.school_id
              )
          ))
        )
    )
  );

drop policy if exists "student insert own enrollment" on public.class_enrollments;
create policy "student insert own enrollment"
  on public.class_enrollments for insert to authenticated
  with check (
    exists (
      select 1
      from public.memberships m
      join public.classes c on c.school_id = m.school_id
      where m.user_id = auth.uid()
        and m.role = 'student'
        and m.status = 'active'
        and c.id = class_enrollments.class_id
        and c.is_active = true
        and c.academic_year_id is not null
        and exists (
          select 1 from public.academic_years ay
          where ay.id = c.academic_year_id
            and ay.school_id = c.school_id
            and ay.is_active = true
        )
        and (
          class_enrollments.academic_year_id is null
          or class_enrollments.academic_year_id = c.academic_year_id
        )
        and (
          exists (
            select 1 from public.student_profiles sp
            where sp.id = class_enrollments.student_profile_id
              and sp.membership_id = m.id
              and (
                class_enrollments.student_id is null
                or class_enrollments.student_id = auth.uid()
              )
              and (
                sp.section_id is null
                or c.section_id is null
                or sp.section_id = c.section_id
              )
          )
          or (
            class_enrollments.student_profile_id is null
            and class_enrollments.student_id = auth.uid()
          )
        )
    )
  );

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
  v_student_profile_id uuid;
  v_student_section_id uuid;
  v_profile_count integer;
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

  if not exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid()
      and m.school_id = v_school_id
      and m.role = 'student'
      and m.status = 'active'
  ) then
    raise exception 'active student membership not found';
  end if;

  select count(*) into v_profile_count
  from public.student_profiles sp
  join public.memberships m on m.id = sp.membership_id
  where m.user_id = auth.uid()
    and m.school_id = v_school_id
    and m.role = 'student'
    and m.status = 'active';
  if v_profile_count <> 1 then
    raise exception 'student profile not found or ambiguous';
  end if;

  select sp.id, sp.section_id
  into v_student_profile_id, v_student_section_id
  from public.student_profiles sp
  join public.memberships m on m.id = sp.membership_id
  where m.user_id = auth.uid()
    and m.school_id = v_school_id
    and m.role = 'student'
    and m.status = 'active';

  if v_class_section_id is not null
     and v_student_section_id is not null
     and v_class_section_id <> v_student_section_id then
    raise exception 'class is not available for this section';
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

revoke all on function public.can_view_student_profile(uuid) from public, anon;
revoke all on function public.can_manage_academic_student(uuid) from public, anon;
revoke all on function public.can_manage_grade_item(uuid) from public, anon;
revoke all on function public.can_manage_student_grade(uuid, uuid) from public, anon;
grant execute on function public.can_view_student_profile(uuid) to authenticated;
grant execute on function public.can_manage_academic_student(uuid) to authenticated;
grant execute on function public.can_manage_grade_item(uuid) to authenticated;
grant execute on function public.can_manage_student_grade(uuid, uuid) to authenticated;
revoke all on function public.enroll_student_by_code(text) from public, anon;
grant execute on function public.enroll_student_by_code(text) to authenticated;
