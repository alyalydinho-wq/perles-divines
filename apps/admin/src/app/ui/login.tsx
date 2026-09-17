"use client";
import { useState } from "react";
export default function Login() {
  const [message, setMessage] = useState(""),
    [busy, setBusy] = useState(false);
  async function submit(form: FormData) {
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch("/api/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: form.get("email"),
          password: form.get("password"),
        }),
      });
      if (response.ok) {
        location.assign("/admin");
        return;
      }
      setMessage(
        "Connexion impossible. Vérifiez vos identifiants et votre accès propriétaire.",
      );
    } catch {
      setMessage("Connexion indisponible. Réessayez.");
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="card narrow">
      <p className="eyebrow">Espace du propriétaire</p>
      <h1>Connexion</h1>
      <form action={submit}>
        <label>
          Adresse e-mail
          <input type="email" name="email" autoComplete="username" required />
        </label>
        <label>
          Mot de passe
          <input
            type="password"
            name="password"
            autoComplete="current-password"
            required
          />
        </label>
        <button disabled={busy}>{busy ? "Connexion…" : "Se connecter"}</button>
      </form>
      <p role="status">{message}</p>
      <a href="/recovery">Mot de passe oublié</a>
    </section>
  );
}
