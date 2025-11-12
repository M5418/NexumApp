const { onRequest, onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// Reverse proxy to legacy backend so the web app can call same-origin /api/**
// TARGET is configurable via env; defaults to production legacy API.
const TARGET = process.env.LEGACY_API_BASE || "https://api.nexum-connects.com";

// DeepL API configuration
// Set DEEPL_API_KEY in Firebase Functions environment config:
// firebase functions:config:set deepl.api_key="YOUR_DEEPL_PRO_API_KEY"
const DEEPL_API_KEY = process.env.DEEPL_API_KEY || "";
const DEEPL_API_URL = "https://api.deepl.com/v2/translate";

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

// Translation function using DeepL Pro API
exports.translateTexts = onCall({ region: "us-central1" }, async (request) => {
  try {
    const { texts, target_lang } = request.data;

    if (!texts || !Array.isArray(texts) || texts.length === 0) {
      throw new Error("'texts' must be a non-empty array");
    }

    if (!target_lang || typeof target_lang !== "string") {
      throw new Error("'target_lang' must be a valid language code (e.g., 'EN', 'FR', 'ES')");
    }

    if (!DEEPL_API_KEY) {
      logger.error("DeepL API key is not configured");
      // Return original texts if API key is missing
      return { translations: texts };
    }

    // Prepare the request body for DeepL API
    const params = new URLSearchParams();
    texts.forEach((text) => params.append("text", text));
    params.append("target_lang", target_lang);

    logger.info("Translating texts", { 
      count: texts.length, 
      target_lang,
      first_text_preview: texts[0]?.substring(0, 50)
    });

    // Call DeepL API
    const response = await fetch(DEEPL_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `DeepL-Auth-Key ${DEEPL_API_KEY}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("DeepL API error", { 
        status: response.status, 
        statusText: response.statusText,
        error: errorText
      });
      // Return original texts on API error
      return { translations: texts };
    }

    const data = await response.json();
    
    if (!data.translations || !Array.isArray(data.translations)) {
      logger.error("Invalid response from DeepL API", { data });
      return { translations: texts };
    }

    const translations = data.translations.map((item) => item.text || "");

    logger.info("Translation successful", { count: translations.length });

    return { translations };
  } catch (error) {
    logger.error("Translation function error", { error: error.message });
    // Return original texts on any error
    return { translations: request.data.texts || [] };
  }
});
