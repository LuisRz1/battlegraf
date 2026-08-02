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

	if (name.length < 3 || code.length < 3) {
		return redirect("/panel?error=validation", 303);
	}

	const { data: membership } = await supabase
		.from("memberships")
		.select("school_id, role")
		.eq("user_id", userData.user.id)
		.in("role", ["owner", "director", "admin"])
		.limit(1)
		.maybeSingle();

	if (!membership) return new Response("Sin permisos", { status: 403 });

	const { error } = await supabase
		.from("schools")
		.update({ name, code, region, city, onboarding_complete: true })
		.eq("id", membership.school_id);

	return redirect(error ? "/panel?error=save" : "/panel?saved=1", 303);
};
