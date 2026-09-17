"use client";
import { useState } from "react";
export default function Password() {
  const [message, setMessage] = useState(""),
    [busy, setBusy] = useState(false);
  return (
    <section className="card narrow">
      <h1>Nouveau mot de passe</h1>
      <form
        action={async (form) => {
          if (form.get("password") !== form.get("confirm")) {
            setMessage("Les mots de passe sont différents.");
            return;
          }
          setBusy(true);
          try {
            const r = await fetch("/api/password", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ password: form.get("password") }),
            });
            if (!r.ok) throw Error();
            location.assign("/admin");
          } catch {
            setMessage(
              "Modification impossible. Réessayez ou demandez un nouveau lien.",
            );
          } finally {
            setBusy(false);
          }
        }}
      >
        <label>
          Mot de passe (12 caractères minimum)
          <input
            type="password"
            name="password"
            minLength={12}
            required
            autoComplete="new-password"
          />
        </label>
        <label>
          Confirmer
          <input
            type="password"
            name="confirm"
            minLength={12}
            required
            autoComplete="new-password"
          />
        </label>
        <button disabled={busy}>Enregistrer</button>
      </form>
      <p role="status">{message}</p>
    </section>
  );
}
