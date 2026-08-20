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

export const POST: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) return new Response("Servicio no configurado", { status: 503 });

	const supabase = createSupabaseServerClient({ request, cookies });
	const { data: userData } = await supabase.auth.getUser();
	if (!userData.user) return redirect("/iniciar-sesion", 303);

	const { data: membership } = await supabase
		.from("memberships")
		.select("school_id, role")
		.eq("user_id", userData.user.id)
		.in("role", ["owner", "director", "subdirector", "coordinator"])
		.limit(1)
		.maybeSingle();

	if (!membership) return new Response("Sin permisos", { status: 403 });

	const form = await request.formData();
	const action = clean(form.get("action"), 30);
	const schoolId = membership.school_id;
	const { data: subscription } = await supabase
		.from("subscriptions")
		.select("plan_slug, status, trial_ends_at")
		.eq("school_id", schoolId)
		.maybeSingle();
	const trialActive = Boolean(
		subscription?.status === "trialing" &&
		subscription.trial_ends_at &&
		new Date(subscription.trial_ends_at).getTime() > Date.now(),
	);
	const hasAdvancedAccess = Boolean(
		subscription && (subscription.plan_slug !== "explorador" || trialActive),
	);

	if (action === "section") {
		const level = clean(form.get("level"), 30) || "Primaria";
		const grade = clean(form.get("grade"), 12);
		const label = clean(form.get("section_label"), 8).toUpperCase();
		if (!grade || !label) return go(redirect, "error=validation", "estructura");

		const code = slugify(`${grade}-${level}-${label}`).toUpperCase();
		const displayName = `${grade}. ${level} ${label}`;
		const { data: year } = await supabase
			.from("academic_years")
			.select("id")
			.eq("school_id", schoolId)
			.eq("is_active", true)
			.limit(1)
			.maybeSingle();
		const { data: section, error } = await supabase
			.from("sections")
			.insert({
				school_id: schoolId,
				academic_year_id: year?.id ?? null,
				level,
				grade,
				section_label: label,
				code,
				display_name: displayName,
				tutor_name: clean(form.get("tutor_name"), 100) || "Tutor por asignar",
				is_demo: false,
			})
			.select("id")
			.single();
		if (error || !section) return go(redirect, "error=save", "estructura");

		const { data: subjects } = await supabase.from("subjects").select("id").eq("school_id", schoolId);
		if (subjects?.length) {
			await supabase.from("section_subjects").insert(
				subjects.map(({ id }) => ({ section_id: section.id, subject_id: id })),
			);
		}
		await supabase.from("clans").insert([
			{ school_id: schoolId, section_id: section.id, name: `${label} Rojos`, color: "#ef3340", is_demo: false },
			{ school_id: schoolId, section_id: section.id, name: `${label} Morados`, color: "#9d55f5", is_demo: false },
		]);
		return go(redirect, "created=section", "estructura");
	}

	if (action === "subject") {
		const name = clean(form.get("name"), 80);
		if (name.length < 3) return go(redirect, "error=validation", "estructura");
		const { data: subject, error } = await supabase
			.from("subjects")
			.insert({
				school_id: schoolId,
				slug: slugify(name),
				name,
				color: clean(form.get("color"), 12) || "#e6b84d",
				icon_code: clean(form.get("icon_code"), 3).toUpperCase() || "LIB",
				is_demo: false,
			})
			.select("id")
			.single();
		if (error || !subject) return go(redirect, "error=save", "estructura");
		const { data: sections } = await supabase.from("sections").select("id").eq("school_id", schoolId).eq("status", "active");
		if (sections?.length) {
			await supabase.from("section_subjects").insert(
				sections.map(({ id }) => ({ section_id: id, subject_id: subject.id })),
			);
		}
		return go(redirect, "created=subject", "estructura");
	}

	if (action === "student") {
		const fullName = clean(form.get("full_name"), 120);
		const sectionId = clean(form.get("section_id"), 40);
		if (fullName.length < 3 || !sectionId) return go(redirect, "error=validation", "personas");
		const { data: section } = await supabase
			.from("sections")
			.select("id")
			.eq("id", sectionId)
			.eq("school_id", schoolId)
			.maybeSingle();
		if (!section) return go(redirect, "error=validation", "personas");
		const { error } = await supabase.from("student_profiles").insert({
			school_id: schoolId,
			full_name: fullName,
			email: clean(form.get("email"), 160) || null,
			section_id: section.id,
			accessibility_preferences: { focus_mode: form.get("focus_mode") === "on" },
			is_demo: false,
		});
		return go(redirect, error ? "error=save" : "created=student", "personas");
	}

	if (action === "material") {
		if (!hasAdvancedAccess) return go(redirect, "error=upgrade", "contenido");
		const title = clean(form.get("title"), 120);
		const subjectId = clean(form.get("subject_id"), 40);
		const uploaded = form.get("file");
		const fileName = uploaded instanceof File && uploaded.size > 0 ? uploaded.name.slice(0, 180) : null;
		const fileType = fileName?.split(".").pop()?.toLowerCase() ?? "manual";
		if (title.length < 3 || !subjectId) return go(redirect, "error=validation", "contenido");
		const { data: subject } = await supabase
			.from("subjects")
			.select("id")
			.eq("id", subjectId)
			.eq("school_id", schoolId)
			.maybeSingle();
		if (!subject) return go(redirect, "error=validation", "contenido");
		const { error } = await supabase.from("learning_materials").insert({
			school_id: schoolId,
			subject_id: subject.id,
			title,
			file_name: fileName,
			file_type: fileType,
			processing_status: "ready",
			created_by: userData.user.id,
			is_demo: false,
		});
		if (error) return go(redirect, "error=save", "contenido");
		await supabase.from("question_bank").insert([
			{ school_id: schoolId, subject_id: subject.id, question: `¿Cuál es la idea principal de «${title}»?`, options: ["El concepto central", "Un detalle secundario", "Un tema distinto", "Ninguna"], correct_index: 0, status: "review", source: "prototype-ai" },
			{ school_id: schoolId, subject_id: subject.id, question: `¿Qué estrategia ayuda a comprender «${title}»?`, options: ["Relacionar sus ideas", "Ignorar ejemplos", "Memorizar sin leer", "Cambiar de tema"], correct_index: 0, status: "review", source: "prototype-ai" },
		]);
		return go(redirect, "created=material", "contenido");
	}

	if (action === "question") {
		const subjectId = clean(form.get("subject_id"), 40);
		const question = clean(form.get("question"), 300);
		const options = [0, 1, 2, 3].map((index) => clean(form.get(`option_${index}`), 160));
		const correctIndex = Number(clean(form.get("correct_index"), 1));
		if (!subjectId || question.length < 8 || options.some((option) => option.length < 1) || !Number.isInteger(correctIndex) || correctIndex < 0 || correctIndex > 3) {
			return go(redirect, "error=validation", "contenido");
		}
		const { data: subject } = await supabase
			.from("subjects")
			.select("id")
			.eq("id", subjectId)
			.eq("school_id", schoolId)
			.maybeSingle();
		if (!subject) return go(redirect, "error=validation", "contenido");
		const { error } = await supabase.from("question_bank").insert({
			school_id: schoolId,
			subject_id: subject.id,
			question,
			options,
			correct_index: correctIndex,
			status: "approved",
			source: "manual",
			is_demo: false,
		});
		return go(redirect, error ? "error=save" : "created=question", "contenido");
	}

	if (action === "staff") {
		const fullName = clean(form.get("full_name"), 120);
		const role = clean(form.get("role"), 24);
		const allowed = ["director", "subdirector", "coordinator", "tutor", "teacher"];
		if (fullName.length < 3 || !allowed.includes(role)) return go(redirect, "error=validation", "personas");
		const { error } = await supabase.from("staff_profiles").insert({ school_id: schoolId, full_name: fullName, email: clean(form.get("email"), 160) || null, role, scope_label: clean(form.get("scope_label"), 160) || "Todo el colegio", status: "invited", is_demo: false });
		if (!error) await supabase.from("audit_logs").insert({ school_id: schoolId, actor_name: "Direccion", action: "Invito a un miembro del equipo", target_label: fullName, category: "users" });
		return go(redirect, error ? "error=save" : "created=staff", "personas");
	}

	if (action === "assignment") {
		const title = clean(form.get("title"), 140);
		const sectionId = clean(form.get("section_id"), 40);
		const subjectId = clean(form.get("subject_id"), 40);
		const deliveryType = clean(form.get("delivery_type"), 20);
		const dueAt = clean(form.get("due_at"), 40);
		const xpReward = Math.min(10000, Math.max(0, Number(clean(form.get("xp_reward"), 6)) || 80));
		if (title.length < 3 || !sectionId || !subjectId || !["quiz", "written", "document"].includes(deliveryType)) return go(redirect, "error=validation", "tareas");
		const { error } = await supabase.from("assignments").insert({ school_id: schoolId, section_id: sectionId, subject_id: subjectId, title, delivery_type: deliveryType, due_at: dueAt || null, xp_reward: xpReward, status: "scheduled", is_demo: false });
		if (!error) await supabase.from("audit_logs").insert({ school_id: schoolId, actor_name: "Direccion", action: "Programo una tarea", target_label: title, category: "learning" });
		return go(redirect, error ? "error=save" : "created=assignment", "tareas");
	}

	if (action === "battle") {
		const title = clean(form.get("title"), 140);
		const battleType = clean(form.get("battle_type"), 30);
		const opponentA = clean(form.get("opponent_a"), 120);
		const opponentB = clean(form.get("opponent_b"), 120);
		const scheduledAt = clean(form.get("scheduled_at"), 40);
		const graphLayers = Math.min(7, Math.max(4, Number(clean(form.get("graph_layers"), 1)) || 4));
		const nodesPerLayer = Math.min(4, Math.max(3, Number(clean(form.get("nodes_per_layer"), 1)) || 4));
		const allowed = ["student_vs_bot", "student_vs_student", "section_vs_section", "tournament"];
		if (title.length < 3 || !opponentA || !opponentB || !allowed.includes(battleType)) return go(redirect, "error=validation", "batallas");
		const { error } = await supabase.from("battle_events").insert({ school_id: schoolId, title, battle_type: battleType, opponent_a: opponentA, opponent_b: opponentB, scheduled_at: scheduledAt || null, status: "scheduled", graph_layers: graphLayers, nodes_per_layer: nodesPerLayer, is_demo: false });
		if (!error) await supabase.from("audit_logs").insert({ school_id: schoolId, actor_name: "Direccion", action: "Programo una batalla", target_label: `${opponentA} vs ${opponentB}`, category: "battle" });
		return go(redirect, error ? "error=save" : "created=battle", "batallas");
	}

	if (action === "rank") {
		const name = clean(form.get("name"), 60);
		const minXp = Math.max(0, Number(clean(form.get("min_xp"), 8)) || 0);
		if (name.length < 3) return go(redirect, "error=validation", "progreso");
		const { count } = await supabase.from("rank_definitions").select("id", { count: "exact", head: true }).eq("school_id", schoolId);
		const { error } = await supabase.from("rank_definitions").insert({ school_id: schoolId, name, min_xp: minXp, position: (count ?? 0) + 1, is_demo: false });
		return go(redirect, error ? "error=save" : "created=rank", "progreso");
	}

	if (action === "approve_question") {
		const questionId = clean(form.get("question_id"), 40);
		const { error } = await supabase.from("question_bank").update({ status: "approved" }).eq("id", questionId).eq("school_id", schoolId);
		if (!error) await supabase.from("audit_logs").insert({ school_id: schoolId, actor_name: "Docente", action: "Aprobo una pregunta", target_label: questionId.slice(0, 8), category: "content" });
		return go(redirect, error ? "error=save" : "created=approval", "preguntas");
	}

	// ── EDITAR (update) ──
	if (action === "update_student") {
		const id = clean(form.get("id"), 40);
		const fullName = clean(form.get("full_name"), 120);
		const sectionId = clean(form.get("section_id"), 40);
		if (!id || fullName.length < 3) return go(redirect, "error=validation", "personas");
		const patch: Record<string, unknown> = { full_name: fullName, email: clean(form.get("email"), 160) || null, section_id: sectionId || null };
		await supabase.from("student_profiles").update(patch).eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=change", "personas");
	}
	if (action === "delete_student") {
		const id = clean(form.get("id"), 40);
		const { error } = await supabase.from("student_profiles").delete().eq("id", id).eq("school_id", schoolId);
		return go(redirect, error ? "error=save" : "saved=deleted", "personas");
	}
	if (action === "update_staff") {
		const id = clean(form.get("id"), 40);
		const fullName = clean(form.get("full_name"), 120);
		const role = clean(form.get("role"), 24);
		const allowed = ["director", "subdirector", "coordinator", "tutor", "teacher"];
		if (!id || fullName.length < 3 || !allowed.includes(role)) return go(redirect, "error=validation", "personas");
		const patch: Record<string, unknown> = { full_name: fullName, email: clean(form.get("email"), 160) || null, role, scope_label: clean(form.get("scope_label"), 160) || "Todo el colegio", status: clean(form.get("status"), 16) || "active" };
		await supabase.from("staff_profiles").update(patch).eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=change", "personas");
	}
	if (action === "delete_staff") {
		const id = clean(form.get("id"), 40);
		await supabase.from("staff_profiles").delete().eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=deleted", "personas");
	}
	if (action === "delete_material") {
		const id = clean(form.get("id"), 40);
		await supabase.from("learning_materials").delete().eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=deleted", "materiales");
	}
	if (action === "update_question") {
		const id = clean(form.get("id"), 40);
		const subjectId = clean(form.get("subject_id"), 40);
		const question = clean(form.get("question"), 300);
		const options = [0, 1, 2, 3].map((index) => clean(form.get(`option_${index}`), 160));
		const correctIndex = Number(clean(form.get("correct_index"), 1));
		const status = clean(form.get("status"), 16) === "approved" ? "approved" : "review";
		if (!id || !subjectId || question.length < 8 || options.some((option) => option.length < 1) || !Number.isInteger(correctIndex) || correctIndex < 0 || correctIndex > 3) {
			return go(redirect, "error=validation", "preguntas");
		}
		await supabase.from("question_bank").update({ subject_id: subjectId, question, options, correct_index: correctIndex, status }).eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=change", "preguntas");
	}
	if (action === "delete_question") {
		const id = clean(form.get("id"), 40);
		await supabase.from("question_bank").delete().eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=deleted", "preguntas");
	}
	if (action === "update_assignment") {
		const id = clean(form.get("id"), 40);
		if (!id) return go(redirect, "error=validation", "tareas");
		const patch: Record<string, unknown> = { title: clean(form.get("title"), 140), section_id: clean(form.get("section_id"), 40), subject_id: clean(form.get("subject_id"), 40), delivery_type: clean(form.get("delivery_type"), 20), due_at: clean(form.get("due_at"), 40) || null, xp_reward: Math.min(10000, Math.max(0, Number(clean(form.get("xp_reward"), 6)) || 80)), status: clean(form.get("status"), 16) || "scheduled" };
		await supabase.from("assignments").update(patch).eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=change", "tareas");
	}
	if (action === "delete_assignment") {
		const id = clean(form.get("id"), 40);
		await supabase.from("assignments").delete().eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=deleted", "tareas");
	}
	if (action === "update_battle") {
		const id = clean(form.get("id"), 40);
		if (!id) return go(redirect, "error=validation", "batallas");
		const patch: Record<string, unknown> = { title: clean(form.get("title"), 140), opponent_a: clean(form.get("opponent_a"), 120), opponent_b: clean(form.get("opponent_b"), 120), scheduled_at: clean(form.get("scheduled_at"), 40) || null, status: clean(form.get("status"), 16) || "scheduled" };
		await supabase.from("battle_events").update(patch).eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=change", "batallas");
	}
	if (action === "delete_battle") {
		const id = clean(form.get("id"), 40);
		await supabase.from("battle_events").delete().eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=deleted", "batallas");
	}
	if (action === "delete_rank") {
		const id = clean(form.get("id"), 40);
		await supabase.from("rank_definitions").delete().eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=deleted", "progreso");
	}
	if (action === "delete_section") {
		const id = clean(form.get("id"), 40);
		await supabase.from("sections").delete().eq("id", id).eq("school_id", schoolId);
		return go(redirect, "saved=deleted", "estructura");
	}

	return go(redirect, "error=unknown_action", "configuracion");
};
