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
		const { data: existingMembership } = userData.user
			? await supabase
				.from("memberships")
				.select("school_id, role")
				.eq("user_id", userData.user.id)
				.limit(1)
				.maybeSingle()
			: { data: null };

		if (mode === "login" && !existingMembership) {
			await supabase.auth.signOut();
			cookies.delete("bg_selected_plan", { path: "/" });
			cookies.delete("bg_auth_mode", { path: "/" });
			cookies.delete("bg_auth_role", { path: "/" });
			cookies.delete("bg_school_code", { path: "/" });
			return redirect("/iniciar-sesion?error=not_found", 303);
		}

		let joinError: string | null = null;
		if (!existingMembership) {
			const fullName = userData.user?.user_metadata?.full_name ?? userData.user?.user_metadata?.name ?? "";
			const email = userData.user?.email ?? null;
			const avatar = userData.user?.user_metadata?.avatar_url ?? userData.user?.user_metadata?.picture ?? null;

			if (role === "director") {
				const { error: bootstrapError } = await supabase.rpc("bootstrap_institution_account", { p_plan_slug: plan });
				if (bootstrapError) return redirect("/panel?setup=retry", 303);
			} else {
				// Profesor o alumno: vincular al colegio por su código (trazabilidad multi-año)
				if (!schoolCodeCookie || schoolCodeCookie.length < 3) {
					joinError = "missing_code";
				} else {
					const { data: school } = await supabase
						.from("schools")
						.select("id, code")
						.ilike("code", schoolCodeCookie)
						.maybeSingle();
					if (!school) {
						joinError = "school_not_found";
					} else {
						const { error: membershipError } = await supabase.from("memberships").insert({
							school_id: school.id,
							user_id: userData.user!.id,
							role,
							status: role === "teacher" ? "active" : "active",
						});
						if (membershipError) {
							joinError = "membership_failed";
						} else {
							// Perfil en el colegio para trazabilidad a lo largo de los años
							if (role === "teacher") {
								await supabase.from("staff_profiles").insert({
									school_id: school.id,
									full_name: fullName || "Docente",
									email,
									role: "teacher",
									scope_label: "Todas las materias",
									status: "active",
									is_demo: false,
								});
							} else {
								await supabase.from("student_profiles").insert({
									school_id: school.id,
									full_name: fullName || "Estudiante",
									email,
									accessibility_preferences: {},
								});
							}
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
			}
		}

		cookies.delete("bg_selected_plan", { path: "/" });
		cookies.delete("bg_auth_mode", { path: "/" });
		cookies.delete("bg_auth_role", { path: "/" });
		cookies.delete("bg_school_code", { path: "/" });

		if (joinError) return redirect(`/registro?plan=${plan}&error=${joinError}`, 303);
		return redirect(existingMembership ? "/panel?login=1" : "/panel?welcome=1", 303);
	};
