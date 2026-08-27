import type { APIRoute } from "astro";
import { createSupabaseServerClient, hasSupabaseConfig } from "../../lib/supabase";

const clean = (value: FormDataEntryValue | null, max: number) =>
	String(value ?? "").trim().slice(0, max);

const slugify = (value: string) =>
	value
		.normalize("NFD")
		.replace(/[\u0300-\u036f]/g, "")
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-|-$/g, "")
		.slice(0, 60);

const go = (redirect: (path: string, status?: 301 | 302 | 303 | 307 | 308) => Response, value: string, anchor: string) =>
	redirect(`/panel?${value}&view=${anchor}`, 303);

const API_BASE = process.env.PANEL_API_URL ?? "https://battlegraf-production.up.railway.app";

export const POST: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) return new Response("Servicio no configurado", { status: 503 });

	const supabase = createSupabaseServerClient({ request, cookies });
	const { data: userData } = await supabase.auth.getUser();
	if (!userData.user) return redirect("/iniciar-sesion", 303);

	const { data: sessionData } = await supabase.auth.getSession();
	const apiToken = sessionData?.session?.access_token ?? "";
	if (!apiToken) return new Response("Sin sesión", { status: 401 });

	const form = await request.formData();
	const action = clean(form.get("action"), 30);

	// Llamada al backend FastAPI
	const api = async (method: string, path: string, body?: Record<string, unknown>): Promise<{ ok: boolean; detail?: string }> => {
		try {
			const res = await fetch(`${API_BASE}/api/v1/panel${path}`, {
				method,
				headers: { Authorization: `Bearer ${apiToken}`, "Content-Type": "application/json" },
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
		});
		return go(redirect, r.ok ? "created=section" : "error=save", "estructura");
	}
	if (action === "update_section") {
		const id = clean(form.get("id"), 40);
		const r = await api("PATCH", `/sections/${id}`, {
			level: clean(form.get("level"), 30) || "Primaria",
			grade: clean(form.get("grade"), 12),
			section_label: clean(form.get("section_label"), 8),
			tutor_name: clean(form.get("tutor_name"), 100) || null,
		});
		return go(redirect, r.ok ? "saved=change" : "error=save", "estructura");
	}
	if (action === "delete_section") {
		const id = clean(form.get("id"), 40);
		const r = await api("DELETE", `/sections/${id}`);
		return go(redirect, r.ok ? "saved=deleted" : "error=save", "estructura");
	}
	if (action === "subject") {
		const schoolId = await parseMember();
		if (!schoolId) return new Response("Sin permisos", { status: 403 });
		const r = await api("POST", `/${schoolId}/subjects`, {
			name: clean(form.get("name"), 80),
			icon_code: clean(form.get("icon_code"), 3),
			color: clean(form.get("color"), 12) || "#e6b84d",
		});
		return go(redirect, r.ok ? "created=subject" : "error=save", "materias");
	}
	if (action === "update_subject") {
		const id = clean(form.get("id"), 40);
		const r = await api("PATCH", `/subjects/${id}`, {
			name: clean(form.get("name"), 80),
			icon_code: clean(form.get("icon_code"), 3),
			color: clean(form.get("color"), 12) || "#e6b84d",
		});
		return go(redirect, r.ok ? "saved=change" : "error=save", "materias");
	}
	if (action === "delete_subject") {
		const id = clean(form.get("id"), 40);
		const r = await api("DELETE", `/subjects/${id}`);
		return go(redirect, r.ok ? "saved=deleted" : "error=save", "materias");
	}
	if (action === "student") {
		const schoolId = await parseMember();
		if (!schoolId) return new Response("Sin permisos", { status: 403 });
		const fullName = clean(form.get("full_name"), 120);
		const sectionId = clean(form.get("section_id"), 40);
		if (fullName.length < 3 || !sectionId) return go(redirect, "error=validation", "personas");
		const r = await api("POST", `/${schoolId}/students`, {
			full_name: fullName,
			email: clean(form.get("email"), 160) || null,
			section_id: sectionId,
		});
		return go(redirect, r.ok ? "created=student" : "error=save", "personas");
	}
	if (action === "update_student") {
		const id = clean(form.get("id"), 40);
		const r = await api("PATCH", `/students/${id}`, {
			full_name: clean(form.get("full_name"), 120),
			email: clean(form.get("email"), 160) || null,
			section_id: clean(form.get("section_id"), 40) || null,
		});
		return go(redirect, r.ok ? "saved=change" : "error=save", "personas");
	}
	if (action === "delete_student") {
		const id = clean(form.get("id"), 40);
		const r = await api("DELETE", `/students/${id}`);
		return go(redirect, r.ok ? "saved=deleted" : "error=save", "personas");
	}
	if (action === "staff") {
		const schoolId = await parseMember();
		if (!schoolId) return new Response("Sin permisos", { status: 403 });
		const role = clean(form.get("role"), 24);
		const allowed = ["director", "subdirector", "coordinator", "tutor", "teacher"];
		if (!allowed.includes(role)) return go(redirect, "error=validation", "personas");
		const r = await api("POST", `/${schoolId}/staff`, {
			full_name: clean(form.get("full_name"), 120),
			email: clean(form.get("email"), 160) || null,
			role,
			scope_label: clean(form.get("scope_label"), 120) || null,
			status: !!form.get("send_invite") ? "invited" : "active",
		});
		return go(redirect, r.ok ? "created=staff" : "error=save", "personas");
	}
	if (action === "update_staff") {
		const id = clean(form.get("id"), 40);
		const role = clean(form.get("role"), 24);
		const allowed = ["director", "subdirector", "coordinator", "tutor", "teacher"];
		if (!allowed.includes(role)) return go(redirect, "error=validation", "personas");
		const r = await api("PATCH", `/staff/${id}`, {
			full_name: clean(form.get("full_name"), 120),
			email: clean(form.get("email"), 160) || null,
			role,
			scope_label: clean(form.get("scope_label"), 120) || null,
			status: clean(form.get("status"), 20) || "active",
		});
		return go(redirect, r.ok ? "saved=change" : "error=save", "personas");
	}
	if (action === "delete_staff") {
		const id = clean(form.get("id"), 40);
		const r = await api("DELETE", `/staff/${id}`);
		return go(redirect, r.ok ? "saved=deleted" : "error=save", "personas");
	}
	if (action === "material") {
		const schoolId = await parseMember();
		if (!schoolId) return new Response("Sin permisos", { status: 403 });
		const title = clean(form.get("title"), 120);
		const subjectId = clean(form.get("subject_id"), 40);
		const uploaded = form.get("file");
		const fileName = uploaded instanceof File && uploaded.size > 0 ? uploaded.name.slice(0, 180) : null;
		if (title.length < 3 || !subjectId) return go(redirect, "error=validation", "materiales");
		const r = await api("POST", `/${schoolId}/materials`, {
			title,
			subject_id: subjectId,
			file_name: fileName,
		});
		return go(redirect, r.ok ? "created=material" : "error=save", "materiales");
	}
	if (action === "delete_material") {
		const id = clean(form.get("id"), 40);
		const r = await api("DELETE", `/materials/${id}`);
		return go(redirect, r.ok ? "saved=deleted" : "error=save", "materiales");
	}
	if (action === "question") {
		const schoolId = await parseMember();
		if (!schoolId) return new Response("Sin permisos", { status: 403 });
		const question = clean(form.get("question"), 300);
		const options = [0, 1, 2, 3].map((index) => clean(form.get(`option_${index}`), 160));
		const correctIndex = Number(clean(form.get("correct_index"), 1));
		if (question.length < 8 || options.some((option) => option.length < 1) || !Number.isInteger(correctIndex) || correctIndex < 0 || correctIndex > 3) {
			return go(redirect, "error=validation", "preguntas");
		}
		const r = await api("POST", `/${schoolId}/questions`, {
			subject_id: clean(form.get("subject_id"), 40) || null,
			question,
			options,
			correct_index: correctIndex,
			status: "approved",
		});
		return go(redirect, r.ok ? "created=question" : "error=save", "preguntas");
	}
	if (action === "update_question") {
		const id = clean(form.get("id"), 40);
		const question = clean(form.get("question"), 300);
		const options = [0, 1, 2, 3].map((index) => clean(form.get(`option_${index}`), 160));
		const correctIndex = Number(clean(form.get("correct_index"), 1));
		if (question.length < 8 || options.some((option) => option.length < 1) || !Number.isInteger(correctIndex) || correctIndex < 0 || correctIndex > 3) {
			return go(redirect, "error=validation", "preguntas");
		}
		const r = await api("PATCH", `/questions/${id}`, {
			subject_id: clean(form.get("subject_id"), 40) || null,
			question,
			options,
			correct_index: correctIndex,
			status: clean(form.get("status"), 20) || "review",
		});
		return go(redirect, r.ok ? "saved=change" : "error=save", "preguntas");
	}
	if (action === "delete_question") {
		const id = clean(form.get("id"), 40);
		const r = await api("DELETE", `/questions/${id}`);
		return go(redirect, r.ok ? "saved=deleted" : "error=save", "preguntas");
	}
	if (action === "approve_question") {
		const id = clean(form.get("question_id"), 40);
		const r = await api("POST", `/questions/${id}/approve`);
		return go(redirect, r.ok ? "created=approval" : "error=save", "preguntas");
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
			status: clean(form.get("status"), 20) || "scheduled",
		});
		return go(redirect, r.ok ? "created=assignment" : "error=save", "tareas");
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
			status: clean(form.get("status"), 20) || "scheduled",
		});
		return go(redirect, r.ok ? "saved=change" : "error=save", "tareas");
	}
	if (action === "delete_assignment") {
		const id = clean(form.get("id"), 40);
		const r = await api("DELETE", `/assignments/${id}`);
		return go(redirect, r.ok ? "saved=deleted" : "error=save", "tareas");
	}
	if (action === "battle") {
		const schoolId = await parseMember();
		if (!schoolId) return new Response("Sin permisos", { status: 403 });
		const r = await api("POST", `/${schoolId}/battles`, {
			title: clean(form.get("title"), 140),
			battle_type: clean(form.get("battle_type"), 30) || "student_vs_bot",
			opponent_a: clean(form.get("opponent_a"), 80) || "Equipo Rojo",
			opponent_b: clean(form.get("opponent_b"), 80) || "Equipo Morado",
			scheduled_at: clean(form.get("scheduled_at"), 40) || null,
			status: clean(form.get("status"), 20) || "scheduled",
		});
		return go(redirect, r.ok ? "created=battle" : "error=save", "batallas");
	}
	if (action === "update_battle") {
		const id = clean(form.get("id"), 40);
		const r = await api("PATCH", `/battles/${id}`, {
			title: clean(form.get("title"), 140),
			battle_type: clean(form.get("battle_type"), 30) || "student_vs_bot",
			opponent_a: clean(form.get("opponent_a"), 80) || "Equipo Rojo",
			opponent_b: clean(form.get("opponent_b"), 80) || "Equipo Morado",
			scheduled_at: clean(form.get("scheduled_at"), 40) || null,
			status: clean(form.get("status"), 20) || "scheduled",
		});
		return go(redirect, r.ok ? "saved=change" : "error=save", "batallas");
	}
	if (action === "delete_battle") {
		const id = clean(form.get("id"), 40);
		const r = await api("DELETE", `/battles/${id}`);
		return go(redirect, r.ok ? "saved=deleted" : "error=save", "batallas");
	}
	if (action === "rank") {
		const schoolId = await parseMember();
		if (!schoolId) return new Response("Sin permisos", { status: 403 });
		const r = await api("POST", `/${schoolId}/ranks`, {
			name: clean(form.get("name"), 80),
			min_xp: Number(clean(form.get("min_xp"), 6)) || 0,
			position: Number(clean(form.get("position"), 3)) || 0,
		});
		return go(redirect, r.ok ? "created=rank" : "error=save", "progreso");
	}
	if (action === "delete_rank") {
		const id = clean(form.get("id"), 40);
		const r = await api("DELETE", `/ranks/${id}`);
		return go(redirect, r.ok ? "saved=deleted" : "error=save", "progreso");
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
		return go(redirect, r.ok ? "created=class" : "error=save", "clases");
	}

	return go(redirect, "error=unknown_action", "configuracion");
};