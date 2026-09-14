import type { APIRoute } from "astro";
import {
  createSupabaseServerClient,
  hasSupabaseConfig,
} from "../../lib/supabase";

const clean = (value: FormDataEntryValue | null, max: number) =>
  String(value ?? "")
    .trim()
    .slice(0, max);

const slugify = (value: string) =>
  value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60);

const go = (
  redirect: (path: string, status?: 301 | 302 | 303 | 307 | 308) => Response,
  value: string,
  anchor: string,
) => redirect(`/panel?${value}&view=${anchor}`, 303);

/** Redirige con el motivo real del backend (reglas de integridad, etc.). */
const fail = (detail?: string) =>
  `error=guard&reason=${encodeURIComponent(
    (!detail || detail === "ok"
      ? "No se pudo completar la operacion."
      : detail
    ).slice(0, 200),
  )}`;

const API_BASE =
  process.env.PANEL_API_URL ?? "https://battlegraf-production.up.railway.app";

export const POST: APIRoute = async ({ request, cookies, redirect }) => {
  if (!hasSupabaseConfig())
    return new Response("Servicio no configurado", { status: 503 });

  const supabase = createSupabaseServerClient({ request, cookies });
  const { data: userData } = await supabase.auth.getUser();
  if (!userData.user) return redirect("/iniciar-sesion", 303);

  const { data: sessionData } = await supabase.auth.getSession();
  const apiToken = sessionData?.session?.access_token ?? "";
  if (!apiToken) return new Response("Sin sesión", { status: 401 });

  const form = await request.formData();
  const action = clean(form.get("action"), 30);

  // Llamada al backend FastAPI
  const api = async (
    method: string,
    path: string,
    body?: Record<string, unknown>,
  ): Promise<{ ok: boolean; detail?: string }> => {
    try {
      const res = await fetch(`${API_BASE}/api/v1/panel${path}`, {
        method,
        headers: {
          Authorization: `Bearer ${apiToken}`,
          "Content-Type": "application/json",
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      const data = await res.json().catch(() => ({}));
      return { ok: res.ok, detail: data?.detail ?? (res.ok ? "ok" : "error") };
    } catch (e) {
      console.error("panel api error", action, e);
      return { ok: false, detail: "api_down" };
    }
  };

  // Parseo común de campos
  const parseMember = async () => {
    const { data: membership } = await supabase
      .from("memberships")
      .select("school_id, role")
      .eq("user_id", userData.user.id)
      .limit(1)
      .maybeSingle();
    return membership?.school_id ?? "";
  };

  if (action === "section") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const r = await api("POST", `/${schoolId}/sections`, {
      level: clean(form.get("level"), 30) || "Primaria",
      grade: clean(form.get("grade"), 12),
      section_label: clean(form.get("section_label"), 8),
      tutor_name: clean(form.get("tutor_name"), 100) || null,
      subject_ids: form
        .getAll("subject_ids")
        .map((value) => String(value).slice(0, 40))
        .filter(Boolean),
    });
    return go(redirect, r.ok ? "created=section" : fail(r.detail), "secciones");
  }
  if (action === "update_section") {
    const id = clean(form.get("id"), 40);
    const r = await api("PATCH", `/sections/${id}`, {
      level: clean(form.get("level"), 30) || "Primaria",
      grade: clean(form.get("grade"), 12),
      section_label: clean(form.get("section_label"), 8),
      tutor_name: clean(form.get("tutor_name"), 100) || null,
      subject_ids: form
        .getAll("subject_ids")
        .map((value) => String(value).slice(0, 40))
        .filter(Boolean),
    });
    return go(redirect, r.ok ? "saved=change" : fail(r.detail), "secciones");
  }
  if (action === "delete_section") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/sections/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "secciones");
  }
  if (action === "subject") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const r = await api("POST", `/${schoolId}/subjects`, {
      name: clean(form.get("name"), 80),
      icon_code: clean(form.get("icon_code"), 3),
      color: clean(form.get("color"), 12) || "#e6b84d",
    });
    return go(redirect, r.ok ? "created=subject"         : fail(r.detail), "materias");
  }
  if (action === "update_subject") {
    const id = clean(form.get("id"), 40);
    const r = await api("PATCH", `/subjects/${id}`, {
      name: clean(form.get("name"), 80),
      icon_code: clean(form.get("icon_code"), 3),
      color: clean(form.get("color"), 12) || "#e6b84d",
    });
    return go(redirect, r.ok ? "saved=change"         : fail(r.detail), "materias");
  }
  if (action === "assign_teacher") {
    const subject_id = clean(form.get("subject_id"), 40);
    const staff_id = clean(form.get("staff_id"), 40);
    const r = await api("POST", `/subjects/${subject_id}/teachers`, {
      staff_id,
    });
    return go(redirect, r.ok ? "saved=assigned" : "error=assign", "materias");
  }
  if (action === "remove_teacher") {
    const subject_id = clean(form.get("subject_id"), 40);
    const staff_id = clean(form.get("staff_id"), 40);
    const r = await api(
      "DELETE",
      `/subjects/${subject_id}/teachers/${staff_id}`,
    );
    return go(redirect, r.ok ? "saved=removed" : "error=assign", "materias");
  }
  if (action === "toggle_subject") {
    const id = clean(form.get("id"), 40);
    const enabled = clean(form.get("is_enabled"), 5) === "true";
    const r = await api("PATCH", `/subjects/${id}`, {
      is_enabled: enabled,
    } as any);
    return go(redirect, r.ok ? "saved=change"         : fail(r.detail), "materias");
  }
  if (action === "delete_subject") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/subjects/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "materias");
  }
  if (action === "student") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const fullName = clean(form.get("full_name"), 120);
    const sectionId = clean(form.get("section_id"), 40);
    if (fullName.length < 3 || !sectionId)
      return go(redirect, "error=validation", "personas");
    const r = await api("POST", `/${schoolId}/students`, {
      full_name: fullName,
      email: clean(form.get("email"), 160) || null,
      section_id: sectionId,
    });
    return go(redirect, r.ok ? "created=student"         : fail(r.detail), "personas");
  }
  if (action === "update_student") {
    const id = clean(form.get("id"), 40);
    const r = await api("PATCH", `/students/${id}`, {
      full_name: clean(form.get("full_name"), 120),
      email: clean(form.get("email"), 160) || null,
      section_id: clean(form.get("section_id"), 40) || null,
    });
    return go(redirect, r.ok ? "saved=change"         : fail(r.detail), "personas");
  }
  if (action === "delete_student") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/students/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "personas");
  }
  if (action === "staff") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const role = clean(form.get("role"), 24);
    const allowed = [
      "director",
      "subdirector",
      "coordinator",
      "tutor",
      "teacher",
    ];
    if (!allowed.includes(role))
      return go(redirect, "error=validation", "personas");
    const r = await api("POST", `/${schoolId}/staff`, {
      full_name: clean(form.get("full_name"), 120),
      email: clean(form.get("email"), 160) || null,
      role,
      scope_label: clean(form.get("scope_label"), 120) || null,
      status: !!form.get("send_invite") ? "invited" : "active",
    });
    return go(redirect, r.ok ? "created=staff"         : fail(r.detail), "personas");
  }
  if (action === "update_staff") {
    const id = clean(form.get("id"), 40);
    const role = clean(form.get("role"), 24);
    const allowed = [
      "director",
      "subdirector",
      "coordinator",
      "tutor",
      "teacher",
    ];
    if (!allowed.includes(role))
      return go(redirect, "error=validation", "personas");
    const r = await api("PATCH", `/staff/${id}`, {
      full_name: clean(form.get("full_name"), 120),
      email: clean(form.get("email"), 160) || null,
      role,
      scope_label: clean(form.get("scope_label"), 120) || null,
      status: clean(form.get("status"), 20) || "active",
    });
    return go(redirect, r.ok ? "saved=change"         : fail(r.detail), "personas");
  }
  if (action === "delete_staff") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/staff/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "personas");
  }
  if (action === "material") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const title = clean(form.get("title"), 120);
    const subjectId = clean(form.get("subject_id"), 40);
    const grade = clean(form.get("grade"), 20);
    const uploaded = form.get("file");
    if (title.length < 3 || !subjectId)
      return go(redirect, "error=validation", "materiales");
    // Subida real del archivo: el backend extrae texto y lo persiste.
    if (uploaded instanceof File && uploaded.size > 0) {
      const forward = new FormData();
      forward.set("subject_id", subjectId);
      forward.set("title", title);
      if (grade) forward.set("grade", grade);
      forward.set("file", uploaded, uploaded.name);
      try {
        const res = await fetch(
          `${API_BASE}/api/v1/panel/${schoolId}/materials/upload`,
          {
            method: "POST",
            headers: { Authorization: `Bearer ${apiToken}` },
            body: forward,
          },
        );
        return go(
          redirect,
          res.ok ? "created=material"         : fail(r.detail),
          "materiales",
        );
      } catch (e) {
        console.error("material upload error", e);
        return go(redirect, fail(), "materiales");
      }
    }
    const r = await api("POST", `/${schoolId}/materials`, {
      title,
      subject_id: subjectId,
      file_name: null,
      grade: grade || null,
    });
    return go(redirect, r.ok ? "created=material"         : fail(r.detail), "materiales");
  }
  if (action === "delete_material") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/materials/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "materiales");
  }
  if (action === "generate_material") {
    const id = clean(form.get("id"), 40);
    const r = await api("POST", `/materials/${id}/generate?count=10`, {});
    return go(redirect, r.ok ? "saved=generated"         : fail(r.detail), "materiales");
  }
  if (action === "question") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const question = clean(form.get("question"), 300);
    const options = [0, 1, 2, 3].map((index) =>
      clean(form.get(`option_${index}`), 160),
    );
    const correctIndex = Number(clean(form.get("correct_index"), 1));
    if (
      question.length < 8 ||
      options.some((option) => option.length < 1) ||
      !Number.isInteger(correctIndex) ||
      correctIndex < 0 ||
      correctIndex > 3
    ) {
      return go(redirect, "error=validation", "preguntas");
    }
    const r = await api("POST", `/${schoolId}/questions`, {
      subject_id: clean(form.get("subject_id"), 40) || null,
      question,
      options,
      correct_index: correctIndex,
      status: "approved",
    });
    return go(redirect, r.ok ? "created=question"         : fail(r.detail), "preguntas");
  }
  if (action === "update_question") {
    const id = clean(form.get("id"), 40);
    const question = clean(form.get("question"), 300);
    const options = [0, 1, 2, 3].map((index) =>
      clean(form.get(`option_${index}`), 160),
    );
    const correctIndex = Number(clean(form.get("correct_index"), 1));
    if (
      question.length < 8 ||
      options.some((option) => option.length < 1) ||
      !Number.isInteger(correctIndex) ||
      correctIndex < 0 ||
      correctIndex > 3
    ) {
      return go(redirect, "error=validation", "preguntas");
    }
    const r = await api("PATCH", `/questions/${id}`, {
      subject_id: clean(form.get("subject_id"), 40) || null,
      question,
      options,
      correct_index: correctIndex,
      status: clean(form.get("status"), 20) || "review",
    });
    return go(redirect, r.ok ? "saved=change"         : fail(r.detail), "preguntas");
  }
  if (action === "delete_question") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/questions/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "preguntas");
  }
  if (action === "approve_question") {
    const id = clean(form.get("question_id"), 40);
    const r = await api("POST", `/questions/${id}/approve`);
    return go(redirect, r.ok ? "created=approval"         : fail(r.detail), "preguntas");
  }
  if (action === "assignment") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const r = await api("POST", `/${schoolId}/assignments`, {
      title: clean(form.get("title"), 140),
      section_id: clean(form.get("section_id"), 40) || null,
      subject_id: clean(form.get("subject_id"), 40) || null,
      delivery_type: clean(form.get("delivery_type"), 20) || "quiz",
      due_at: clean(form.get("due_at"), 40) || null,
      xp_reward: Number(clean(form.get("xp_reward"), 6)) || 80,
      instructions: clean(form.get("instructions"), 4000) || null,
      points: Number(clean(form.get("points"), 8)) || 100,
      status: clean(form.get("status"), 20) || "scheduled",
    });
    return go(redirect, r.ok ? "created=assignment"         : fail(r.detail), "tareas");
  }
  if (action === "update_assignment") {
    const id = clean(form.get("id"), 40);
    const r = await api("PATCH", `/assignments/${id}`, {
      title: clean(form.get("title"), 140),
      section_id: clean(form.get("section_id"), 40) || null,
      subject_id: clean(form.get("subject_id"), 40) || null,
      delivery_type: clean(form.get("delivery_type"), 20) || "quiz",
      due_at: clean(form.get("due_at"), 40) || null,
      xp_reward: Number(clean(form.get("xp_reward"), 6)) || 80,
      instructions: clean(form.get("instructions"), 4000) || null,
      points: Number(clean(form.get("points"), 8)) || 100,
      status: clean(form.get("status"), 20) || "scheduled",
    });
    return go(redirect, r.ok ? "saved=change"         : fail(r.detail), "tareas");
  }
  if (action === "delete_assignment") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/assignments/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "tareas");
  }
  if (action === "battle") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const r = await api("POST", `/${schoolId}/battles`, {
      title: clean(form.get("title"), 140),
      battle_type: clean(form.get("battle_type"), 30) || "student_vs_bot",
      subject_id: clean(form.get("subject_id"), 40) || null,
      grade: clean(form.get("grade"), 20) || null,
      opponent_a: clean(form.get("opponent_a"), 80) || "Equipo Rojo",
      opponent_b: clean(form.get("opponent_b"), 80) || "Equipo Morado",
      scheduled_at: clean(form.get("scheduled_at"), 40) || null,
      graph_layers: Number(clean(form.get("graph_layers"), 2)) || 4,
      nodes_per_layer: Number(clean(form.get("nodes_per_layer"), 2)) || 4,
      bot_difficulty: clean(form.get("bot_difficulty"), 20) || "balanced",
      status: clean(form.get("status"), 20) || "scheduled",
    });
    return go(redirect, r.ok ? "created=battle"         : fail(r.detail), "batallas");
  }
  if (action === "update_battle") {
    const id = clean(form.get("id"), 40);
    const r = await api("PATCH", `/battles/${id}`, {
      title: clean(form.get("title"), 140),
      battle_type: clean(form.get("battle_type"), 30) || "student_vs_bot",
      subject_id: clean(form.get("subject_id"), 40) || null,
      grade: clean(form.get("grade"), 20) || null,
      opponent_a: clean(form.get("opponent_a"), 80) || "Equipo Rojo",
      opponent_b: clean(form.get("opponent_b"), 80) || "Equipo Morado",
      scheduled_at: clean(form.get("scheduled_at"), 40) || null,
      graph_layers: Number(clean(form.get("graph_layers"), 2)) || 4,
      nodes_per_layer: Number(clean(form.get("nodes_per_layer"), 2)) || 4,
      bot_difficulty: clean(form.get("bot_difficulty"), 20) || null,
      status: clean(form.get("status"), 20) || "scheduled",
    });
    return go(redirect, r.ok ? "saved=change"         : fail(r.detail), "batallas");
  }
  if (action === "delete_battle") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/battles/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "batallas");
  }
  if (action === "rank") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const r = await api("POST", `/${schoolId}/ranks`, {
      name: clean(form.get("name"), 80),
      min_xp: Number(clean(form.get("min_xp"), 6)) || 0,
      position: Number(clean(form.get("position"), 3)) || 0,
    });
    return go(redirect, r.ok ? "created=rank"         : fail(r.detail), "progreso");
  }
  if (action === "delete_rank") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/ranks/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "progreso");
  }
  if (action === "class") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const name = clean(form.get("name"), 140);
    if (name.length < 3) return go(redirect, "error=validation", "clases");
    const r = await api("POST", `/${schoolId}/classes`, {
      name,
      subject_id: clean(form.get("subject_id"), 40) || null,
      section_id: clean(form.get("section_id"), 40) || null,
    });
    return go(redirect, r.ok ? "created=class"         : fail(r.detail), "clases");
  }

  const list = (value: FormDataEntryValue | null) =>
    clean(value, 800)
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);

  if (action === "badge") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const r = await api("POST", `/${schoolId}/badges`, {
      code: clean(form.get("code"), 60),
      name: clean(form.get("name"), 120),
      description: clean(form.get("description"), 500) || null,
      icon_code: clean(form.get("icon_code"), 3) || "M",
      category: clean(form.get("category"), 40) || "general",
      points: Number(clean(form.get("points"), 5)) || 0,
    });
    return go(redirect, r.ok ? "created=badge"         : fail(r.detail), "recompensas");
  }
  if (action === "powerup") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const r = await api("POST", `/${schoolId}/powerups`, {
      code: clean(form.get("code"), 60),
      name: clean(form.get("name"), 120),
      description: clean(form.get("description"), 500) || null,
      effect: clean(form.get("effect"), 40) || "half",
      rarity: clean(form.get("rarity"), 20) || "tactico",
      cost_points: Number(clean(form.get("cost_points"), 6)) || 0,
      duration_seconds: Number(clean(form.get("duration_seconds"), 5)) || 0,
    });
    return go(redirect, r.ok ? "created=powerup"         : fail(r.detail), "recompensas");
  }
  if (action === "mission") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const r = await api("POST", `/${schoolId}/missions`, {
      title: clean(form.get("title"), 160),
      description: clean(form.get("description"), 800) || null,
      scope: clean(form.get("scope"), 20) || "section",
      section_id: clean(form.get("section_id"), 40) || null,
      subject_id: clean(form.get("subject_id"), 40) || null,
      goal_type: clean(form.get("goal_type"), 30) || "tasks_completed",
      goal_value: Number(clean(form.get("goal_value"), 6)) || 1,
      reward_points: Number(clean(form.get("reward_points"), 6)) || 0,
      reward_powerup_id: clean(form.get("reward_powerup_id"), 40) || null,
      status: "active",
    });
    return go(redirect, r.ok ? "created=mission"         : fail(r.detail), "misiones");
  }
  if (action === "study_goal") {
    const schoolId = await parseMember();
    if (!schoolId) return new Response("Sin permisos", { status: 403 });
    const r = await api("POST", `/${schoolId}/study-goals`, {
      grade: clean(form.get("grade"), 20),
      subject_id: clean(form.get("subject_id"), 40) || null,
      title: clean(form.get("title"), 160),
      topics: list(form.get("topics")),
      objectives: list(form.get("objectives")),
      competences: list(form.get("competences")),
    });
    return go(redirect, r.ok ? "created=goal"         : fail(r.detail), "metas");
  }
  if (action === "delete_badge") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/badges/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "recompensas");
  }
  if (action === "delete_powerup") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/powerups/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "recompensas");
  }
  if (action === "delete_mission") {
    const id = clean(form.get("id"), 40);
    const r = await api("DELETE", `/missions/${id}`);
    return go(redirect, r.ok ? "saved=deleted"         : fail(r.detail), "misiones");
  }

  return go(redirect, "error=unknown_action", "configuracion");
};
