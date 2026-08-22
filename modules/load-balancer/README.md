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

## Custom OAuth client

IAP uses a custom OAuth client, not the Google-managed one. The managed client
admits only identities internal to the organization, so an account from outside
it signs in and is then refused whatever IAM says, and service accounts get no
programmatic access at all. The client is created by hand in the console;
`iap_oauth_client_id` is committed and the secret arrives as
`TF_VAR_iap_oauth_client_secret`.

The consent screen is External and stays in Testing, which caps it at 100 test
users. An account has to be on that test user list *and* in `allowed_members` —
missing from either one gives a 403.

`oauth2_client_secret` is not a write-only argument, so unlike the other secrets
in this repository it is persisted in the state file.
