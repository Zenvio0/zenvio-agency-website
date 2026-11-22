(() => {
  const script = document.currentScript;
  if (!script || script.dataset.ariaLoaded === "true") return;
  script.dataset.ariaLoaded = "true";
  const greeting = script.dataset.greeting || "Hello! How can I help you today?";
  const knowledge = script.dataset.knowledge || "";
  const host = document.createElement("div");
  host.id = "zenvio-aria-widget";
  const shadow = host.attachShadow({ mode: "open" });
  shadow.innerHTML = `
    <style>
      :host{all:initial;font-family:Inter,Arial,sans-serif}
      .launcher{position:fixed;right:22px;bottom:22px;z-index:2147483000;border:0;border-radius:999px;padding:14px 20px;background:#17151d;color:#fff;font:600 14px Inter,Arial;box-shadow:0 12px 38px #0004;cursor:pointer}
      .panel{position:fixed;right:22px;bottom:82px;z-index:2147483000;width:min(360px,calc(100vw - 32px));height:min(480px,calc(100vh - 120px));display:flex;flex-direction:column;background:#17151d;color:#fff;border:1px solid #a78bfa66;border-radius:18px;box-shadow:0 18px 60px #0008;overflow:hidden}
      .panel[hidden]{display:none}.head{display:flex;align-items:center;justify-content:space-between;padding:16px;border-bottom:1px solid #ffffff22;font-weight:700}.close{background:transparent;color:#fff;border:0;font-size:22px;cursor:pointer}
      .messages{flex:1;overflow:auto;padding:14px;display:flex;flex-direction:column;gap:10px}.bubble{white-space:pre-wrap;overflow-wrap:anywhere;max-width:90%;padding:10px 12px;border-radius:12px;background:#ffffff14;color:#fff;font:13px/1.5 Inter,Arial}.user{align-self:flex-end;background:#7256c8}.foot{display:flex;gap:8px;padding:12px;border-top:1px solid #ffffff22}.question{min-width:0;flex:1;padding:11px;border-radius:9px;border:1px solid #ffffff33;background:#ffffff10;color:white;font:13px Inter,Arial}.send{padding:10px 14px;border:0;border-radius:9px;background:#a78bfa;color:#17151d;font-weight:700;cursor:pointer}
      .hint{padding:0 14px 10px;color:#aaa;font:10px Inter,Arial}
    </style>
    <button class="launcher" type="button">Chat with us · ARIA</button>
    <section class="panel" hidden aria-label="ARIA website assistant">
      <header class="head"><span>ARIA · Website assistant</span><button class="close" type="button" aria-label="Close">×</button></header>
      <div class="messages" aria-live="polite"></div>
      <div class="foot"><input class="question" maxlength="1200" placeholder="Ask about services…" /><button class="send" type="button">Send</button></div>
      <div class="hint">Preview assistant · answers from business information provided by the website owner.</div>
    </section>`;
  document.body.appendChild(host);
  const $ = (selector) => shadow.querySelector(selector);
  const panel = $(".panel"), messages = $(".messages"), input = $(".question");
  const addMessage = (text, role) => {
    const bubble = document.createElement("div");
    bubble.className = "bubble " + role;
    bubble.textContent = text;
    messages.appendChild(bubble);
    messages.scrollTop = messages.scrollHeight;
  };
  const answer = (question) => {
    const terms = question.toLowerCase().match(/[a-z0-9]{3,}/g) || [];
    const rows = knowledge.split(/\n+/).map(x => x.trim()).filter(Boolean);
    const ranked = rows.map(row => ({
      row,
      score: terms.reduce((sum, term) => sum + (row.toLowerCase().includes(term) ? 1 : 0), 0)
    })).filter(x => x.score > 0).sort((a, b) => b.score - a.score).slice(0, 3);
    return ranked.length
      ? ranked.map(x => x.row).join("\n")
      : "I don't have that detail in the business information provided. Please contact the team and they will be happy to help.";
  };
  const send = () => {
    const question = input.value.trim();
    if (!question) return;
    addMessage(question, "user");
    input.value = "";
    addMessage(answer(question), "assistant");
  };
  $(".launcher").addEventListener("click", () => { panel.hidden = false; input.focus(); });
  $(".close").addEventListener("click", () => { panel.hidden = true; });
  $(".send").addEventListener("click", send);
  input.addEventListener("keydown", event => { if (event.key === "Enter") send(); });
  addMessage(greeting, "assistant");
})();
