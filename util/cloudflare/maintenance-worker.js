/**
 * sportDeets planned-maintenance Worker.
 *
 * ONE worker, two personalities, driven by env vars (see wrangler/README):
 *
 *   1. status.sportdeets.com/*  (route ALWAYS on)
 *      Returns status JSON. The mobile app checks this URL when API calls
 *      fail to distinguish "planned maintenance" from "something broke".
 *      Normal times: { maintenance: false }. Costs ~nothing — only hit on
 *      failures and during outages.
 *
 *   2. sportdeets.com/* and api hostname routes (added ONLY during an outage)
 *      Browser requests (Accept: text/html) get a branded 503 maintenance
 *      page; everything else (the mobile app's API calls) gets 503 JSON with
 *      the maintenance payload. Retry-After keeps crawlers from deindexing.
 *
 * Env vars (set in the Cloudflare dashboard; editing them redeploys instantly):
 *   MAINTENANCE       "true" | "false"
 *   MESSAGE           e.g. "We're moving some hardware to its new home."
 *   EXPECTED_BACK_UTC e.g. "2026-08-20T02:00:00Z" (optional)
 *
 * Runbook: util/cloudflare/README.md
 */

export default {
  async fetch(request, env) {
    const maintenance = (env.MAINTENANCE ?? 'false') === 'true';
    const message =
      env.MESSAGE ?? "We're doing some planned maintenance. Back soon.";
    const expectedBackUtc = env.EXPECTED_BACK_UTC || null;

    const url = new URL(request.url);
    const isStatusHost =
      url.hostname.startsWith('status.') || url.pathname === '/status.json';

    const statusBody = JSON.stringify({
      maintenance,
      message,
      expectedBackUtc,
    });

    // Personality 1: the always-on status endpoint.
    if (isStatusHost) {
      return new Response(statusBody, {
        status: 200,
        headers: {
          'content-type': 'application/json',
          'cache-control': 'no-store',
          // The app fetches this cross-origin from a webview-less client, but
          // the web app might too someday — permissive CORS is safe for a
          // public status document.
          'access-control-allow-origin': '*',
        },
      });
    }

    // Personality 2: only reachable when the outage routes are attached.
    // If someone leaves a route attached with MAINTENANCE=false, pass
    // through to the origin so nothing breaks.
    if (!maintenance) {
      return fetch(request);
    }

    const wantsHtml = (request.headers.get('accept') ?? '').includes('text/html');

    if (!wantsHtml) {
      return new Response(statusBody, {
        status: 503,
        headers: {
          'content-type': 'application/json',
          'retry-after': '3600',
          'cache-control': 'no-store',
        },
      });
    }

    const eta = expectedBackUtc
      ? new Date(expectedBackUtc).toLocaleString('en-US', {
          timeZone: 'America/Chicago',
          month: 'short',
          day: 'numeric',
          hour: 'numeric',
          minute: '2-digit',
          timeZoneName: 'short',
        })
      : null;

    const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>sportDeets — scheduled maintenance</title>
<style>
  body { margin:0; font-family:-apple-system,Segoe UI,Roboto,sans-serif;
         background:#111; color:#f8f9fa; display:flex; min-height:100vh;
         align-items:center; justify-content:center; text-align:center; }
  .card { max-width:28rem; padding:2rem; }
  h1 { font-size:1.5rem; margin-bottom:.5rem; }
  p { color:#adb5bd; line-height:1.5; }
  .eta { color:#0077cc; font-weight:700; }
</style>
</head>
<body>
  <div class="card">
    <h1>🏈 Be right back</h1>
    <p>${message}</p>
    ${eta ? `<p>Expected back around <span class="eta">${eta}</span>.</p>` : ''}
    <p>Thanks for your patience — see you at kickoff.</p>
  </div>
</body>
</html>`;

    return new Response(html, {
      status: 503,
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'retry-after': '3600',
        'cache-control': 'no-store',
      },
    });
  },
};
