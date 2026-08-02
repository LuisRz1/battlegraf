import type { APIRoute } from "astro";
import { isPlanSlug } from "../../lib/plans";
import {
	createSupabaseServerClient,
	hasSupabaseConfig,
} from "../../lib/supabase";

export const GET: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) {
		return redirect("/registro?error=config", 303);
	}

	const url = new URL(request.url);
	const code = url.searchParams.get("code");
	const cookiePlan = cookies.get("bg_selected_plan")?.value ?? null;
	const plan = isPlanSlug(cookiePlan) ? cookiePlan : "explorador";
	const mode = cookies.get("bg_auth_mode")?.value === "login" ? "login" : "register";
	const errorTarget = mode === "login" ? "/iniciar-sesion" : `/registro?plan=${plan}`;

	if (!code) return redirect(`${errorTarget}${errorTarget.includes("?") ? "&" : "?"}error=missing_code`, 303);

	const supabase = createSupabaseServerClient({ request, cookies });
	const { error } = await supabase.auth.exchangeCodeForSession(code);
	if (error) return redirect(`${errorTarget}${errorTarget.includes("?") ? "&" : "?"}error=exchange`, 303);

	const { data: userData } = await supabase.auth.getUser();
	const { data: existingMembership } = userData.user
		? await supabase
			.from("memberships")
			.select("school_id")
			.eq("user_id", userData.user.id)
			.limit(1)
			.maybeSingle()
		: { data: null };

	if (mode === "login" && !existingMembership) {
		await supabase.auth.signOut();
		cookies.delete("bg_selected_plan", { path: "/" });
		cookies.delete("bg_auth_mode", { path: "/" });
		return redirect("/iniciar-sesion?error=not_found", 303);
	}

	const { error: bootstrapError } = existingMembership
		? { error: null }
		: await supabase.rpc("bootstrap_institution_account", { p_plan_slug: plan });

	cookies.delete("bg_selected_plan", { path: "/" });
	cookies.delete("bg_auth_mode", { path: "/" });

	if (bootstrapError) return redirect("/panel?setup=retry", 303);
	return redirect(existingMembership ? "/panel?login=1" : "/panel?welcome=1", 303);
};
