const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// Reverse proxy to legacy backend so the web app can call same-origin /api/**
// TARGET is configurable via env; defaults to production legacy API.
const TARGET = process.env.LEGACY_API_BASE || "https://api.nexum-connects.com";

exports.api = onRequest({ region: "us-central1", cors: true }, async (req, res) => {
  const origin = req.get("Origin") || "*";
  res.set("Access-Control-Allow-Origin", origin);
  res.set("Vary", "Origin");
  res.set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS");
  res.set("Access-Control-Allow-Headers", req.get("Access-Control-Request-Headers") || "Content-Type, Authorization");
  res.set("Access-Control-Allow-Credentials", "true");
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    const url = new URL(req.url, `https://${req.get("host")}`);
    // Strip the /api prefix so "/api/auth/login" -> "/auth/login"
    const forwardPath = url.pathname.replace(/^\/api(\/|$)/, "/");
    const targetUrl = `${TARGET}${forwardPath}${url.search}`;

    // Build headers, excluding hop-by-hop and host
    const headers = new Headers();
    for (const [k, v] of Object.entries(req.headers)) {
      const key = k.toLowerCase();
      if (["host", "connection", "accept-encoding"].includes(key)) continue;
      // Skip cookie forwarding unless you know legacy uses cookie auth
      if (key === "cookie") continue;
      headers.append(k, Array.isArray(v) ? v.join(", ") : v);
    }

    const init = {
      method: req.method,
      headers,
      body: ["GET", "HEAD"].includes(req.method) ? undefined : req.rawBody,
    };

    logger.info("Proxying request", { method: req.method, path: forwardPath, target: targetUrl });

    const resp = await fetch(targetUrl, init);
    const buf = Buffer.from(await resp.arrayBuffer());

    // Propagate content-type and status
    const contentType = resp.headers.get("content-type");
    if (contentType) res.set("Content-Type", contentType);
    res.status(resp.status).send(buf);
  } catch (err) {
    logger.error("Proxy error", { error: err?.message || String(err) });
    res.status(502).json({ ok: false, error: "Bad gateway", detail: String(err) });
  }
});
