# Operations: access, health, metrics, environment settings and rake tasks

## Purpose

The plugin gives operators a health report, a Prometheus metrics endpoint, a contrast report for audits, environment variables that fix the design system and the environment marker as code, and rake tasks for servers without a browser. It also defines who may open the admin page. The main code paths are `lib/open_project/thematiq/health.rb`, `lib/open_project/thematiq/metrics.rb`, `app/controllers/thematiq/metrics_controller.rb`, `lib/open_project/thematiq/store.rb`, `lib/open_project/thematiq/engine.rb` and `lib/tasks/thematiq.rake`.

## Requirements

### Requirement: Access to the admin page

The "Thematiq design" page and its actions SHALL be open to administrators and to holders of the global permission "Manage the design", which no role has until an administrator gives it; an ordinary member SHALL get none of its pages or actions.

#### Scenario: Ordinary member

- **WHEN** a member without the permission opens `/admin/thematiq`
- **THEN** access is refused

### Requirement: Health report

`GET /admin/thematiq/health` SHALL answer JSON with the version, the catalogue, the design system in use, whether the plugin's tables exist and which watched core files changed, with status 200 when there are no problems and 503 with the list of problems otherwise; `rake thematiq:health` SHALL print the same report and exit 1 when it is degraded.

#### Scenario: Missing table

- **WHEN** the migration of one of the plugin's tables has not run
- **THEN** the report lists `table_missing:<name>` and the status is 503

### Requirement: Metrics endpoint

`GET /thematiq/metrics` SHALL answer 404 unless `THEMATIQ_METRICS_TOKEN` holds at least 24 characters; with it, the endpoint SHALL answer 401 without `Authorization: Bearer <token>` and Prometheus' text format with the token, reading no session.

#### Scenario: Token not set

- **WHEN** `THEMATIQ_METRICS_TOKEN` is unset or shorter than 24 characters
- **THEN** the endpoint answers 404

#### Scenario: Right token

- **WHEN** a scraper sends the configured bearer token
- **THEN** the answer is 200 with gauges such as `thematiq_up`, `thematiq_info` and `thematiq_changes`

### Requirement: Design system as code

When `THEMATIQ_DESIGN_SYSTEM` names an existing design system, it SHALL be the design system in use and applying another one from the admin page or `rake thematiq:apply` SHALL be refused; an id that does not exist SHALL be ignored and reported by the health report as `environment_unknown`.

#### Scenario: Unknown id in the environment

- **WHEN** `THEMATIQ_DESIGN_SYSTEM` names an id that does not exist
- **THEN** the chosen design system stays in use and the health report is degraded

### Requirement: Environment marker

An administrator SHALL be able to set a label of at most 30 characters and a colour that shows at the top of every page, the sign-in page included; `THEMATIQ_ENVIRONMENT_LABEL` SHALL win over the field when it holds a valid label.

#### Scenario: Marker set

- **WHEN** the environment marker is set to "Test"
- **THEN** every page shows the label in its colour, with a text colour that reads on it

### Requirement: Contrast report

The compliance page SHALL list the contrast of every design system in use (the instance's and every project and module choice), light and dark, as HTML and as a JSON download; `rake thematiq:compliance` SHALL write the same report and exit 1 on a failing pair when `STRICT=1`.

#### Scenario: Download

- **WHEN** an administrator downloads the contrast report as JSON
- **THEN** a file named `openproject-thematiq-contrast-<date>.json` is sent

### Requirement: Rake tasks

The rake tasks `thematiq:status`, `thematiq:list` and `thematiq:apply[id]` SHALL show the design system in use and the counts, list every design system by id and name, and make a design system the one in use; a task that changes the setup SHALL leave a row in the history.

#### Scenario: Apply an unknown id

- **WHEN** `rake "thematiq:apply[nope]"` runs and no design system has that id
- **THEN** the task aborts and nothing changes
