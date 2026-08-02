import type { APIRoute } from "astro";
import { isPlanSlug } from "../../lib/plans";
import {
	createSupabaseServerClient,
	getPublicOrigin,
	hasSupabaseConfig,
} from "../../lib/supabase";

export const GET: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) {
		return new Response("Supabase no está configurado.", { status: 503 });
	}

	const url = new URL(request.url);
	const requestedPlan = url.searchParams.get("plan");
	const plan = isPlanSlug(requestedPlan) ? requestedPlan : "explorador";

	cookies.set("bg_selected_plan", plan, {
		httpOnly: true,
		sameSite: "lax",
		secure: url.protocol === "https:",
		path: "/",
		maxAge: 60 * 15,
	});

	const supabase = createSupabaseServerClient({ request, cookies });
	const { data, error } = await supabase.auth.signInWithOAuth({
		provider: "google",
		options: {
			redirectTo: `${getPublicOrigin(request)}/auth/callback`,
			skipBrowserRedirect: true,
		},
	});

	if (error || !data.url) {
		return redirect(`/registro?plan=${plan}&error=oauth`, 303);
	}

	return redirect(data.url, 303);
};
