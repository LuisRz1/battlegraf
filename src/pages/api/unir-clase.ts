import type { APIRoute } from "astro";
import { createSupabaseServerClient, hasSupabaseConfig } from "../../lib/supabase";

/**
 * Enrolamiento del alumno a una clase mediante su código (CL-XXXX).
 * POST form: codigo
 * Usa la función RPC enroll_student_by_code (solo clases activas del año lectivo vigente).
 */
export const POST: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) return redirect("/iniciar-sesion?error=config", 303);
	const supabase = createSupabaseServerClient({ request, cookies });
	const { data: userData } = await supabase.auth.getUser();
	if (!userData.user) return redirect("/iniciar-sesion", 303);

	const form = await request.formData();
	const codigo = (form.get("codigo") ?? "").toString().trim().toUpperCase();

	if (!codigo || codigo.length < 3) return redirect("/mis-clases?error=missing_code", 303);

	const { error } = await supabase.rpc("enroll_student_by_code", { p_join_code: codigo });
	if (error) {
		const msg = error.message.toLowerCase();
		if (msg.includes("student profile")) return redirect("/mis-clases?error=no_student", 303);
		if (msg.includes("class not found")) return redirect("/mis-clases?error=class_not_found", 303);
		return redirect("/mis-clases?error=save", 303);
	}
	return redirect("/mis-clases?ok=1", 303);
};