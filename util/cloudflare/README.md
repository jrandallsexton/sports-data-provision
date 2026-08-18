# Planned-maintenance Worker

One Cloudflare Worker (`maintenance-worker.js`) covers both surfaces during a
planned outage (e.g. physically relocating the cluster):

- **Web**: branded 503 maintenance page instead of Cloudflare's raw 522.
- **Mobile**: the app checks `https://status.sportdeets.com/status.json` when
  API calls fail; `maintenance: true` shows the in-app maintenance screen
  (shipped in the app since 2026-08 EAS).

## One-time setup

1. Cloudflare dashboard → Workers & Pages → Create Worker →
   name `sportdeets-maintenance`, paste `maintenance-worker.js`.
2. Settings → Variables: `MAINTENANCE=false`, `MESSAGE=...`,
   `EXPECTED_BACK_UTC=` (empty).
3. DNS: add `status` as a proxied AAAA `100::` (dummy — the Worker answers).
4. Add route `status.sportdeets.com/*` → this Worker. **Leave this attached
   permanently** (it serves `maintenance:false` in normal times).

## Starting an outage

1. Set variables: `MAINTENANCE=true`, `MESSAGE`, `EXPECTED_BACK_UTC`.
2. Attach routes to the Worker:
   - `sportdeets.com/*`
   - `www.sportdeets.com/*`
   - the API hostname `/*` (so the mobile app gets 503 JSON, not a 522).
3. (Optional, courteous) Send a pre-outage push via the notification pipeline
   BEFORE shutting down.
4. Shut down in order: drain k8s workloads → apps → PostgreSQL (data-01) →
   Mongo (data-02).

## Ending an outage

1. Power on; cloudflare-ddns re-points DNS to the new public IP within ~5 min.
2. Verify the API answers internally.
3. Detach the three outage routes (leave `status.*` attached).
4. Set `MAINTENANCE=false`.

## Notes

- 503 + `Retry-After` keeps search engines from deindexing.
- If an outage route is left attached with `MAINTENANCE=false`, the Worker
  passes through to the origin — forgetting step 3 degrades gracefully (one
  extra hop, mind the free-tier request quota).
