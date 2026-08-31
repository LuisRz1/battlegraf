-- Políticas RLS para auto-registro de profesor y alumno (join por código de colegio)
-- Trazabilidad: la membership vincula user_id -> school_id de forma estable a lo largo de los años.

-- 1) Insertar la propia membership (solo rol teacher/student, nunca director/owner)
create policy "user insert own membership join"
  on public.memberships
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and role in ('teacher', 'student')
    and status = 'active'
  );

-- 2) Alumno: insertar su propio perfil (debe tener una membership propia del mismo colegio)
create policy "member insert own student profile"
  on public.student_profiles
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid()
        and m.role = 'student'
        and m.school_id = student_profiles.school_id
        and m.status = 'active'
    )
  );

-- 3) Profesor: insertar su propio perfil (debe tener membership propia del mismo colegio)
create policy "member insert own staff profile"
  on public.staff_profiles
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid()
        and m.role = 'teacher'
        and m.school_id = staff_profiles.school_id
        and m.status = 'active'
    )
  );

-- 4) El usuario autenticado puede ver SU staff/student profile (además de lo que ve el admin)
create policy "member read own staff profile"
  on public.staff_profiles
  for select
  to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid()
        and m.school_id = staff_profiles.school_id
    )
  );

create policy "member read own student profile"
  on public.student_profiles
  for select
  to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where m.user_id = auth.uid()
        and m.school_id = student_profiles.school_id
    )
  );