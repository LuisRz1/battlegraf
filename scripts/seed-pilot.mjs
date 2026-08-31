import { createClient } from "@supabase/supabase-js";
import postgres from "postgres";

const required = [
  "SUPABASE_URL",
  "SUPABASE_SECRET_KEY",
  "POSTGRES_URL_NON_POOLING",
  "PILOT_PASSWORD",
];
for (const name of required) {
  if (!process.env[name]) throw new Error(`Falta ${name}.`);
}
if (process.env.CONFIRM_CREATE_PILOT !== "YES") {
  throw new Error(
    "Use CONFIRM_CREATE_PILOT=YES para crear o actualizar el piloto.",
  );
}

const schoolCode = "BG-PILOT2";
const accounts = [
  {
    role: "director",
    email: "piloto.director@battlegraf.app",
    name: "Diana Directora",
  },
  { role: "tutor", email: "piloto.tutor@battlegraf.app", name: "Tomás Tutor" },
  {
    role: "teacher",
    email: "piloto.docente@battlegraf.app",
    name: "Patricia Profesora",
  },
  {
    role: "student",
    email: "piloto.alumno@battlegraf.app",
    name: "Alonso Alumno",
  },
];

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SECRET_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

const existingUsers = [];
for (let page = 1; ; page += 1) {
  const { data, error } = await supabase.auth.admin.listUsers({
    page,
    perPage: 1000,
  });
  if (error) throw error;
  existingUsers.push(...data.users);
  if (data.users.length < 1000) break;
}

for (const account of accounts) {
  let user = existingUsers.find(
    (candidate) =>
      candidate.email?.toLowerCase() === account.email.toLowerCase(),
  );
  if (!user) {
    const { data, error } = await supabase.auth.admin.createUser({
      email: account.email,
      password: process.env.PILOT_PASSWORD,
      email_confirm: true,
      user_metadata: { full_name: account.name, pilot: true },
    });
    if (error) throw error;
    user = data.user;
  } else {
    const { data, error } = await supabase.auth.admin.updateUserById(user.id, {
      password: process.env.PILOT_PASSWORD,
      email_confirm: true,
      user_metadata: {
        ...user.user_metadata,
        full_name: account.name,
        pilot: true,
      },
    });
    if (error) throw error;
    user = data.user;
  }
  account.id = user.id;
}

const sql = postgres(process.env.POSTGRES_URL_NON_POOLING, {
  max: 1,
  ssl: "require",
  connect_timeout: 20,
});

