# cloudsql

MySQL 8 on a private IP, the `petclinic` database, and the user the application
connects as. The password is generated and written to Secret Manager; host,
port, database and user go to a second secret as JSON.

Exposes the instance and connection names, the private IP, the database and user
names, and the two secret ids. Never the password.

The private IP comes out of the PSA range the network module reserved, so this
attaches to that peering instead of creating one. Backups and binary logs are on
for point-in-time recovery, `local_infile` is off, deletion protection is on in
dev too, and `sa-app-vm` can read these two secrets and nothing else. TLS is
required but unverified — no CA reaches the client, which is the trade for a
database only reachable from inside the VPC, so clients still ask for it with
`sslMode=REQUIRED`.

Terraform generates the passwords, so they sit in state in cleartext. The
mitigation is the state itself: a CMEK-encrypted, versioned bucket that only
`sa-terraform` can read. Root gets a password nobody keeps — reset it with
`gcloud sql users set-password` if it is ever needed.

Rotate the application password by bumping `password_version`
(`db_password_version` in `envs/dev`) and applying.
