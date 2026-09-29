import type { SupabaseClient } from "@supabase/supabase-js";
import { isPlanSlug } from "./plans";

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
 *   - director  -> crea colegio, membership owner y suscripción
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

	const { data: existingMemberships } = await supabase
		.from("memberships")
		.select("status")
		.eq("user_id", user.id);
	if (existingMemberships?.some((membership) => membership.status === "active")) {
		return { onboarded: false };
	}
	if (existingMemberships?.length) {
		return { onboarded: false, error: "membership_inactive" };
	}

	const plan = isPlanSlug(ctx.plan) ? ctx.plan : "explorador";
	const fullName =
		user.user_metadata?.full_name ?? user.user_metadata?.name ?? "";

	const schoolCode = (ctx.schoolCode ?? "").trim().toUpperCase();
	if (ctx.role !== "director" && schoolCode.length < 3) {
		return { onboarded: false, error: "missing_code" };
	}

	const { error: onboardingError } = await supabase.rpc(
		"complete_mobile_onboarding",
		{
			p_role: ctx.role,
			p_school_code: schoolCode || null,
			p_school_name: null,
			p_region: null,
			p_plan_slug: plan,
		},
	);
	if (onboardingError) {
		const message = onboardingError.message.toLowerCase();
		if (ctx.role === "director") {
			return { onboarded: false, error: "bootstrap_failed" };
		}
		return {
			onboarded: false,
			error: message.includes("school not found")
				? "school_not_found"
				: "membership_failed",
		};
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
