// e2e_rb CI. Two GitHub commit statuses, each linked to this build; a pull request is built at its head commit, so they
// land on the sha the PR shows:
//   jenkins/ci       the gate: `scripts/ci/test.sh matrix` — the deterministic Docker suite (unit specs, the browser
//                    examples in RSpec + Minitest with no network and no model, parallel worker processes, the gem built
//                    and installed) on every supported Ruby. Needs nothing outside the build host.
//   jenkins/agentic  `scripts/ci/test.sh agentic` — agent steps against a real model, reported on its own so a model
//                    outage or a model's bad answer never decides the gate. The model settings are the folder-scoped
//                    Secret Text credential `e2e-rb-model-env` (E2E_MODEL_* lines, .env.example).
//
// Jenkins side (a JCasC job fragment on the controller, not in this repo): a multibranch job reading this file from SCM,
// this repository's own branches and pull requests only (never a fork's), nodes labelled `e2e-rb-ci` with a Docker CLI
// (the label is the interface: the deployment's nodes file decides which hosts carry it), and the folder-scoped
// Secret Text credential `github-pat` (a token allowed to post statuses on this repo). The repo the status goes to is
// read from the checkout's origin remote: nothing about the deployment is written here.
//
// The token never reaches a command line: curl reads the Authorization header from stdin (-H @-), so /proc/*/cmdline
// shows no secret. Credential variables are referenced from single-quoted shell only, never Groovy-interpolated.

pipeline {
  agent { label 'e2e-rb-ci' }

  options {
    timestamps()
    timeout(time: 60, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  stages {
    stage('Checkout') {
      steps {
        script {
          if (env.CHANGE_FORK) {
            error("pull request ${env.CHANGE_ID} from fork ${env.CHANGE_FORK} refused: a fork's code never runs on this Jenkins")
          }
        }
        checkout scm
        script {
          env.GIT_SHA = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
          env.GH_REPO = sh(returnStdout: true, script: '''
            url=$(git config --get remote.origin.url)
            repo=$(printf '%s' "$url" | sed -nE 's#^(https://|git@|ssh://git@)github\\.com[:/]([^/]+/[^/]+)$#\\2#p' | sed 's#\\.git$##')
            [ -n "$repo" ] || { echo "origin $url is not a GitHub repo: nowhere to post the status" >&2; exit 1; }
            printf '%s' "$repo"
          ''').trim()
          echo "Building ${env.GH_REPO}@${env.GIT_SHA}"
        }
        notifyGitHub('jenkins/ci', 'pending', 'Docker suite running')
      }
    }

    stage('Gates') {
      steps { sh 'scripts/ci/test.sh matrix' }
      post {
        success { notifyGitHub('jenkins/ci', 'success', 'Docker suite passed on every Ruby') }
        failure { notifyGitHub('jenkins/ci', 'failure', 'Docker suite failed: see the build log') }
        aborted { notifyGitHub('jenkins/ci', 'error', 'Build aborted') }
      }
    }

    stage('Agentic') {
      steps {
        notifyGitHub('jenkins/agentic', 'pending', 'agent steps against the model running')
        catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
          // Secret Text → a file in the workspace (the compose container sees only the checkout), removed after.
          withCredentials([string(credentialsId: 'e2e-rb-model-env', variable: 'MODEL_ENV')]) {
            sh '''
              set +x  # the model settings are never echoed into the build log
              f=.ci-model.env
              umask 077
              printf '%s\\n' "$MODEL_ENV" > "$f"
              status=0
              CI_MODEL_ENV_FILE="$PWD/$f" scripts/ci/test.sh agentic || status=$?
              rm -f "$f"
              exit "$status"
            '''
          }
        }
      }
      post {
        success { notifyGitHub('jenkins/agentic', 'success', 'agent steps passed') }
        failure { notifyGitHub('jenkins/agentic', 'failure', 'agent steps failed: see the build log') }
        aborted { notifyGitHub('jenkins/agentic', 'error', 'Build aborted') }
      }
    }
  }

  post {
    cleanup { cleanWs() }
  }
}

void notifyGitHub(String context, String state, String description) {
  if (!env.GIT_SHA || !env.GH_REPO) { error("no commit/repo known yet: cannot post GitHub status ${context}=${state}") }
  withCredentials([string(credentialsId: 'github-pat', variable: 'GH_TOKEN')]) {
    writeFile file: '.github-status.json', text: groovy.json.JsonOutput.toJson([
      state: state, target_url: env.BUILD_URL, description: description, context: context
    ])
    def code = sh(returnStdout: true, script: '''
      set +x
      printf 'Authorization: Bearer %s\\n' "$GH_TOKEN" | curl -sS -o /dev/null -w '%{http_code}' -X POST \
        -H @- -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
        --data @.github-status.json "https://api.github.com/repos/$GH_REPO/statuses/$GIT_SHA"
      rm -f .github-status.json
    ''').trim()
    if (code != '201') { error("GitHub refused status ${context}=${state} for ${env.GH_REPO}@${env.GIT_SHA} (HTTP ${code}): check credential github-pat") }
    echo "GitHub status ${context}=${state} posted for ${env.GIT_SHA.take(8)}"
  }
}
