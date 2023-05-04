#!/bin/sh -l

set -ex

if [ -n "$INPUT_PATH" ]; then
  # Allow user to change directories in which to run Fly commands.
  cd "$INPUT_PATH" || exit
fi

TAG_NAME=$(jq -r  .release.tag_name /github/workflow/event.json | tr "." "-")
if [ -z "$TAG_NAME" ]; then
  echo "This action only supports release actions."
  exit 1
fi

REPO_NAME=$(echo $GITHUB_REPOSITORY | tr "/" "-")
EVENT_TYPE=$(jq -r .action /github/workflow/event.json)

# Default the Fly app name to release-{tag name}-{repo_name}
app="${INPUT_NAME:-release-$TAG_NAME-$REPO_NAME}"
region="${INPUT_REGION:-${FLY_REGION:-iad}}"
org="${INPUT_ORG:-${FLY_ORG:-personal}}"
image="$INPUT_IMAGE"
config="${INPUT_CONFIG:-fly.toml}"
database="${INPUT_DATABASE:-$app}"

if ! echo "$app" | grep "$TAG_NAME"; then
  echo "For safety, this action requires the app's name to contain the tag name."
  exit 1
fi

# release was deleted - remove the Fly app if one exists and exit.
if [ "$EVENT_TYPE" = "deleted" ]; then
  flyctl apps destroy "$app" -y || true
  exit 0
fi

# Deploy the Fly app, creating it first if needed.
if ! flyctl status --app "$app"; then
  # Backup the original config file since 'flyctl launch' messes up the [build.args] section
  cp "$config" "$config.bak"

  # Install elixir
  apk add elixir
  mix local.hex --force

  # Launch new app
  flyctl launch --no-deploy --copy-config --name "$app" --region "$region" --org "$org" --remote-only

  # Add app host to env secrets
  flyctl secrets set --app "$app" PHX_HOST="$app".fly.dev

  if [ -n "$INPUT_POSTGRES" ]; then
    # Attach app to postgres cluster and database.
    flyctl postgres attach --app "$app" "$INPUT_POSTGRES" --database-name "$database" --yes || true
  fi

  # Restore the original config file
  cp "$config.bak" "$config"
fi

if [ -n "$INPUT_SECRETS" ]; then
  echo $INPUT_SECRETS | tr " " "\n" | flyctl secrets import --app "$app"
fi

# Deploy app
flyctl deploy --config "$config" --app "$app" --region "$region" --image "$image" --strategy immediate

# Scale the VM
if [ -n "$INPUT_VM" ]; then
  flyctl scale --app "$app" vm "$INPUT_VM"
fi

if [ -n "$INPUT_MEMORY" ]; then
  flyctl scale --app "$app" memory "$INPUT_MEMORY"
fi

if [ -n "$INPUT_COUNT" ]; then
  flyctl scale --app "$app" count "$INPUT_COUNT"
fi

# Make some info available to the GitHub workflow.
flyctl status --app "$app" --json >status.json
hostname=$(jq -r .Hostname status.json)
appid=$(jq -r .ID status.json)
echo "hostname=$hostname" >> $GITHUB_OUTPUT
echo "url=https://$hostname" >> $GITHUB_OUTPUT
echo "id=$appid" >> $GITHUB_OUTPUT
echo "name=$app" >> $GITHUB_OUTPUT
