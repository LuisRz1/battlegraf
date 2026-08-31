import type { APIRoute } from "astro";

import {
  createSupabaseServerClient,
  hasSupabaseConfig,
} from "../../lib/supabase";

export const prerender = false;

const API_BASE =
  process.env.PANEL_API_URL ?? "https://battlegraf-production.up.railway.app";

const clean = (value: FormDataEntryValue | null, max = 2000) =>
  String(value ?? "")
    .trim()
    .slice(0, max);

const numberOrNull = (value: FormDataEntryValue | null) => {
  const parsed = Number(clean(value, 20));
  return Number.isFinite(parsed) ? parsed : null;
};

const resultRedirect = (
  redirect: (path: string, status?: 301 | 302 | 303 | 307 | 308) => Response,
  ok: boolean,
) =>
  redirect(
    `/panel?view=academico&${ok ? "saved=academic" : "error=academic"}`,
    303,
  );

export const POST: APIRoute = async ({ request, cookies, redirect }) => {
  if (!hasSupabaseConfig())
    return new Response("Servicio no configurado", { status: 503 });

  const supabase = createSupabaseServerClient({ request, cookies });
  const [{ data: userData }, { data: sessionData }] = await Promise.all([
    supabase.auth.getUser(),
    supabase.auth.getSession(),
  ]);
  if (!userData.user) return redirect("/iniciar-sesion", 303);
  const apiToken = sessionData?.session?.access_token ?? "";
  if (!apiToken) return new Response("Sin sesión", { status: 401 });

  const form = await request.formData();
  const action = clean(form.get("action"), 40);
  const schoolId = clean(form.get("school_id"), 64);
  if (!schoolId) return resultRedirect(redirect, false);

  const { data: membership } = await supabase
    .from("memberships")
    .select("id, role")
    .eq("user_id", userData.user.id)
    .eq("school_id", schoolId)
    .eq("status", "active")
    .maybeSingle();
  if (!membership) return new Response("Sin permisos", { status: 403 });

  const api = async (method: string, path: string, body?: unknown) => {
    try {
      const response = await fetch(`${API_BASE}/api/v1/panel${path}`, {
        method,
        headers: {
          Authorization: `Bearer ${apiToken}`,
          "Content-Type": "application/json",
        },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      return response.ok;
    } catch (error) {
      console.error("academic api error", action, error);
      return false;
    }
  };

  if (action === "seed_demo") {
    return resultRedirect(
      redirect,
      await api("POST", `/${schoolId}/academics/seed-demo`),
    );
  }

  if (action === "attendance") {
    const attendanceDate = clean(form.get("attendance_date"), 10);
    const records = [...form.entries()]
      .filter(([key]) => key.startsWith("attendance:"))
      .map(([key, value]) => ({
        student_profile_id: key.slice("attendance:".length),
        attendance_date: attendanceDate,
        status: clean(value, 12),
        minutes_late: clean(value, 12) === "late" ? 5 : 0,
      }));
    if (!attendanceDate || records.length === 0)
      return resultRedirect(redirect, false);
    return resultRedirect(
      redirect,
      await api("POST", `/${schoolId}/attendance/batch`, { records }),
    );
  }

  if (action === "grade_item") {
    return resultRedirect(
      redirect,
      await api("POST", `/${schoolId}/grade-items`, {
        title: clean(form.get("title"), 160),
        subject_id: clean(form.get("subject_id"), 64),
        section_id: clean(form.get("section_id"), 64) || null,
        academic_period_id: clean(form.get("academic_period_id"), 64) || null,
        category: clean(form.get("category"), 24) || "assessment",
        max_score: numberOrNull(form.get("max_score")) ?? 20,
        weight: numberOrNull(form.get("weight")) ?? 1,
        due_on: clean(form.get("due_on"), 10) || null,
        status: "published",
      }),
    );
  }

  if (action === "grade") {
    const itemId = clean(form.get("grade_item_id"), 64);
    const studentId = clean(form.get("student_id"), 64);
    if (!itemId || !studentId) return resultRedirect(redirect, false);
    return resultRedirect(
      redirect,
      await api("PUT", `/grade-items/${itemId}/students/${studentId}`, {
        score: numberOrNull(form.get("score")),
        status: clean(form.get("status"), 20) || "graded",
        feedback: clean(form.get("feedback"), 1200) || null,
      }),
    );
  }

  if (action === "observation") {
    const studentId = clean(form.get("student_id"), 64);
    if (!studentId) return resultRedirect(redirect, false);
    return resultRedirect(
      redirect,
      await api("POST", `/${schoolId}/students/${studentId}/observations`, {
        category: clean(form.get("category"), 24) || "academic",
        note: clean(form.get("note"), 2000),
        visibility: clean(form.get("visibility"), 24) || "academic_team",
        follow_up_on: clean(form.get("follow_up_on"), 10) || null,
        status: "open",
      }),
    );
  }

  return resultRedirect(redirect, false);
};
