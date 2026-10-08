# Daily Report external read API

The first external integration endpoint is read-only and scoped to one Work Package:

```http
GET /work_packages/{work_package_id}/daily_report_entries.json
Accept: application/json
X-OpenProject-API-Key: <api-token>
```

Example:

```bash
curl --fail \
  --header "Accept: application/json" \
  --header "X-OpenProject-API-Key: $OPENPROJECT_API_TOKEN" \
  "https://openproject.example/work_packages/75/daily_report_entries.json"
```

The response is a JSON array. Every item contains the report fields, author, Work Package and project identity, lock version, update timestamp and capability flags.

Authorization is identical to the UI:

- a participant only receives their own entries;
- an Ausbilder/Admin with the Daily Report management permission receives all entries for a Work Package they can view;
- an invisible Work Package is returned as not found;
- deleted entries are excluded.

Only `GET index` accepts API-key authentication. External create, update, delete and restore operations are intentionally not exposed.

Create an API token in the OpenProject account settings. Send it in the `X-OpenProject-API-Key` header. Do not put tokens in URLs, logs or source control.
