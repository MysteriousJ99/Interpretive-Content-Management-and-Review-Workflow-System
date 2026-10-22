# Published-Content Retrieval API (v0.2)

Status: **implemented** in `visitor/` (Sprint 2/3, WBS 3.2.1). Tested against MariaDB with
`db/dev_test_data.sql`.
Owners: Alexander Reynolds (API, database) and Will Berry (visitor pages that call it).
Depends on: schema v3 (`db/interpretive_cms_schema_v3.sql`), view `v_published_content`.

Changes from v0: French added (decision 2026-10-14); new list endpoint for the browse page;
error bodies defined; `/v/<token>` redirect; mock mode for front-end work.

## Purpose

Lets a visitor's phone retrieve the **published** content for a building, in a chosen
language and reading level. This is the only public API. Staff editing, review and
approval happen in the admin app (`app/`), which is never public.

## Visitor flow

1. The visitor scans the building's QR code. It encodes `https://<host>/v/<token>`, where
   `<token>` is the UUID in `location_code.token`. The server redirects to
   `guided_viewing.html?token=<token>`.
2. The page calls `GET /api/v1/locations/{token}` and builds the language and reading-level
   pickers **from the `available` list** (do not hard-code options).
3. When the visitor chooses, the page calls
   `GET /api/v1/locations/{token}/content?lang=...&level=...` and renders the sections.
4. The "Learn from Home" page (`viewer.html`) calls `GET /api/v1/locations` to list buildings.

## Endpoints

All endpoints are `GET` (or `HEAD`), public (no login), same-origin, and return JSON.

### 1. List buildings

`GET /api/v1/locations`

```json
{
  "locations": [
    { "token": "6f1d2c3b-4a5e-4f60-8a7b-0c1d2e3f4a01", "location": "<Building name>" }
  ]
}
```

Only buildings with at least one published entry are listed. Sorted by name.

### 2. Building summary

`GET /api/v1/locations/{token}`

```json
{
  "location": "<Building name>",
  "available": [
    { "lang": "en", "level": "college" },
    { "lang": "en", "level": "simplified" },
    { "lang": "es", "level": "college" },
    { "lang": "es", "level": "simplified" },
    { "lang": "fr", "level": "college" },
    { "lang": "fr", "level": "simplified" }
  ]
}
```

`available` lists only language/level pairs that have published content, ordered
en, es, fr then college, simplified.

### 3. Content

`GET /api/v1/locations/{token}/content?lang={code}&level={code}`

- `lang`: `en`, `es` or `fr` (values in `language.code`)
- `level`: `college` or `simplified` (values in `audience_level.code`)

```json
{
  "location": "<Building name>",
  "language": "fr",
  "level": "college",
  "sections": [
    { "code": "building_history", "heading": "Histoire du bâtiment", "body": "..." },
    { "code": "name_history",     "heading": "Histoire du nom",      "body": "..." }
  ]
}
```

Sections are ordered by `section_order`. `body` is **plain text**; paragraphs are separated
by a blank line (`\n\n`). Render it with `textContent`, never `innerHTML`.

## Errors

| Case | Status | Body |
| --- | --- | --- |
| Unknown token, malformed token, or nothing published for it | `404` | `{"error":"not_found"}` |
| Building is published but not in that language/level | `404` | `{"error":"not_available","location":"...","available":[...]}` |
| Missing or malformed `lang` / `level` | `400` | `{"error":"bad_request","message":"..."}` |
| Any method other than GET/HEAD | `405` | `{"error":"method_not_allowed"}` + `Allow: GET, HEAD` |
| Server or database problem | `500` | `{"error":"server_error"}` (details go to the server log only) |

The API never returns `403` or says content "exists but is not published". An unknown
token and an unpublished building get the identical `404`.

Fallback decision: the API does **not** fall back to English. On `not_available`, the page
shows a message and offers the pairs in `available`.

## Security rules (Success Step 5)

- In database mode the API connects as `cms_public_api`, which has `SELECT` on
  `v_published_content` and nothing else. Drafts, in-review, approved-but-unpublished and
  archived rows are not in that view, so they are unreachable even if the API code has a bug.
- No write endpoints exist. All queries are prepared statements; `token`, `lang` and
  `level` are validated against strict patterns before use.
- Responses send `Cache-Control: no-store`, `X-Content-Type-Options: nosniff` and a
  `default-src 'none'` CSP.
- Only `visitor/public` is served. `visitor/config.php` (password) is outside it and git-ignored.

### Negative tests (WBS 3.3.2), all passing with `db/dev_test_data.sql`

| Test | Expected | Result |
| --- | --- | --- |
| Building C (only drafts, one approved-but-unpublished, one archived) by token | 404 not_found, not in list | Pass |
| Building B es/simplified (archived after publishing) | 404 not_available, not in `available` | Pass |
| Published row moved back to draft | disappears from the API immediately | Pass |
| Random valid UUID | 404 not_found | Pass |
| `lang=EN'--` / `lang[]=en` | 400 | Pass |
| POST / DELETE | 405 | Pass |
| `cms_public_api` runs `SELECT` on `location_content` | denied (error 1142) | Pass |
| Wrong DB password / missing config | 500 with no details in the response | Pass |

## Running it

See `visitor/README.md`. Short version, from the repo root:

```
C:\xampp\php\php.exe -S localhost:8081 -t visitor\public visitor\router.php
```

Mock mode (`'mode' => 'mock'` in `visitor/config.php`) serves
`visitor/mock/published_content.json` with the same tokens and text as
`db/dev_test_data.sql`, so the front end can be built without MySQL.

## Open questions

- Final hosting after Nov 15 (ask Patrick). The API needs PHP 8 + MySQL/MariaDB and HTTPS.
- Reading levels: the database has `college` and `simplified`. Will's pages used three
  levels; the pages must follow `available`.
- Optional: a 6-digit manual entry code per building for phones whose camera won't scan.
