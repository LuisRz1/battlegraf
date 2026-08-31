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

/**
 * Destino del enlace de confirmación de correo (emailRedirectTo del signUp).
 * Supabase llega con ?token_hash=...&type=email; verificamos el OTP en el
 * servidor, completamos el onboarding pendiente (si lo hay) y entramos al panel.
 */
export const GET: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) return redirect("/iniciar-sesion?error=config", 303);

	const url = new URL(request.url);
	const tokenHash = url.searchParams.get("token_hash");
	const type = url.searchParams.get("type");

	if (!tokenHash || type !== "email") {
		return redirect("/iniciar-sesion?error=confirm", 303);
	}

	const supabase = createSupabaseServerClient({ request, cookies });
	const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: "email" });
	if (error) return redirect("/iniciar-sesion?error=confirm", 303);

	const pending = readPendingOnboardingCookies(cookies);
	if (pending) {
		const result = await ensureOnboarding(supabase, pending);
		clearPendingOnboardingCookies(cookies);
		if (result.error) {
			return redirect(`/registro?plan=${pending.plan}&error=${result.error}`, 303);
		}
		return redirect(result.onboarded ? "/panel?welcome=1" : "/panel?login=1", 303);
	}

	return redirect("/panel?login=1", 303);
};