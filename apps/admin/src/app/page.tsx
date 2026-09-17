import { redirect } from "next/navigation";
import { configured } from "@/lib/config";
import { requireAdmin } from "@/lib/auth";
import { AdminError } from "@/lib/security";
import Login from "./ui/login";
export const dynamic = "force-dynamic";
export default async function Home() {
  if (!configured())
    return (
      <section className="card">
        <p className="eyebrow">Préparation de l’espace privé</p>
        <h1>Votre administration</h1>
        <p>
          La connexion sera disponible lorsque les paramètres du service et le
          compte propriétaire seront configurés.
        </p>
        <p>Aucun contenu privé n’est accessible dans cet état.</p>
      </section>
    );
  let signedIn = false;
  try {
    await requireAdmin();
    signedIn = true;
  } catch (e) {
    if (!(e instanceof AdminError) || ![401, 403].includes(e.status)) throw e;
  }
  if (signedIn) redirect("/admin");
  return <Login />;
}
