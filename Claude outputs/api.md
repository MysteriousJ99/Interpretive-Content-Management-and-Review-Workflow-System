# Published-Content Retrieval API (draft v0)

Status: draft for Sprint 1 review. Not yet implemented (build is Sprint 3, WBS 3.2.1).
Owner: Will Berry (Development Technical Lead) with Alexander Reynolds.
Depends on: `db/schema.sql` (v1), view `v_published_content`.

## Purpose

Lets a visitor's phone retrieve the **published** content for one building, in a chosen
language and reading level, after scanning that building's QR code. This is the only
public API. Staff editing, review and approval are normal framework pages and are not
part of this API.

## Visitor flow

1. Visitor scans the QR code. It encodes `https://<host>/v/<token>`, where `<token>` is the
   UUID in `location_code.token`.
2. The phone page calls `GET /api/v1/locations/{token}` to learn which languages and
   reading levels are available, and shows the pickers.
3. When the visitor chooses, the page calls
   `GET /api/v1/locations/{token}/content?lang=...&level=...` and renders the sections.

## Endpoints

All endpoints are `GET`, public (no login), and return JSON.

### 1. Location summary

`GET /api/v1/locations/{token}`

```json
{
  "location": "<Building name>",
  "available": [
    { "lang": "en", "level": "college" },
    { "lang": "en", "level": "simplified" },
    { "lang": "es", "level": "college" },
    { "lang": "es", "level": "simplified" }
  ]
}
```

`available` lists only language/level pairs that have published content.

### 2. Content

`GET /api/v1/locations/{token}/content?lang={code}&level={code}`

- `lang`: `en` or `es` (values in `language.code`)
- `level`: `college` or `simplified` (values in `audience_level.code`)

```json
{
  "location": "<Building name>",
  "language": "en",
  "level": "college",
  "sections": [
    { "code": "building_history", "heading": "History of the building", "body": "..." },
    { "code": "name_history",     "heading": "History of the name",     "body": "..." }
  ]
}
```

Sections are ordered by `section_order`.

## Query behind endpoint 2

```sql
SELECT section_code, heading, body
FROM v_published_content
WHERE token = ? AND language_code = ? AND audience_code = ?
ORDER BY section_order;
```

Always use prepared statements. Never build SQL from request values.

## Errors

| Case | Response |
| --- | --- |
| Unknown token | `404` |
| No published content for that language/level | `404`, body lists the `available` pairs |
| Missing or invalid `lang` / `level` | `400` |
| Any non-GET method | `405` |

Do not return `403` or any message that says content "exists but is not published".
That would reveal unpublished content.

## Security rules (Success Step 5)

- The API connects to MySQL as `cms_public_api`, which has `SELECT` on `v_published_content`
  and nothing else. Drafts, in-review, approved-but-unpublished and archived rows are not
  in that view, so they are unreachable even if the API code has a bug.
- No write endpoints exist.
- Negative tests (WBS 3.3.2) must confirm that unapproved or archived content cannot be
  retrieved, by token or by guessing ids.

## Open questions

- Which framework/language (affects routing and how `cms_public_api` credentials are stored).
- Fallback behavior: if a visitor requests a language/level that is not published, return
  `404` (current plan) or fall back to English/college?
- Response caching: not needed for the demo.
- Phone page hosting: same app, or a separate minimal static client (WBS 3.2.2)?
