# Troubleshooting

How to find out why a software template, the catalog or TechDocs is not doing what you expect, and
fixes for the problems that have come up in this lab.

## Where to look first

Work through these in order. Most problems are found in the first two.

| # | Where | What it tells you |
|---|---|---|
| 1 | **The task page** (opens when you click **Create**) | Which step failed, and that step's log. Click the step name to expand it. |
| 2 | **The backend terminal** (`yarn start`) | The full error, including GitHub API responses. Look for `error` or `warn` lines at the time of the run. |
| 3 | **Task list**: `/create/tasks` | Every past run, with its logs. Useful when the task page was closed. |
| 4 | **Installed actions**: `/create/actions` | Every action this Backstage has, with its exact inputs and outputs. Check here before using a new input. |
| 5 | **Template editor**: `/create/edit` | Load a template and run it as a **dry run**: it shows the files it would create and the step logs, without creating a repository. |

Tasks 3 to 5 are also in the **⋮** menu on the **Create** page.

### Print values in the middle of a template

When a value looks wrong in the generated files, add a `debug:log` step to see what the template
actually received. Put it before the step you are checking, and remove it afterwards:

```yaml
    - id: debug
      name: Show the values
      action: debug:log
      input:
        message: |
          name=${{ parameters.name }}
          repoUrl=${{ parameters.repoUrl }}
          owner=${{ (parameters.repoUrl | parseRepoUrl).owner }}
```

The output appears in the task log for that step.

## The template

### The template does not appear on the Create page

| Cause | Check | Fix |
|---|---|---|
| The catalog has not read the new version yet | Wait 1 to 2 minutes after pushing | Open the template in the catalog and click the **refresh** icon in the About card |
| The location rule does not allow templates | `app-config.yaml` location for this repo | It needs `rules: - allow: [Location, Template]` (plus `Component` for these docs) |
| The template is not listed in the root `catalog-info.yaml` | `spec.targets` in the Location file | Add `./<folder>/template.yaml` |
| A YAML error in `template.yaml` | Backend terminal: errors mentioning the file's URL | Fix indentation; every list item at one level must start at the same column |

### "repo not provided" in the repository picker

The **RepoUrlPicker** only saves the value when the field loses focus. Type the repository name, then
click outside the field before pressing **Next**.

### Values are empty or wrong in the generated files

- A skeleton file can only use values passed under `fetch:template` → `input.values`. A form field
  that is not in that list is empty in the files, even though the form asked for it.
- In the skeleton, use `${{ values.name }}`. In `template.yaml`, use `${{ parameters.name }}`.
- Step outputs use the step id: `${{ steps['publish'].output.remoteUrl }}`. Use camelCase ids
  (`fetchSkeleton`), because dashes in ids need the `['...']` form.

### A GitHub Actions workflow in the skeleton breaks

GitHub workflows use `${{ ... }}` too, and `fetch:template` tries to fill those in. Wrap GitHub
expressions so the template leaves them alone:

```yaml
{% raw %}
      - run: echo "Branch is ${{ github.ref_name }}"
{% endraw %}
```

### Files end up in the wrong folder

The skeleton is copied as it is: a file at `skeleton/terraform/network/known-ranges.txt` is created
at `terraform/network/known-ranges.txt`. Check the template repository with:

```bash
git ls-files platform-service
```

Move a file with `git mv old/path new/path`, commit and push.

### The editor says "missing property Resources"

The editor's YAML extension guesses that a file named `template.yaml` is an AWS CloudFormation
template. Backstage is not affected. To use the Backstage schema instead, make this the first line:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/backstage/backstage/master/plugins/scaffolder-common/src/Template.v1beta3.schema.json
```

## GitHub

### 403: "Resource not accessible by personal access token"

The token is missing a permission. The backend log shows the GitHub URL that failed, which tells you
which one:

| Failing request contains | Permission needed |
|---|---|
| `/orgs/<org>/repos` (creating the repo) | Repository creation: Read and write (organization) |
| `/git/` or `/contents/` | Contents: Read and write |
| `/commits/<branch>/status` | Commit statuses: Read-only |
| `/branches/<branch>/protection` | Administration: Read and write |
| `/properties/values` | Custom properties: Read and write |
| `.github/workflows/` files | Workflows: Read and write |

Edit the token at **github.com/settings/personal-access-tokens**. The token value does not change, so
the env file stays the same. If the organization requires approval, approve the change under the
organization's **Settings → Personal access tokens → Pending requests**.

### 422: "name already exists on this account"

A repository with that name exists already, often from an earlier test run. Choose another name, or
delete the old repository (its **Settings → Delete this repository**).

### The required check never runs ("Expected — waiting for status to be reported")

The name in `requiredStatusCheckContexts` must match the **job name** in the workflow exactly,
including capitals and brackets: `Network (VPC overlaps)`. If they differ, GitHub waits for a check
that never arrives.

### Custom properties are not set

- The property must exist in the organization first (**Settings → Custom properties**).
- The value must be one of the property's options. The form uses an `enum` with the same list so the
  two cannot disagree.
- The token needs the Custom properties permission (see the 403 table).
- An "unknown input" error means the installed GitHub module is older than the `customProperties`
  input. Check `/create/actions` → `publish:github`.

## The catalog

### A component disappears after restarting Backstage

The local database is in memory (`connection: ':memory:'`), so anything added by `catalog:register`
or **Register Existing Component** is lost on restart. Repositories in the organization come back
through **GitHub discovery** (`catalog.providers.github`), which runs at start-up and every 30
minutes. The permanent fix is PostgreSQL.

### A repository is not found by discovery

- Its `catalog-info.yaml` must be at the repository root on `main`.
- Its name must match the `repository` filter. `backstage-templates` is excluded on purpose, because
  it is loaded through its own location.
- Discovery only scans `jk-platform-lab`. Repositories in a personal account need a `locations`
  entry.

### "Conflict" warnings in the backend log

The same entity is loaded from two places, for example a `locations` entry and discovery, or the
template's `catalog:register` step and discovery. The first one wins and the warning is harmless,
but keep each repository loaded from one place where possible.

## TechDocs

| Symptom | Cause | Fix |
|---|---|---|
| Red **AbortError** overlay when opening docs | The search box cancels a request while the page loads. Development mode shows every uncaught error | Press **Esc**. Production builds do not show it |
| Docs tab says the entity is not found (404) | The component is no longer in the catalog | See "A component disappears after restarting" |
| Spinner for a while on the first visit | The docs are being built with mkdocs | Wait 10 to 20 seconds |
| Build error mentioning `mkdocs` | mkdocs is not installed in the container (it is lost when the container is recreated) | `pip3 install --break-system-packages mkdocs-techdocs-core` |
| Build error about the nav | A page in `mkdocs.yml` `nav` does not exist under `docs/` | Fix the file name or the nav entry |

## Other messages that can be ignored

| Message | Why |
|---|---|
| `JWKSNoMatchingKey` warning after a restart | The browser still has a login cookie from before the restart. It renews itself; refresh the page |
| infradoctor exit code **2** | Not a finding: infradoctor could not run, usually a missing file (`[Errno 2]`). Exit code **1** means it ran and found a problem |

## Restarting Backstage

In the container:

```bash
cd /app/backstage-udemy
set -a
source /app/github-auth.env
set +a
yarn start
```

From a new terminal on the Mac, enter the container first with `docker exec -it backstage bash`.
Template changes do not need a restart; new backend modules and `app-config` changes do.