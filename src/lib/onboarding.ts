import type { SupabaseClient } from "@supabase/supabase-js";
import { isPlanSlug } from "./plans";
import { createSupabaseServiceClient, hasSupabaseSecret } from "./supabase";

export type OnboardingRole = "director" | "teacher" | "student";

export interface OnboardingContext {
	plan: string;
	role: OnboardingRole;
	schoolCode?: string | null;
}

export interface OnboardingResult {
	onboarded: boolean;
	error?: string;
}

/**
 * Completa el onboarding de una cuenta que todavía no pertenece a ningún
 * colegio. Es el equivalente del flujo de Google (auth/callback) pero usable
 * desde el registro y el inicio de sesión por correo:
 *   - director  -> RPC bootstrap_institution_account (crea colegio, membership owner y suscripción)
 *   - teacher   -> se une por código de colegio y crea staff_profile
 *   - student   -> se une por código de colegio y crea student_profile
 * Si la cuenta ya tiene membership devuelve { onboarded: false } sin tocar nada
 * (permite que el endpoint de login lo llame siempre, idempotente).
 */
export async function ensureOnboarding(
	supabase: SupabaseClient,
	ctx: OnboardingContext
): Promise<OnboardingResult> {
	const {
		data: { user },
	} = await supabase.auth.getUser();
	if (!user) return { onboarded: false, error: "no_session" };

	const { data: existingMembership } = await supabase
		.from("memberships")
		.select("school_id, role")
		.eq("user_id", user.id)
		.limit(1)
		.maybeSingle();
	if (existingMembership) return { onboarded: false };

	const plan = isPlanSlug(ctx.plan) ? ctx.plan : "explorador";
	const fullName =
		user.user_metadata?.full_name ?? user.user_metadata?.name ?? "";

	if (ctx.role === "director") {
		const { error: bootstrapError } = await supabase.rpc("bootstrap_institution_account", {
			p_plan_slug: plan,
		});
		if (bootstrapError) return { onboarded: false, error: "bootstrap_failed" };
		return { onboarded: true };
	}

	// Profesor o alumno: vincular al colegio por su código.
	// El usuario aún NO tiene membership, así que RLS le impide leer `schools`
	// (la política solo permite a is_school_member). Se busca con el cliente
	// service-role (solo devuelve id y código); si no hay secret key configurada,
	// se intenta con la sesión del usuario como último recurso.
	const schoolCode = (ctx.schoolCode ?? "").trim().toUpperCase();
	if (schoolCode.length < 3) return { onboarded: false, error: "missing_code" };

	let school: { id: string; code: string } | null = null;
	if (hasSupabaseSecret()) {
		const admin = createSupabaseServiceClient();
		const { data: found } = await admin
			.from("schools")
			.select("id, code")
			.ilike("code", schoolCode)
			.limit(2);
		school = found && found.length === 1 ? found[0] : null;
	} else {
		const { data: found } = await supabase
			.from("schools")
			.select("id, code")
			.ilike("code", schoolCode)
			.maybeSingle();
		school = found ?? null;
	}
	if (!school) return { onboarded: false, error: "school_not_found" };

	const { error: membershipError } = await supabase.from("memberships").insert({
		school_id: school.id,
		user_id: user.id,
		role: ctx.role,
		status: "active",
	});
	if (membershipError) return { onboarded: false, error: "membership_failed" };

	if (ctx.role === "teacher") {
		await supabase.from("staff_profiles").insert({
			school_id: school.id,
			full_name: fullName || "Docente",
			email: user.email ?? null,
			role: "teacher",
			scope_label: "Todas las materias",
			status: "active",
			is_demo: false,
		});
	} else {
		await supabase.from("student_profiles").insert({
			school_id: school.id,
			full_name: fullName || "Estudiante",
			email: user.email ?? null,
			accessibility_preferences: {},
		});
	}
	await supabase.from("profiles").upsert(
		{
			id: user.id,
			email: user.email,
			full_name: fullName,
		},
		{ onConflict: "id" }
	);

	return { onboarded: true };
}

/** Escribe los parámetros pendientes de onboarding en cookies (15 min por defecto). */
export function setPendingOnboardingCookies(
	cookies: {
		set: (name: string, value: string, options: Record<string, unknown>) => void;
		delete: (name: string, options: Record<string, unknown>) => void;
	},
	ctx: OnboardingContext,
	maxAgeSeconds = 60 * 60 * 24 * 7 // 7 días: aguanta la confirmación de correo
) {
	const base = {
		httpOnly: true,
		sameSite: "lax",
		path: "/",
		maxAge: maxAgeSeconds,
	} as Record<string, unknown>;

	cookies.set("bg_selected_plan", ctx.plan, base);
	cookies.set("bg_auth_role", ctx.role, base);
	if (ctx.schoolCode) {
		cookies.set("bg_school_code", ctx.schoolCode.trim().toUpperCase(), base);
	} else {
		cookies.delete("bg_school_code", base);
	}
}

/** Lee las cookies pendientes de onboarding si existen. */
export function readPendingOnboardingCookies(cookies: {
	get: (name: string) => { value: string | null } | undefined;
}): OnboardingContext | null {
	const role = cookies.get("bg_auth_role")?.value;
	if (!["director", "teacher", "student"].includes(role ?? "")) return null;
	return {
		plan: cookies.get("bg_selected_plan")?.value ?? "explorador",
		role: role as OnboardingRole,
		schoolCode: cookies.get("bg_school_code")?.value ?? null,
	};
}

/** Borra las cookies pendientes de onboarding. */
export function clearPendingOnboardingCookies(cookies: {
	delete: (name: string, options: Record<string, unknown>) => void;
}) {
	const base = { path: "/" } as Record<string, unknown>;
	cookies.delete("bg_selected_plan", base);
	cookies.delete("bg_auth_mode", base);
	cookies.delete("bg_auth_role", base);
	cookies.delete("bg_school_code", base);
}