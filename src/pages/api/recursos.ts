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
	redirect(`/panel?${value}#${anchor}`, 303);

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

	return go(redirect, "error=unknown_action", "configuracion");
};
