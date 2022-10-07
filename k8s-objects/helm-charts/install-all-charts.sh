set -euxo pipefail

# Stolen from Docker - https://get.docker.com/
command_exists() {
  command -v "$@" > /dev/null 2>&1
}

if ! command_exists yq; then
  echo "This script relies on yq. Install with 'brew install yq' (assuming you're on Mac)"
  exit 1
fi

addRepo() {
  echo "Adding repo for $1"
  # https://stackoverflow.com/a/315113/1040915
  {
    pushd "$1" > /dev/null
    if [[ ! -f "chart-info.yaml" ]]; then
      echo "Missing required file 'chart-info.yaml"
      exit 1
    fi
    # TODO - error checking for incomplete chart-info

    yq '.chartRepos[] | [.name, .url] | join(" ")' chart-info.yaml | xargs -I {} sh -c "helm repo add {}"
    popd > /dev/null
  } >"out/$1.out" 2>"out/$1.err"
}

process () {
  echo "Processing $1"
  # https://stackoverflow.com/a/315113/1040915
  {
    pushd "$1" > /dev/null
    if [[ ! -f "chart-info.yaml" ]]; then
      echo "Missing required file 'chart-info.yaml"
      exit 1
    fi
    # TODO - error checking for incomplete chart-info

    args=$(yq '[.namespace, .chartName, .chartReference] | join(" ")' chart-info.yaml)
    if [[ -f "values.yaml" ]]; then
      args+=" --values values.yaml"
    fi
    eval "helm upgrade --install --create-namespace -n $args"
    popd > /dev/null
  } >"out/$1.out" 2>"out/$1.err"
}
# https://unix.stackexchange.com/a/50695/30828
export -f addRepo
export -f process

if [[ -d "out" ]]; then
  rm -rf out-old/
  mv out/ out-old/
fi
mkdir -p out/

find . -type d -depth 1 -not -name 'out' -exec bash -c 'set -euxo pipefail; addRepo "$@"' bash {} \;
helm repo update
find . -type d -depth 1 -not -name 'out' -exec bash -c 'set -euxo pipefail; process "$@"' bash {} \;