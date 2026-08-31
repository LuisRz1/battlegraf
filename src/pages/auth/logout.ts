import type { APIRoute } from "astro";
import { createSupabaseServerClient, hasSupabaseConfig } from "../../lib/supabase";

export const POST: APIRoute = async ({ request, cookies, redirect }) => {
	if (hasSupabaseConfig()) {
		const supabase = createSupabaseServerClient({ request, cookies });
		await supabase.auth.signOut();
	}
	return redirect("/", 303);
};
