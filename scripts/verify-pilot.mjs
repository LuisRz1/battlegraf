import { createClient } from "@supabase/supabase-js";

const apiBase = process.env.PANEL_API_URL ?? "http://127.0.0.1:8000";
const supabaseUrl = process.env.SUPABASE_URL;
const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY;
const password = process.env.PILOT_PASSWORD;
if (!supabaseUrl || !publishableKey || !password) {
  throw new Error(
    "Faltan SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY o PILOT_PASSWORD.",
  );
}

const accounts = [
  ["director", "piloto.director@battlegraf.app"],
  ["tutor", "piloto.tutor@battlegraf.app"],
  ["teacher", "piloto.docente@battlegraf.app"],
  ["student", "piloto.alumno@battlegraf.app"],
];
const results = {};

for (const [expectedRole, email] of accounts) {
  const client = createClient(supabaseUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await client.auth.signInWithPassword({
    email,
    password,
  });
  if (error || !data.session)
    throw error ?? new Error(`Sin sesión para ${email}`);
  const { data: memberships, error: membershipError } = await client
    .from("memberships")
    .select("school_id, role")
    .eq("user_id", data.user.id)
    .eq("status", "active")
    .limit(1);
  if (membershipError || !memberships?.length) {
    throw membershipError ?? new Error(`Sin institución para ${email}`);
  }
  const membership = memberships[0];
  if (membership.role !== expectedRole) {
    throw new Error(`Rol inesperado para ${email}: ${membership.role}`);
  }
  const headers = { Authorization: `Bearer ${data.session.access_token}` };
  const [overviewResponse, dashboardResponse] = await Promise.all([
    fetch(
      `${apiBase}/api/v1/panel/${membership.school_id}/academics/overview`,
      {
        headers,
      },
    ),
    fetch(`${apiBase}/api/v1/panel/${membership.school_id}/dashboard`, {
      headers,
    }),
  ]);
  if (!overviewResponse.ok || !dashboardResponse.ok) {
    throw new Error(
      `${expectedRole}: overview ${overviewResponse.status}, dashboard ${dashboardResponse.status}`,
    );
  }
  const overview = await overviewResponse.json();
  const dashboard = await dashboardResponse.json();
  if (
    overview.role !== expectedRole ||
    dashboard.viewer_role !== expectedRole
  ) {
    throw new Error(`${expectedRole}: el backend no conservó el rol.`);
  }
  if (expectedRole === "student") {
    if (overview.students.length !== 1 || dashboard.students.length !== 1) {
      throw new Error("El alumno puede ver perfiles que no le pertenecen.");
    }
    if (
      dashboard.questions.length ||
      dashboard.audits.length ||
      dashboard.staff.length
    ) {
      throw new Error("El alumno recibió módulos administrativos.");
    }
  }
  const firstStudent = overview.students[0];
  if (firstStudent) {
    const tracking = await fetch(
      `${apiBase}/api/v1/panel/${membership.school_id}/students/${firstStudent.id}/tracking`,
      { headers },
    );
    if (!tracking.ok)
      throw new Error(`${expectedRole}: ficha ${tracking.status}`);
    const detail = await tracking.json();
    if (!detail.academic_ready)
      throw new Error(`${expectedRole}: módulo académico no listo`);
  }
  results[expectedRole] = {
    students: overview.students.length,
    attendanceRate: overview.metrics.attendance_rate,
    gradeAverage: overview.metrics.grade_average,
    critical: overview.metrics.critical,
  };
  await client.auth.signOut();
}

console.log(JSON.stringify({ ok: true, apiBase, roles: results }, null, 2));
