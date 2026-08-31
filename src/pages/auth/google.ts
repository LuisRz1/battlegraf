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
	const mode = url.searchParams.get("mode") === "login" ? "login" : "register";
		const role = ["director", "teacher", "student"].includes(url.searchParams.get("role") ?? "")
			? (url.searchParams.get("role") as string)
			: "director";
		const schoolCode = (url.searchParams.get("school_code") ?? "").trim().toUpperCase().replace(/[^A-Z0-9-]/g, "");

		cookies.set("bg_selected_plan", plan, {
			httpOnly: true,
			sameSite: "lax",
			secure: url.protocol === "https:",
			path: "/",
			maxAge: 60 * 15,
		});
		cookies.set("bg_auth_mode", mode, {
			httpOnly: true,
			sameSite: "lax",
			secure: url.protocol === "https:",
			path: "/",
			maxAge: 60 * 15,
		});
		cookies.set("bg_auth_role", role, {
			httpOnly: true,
			sameSite: "lax",
			secure: url.protocol === "https:",
			path: "/",
			maxAge: 60 * 15,
		});
		if (schoolCode) {
			cookies.set("bg_school_code", schoolCode, {
				httpOnly: true,
				sameSite: "lax",
				secure: url.protocol === "https:",
				path: "/",
				maxAge: 60 * 15,
			});
		} else {
			cookies.delete("bg_school_code", { path: "/" });
		}

	const supabase = createSupabaseServerClient({ request, cookies });
	const { data, error } = await supabase.auth.signInWithOAuth({
		provider: "google",
		options: {
			redirectTo: `${getPublicOrigin(request)}/auth/callback`,
			skipBrowserRedirect: true,
		},
	});

	if (error || !data.url) {
		return redirect(mode === "login" ? "/iniciar-sesion?error=oauth" : `/registro?plan=${plan}&error=oauth`, 303);
	}

	return redirect(data.url, 303);
};
