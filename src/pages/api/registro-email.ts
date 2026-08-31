import type { APIRoute } from "astro";
import { isPlanSlug } from "../../lib/plans";
import {
	createSupabaseServerClient,
	getPublicOrigin,
	hasSupabaseConfig,
} from "../../lib/supabase";
import {
	clearPendingOnboardingCookies,
	ensureOnboarding,
	setPendingOnboardingCookies,
	type OnboardingRole,
} from "../../lib/onboarding";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const POST: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) return redirect("/registro?error=config", 303);

	const form = await request.formData();
	const fullName = (form.get("full_name") ?? "").toString().trim();
	const email = (form.get("email") ?? "").toString().trim().toLowerCase();
	const password = (form.get("password") ?? "").toString();
	const rawRole = (form.get("role") ?? "").toString();
	const rawPlan = (form.get("plan") ?? "").toString();
	const schoolCode = (form.get("school_code") ?? "").toString().trim();

	const role: OnboardingRole = ["director", "teacher", "student"].includes(rawRole)
		? (rawRole as OnboardingRole)
		: "director";
	const plan = isPlanSlug(rawPlan) ? rawPlan : "explorador";
	const errorTarget = `/registro?plan=${plan}`;

	if (!fullName || fullName.length < 2) return redirect(`${errorTarget}&error=invalid_name`, 303);
	if (!EMAIL_RE.test(email)) return redirect(`${errorTarget}&error=invalid_email`, 303);
	if (password.length < 8) return redirect(`${errorTarget}&error=short_password`, 303);
	if (role !== "director" && schoolCode.length < 3) {
		return redirect(`${errorTarget}&error=missing_code`, 303);
	}

	const supabase = createSupabaseServerClient({ request, cookies });

	const { data, error } = await supabase.auth.signUp({
		email,
		password,
		options: {
			data: { full_name: fullName },
			emailRedirectTo: `${getPublicOrigin(request)}/auth/confirmado`,
		},
	});

	if (error) {
		const message = error.message.toLowerCase();
		if (message.includes("already") || message.includes("exists") || message.includes("registrado")) {
			return redirect("/iniciar-sesion?error=email_exists", 303);
		}
		return redirect(`${errorTarget}&error=signup`, 303);
	}

	// Guardar el contexto pendiente (plan/rol/código) por si hay que confirmar el correo
	setPendingOnboardingCookies(cookies, { plan, role, schoolCode });

	// Si Supabase devuelve sesión inmediata (confirmación desactivada), completar onboarding ya
	if (data.session) {
		const result = await ensureOnboarding(supabase, { plan, role, schoolCode });
		clearPendingOnboardingCookies(cookies);
		if (result.error) return redirect(`${errorTarget}&error=${result.error}`, 303);
		return redirect("/panel?welcome=1", 303);
	}

	// Confirmación de correo requerida: avisar al usuario
	return redirect(`${errorTarget}&enviado=1`, 303);
};