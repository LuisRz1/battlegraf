import type { APIRoute } from "astro";
import { createSupabaseServerClient, hasSupabaseConfig } from "../../lib/supabase";

const clean = (value: FormDataEntryValue | null, max: number) =>
	String(value ?? "").trim().slice(0, max);

const API_BASE = process.env.PANEL_API_URL ?? "https://battlegraf-production.up.railway.app";

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
		.limit(1)
		.maybeSingle();
	if (!membership) return new Response("Sin permisos", { status: 403 });

	const { data: sessionData } = await supabase.auth.getSession();
	const apiToken = sessionData?.session?.access_token ?? "";
	if (!apiToken) return new Response("Sin sesión", { status: 401 });

	const battleRules = {
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
	};

	let ok = false;
	try {
		const res = await fetch(`${API_BASE}/api/v1/panel/${membership.school_id}`, {
			method: "PATCH",
			headers: { Authorization: `Bearer ${apiToken}`, "Content-Type": "application/json" },
			body: JSON.stringify({ name, code, region, city, ugel, address, battle_rules: battleRules }),
		});
		ok = res.ok;
		if (!ok) console.error("update school api error", await res.text());
	} catch (e) {
		console.error("update school api down", e);
	}

	return redirect(ok ? "/panel?saved=1" : "/panel?error=save", 303);
};