# load-balancer

A global external HTTPS load balancer for the application: reserved IP, Cloud
Armor policy, backend service, URL map, certificate and proxy, plus an HTTP
forwarding rule that only redirects to HTTPS.

Exposes the IP, the URL, the Cloud Armor policy name and the backend service
name.

Its IP is the only public address in the project, and Cloud Armor is what stops
that from meaning open to the Internet: everything gets a 403 except
`allowed_source_ranges`, which has no default. The instances behind it keep no
public IP — only Google's load balancer and health check ranges reach them. The
policy sits on the backend service, so port 80, which has no backend and only
redirects, answers every source with a 301.

Without a domain the certificate is self-signed and browsers will warn; setting
`domain` switches to a managed one. The backend stays UNHEALTHY until the
instances actually run the application, so a 502 from an allowed address is the
sign that the load balancer itself works.
