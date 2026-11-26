#!/bin/sh
# CI entry point (Jenkinsfile; also runs locally, needs only Docker).
#   scripts/ci/test.sh matrix    the deterministic suite (scripts/ci/suite.sh, no network) on every
#                                supported Ruby with Minitest 6, plus the oldest Ruby with Minitest 5
#   scripts/ci/test.sh agentic   the model-driven example; the model comes from the env file named by
#                                CI_MODEL_ENV_FILE (E2E_MODEL_* lines, .env.example), which may also
#                                set COMPOSE_FILE + E2E_MODEL_NETWORK for a server on a docker network
# Each run uses its own compose project and removes its containers and image afterwards.
#
# Compose runs from a pinned CLI image (COMPOSE_IMAGE: compose + buildx plugins), so the build host needs only a docker
# CLI and a daemon on a unix socket (DOCKER_HOST, or /var/run/docker.sock). The socket goes into that container: on a
# rootful daemon that is root on the host, the same trust as the build itself. Run inside a container (a Jenkins agent),
# the checkout must be on one of its mounts, which is handed to the daemon by its host path.
set -eu
cd "$(dirname "$0")/../.."

COMPOSE_IMAGE=docker:28.5.2-cli
case "${DOCKER_HOST:-unix:///var/run/docker.sock}" in
  unix://*) socket=${DOCKER_HOST:-unix:///var/run/docker.sock}; socket=${socket#unix://} ;;
  *) echo "DOCKER_HOST=$DOCKER_HOST: only a unix socket can be handed to the compose container" >&2; exit 1 ;;
esac

# This container's id, from the hostname file Docker bind-mounts into it (its hostname
# may be set to anything, so `hostname` cannot name it).
container_id() {
  sed -n 's#.*/containers/\([0-9a-f]\{64\}\)/hostname .*#\1#p' /proc/self/mountinfo | head -n 1
}

# The host path of a path in this checkout (the same path unless we run inside a container): the mount with the
# longest destination that contains it, so a nested mount wins over the one around it. Prints nothing when it
# cannot tell; the callers refuse an empty answer.
host_path() {
  if [ ! -f /.dockerenv ]; then printf '%s' "$1"; return; fi
  id=$(container_id)
  [ -n "$id" ] || { echo "inside a container, but no container id in /proc/self/mountinfo" >&2; return; }
  mounts=$(docker inspect "$id" --format '{{range .Mounts}}{{.Destination}}|{{.Source}}{{"\n"}}{{end}}') ||
    { echo "docker inspect of this container ($id) failed" >&2; return; }
  printf '%s\n' "$mounts" | while IFS='|' read -r dest source; do
    [ -n "$dest" ] || continue
    case "$1/" in "$dest"/*) printf '%s|%s\n' "${#dest}" "$source${1#"$dest"}" ;; esac
  done | sort -t'|' -k1,1nr | head -n 1 | cut -d'|' -f2-
}
src=$(host_path "$PWD")
[ -n "$src" ] || { echo "$PWD: cannot find its host path (see above): cannot hand it to the Docker daemon" >&2; exit 1; }

compose() {
  docker run --rm -v "$socket:/var/run/docker.sock" -v "$src:$src" -w "$src" \
    -e TEST_RUBY_VERSION -e TEST_GEMFILE "$COMPOSE_IMAGE" docker compose "$@"
}

RUBIES="3.2 3.3 3.4 4.0"
OLDEST_RUBY=3.2
tag=$(printf '%s' "${BUILD_TAG:-local-$$}" | tr -c 'a-zA-Z0-9_-' '_' | tr 'A-Z' 'a-z')

run() { # <ruby> <gemfile> <service> [compose args...]
  ruby=$1 gemfile=$2 service=$3
  shift 3
  project="e2erb_${tag}_$(printf '%s_%s_%s' "$service" "$ruby" "$gemfile" | tr -c 'a-z0-9' '_')"
  printf '\n##### %s · Ruby %s · %s\n' "$service" "$ruby" "$gemfile"
  status=0
  export TEST_RUBY_VERSION=$ruby TEST_GEMFILE=$gemfile
  compose -p "$project" "$@" build "$service" && compose -p "$project" "$@" run --rm "$service" || status=$?
  # cleanup: the run's result is $status; a failed cleanup is reported, not hidden
  compose -p "$project" "$@" down --rmi local --remove-orphans >/dev/null 2>&1 ||
    echo "warning: removing compose project $project failed (containers/image may be left)" >&2
  return "$status"
}

case "${1:-}" in
  matrix)
    failed=""
    for ruby in $RUBIES; do run "$ruby" Gemfile test || failed="$failed ruby-$ruby/minitest6"; done
    run "$OLDEST_RUBY" gemfiles/minitest5.gemfile test || failed="$failed ruby-$OLDEST_RUBY/minitest5"
    if [ -n "$failed" ]; then echo "FAILED:$failed" >&2; exit 1; fi
    echo "matrix: all passed"
    ;;
  agentic)
    : "${CI_MODEL_ENV_FILE:?set CI_MODEL_ENV_FILE to the env file with the model settings}"
    [ -f "$CI_MODEL_ENV_FILE" ] || { echo "CI_MODEL_ENV_FILE=$CI_MODEL_ENV_FILE is not a file" >&2; exit 1; }
    case "$(cd "$(dirname "$CI_MODEL_ENV_FILE")" && pwd)/" in
      "$PWD"/*) ;;
      *) echo "CI_MODEL_ENV_FILE must be inside the checkout ($PWD): the compose container sees only that" >&2; exit 1 ;;
    esac
    env_dir=$(host_path "$(cd "$(dirname "$CI_MODEL_ENV_FILE")" && pwd)")
    [ -n "$env_dir" ] || { echo "cannot find the host path of $CI_MODEL_ENV_FILE" >&2; exit 1; }
    run "$OLDEST_RUBY" Gemfile agentic --env-file "$env_dir/$(basename "$CI_MODEL_ENV_FILE")"
    ;;
  *)
    echo "usage: scripts/ci/test.sh matrix|agentic" >&2
    exit 2
    ;;
esac
