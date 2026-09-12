# Coolify compose deploys

Docker Compose files used by the RemarkableCloud App Platform for apps that cannot be deployed from a
single Docker image (they publish UDP or raw ports, or are multi-container). Coolify clones this public
repository and deploys the compose file with `build_pack=dockercompose`; the broker injects the
environment each file references (`${...}`) and pins the web service to the instance hostname.

These are deploy manifests, not standalone quick-starts: the referenced variables are supplied by the
platform at deploy time.
