# artifact-registry

One Docker repository for the application images, plus the IAM binding that
lets the app repository's pipeline push to it.

Exposes the repository name, the registry path images are tagged with, and the
hostname on its own for `gcloud auth configure-docker`.

Artifact Registry and not Container Registry: GCR is deprecated and shut down,
and `gcr.io` now redirects into Artifact Registry regardless. The more useful
difference is IAM. GCR's permissions were bucket ACLs covering every image in
the project, so "this pipeline may write these images and nothing else" could
not be said. Artifact Registry has IAM per repository, which is the grain this
project grants at.

## The first binding on sa-cicd

`sa-cicd` came out of bootstrap with no roles at all. That was deliberate: a
project-level `roles/artifactregistry.writer` would have covered every
repository the project will ever hold, and there was nothing else to scope it
to until this repository existed. This module is where that changes — the grant
is `roles/artifactregistry.writer`, on this repository only.

Writer rather than admin. The pipeline pushes images and pulls them back;
deleting them belongs to the cleanup policies and changing who may push belongs
in this file.

`sa-app-vm` is untouched here. It already reads project-wide from bootstrap,
which is what lets the instances pull. Narrowing that to a repository-level
`roles/artifactregistry.reader` here and dropping the project grant is a real
tightening and a known follow-up, but it is not this change: the VMs are
already running against the project-level binding, and swapping them mid-phase
would break image pulls to save a permission that grants read on repositories
that do not exist yet.

## Cleanup

The pipeline pushes one image per commit on every pull request. Nobody deletes
them by hand, so the repository needs a policy or it grows for the life of the
project.

Three rules. `keep-recent-tagged` protects the most recent
`keep_tagged_count` images whatever their age; `delete-untagged` clears the
layer sets that failed or superseded builds leave behind; `delete-old-tagged`
clears per-PR images past `tagged_retention_days`. KEEP wins over DELETE when
both match, which is what makes the delete rules safe to write broadly — the
keep rule is a floor under them, so a quiet month cannot empty the repository,
and the newest `keep_tagged_count` images are always there to roll back to.

Set `cleanup_dry_run = true` to see what a policy change would remove, in the
logs, before it removes it.
