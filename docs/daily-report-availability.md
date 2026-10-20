# Daily Report availability calendar

## Confirmed behaviour

- Ausbilder and administrators maintain the availability calendar for
  Teilnehmende. A Teilnehmende cannot create, change, or delete these records.
- The supported absence kinds are `Berufsschule`, `Urlaub`, and `Krank`.
- `Berufsschule` is a recurring rule: one or more weekdays within an inclusive
  start and end date. `Urlaub` and `Krank` are inclusive date ranges.
- A work package uses the personal calendar only when it has exactly one direct
  user assignee who is a Daily Report participant. Group assignees and
  elevated users are intentionally excluded.
- With **Working days only** selected, all three absence kinds are excluded by
  default. The person editing the work package may opt out of individual kinds
  for that work package. **All days** continues to include every calendar day.
- The Work Package **Date** picker marks personal absences with the applicable
  type in its tooltip. With **Working days only**, those dates cannot be
  selected; with **All days**, they remain selectable and are visibly marked.
- Personal absences affect duration calculations and automatic schedules. A
  manually scheduled work package keeps its explicitly chosen dates.
- An aggregated year calendar shows all Teilnehmende and their three absence
  kinds to authorized Ausbilder and administrators. It is reached from the
  existing non-working-times area rather than through a new main-navigation
  module.

## Data and security

Availability is stored separately from OpenProject's generic
`user_non_working_times`: that native feature has no kind, recurrence, or Work
Package scheduler integration. The Daily Report tables are
`daily_report_user_unavailabilities`, their append-only revisions, and
`daily_report_work_package_schedule_settings`.

Only `DailyReport::EntryPolicy#correct?` users may read or manage availability
records. The scheduler does not rely on browser input: it checks the direct
assignee and the persisted per-work-package setting for every calculation.
