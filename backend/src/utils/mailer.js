let transporter = null;
let attemptedLoad = false;

async function getTransporter() {
  if (transporter || attemptedLoad) return transporter;
  attemptedLoad = true;

  const { SMTP_HOST, SMTP_PORT, SMTP_SECURE, SMTP_USER, SMTP_PASS, MAILER_DISABLE } = process.env;

  // Allow disabling SMTP quickly in dev
  if (String(MAILER_DISABLE || 'false') === 'true') {
    console.warn('[mailer] MAILER_DISABLE=true; emails will be logged to console.');
    transporter = null;
    return transporter;
  }

  // If SMTP not configured, fallback to console logging
  if (!SMTP_HOST || !SMTP_PORT || !SMTP_USER || !SMTP_PASS) {
    console.warn('[mailer] SMTP not fully configured; emails will be logged to console.');
    transporter = null;
    return transporter;
  }

  try {
    const mod = await import('nodemailer');
    const nodemailer = mod.default || mod;
    transporter = nodemailer.createTransport({
      host: SMTP_HOST,
      port: Number(SMTP_PORT),
      secure: String(SMTP_SECURE || 'false') === 'true',
      auth: { user: SMTP_USER, pass: SMTP_PASS },
    });
  } catch (e) {
    console.warn('[mailer] nodemailer load failed; emails will be logged to console.', e?.message || e);
    transporter = null;
  }
  return transporter;
}

export async function sendEmail({ to, subject, text, html }) {
  const from = process.env.FROM_EMAIL || 'Nexum <no-reply@nexum.local>';
  const tx = await getTransporter();

  // Dev/log fallback
  const logDev = (extra = null) => {
    console.log('--- MAIL (DEV LOG) ---');
    if (extra) console.log('Note:', extra);
    console.log('From:   ', from);
    console.log('To:     ', to);
    console.log('Subject:', subject);
    console.log('Text:\n', text || '(no text)');
    if (html) console.log('HTML:\n', html);
    console.log('----------------------');
  };

  if (!tx) {
    logDev();
    return { ok: true, devLogged: true };
  }

  try {
    await tx.sendMail({ from, to, subject, text, html });
    return { ok: true, sent: true };
  } catch (e) {
    console.error('[mailer] send error:', e?.message || e);
    // Fallback to console log so API does NOT fail
    logDev('SMTP send failed; falling back to console log.');
    return { ok: true, devLogged: true, emailError: String(e?.message || 'send_failed') };
  }
}