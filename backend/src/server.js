// File: backend/src/server.js
import "dotenv/config";
import express from "express";
import cors from "cors";


// --- Route imports ---
import authRoutes from "./routes/auth.js";
import filesRoutes from "./routes/files.js";
import profileRoutes from "./routes/profile.js";
import usersRoutes from "./routes/users.js";
import connectionsRoutes from "./routes/connections.js";
import invitationsRoutes from "./routes/invitations.js";
import authMiddleware from "./middleware/auth.js";
import postsRoutes from "./routes/posts-simplified.js";
import conversationsRoutes from "./routes/conversations.js";
import messagesRoutes from "./routes/messages.js";
import storiesRoutes from "./routes/stories.js";
import communitiesRoutes from "./routes/communities.js";
import communityPostsRoutes from "./routes/community-posts.js";
import communityRepostsRoutes from "./routes/community-posts-reposts.js";
import repostsRoutes from "./routes/posts-reposts.js";
import booksRoutes from "./routes/books.js";
import podcastsRoutes from "./routes/podcasts.js";
import mentorshipRoutes from "./routes/mentorship.js";
import searchRoutes from "./routes/search.js";
import notificationsRoutes from "./routes/notifications.js";
import kycRoutes from "./routes/kyc.js";
import reportsRoutes from "./routes/reports.js";

// --- App setup ---
const app = express();
const PORT = process.env.PORT || 8080;

// behind ALB/Cloudflare
app.set("trust proxy", 1);

/* ---------------------- C O R S  (FIRST) ---------------------- */

// exact prod
const STATIC_ALLOW = new Set([
  "https://nexum-connects.com",
  "https://www.nexum-connects.com",
]);

// allow *.nexum-connects.com
function isAllowedSubdomain(origin) {
  try {
    const host = new URL(origin).hostname.toLowerCase();
    return host === "nexum-connects.com" || host.endsWith(".nexum-connects.com");
  } catch {
    return false;
  }
}

// allow any localhost (any port)
const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1"]);
function isLocalhost(origin) {
  try {
    const { hostname, protocol } = new URL(origin);
    return (protocol === "http:" || protocol === "https:") && LOCAL_HOSTS.has(hostname);
  } catch {
    return false;
  }
}

// optional extra origins from env (comma-separated)
const EXTRA = (process.env.CORS_EXTRA_ORIGINS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const corsOptions = {
  origin(origin, cb) {
    if (!origin) return cb(null, true); // curl/Postman/no-origin
    if (STATIC_ALLOW.has(origin)) return cb(null, true);
    if (EXTRA.includes(origin)) return cb(null, true);
    if (isAllowedSubdomain(origin)) return cb(null, true);
    if (isLocalhost(origin)) return cb(null, true);
    return cb(null, false); // deny silently (no headers -> browser blocks)
  },
  credentials: true, // set false if you never use cookies
  methods: ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "X-Requested-With", "Accept"],
  optionsSuccessStatus: 204,
  preflightContinue: false,
  maxAge: 86400,
};

app.use(cors(corsOptions));
app.options("*", cors(corsOptions)); // preflight

/* -------------------- B O D Y   P A R S I N G -------------------- */
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

/* ---------------------- H E A L T H  C H E C K S ----------------- */
app.get("/api/ping", (_req, res) => res.json({ ok: true, msg: "pong" }));
app.get("/health", (_req, res) => res.status(200).json({ ok: true }));
app.get("/healthz", (_req, res) => res.status(200).json({ ok: true }));

/* --------------------------- R O U T E S ------------------------- */
app.use("/api/auth", authRoutes);

// files/profile/users/graph
app.use("/api/files", authMiddleware, filesRoutes);
app.use("/api/profile", authMiddleware, profileRoutes);
app.use("/api/users", authMiddleware, usersRoutes);
app.use("/api/connections", authMiddleware, connectionsRoutes);

// invitations/messaging
app.use("/api/invitations", authMiddleware, invitationsRoutes);
app.use("/api/conversations", authMiddleware, conversationsRoutes);
app.use("/api/messages", authMiddleware, messagesRoutes);

// stories
app.use("/api/stories", authMiddleware, storiesRoutes);

// posts + reposts
app.use("/api/posts", authMiddleware, postsRoutes);
app.use("/api/posts", authMiddleware, repostsRoutes);

// communities
app.use("/api/communities", authMiddleware, communitiesRoutes);
app.use("/api/communities", authMiddleware, communityPostsRoutes);
app.use("/api/communities", authMiddleware, communityRepostsRoutes);

// content libs
app.use("/api/books", authMiddleware, booksRoutes);
app.use("/api/podcasts", authMiddleware, podcastsRoutes);

// mentorship
app.use("/api/mentorship", authMiddleware, mentorshipRoutes);

// notifications
app.use("/api/notifications", authMiddleware, notificationsRoutes);

// reports
app.use("/api/reports", authMiddleware, reportsRoutes);

// search
app.use("/api/search", authMiddleware, searchRoutes);

// kyc
app.use("/api/kyc", authMiddleware, kycRoutes);

/* ----------------------------- 404 ------------------------------- */
app.use((req, res) => {
  res.status(404).json({ ok: false, error: "not_found" });
});

/* ------------------------- ERROR HANDLER ------------------------- */
app.use((err, _req, res, _next) => {
  console.error("Global error:", err?.stack || err);
  if (err && err.name === "CorsError") {
    return res.status(403).json({ ok: false, error: "cors_forbidden" });
  }
  return res.status(500).json({ ok: false, error: "internal_server_error" });
});

/* --------------------------- START ------------------------------- */
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});