# Home training dashboard

The native OpenProject home page includes a training overview for active
administrators and users with the global `manage_daily_report_entries`
permission (the existing Ausbilder capability). Ordinary users and anonymous
visitors neither render nor query these widgets.

The widgets use the existing home page grid, Primer components and English
and German translations. Data is read directly from the existing PostgreSQL
models under the current user's authorization.

## Calculations

- Work packages must be visible to the current user and belong to active
  projects. All counts and lists use the same scope.
- **Configure task types** on the dashboard opens a dedicated native settings
  page available to both Ausbilder and Admin. Administration → Work packages →
  General also links to this page. No other administration settings are exposed
  to Ausbilder.
- The shared `training_dashboard_task_type_ids` setting stores selected type IDs
  in the native settings table. On first use it selects existing types named
  `Aufgabe` and `Project` and persists their IDs. Subsequent renames preserve the
  selection. All types, including milestones, appear dynamically in the form;
  new types are unchecked. Clearing every checkbox is a valid empty selection.
- All widgets use the selected types, including parent work packages and
  milestones when their types are selected. `Project` can be deselected.
  The previous exclusion setting is superseded by this explicit selection.
- The task count includes open and closed tasks. Average progress is the rounded
  arithmetic mean of known percentages, respecting OpenProject's field-based or
  status-based progress setting. Unknown progress is displayed as an em dash.
- The upcoming metric includes open tasks due today through seven calendar days
  from today, inclusive. Overdue means an open status and a finish date strictly
  before today. Closed tasks and undated tasks never generate warnings.
- Warnings contain one row per visible participant with directly assigned overdue
  tasks. SQL groups by assignee and selects the earliest finish date. Rows show
  that date and the calendar-day difference from today, oldest first. There is
  no per-work-package row and no eight-row cutoff.
- Clicking a warning row opens the native work package table with the participant's
  internal assignee ID, selected type IDs, open status and finish date filters.
  OpenProject 17.9.4 implements `more than days ago` with an inclusive upper bound:
  `0` includes today. As agreed, the native overdue query uses `1` to exclude today
  and match the dashboard exactly, without changing OpenProject's date operators.
- When overdue items exist, the widget footer links to the native global work
  package table. Its query shows every visible open overdue selected-type work
  package, including unassigned tasks, ordered by finish date.
  The table applies native OpenProject visibility again and has no widget limit.
- Participants are active, visible, non-admin users with a non-empty `Lehrjahr`
  user custom field. The field is resolved by name, without hard-coded field IDs,
  and must itself be visible to the viewer. A missing or restricted field has an
  explicit empty state.
- A participant without tasks has no directly assigned open selected-type work
  package visible to the viewer. Having only closed tasks or unselected types
  still puts them in this list. Group assignments do not count as direct
  assignments, matching the requested native Assignee filter. Each participant
  appears once. Their link applies only Assignee, so the resulting history also
  includes closed tasks and unselected types.
- Availability checks use SQL subqueries and deadlines use a grouped SQL join.
  Names and dates do not trigger per-participant queries. The interface states
  the visibility boundary; it makes no assertion about assignments in hidden
  projects. No idle-duration history is created.

## Verification

Run the focused query and request tests in the test backend:

```sh
docker compose exec -T backend-test bundle exec rspec \
  spec/queries/homescreen/training_dashboard_query_spec.rb \
  spec/requests/homescreen/training_dashboard_spec.rb \
  spec/requests/homescreen/training_dashboard_settings_spec.rb \
  spec/models/setting_spec.rb
```

These tests require the test database and Rails backend, without a frontend
build or browser container. They cover global access, native visibility,
direct assignments, deadlines, progress, missing fields and translated home-page
rendering. Settings tests also cover persistence, renames, empty selections,
new types, invalid IDs and refusal of unauthorized changes. The native settings
model regression verifies that array defaults are serialized only once.

`spec/features/homescreen/training_dashboard_spec.rb` additionally exercises
an Ausbilder changing selected types, availability changes, and actual work
package table results after both participant links and the all-overdue link.
