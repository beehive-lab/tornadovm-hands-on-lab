# Shared by the dashboard scripts (L07 tornadovm-pulse.sh, L08 tornadoviz.sh). Source it; do not run it.
# streamlit_app REPO DIR APP HINT [streamlit options]: clones REPO into DIR, installs its requirements
# in DIR/.venv (the system Python may refuse pip installs, PEP 668), and runs APP with streamlit.
# Steps already done are skipped; every command is printed before it runs.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env/versions.env"

run() { echo "\$ $*"; "$@"; }

streamlit_app() {
  local repo=$1 dir=$2 app=$3 hint=$4; shift 4
  local stamp=.venv/.requirements-installed

  if [ ! -d "$dir/.git" ]; then
    run git clone "$repo" "$dir"
  fi
  run cd "$dir"

  if [ ! -x .venv/bin/python ]; then
    run python3 -m venv .venv
  fi

  # Install again only when requirements.txt changed since the last install.
  if [ ! -f "$stamp" ] || [ requirements.txt -nt "$stamp" ]; then
    run .venv/bin/pip install -r requirements.txt
    touch "$stamp"
  fi

  echo "# $hint"
  echo "\$ .venv/bin/streamlit run $app $*"
  exec .venv/bin/streamlit run "$app" "$@"
}
