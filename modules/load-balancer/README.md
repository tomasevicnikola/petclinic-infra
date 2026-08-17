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
