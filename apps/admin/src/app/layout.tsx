import type { Metadata } from "next";
import "./style.css";
export const dynamic = "force-dynamic";
export const metadata: Metadata = {
  title: "Administration — Perles Divines",
  robots: { index: false, follow: false },
};
export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <body>
        <header>
          <a href="/">Perles Divines</a>
          <span>Administration privée</span>
        </header>
        <main>{children}</main>
      </body>
    </html>
  );
}