try {
  await sql.begin(async (tx) => {
    for (const account of accounts) {
      await tx`
        insert into public.profiles (id, email, full_name)
        values (${account.id}, ${account.email}, ${account.name})
        on conflict (id) do update set
          email = excluded.email,
          full_name = excluded.full_name,
          updated_at = now()
      `;
    }

    const director = accounts.find((account) => account.role === "director");
    const [school] = await tx`
      insert into public.schools
        (name, code, region, city, onboarding_complete, created_by)
      values
        ('BattleGraph Piloto Sprint 2', ${schoolCode}, 'Lima', 'Lima', true, ${director.id})
      on conflict (code) do update set
        name = excluded.name,
        region = excluded.region,
        city = excluded.city,
        onboarding_complete = true,
        updated_at = now()
      returning id
    `;

    const membershipIds = {};
    for (const account of accounts) {
      const [membership] = await tx`
        insert into public.memberships (school_id, user_id, role, status)
        values (${school.id}, ${account.id}, ${account.role}, 'active')
        on conflict (school_id, user_id) do update set
          role = excluded.role,
          status = 'active'
        returning id
      `;
      membershipIds[account.role] = membership.id;
    }

    await tx`
      insert into public.subscriptions
        (school_id, plan_slug, status, student_limit, ai_credits_monthly,
         trial_plan_slug, trial_started_at, trial_ends_at)
      values (${school.id}, 'explorador', 'trialing', 30, 0, 'red', now(), now() + interval '30 days')
      on conflict (school_id) do update set
        status = 'trialing',
        trial_plan_slug = 'red',
        trial_started_at = now(),
        trial_ends_at = now() + interval '30 days'
    `;
    await tx`select public.seed_school_defaults(${school.id})`;
    await tx`select public.seed_command_center(${school.id})`;

    const sections = await tx`
      select id, grade, section_label, display_name, created_at
      from public.sections
      where school_id = ${school.id}
      order by created_at, id
    `;
    const section = sections.find(
      (row) => row.grade === "5" && row.section_label === "A",
    );
    const secondSection = sections.find(
      (row) => row.grade === "6" && row.section_label === "A",
    );
    if (!section || !secondSection) {
      throw new Error("No se encontraron las secciones piloto 5A y 6A.");
    }
    for (const duplicate of sections.filter(
      (row) =>
        row.id !== section.id &&
        row.grade === section.grade &&
        row.section_label === section.section_label,
    )) {
      await tx`update public.student_profiles set section_id = ${section.id} where section_id = ${duplicate.id}`;
      await tx`update public.assignments set section_id = ${section.id} where section_id = ${duplicate.id}`;
      await tx`update public.classes set section_id = ${section.id} where section_id = ${duplicate.id}`;
      await tx`update public.attendance_records set section_id = ${section.id} where section_id = ${duplicate.id}`;
      await tx`update public.grade_items set section_id = ${section.id} where section_id = ${duplicate.id}`;
      await tx`delete from public.sections where id = ${duplicate.id}`;
    }
    await tx`
      update public.student_profiles
      set section_id = case
        when full_name in ('Ana Torres', 'Diego Ramos', 'Lucia Vargas', 'Marco Salas')
          then ${section.id}
        when full_name in ('Camila Rios', 'Jose Medina', 'Valeria Cruz', 'Bruno Leon')
          then ${secondSection.id}
        else section_id
      end
      where school_id = ${school.id} and is_demo = true
    `;

    for (const account of accounts.filter((item) => item.role !== "student")) {
      await tx`
        insert into public.staff_profiles
          (school_id, membership_id, full_name, email, role, scope_label, status, is_demo)
        select ${school.id}, ${membershipIds[account.role]}, ${account.name},
          ${account.email}, ${account.role},
          ${account.role === "tutor" ? "5. Primaria A" : account.role === "teacher" ? "Matematica" : "Dirección"},
          'active', false
        where not exists (
          select 1 from public.staff_profiles
          where school_id = ${school.id} and email = ${account.email}
        )
      `;
      await tx`
        update public.staff_profiles set
          membership_id = ${membershipIds[account.role]},
          full_name = ${account.name}, role = ${account.role}, status = 'active'
        where school_id = ${school.id} and email = ${account.email}
      `;
    }

    const student = accounts.find((account) => account.role === "student");
    await tx`
      insert into public.student_profiles
        (school_id, membership_id, full_name, email, section_id, status, is_demo)
      select ${school.id}, ${membershipIds.student}, ${student.name}, ${student.email},
        ${section.id}, 'active', false
      where not exists (
        select 1 from public.student_profiles
        where school_id = ${school.id} and email = ${student.email}
      )
    `;
    await tx`
      update public.student_profiles set
        membership_id = ${membershipIds.student}, full_name = ${student.name},
        section_id = ${section.id}, status = 'active'
      where school_id = ${school.id} and email = ${student.email}
    `;

    const [tutor] = await tx`
      select id from public.staff_profiles
      where school_id = ${school.id} and email = 'piloto.tutor@battlegraf.app'
      limit 1
    `;
    const [teacher] = await tx`
      select id from public.staff_profiles
      where school_id = ${school.id} and email = 'piloto.docente@battlegraf.app'
      limit 1
    `;
    await tx`
      update public.sections set tutor_staff_id = ${tutor.id}, tutor_name = 'Tomás Tutor'
      where id = ${section.id}
    `;
    await tx`
      insert into public.subject_teachers (school_id, subject_id, staff_id)
      select ${school.id}, id, ${teacher.id}
      from public.subjects where school_id = ${school.id}
      on conflict (subject_id, staff_id) do nothing
    `;

    const [subject] = await tx`
      select id, name from public.subjects
      where school_id = ${school.id} and slug = 'matematica'
      limit 1
    `;
    const [year] = await tx`
      select id from public.academic_years
      where school_id = ${school.id} and is_active = true
      order by created_at desc limit 1
    `;
    const [classroom] = await tx`
      insert into public.classes
        (id, school_id, name, subject, code, is_active, academic_year_id,
         section_id, subject_id, teacher_membership_id, created_at, updated_at)
      values
        (gen_random_uuid(), ${school.id}, 'Matemática - Piloto', ${subject.name},
         'PIL5AMAT', true, ${year.id}, ${section.id}, ${subject.id},
         ${membershipIds.teacher}, now(), now())
      on conflict (code) do update set
        is_active = true,
        academic_year_id = excluded.academic_year_id,
        section_id = excluded.section_id,
        subject_id = excluded.subject_id,
        teacher_membership_id = excluded.teacher_membership_id,
        updated_at = now()
      returning id
    `;
    const [studentProfile] = await tx`
      select id from public.student_profiles
      where school_id = ${school.id} and email = ${student.email}
      limit 1
    `;
    await tx`
      insert into public.class_enrollments
        (id, class_id, student_id, student_profile_id, academic_year_id,
         status, is_active, enrolled_at, created_at, updated_at)
      select gen_random_uuid(), ${classroom.id}, null, ${studentProfile.id},
        ${year.id}, 'active', true, now(), now(), now()
      where not exists (
        select 1 from public.class_enrollments
        where class_id = ${classroom.id}
          and (
            student_profile_id = ${studentProfile.id}
            or student_id = ${student.id}
          )
      )
    `;

    await tx`select set_config('request.jwt.claim.sub', ${director.id}, true)`;
    await tx`select public.seed_academic_pilot(${school.id})`;
  });

  console.log(
    JSON.stringify(
      {
        school: "BattleGraph Piloto Sprint 2",
        schoolCode,
        accounts: accounts.map(({ role, email }) => ({ role, email })),
      },
      null,
      2,
    ),
  );
} finally {
  await sql.end({ timeout: 5 });
}
