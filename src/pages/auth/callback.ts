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

	if (!code) return redirect(`/registro?plan=${plan}&error=missing_code`, 303);

	const supabase = createSupabaseServerClient({ request, cookies });
	const { error } = await supabase.auth.exchangeCodeForSession(code);
	if (error) return redirect(`/registro?plan=${plan}&error=exchange`, 303);

	const { error: bootstrapError } = await supabase.rpc(
		"bootstrap_institution_account",
		{ p_plan_slug: plan },
	);

	cookies.delete("bg_selected_plan", { path: "/" });

	if (bootstrapError) return redirect("/panel?setup=retry", 303);
	return redirect("/panel?welcome=1", 303);
};
