# Stage Release Apps on Fly.io

This GitHub action wraps the Fly.io CLI to automatically stage releases to [fly.io](http://fly.io) for QA review.

This action will create, deploy, and destroy Fly apps. Just set an Action Secret for `FLY_API_TOKEN`.

If you have an existing `fly.toml` in your repo, this action will copy it with a new name when deploying. By default, Fly apps will be named with the scheme `release-{tag_name}-{repo_org}-{repo_name}`.

## Inputs

| name       | description                                                                                                                                                                                                       |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`     | The name of the Fly app. Alternatively, set the env `FLY_APP`. For safety, must include the tag name. Example: `myapp-release-${{ github.event.number }}`. Defaults to `release-{number}-{repo_org}-{repo_name}`. |
| `image`    | Optional pre-existing Docker image to use                                                                                                                                                                         |
| `config`   | Optional path to a custom Fly toml config. Config path should be relative to `path` parameter, if specified.                                                                                                      |
| `region`   | Which Fly region to run the app in. Alternatively, set the env `FLY_REGION`. Defaults to `iad`.                                                                                                                   |
| `org`      | Which Fly organization to launch the app under. Alternatively, set the env `FLY_ORG`. Defaults to `personal`.                                                                                                     |
| `path`     | Path to run the `flyctl` commands from. Useful if you have an existing `fly.toml` in a subdirectory.                                                                                                              |
| `postgres` | Optional name of an existing Postgres cluster to `flyctl postgres attach` to.                                                                                                                                     |
| `update`   | Whether or not to update this Fly app when the release is updated. Default `true`.                                                                                                                                |

## Required Secrets

`FLY_API_TOKEN` - **Required**. The token to use for authentication. You can find a token by running `flyctl auth token` or going to your [user settings on fly.io](https://fly.io/user/personal_access_tokens).

## Basic Example

```yaml
name: Stage releases on Fly.io

on:
  release:
    types: [published, edited, deleted]

env:
  FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
  FLY_REGION: iad
  FLY_ORG: personal

jobs:
  staging_app:
    runs-on: ubuntu-latest

    # Only run one deployment at a time per release.
    concurrency:
      group: release-${{ github.event.number }}

    steps:
      - uses: actions/checkout@v3

      - name: Stage
        uses: projectstake/workflows/.github/workflows/release.yml@create-release-worfkflow
```

## Example with Postgres cluster

If you have an existing [Fly Postgres cluster](https://fly.io/docs/reference/postgres/) you can attach it using the `postgres` action input. `flyctl postgres attach` will be used, which automatically creates a new database in the cluster named after the Fly app and sets `DATABASE_URL`.

For production apps, it's a good idea to create a new Postgres cluster specifically for staging apps.

```yaml
# ...
steps:
  - uses: actions/checkout@v2

  - name: Deploy app
    id: deploy
    uses: projectstake/workflows/.github/workflows/release.yml@create-release-worfkflow
    with:
      postgres: myapp-postgres-staging-apps
```

## Example with multiple Fly apps

If you need to run multiple Fly apps per staging app, for example Redis, memcached, etc, just give each app a unique name. Your application code will need to be able to discover the app hostnames.

Redis example:

```yaml
steps:
  - uses: actions/checkout@v2

  - name: Deploy redis
    uses: projectstake/workflows/.github/workflows/release.yml@create-release-worfkflow
    with:
      update: false # Don't need to re-deploy redis when the PR is updated
      path: redis # Keep fly.toml in a subdirectory to avoid confusing flyctl
      image: flyio/redis:6.2.6
      name: release-${{ github.event.number }}-myapp-redis

  - name: Deploy app
    id: deploy
    uses: projectstake/workflows/.github/workflows/release.yml@create-release-worfkflow
    with:
      name: release-${{ github.event.number }}-myapp-app
```
