set -euo pipefail

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
    if [[ -f "chart-info.yaml" ]]; then
      yq '.chartRepos[] | [.name, .url] | join(" ")' chart-info.yaml | xargs -I {} sh -c "helm repo add {}"
    fi
    # TODO - error checking for incomplete chart-info

    popd > /dev/null
  } >"out/$1.out" 2>"out/$1.err"
}

process () {
  echo "Processing $1"
  # https://stackoverflow.com/a/315113/1040915
  {
    pushd "$1" > /dev/null
    dir_name=$(basename $1)
    if [[ ! -f "chart-info.yaml" ]]; then
      args="$dir_name $dir_name helm/"
    else
      args=$(yq "[.namespace // \"$dir_name\", .chartName // \"$dir_name\", .chartReference // \"helm/\"] | join(\" \")" chart-info.yaml)
    fi

    if [[ -f "values.yaml" ]]; then
      args+=" --values values.yaml"
    fi

    if ! eval "helm upgrade --install --create-namespace -n $args"; then
      # The following line will print to (actual) stdout, even though (regular)
      # stdout is being captured into `out/$1.out` (see end of braced-expression)
      >&3 echo "=== ERROR while processing $1 - check the logs! ==="
    fi
    popd > /dev/null
  } 3>&1 >"out/$1.out" 2>"out/$1.err"
}
# https://unix.stackexchange.com/a/50695/30828
export -f addRepo
export -f process

if [[ -d "out" ]]; then
  rm -rf out-old/
  mv out/ out-old/
fi
mkdir -p out/

while getopts n:a flag
do
  case "${flag}" in
    n) name=${OPTARG};;
    a) all=1;;
    *) echo "Unknown flag detected"; exit 1;;
  esac
done

if [ -n "${name+x}" ] && [ -n "${all+x}" ]; then
  echo "You cannot set both -n and -a. Try again";
  exit 1
fi

if [ -z ${name+x} ] && [ -z ${all+x} ]; then
  echo "You must set one of -n [name] or -a.";
  exit 1
fi

if [ -n "${name+x}" ]; then
  names="./$name"
fi
if [ -n "${all+x}" ]; then
  names=$(find . -type d -depth 1 -not -name 'out' -not -name 'out-old' | tr '\n' ':')
fi

IFS=':' read -ra ARR <<< "$names"
for dir in "${ARR[@]}"; do
  addRepo "$dir"
done

helm repo update

IFS=':' read -ra ARR <<< "$names"
for dir in "${ARR[@]}"; do
  process "$dir"
done
