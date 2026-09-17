"use client";
import { useEffect, useState } from "react";
type Page = { id: string; title: string; current_revision: number };
type Document = {
  id: string;
  title: string;
  revision: number;
  fragments: { id: string; text: string; label: string }[];
};
export default function Editor() {
  const [pages, setPages] = useState<Page[]>([]),
    [document, setDocument] = useState<Document | null>(null),
    [selected, setSelected] = useState(""),
    [text, setText] = useState(""),
    [message, setMessage] = useState(""),
    [busy, setBusy] = useState(false),
    [dirty, setDirty] = useState(false);
  useEffect(() => {
    fetch("/api/pages")
      .then(async (r) => {
        if (!r.ok) throw Error();
        setPages((await r.json()).pages);
      })
      .catch(() => setMessage("Impossible de charger les pages."));
  }, []);
  useEffect(() => {
    const warn = (e: BeforeUnloadEvent) => {
      if (dirty) e.preventDefault();
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);
  async function open(id: string) {
    if (dirty && !confirm("Abandonner la modification non enregistrée ?"))
      return;
    setBusy(true);
    try {
      const r = await fetch(`/api/pages/${id}`);
      if (!r.ok) throw Error();
      setDocument(await r.json());
      setSelected("");
      setText("");
      setDirty(false);
      setMessage("");
    } catch {
      setMessage("Impossible d’ouvrir cette page.");
    } finally {
      setBusy(false);
    }
  }
  async function save() {
    if (!document) return;
    setBusy(true);
    try {
      const response = await fetch(`/api/pages/${document.id}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          expectedRevision: document.revision,
          fragmentId: selected,
          text,
        }),
      });
      if (response.status === 409) {
        setMessage(
          "La page a changé dans un autre onglet. Votre texte est conservé ici ; copiez-le puis rouvrez la page.",
        );
        return;
      }
      if (!response.ok) throw Error();
      setDocument(await response.json());
      setSelected("");
      setText("");
      setDirty(false);
      setMessage(
        "Brouillon enregistré. Cette modification n’est pas encore publiée.",
      );
    } catch {
      setMessage(
        "Enregistrement impossible. Votre modification reste affichée.",
      );
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      <div className="heading">
        <div>
          <p className="eyebrow">Contenus de l’application</p>
          <h1>Les textes</h1>
        </div>
        <button
          className="secondary"
          onClick={async () => {
            if (dirty && !confirm("Se déconnecter sans enregistrer ?")) return;
            const r = await fetch("/api/session", { method: "DELETE" });
            if (r.ok) location.assign("/");
          }}
        >
          Se déconnecter
        </button>
      </div>
      <p>
        Modifiez un passage à la fois. Les images et blocs complexes sont
        conservés. Le site d’origine reste inchangé.
      </p>
      <div className="workspace">
        <aside className="card">
          <h2>Pages</h2>
          {pages.length === 0 ? (
            <p>Aucune page importée dans cet espace.</p>
          ) : (
            pages.map((p) => (
              <button
                className="page-button"
                key={p.id}
                disabled={busy}
                aria-pressed={p.id === document?.id}
                onClick={() => open(p.id)}
              >
                {p.title}
              </button>
            ))
          )}
        </aside>
        <section className="card">
          {document ? (
            <>
              <h2>{document.title}</h2>
              <p>Brouillon · révision {document.revision}</p>
              <label>
                Passage
                <select
                  value={selected}
                  disabled={busy}
                  onChange={(e) => {
                    if (
                      dirty &&
                      !confirm("Abandonner la modification non enregistrée ?")
                    )
                      return;
                    setSelected(e.target.value);
                    setText(
                      document.fragments.find((f) => f.id === e.target.value)
                        ?.text ?? "",
                    );
                    setDirty(false);
                  }}
                >
                  <option value="">Choisir un passage</option>
                  {document.fragments.map((f, i) => (
                    <option key={f.id} value={f.id}>
                      {i + 1}. {f.text.trim().slice(0, 110)}
                    </option>
                  ))}
                </select>
              </label>
              {selected && (
                <>
                  <label>
                    Texte du passage
                    <textarea
                      dir="auto"
                      rows={8}
                      value={text}
                      disabled={busy}
                      onChange={(e) => {
                        setText(e.target.value);
                        setDirty(true);
                      }}
                    />
                  </label>
                  <button disabled={busy || !dirty} onClick={save}>
                    {busy ? "Enregistrement…" : "Enregistrer en brouillon"}
                  </button>
                </>
              )}
              <h3>Aperçu du brouillon enregistré</h3>
              <iframe
                title="Aperçu mobile de la page"
                sandbox="allow-same-origin"
                src={`/api/pages/${document.id}/preview?revision=${document.revision}`}
              />
            </>
          ) : (
            <p>Choisissez une page à modifier.</p>
          )}
          <p role="status">{message}</p>
        </section>
      </div>
    </>
  );
}
