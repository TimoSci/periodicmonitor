import { Session, ready } from "@session.js/client";

await ready;

const mnemonic = process.env.SESSION_BOT_MNEMONIC;
if (!mnemonic) {
  console.error("SESSION_BOT_MNEMONIC is required");
  process.exit(1);
}

const displayName = process.env.SESSION_DISPLAY_NAME || "ENS Monitor Bot";
const port = parseInt(process.env.PORT || "3100", 10);

const session = new Session();
session.setMnemonic(mnemonic, displayName);

const sessionId = session.getSessionID();
console.log(`Bot Session ID: ${sessionId}`);
console.log(`Listening on port ${port}`);

Bun.serve({
  port,
  async fetch(req) {
    const url = new URL(req.url);

    if (req.method === "GET" && url.pathname === "/health") {
      return Response.json({ status: "ok", session_id: sessionId });
    }

    if (req.method === "GET" && url.pathname === "/generate-mnemonic") {
      const { Mnemonic } = await import("@session.js/mnemonic");
      const newMnemonic = Mnemonic.generate();
      return Response.json({ mnemonic: newMnemonic });
    }

    if (req.method === "POST" && url.pathname === "/send") {
      try {
        const body = await req.json();
        const { to, text } = body;

        if (!to || !text) {
          return Response.json(
            { error: "Missing 'to' or 'text' field" },
            { status: 400 }
          );
        }

        const result = await session.sendMessage({ to, text });
        return Response.json({
          status: "sent",
          message_hash: result.messageHash,
          timestamp: result.timestamp,
        });
      } catch (error) {
        return Response.json(
          { error: String(error) },
          { status: 500 }
        );
      }
    }

    return Response.json({ error: "Not found" }, { status: 404 });
  },
});
