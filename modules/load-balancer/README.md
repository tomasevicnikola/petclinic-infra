# load-balancer

A global external HTTPS load balancer for the application: reserved IP, backend
service behind Identity-Aware Proxy, URL map, certificate and proxy, plus an
HTTP forwarding rule that only redirects to HTTPS.

Exposes the IP, the URL and the backend service name.

Its IP is the only public address in the project, and IAP is what stops that
from meaning open to the Internet: a request has to carry a Google identity
listed in `allowed_members`, which has no default, and anyone else is turned
away before reaching a backend. The instances behind it keep no public IP —
only Google's load balancer and health check ranges reach them, and health
checks bypass IAP. Port 80 has no backend and only redirects, so it answers
every source with a 301.

IAP needs an OAuth consent screen configured once in the console; without it
enabling IAP fails. Without a domain the certificate is self-signed and browsers
will warn; setting `domain` switches to a managed one. The backend stays
UNHEALTHY until the instances actually run the application, so a 502 after
signing in is the sign that the load balancer itself works.

## Deploy pipeline access

`sa-ops-vm` is on `allowed_members` via the `LB_ALLOWED_MEMBERS` repository
variable — the list is not in this repo, so `gh variable get LB_ALLOWED_MEMBERS`
is the only way to read it. The grant is `roles/iap.httpsResourceAccessor` on
this backend service only.

That grant is necessary but not sufficient. IAP here uses the Google-managed
OAuth client, which rejects a service-account ID token whatever audience it
carries — `Invalid JWT audience`, tested against the resource path, the URL and
the self link. Programmatic access needs a custom OAuth client, and the IAP
OAuth Admin API that created those was shut down in March 2026.

So the deploy workflow's load balancer check warns instead of failing, and that
is permanent rather than a TODO. Per-instance checks against each internal IP
are what actually verify a release; the load balancer is verified by signing in
as a human.
