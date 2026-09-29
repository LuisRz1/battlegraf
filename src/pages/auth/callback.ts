import type { APIRoute } from "astro";
import { isPlanSlug } from "../../lib/plans";
import { createSupabaseServerClient, hasSupabaseConfig } from "../../lib/supabase";

export const GET: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) {
		return redirect("/registro?error=config", 303);
	}

	const url = new URL(request.url);
	const code = url.searchParams.get("code");
	const cookiePlan = cookies.get("bg_selected_plan")?.value ?? null;
	const plan = isPlanSlug(cookiePlan) ? cookiePlan : "explorador";
	const mode = cookies.get("bg_auth_mode")?.value === "login" ? "login" : "register";
	const role = ["director", "teacher", "student"].includes(cookies.get("bg_auth_role")?.value ?? "")
		? (cookies.get("bg_auth_role")?.value as string)
		: "director";
	const schoolCodeCookie = (cookies.get("bg_school_code")?.value ?? "").trim().toUpperCase();
	const errorTarget = mode === "login" ? "/iniciar-sesion" : `/registro?plan=${plan}`;

	if (!code) return redirect(`${errorTarget}${errorTarget.includes("?") ? "&" : "?"}error=missing_code`, 303);

	const supabase = createSupabaseServerClient({ request, cookies });
	const { error } = await supabase.auth.exchangeCodeForSession(code);
	if (error) return redirect(`${errorTarget}${errorTarget.includes("?") ? "&" : "?"}error=exchange`, 303);

	const { data: userData } = await supabase.auth.getUser();
	const { data: existingMemberships } = userData.user
		? await supabase
			.from("memberships")
			.select("school_id, role, status")
			.eq("user_id", userData.user.id)
			.order("created_at")
		: { data: null };
	const existingMembership =
		existingMemberships?.find((membership) => membership.status === "active") ?? null;
	const hasInactiveMembership = Boolean(existingMemberships?.length && !existingMembership);

	if (mode === "login" && !existingMembership) {
		await supabase.auth.signOut();
		cookies.delete("bg_selected_plan", { path: "/" });
		cookies.delete("bg_auth_mode", { path: "/" });
		cookies.delete("bg_auth_role", { path: "/" });
		cookies.delete("bg_school_code", { path: "/" });
		return redirect(
			hasInactiveMembership
				? "/iniciar-sesion?error=membership_inactive"
				: "/iniciar-sesion?error=not_found",
			303,
		);
	}

	let joinError: string | null = null;
	if (!existingMembership) {
		if (hasInactiveMembership) {
			joinError = "membership_inactive";
		} else if (role !== "director" && schoolCodeCookie.length < 3) {
			joinError = "missing_code";
		} else {
			const fullName = userData.user?.user_metadata?.full_name ?? userData.user?.user_metadata?.name ?? "";
			const email = userData.user?.email ?? null;
			const avatar = userData.user?.user_metadata?.avatar_url ?? userData.user?.user_metadata?.picture ?? null;
			const { error: onboardingError } = await supabase.rpc(
				"complete_mobile_onboarding",
				{
					p_role: role,
					p_school_code: schoolCodeCookie || null,
					p_school_name: null,
					p_region: null,
					p_plan_slug: plan,
				},
			);
			if (onboardingError) {
				joinError = role === "director"
					? "bootstrap_failed"
					: onboardingError.message.toLowerCase().includes("school not found")
						? "school_not_found"
						: "membership_failed";
			} else {
				await supabase.from("profiles").upsert(
					{
						id: userData.user!.id,
						email,
						full_name: fullName,
						avatar_url: avatar,
					},
					{ onConflict: "id" }
				);
			}
		}
	}

	cookies.delete("bg_selected_plan", { path: "/" });
	cookies.delete("bg_auth_mode", { path: "/" });
	cookies.delete("bg_auth_role", { path: "/" });
	cookies.delete("bg_school_code", { path: "/" });

	if (joinError) {
		const target = mode === "login" ? "/iniciar-sesion" : `/registro?plan=${plan}`;
		return redirect(
			`${target}${target.includes("?") ? "&" : "?"}error=${joinError}`,
			303,
		);
	}
	return redirect(existingMembership ? "/panel?login=1" : "/panel?welcome=1", 303);
};
