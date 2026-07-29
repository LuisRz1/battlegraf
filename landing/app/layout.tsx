import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://battlegraf-landing.vercel.app"),
  title: "BattleGraf | Aprender es conquistar",
  description:
    "Plataforma escolar de aprendizaje gamificado con batallas estratégicas sobre grafos, tareas, XP, rangos y clanes.",
  applicationName: "BattleGraf",
  keywords: [
    "BattleGraf",
    "educación",
    "gamificación",
    "colegios",
    "aprendizaje",
    "juego educativo",
  ],
  openGraph: {
    title: "BattleGraf | Aprender es conquistar",
    description:
      "Convierte el contenido de clase en rutas, batallas y progreso visible.",
    type: "website",
    locale: "es_PE",
    images: [
      {
        url: "/og.png",
        width: 1200,
        height: 630,
        alt: "BattleGraf: aprender es conquistar",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "BattleGraf | Aprender es conquistar",
    description:
      "Convierte el contenido de clase en rutas, batallas y progreso visible.",
    images: ["/og.png"],
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body className={`${geistSans.variable} ${geistMono.variable}`}>
        {children}
      </body>
    </html>
  );
}
