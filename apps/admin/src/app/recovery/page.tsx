"use client";
import { useState } from "react";
export default function Recovery() {
  const [message, setMessage] = useState(""),
    [busy, setBusy] = useState(false);
  return (
    <section className="card narrow">
      <h1>Récupérer l’accès</h1>
      <p>Utilisez l’adresse du compte propriétaire.</p>
      <form
        action={async (form) => {
          setBusy(true);
          try {
            const response = await fetch("/api/recovery", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ email: form.get("email") }),
            });
            if (!response.ok) throw Error();
            setMessage(
              "Si cette adresse correspond à un compte, un lien de récupération lui sera envoyé.",
            );
          } catch {
            setMessage("Service indisponible. Réessayez.");
          } finally {
            setBusy(false);
          }
        }}
      >
        <label>
          Adresse e-mail
          <input required name="email" type="email" autoComplete="email" />
        </label>
        <button disabled={busy}>{busy ? "Envoi…" : "Recevoir un lien"}</button>
      </form>
      <p role="status">{message}</p>
      <a href="/">Retour à la connexion</a>
    </section>
  );
}
