import type { APIRoute } from "astro";
import {
	createSupabaseServerClient,
	hasSupabaseConfig,
} from "../../lib/supabase";
import {
	clearPendingOnboardingCookies,
	ensureOnboarding,
	readPendingOnboardingCookies,
} from "../../lib/onboarding";

export const POST: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) return redirect("/iniciar-sesion?error=config", 303);

	const form = await request.formData();
	const email = (form.get("email") ?? "").toString().trim().toLowerCase();
	const password = (form.get("password") ?? "").toString();

	if (!email || !password) return redirect("/iniciar-sesion?error=invalid", 303);

	const supabase = createSupabaseServerClient({ request, cookies });

	const { data, error } = await supabase.auth.signInWithPassword({ email, password });
	if (error || !data.session) {
		const message = error?.message.toLowerCase() ?? "";
		if (message.includes("confirm")) return redirect("/iniciar-sesion?error=email_not_confirmed", 303);
		return redirect("/iniciar-sesion?error=invalid", 303);
	}

	// Si la cuenta se registró por correo y aún no completó el onboarding
	// (p. ej. confirmó el correo pero nunca volvió al sitio), completarlo aquí.
	const pending = readPendingOnboardingCookies(cookies);
	let onboarded = false;
	if (pending) {
		const result = await ensureOnboarding(supabase, pending);
		onboarded = result.onboarded && !result.error;
		if (result.error) {
			clearPendingOnboardingCookies(cookies);
			return redirect(`/registro?plan=${pending.plan}&error=${result.error}`, 303);
		}
	}
	clearPendingOnboardingCookies(cookies);

	return redirect(onboarded ? "/panel?welcome=1" : "/panel?login=1", 303);
};