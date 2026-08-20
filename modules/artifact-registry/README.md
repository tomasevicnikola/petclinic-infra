# artifact-registry

One Docker repository for the application images in `europe-west3`, with
cleanup policies and the IAM binding the app pipeline pushes with.

Exposes the repository name, the registry path images are tagged with, and the
hostname on its own for `gcloud auth configure-docker`.

Artifact Registry and not Container Registry: GCR is shut down and `gcr.io`
redirects here anyway. It also grants per repository, where GCR's permissions
were bucket ACLs covering every image in the project.

`sa-cicd` gets `roles/artifactregistry.writer` on this repository and nothing
else. It is its first binding — bootstrap left it with no roles until there was
a resource to scope one to. `sa-app-vm` still reads project-wide from
bootstrap; narrowing that to this repository is a follow-up, not this change.

Three cleanup rules. `keep-recent-versions` protects the newest
`keep_recent_count` versions at any age, `delete-untagged` and
`delete-old-tagged` clear the rest. KEEP wins over DELETE, so the keep rule is
a floor under the other two. It is not tag-aware, so untagged versions take
slots and rollback depth is at most `keep_recent_count`.
