export const plans = [
	{
		slug: "explorador",
		name: "Explorador",
		price: "Gratis",
		period: "para siempre",
		studentLimit: 30,
		aiCredits: 0,
		trialDays: 7,
		description: "Empieza con siete días de acceso total y continúa gratis con un aula.",
		cta: "Crear cuenta gratis",
		featured: false,
		features: [
			"7 días con todas las funciones de Red Educativa",
			"Hasta 30 estudiantes",
			"1 sección activa",
			"Batallas por turnos y tareas",
			"Banco de preguntas manual",
			"Accesibilidad esencial",
			"Sin funciones de IA",
		],
	},
	{
		slug: "aula",
		name: "Aula",
		price: "S/ 89",
		period: "por mes",
		studentLimit: 150,
		aiCredits: 400,
		trialDays: 0,
		description: "Para docentes y coordinadores que administran varias secciones.",
		cta: "Comenzar con Aula",
		featured: false,
		features: [
			"Hasta 150 estudiantes",
			"Hasta 6 secciones",
			"Subida de PDF, PPTX, DOCX e imágenes",
			"Preguntas generadas con IA",
			"400 acciones de IA al mes",
			"Reportes básicos por sección",
		],
	},
	{
		slug: "colegio",
		name: "Colegio",
		price: "S/ 249",
		period: "por mes",
		studentLimit: 600,
		aiCredits: 2500,
		trialDays: 0,
		description: "El núcleo institucional para dirección, docentes y tutores.",
		cta: "Elegir Colegio",
		featured: true,
		features: [
			"Hasta 600 estudiantes",
			"Secciones y cursos ilimitados",
			"Creación de clases y materiales con IA",
			"Revisión de respuestas y recomendaciones",
			"Asistente para docentes",
			"Torneos entre secciones y analítica",
		],
	},
	{
		slug: "red",
		name: "Red Educativa",
		price: "A medida",
		period: "contrato anual",
		studentLimit: 2000,
		aiCredits: 15000,
		trialDays: 0,
		description: "Para redes, UGEL, campus múltiples o despliegues de gran escala.",
		cta: "Solicitar implementación",
		featured: false,
		features: [
			"Desde 2,000 estudiantes",
			"Múltiples sedes y administración central",
			"Resumen inteligente después de cada batalla",
			"Chatbot para docentes y estudiantes",
			"Personalización pedagógica y apoyo TDAH",
			"SSO, API, acompañamiento y SLA",
		],
	},
] as const;

export type PlanSlug = (typeof plans)[number]["slug"];

export function getPlan(slug: string | null | undefined) {
	return plans.find((plan) => plan.slug === slug) ?? plans[0];
}

export function isPlanSlug(value: string | null): value is PlanSlug {
	return plans.some((plan) => plan.slug === value);
}
