import type { APIRoute } from "astro";
import { createSupabaseServerClient, hasSupabaseConfig } from "../../lib/supabase";

const clean = (value: FormDataEntryValue | null, max: number) =>
	String(value ?? "").trim().slice(0, max);

export const POST: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) return new Response("Servicio no configurado", { status: 503 });

	const supabase = createSupabaseServerClient({ request, cookies });
	const { data: userData } = await supabase.auth.getUser();
	if (!userData.user) return redirect("/registro", 303);

	const form = await request.formData();
	const name = clean(form.get("name"), 120);
	const code = clean(form.get("code"), 30).toUpperCase().replace(/[^A-Z0-9-]/g, "");
	const region = clean(form.get("region"), 80);
	const city = clean(form.get("city"), 80);
	const ugel = clean(form.get("ugel"), 80);
	const address = clean(form.get("address"), 180);

	if (name.length < 3 || code.length < 3) {
		return redirect("/panel?error=validation", 303);
	}

	const { data: membership } = await supabase
		.from("memberships")
		.select("school_id, role")
		.eq("user_id", userData.user.id)
		.in("role", ["owner", "director", "subdirector", "coordinator"])
		.limit(1)
		.maybeSingle();

	if (!membership) return new Response("Sin permisos", { status: 403 });

	const { error } = await supabase
		.from("schools")
		.update({ name, code, region, city, ugel, address, onboarding_complete: true })
		.eq("id", membership.school_id);

	if (!error) {
		await supabase.from("school_settings").upsert({
			school_id: membership.school_id,
			battle_rules: {
				mode: "turn_based",
				first_team: "red",
				cross_section_battles: form.get("cross_section_battles") === "on",
				task_progress: form.get("task_progress") === "on",
				review_required: form.get("review_required") === "on",
				turn_seconds: Math.min(120, Math.max(10, Number(clean(form.get("turn_seconds"), 3)) || 30)),
				min_layers: 4,
				max_layers: 7,
				nodes_per_layer: { min: 3, max: 4 },
				capture_rule: "fastest_correct_time",
			},
		}, { onConflict: "school_id" });
		await supabase.from("audit_logs").insert({ school_id: membership.school_id, actor_name: "Direccion", action: "Actualizo la entidad y reglas", target_label: name, category: "configuration" });
	}

	return redirect(error ? "/panel?error=save" : "/panel?saved=1", 303);
};
