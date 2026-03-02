import { useEffect, useMemo, useState } from "react";

// Comentario

function App() {
  const apiBase = useMemo(() => import.meta.env.VITE_API_URL || "/api", []);
  const [health, setHealth] = useState("checking...");
  const [items, setItems] = useState([]);
  const [name, setName] = useState("");
  const [error, setError] = useState("");

  const healthUrl = apiBase.endsWith("/api") ? apiBase.replace(/\/api$/, "/health") : `${apiBase}/health`;
  const itemsUrl = apiBase.endsWith("/api") ? `${apiBase}/items` : `${apiBase}/api/items`;

  async function loadItems() {
    const response = await fetch(itemsUrl);
    if (!response.ok) throw new Error(`items failed: ${response.status}`);
    const data = await response.json();
    setItems(data);
  }

  useEffect(() => {
    (async () => {
      try {
        const response = await fetch(healthUrl);
        const data = await response.json();
        setHealth(data.status || "unknown");
        await loadItems();
      } catch (e) {
        setError(String(e));
      }
    })();
  }, []);

  async function onSubmit(event) {
    event.preventDefault();
    setError("");
    if (!name.trim()) return;
    try {
      const response = await fetch(itemsUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: name.trim() }),
      });
      if (!response.ok) throw new Error(`create failed: ${response.status}`);
      setName("");
      await loadItems();
    } catch (e) {
      setError(String(e));
    }
  }

  return (
    <main>
      <h1>Devbox App</h1>
      <p>
        Backend health: <strong>{health}</strong>
      </p>
      {error ? <p style={{ color: "#b91c1c" }}>{error}</p> : null}

      <form onSubmit={onSubmit}>
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="New item name" />
        <button type="submit">Create</button>
      </form>

      <ul>
        {items.map((item) => (
          <li key={item.id}>
            {item.name} <small>({new Date(item.created_at).toLocaleString()})</small>
          </li>
        ))}
      </ul>
    </main>
  );
}

export default App;
