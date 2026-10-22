# Visitor site + public API

The public side of the system: Will's visitor pages (in `visitor/public`) and the
read-only JSON API they call (`docs/api.md`). It is separate from the staff admin app in
`app/` on purpose: nothing here can change data, and visitors can never reach admin code.

```
visitor/
├─ public/              the ONLY folder a web server should serve
│  ├─ *.html, *.css, *.js   Will's pages
│  ├─ api.php           API front controller (/api/v1/...)
│  └─ .htaccess         routes for Apache
├─ src/public_api.php   API code
├─ mock/                mock data (same as db/dev_test_data.sql)
├─ router.php           routes for PHP's built-in server
├─ config.sample.php    copy to config.php (git-ignored)
└─ README.md
```

## Option A: front-end work only, no MySQL (mock mode)

Needs only PHP (XAMPP's is fine). From the repo root in Command Prompt:

```
copy visitor\config.sample.php visitor\config.php
```

Open `visitor\config.php` and set `'mode' => 'mock'`. Then:

```
C:\xampp\php\php.exe -S localhost:8081 -t visitor\public visitor\router.php
```

Open http://localhost:8081/api/v1/locations to check it works. Stop with Ctrl+C.

## Option B: real database

1. Database at schema v3 (French). Start MySQL in XAMPP first.
   - Existing v2 database: `C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 < db\migrate_v2_to_v3.sql`
   - New database: `C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 < db\interpretive_cms_schema_v3.sql`
2. Create the API's database account (pick your own password; run once):
   ```
   C:\xampp\mysql\bin\mysql.exe -u root
   CREATE USER 'cms_public_api'@'localhost' IDENTIFIED BY 'your-password';
   GRANT SELECT ON interpretive_cms.v_published_content TO 'cms_public_api'@'localhost';
   SHOW GRANTS FOR 'cms_public_api'@'localhost';
   exit
   ```
   `SHOW GRANTS` must list only `USAGE` and `SELECT ON interpretive_cms.v_published_content`.
   (If a GRANT silently doesn't stick, see the mariadb.sys note in the handoff doc.)
3. Optional test data (dev databases only; adds three `[TEST]` buildings):
   `C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 < db\dev_test_data.sql`
4. `copy visitor\config.sample.php visitor\config.php`, keep `'mode' => 'database'`, and set
   `'pass'` to the password from step 2.
5. Start it:
   `C:\xampp\php\php.exe -S localhost:8081 -t visitor\public visitor\router.php`

The admin app keeps running separately on port 8080. Both can run at the same time.

## Test tokens (mock mode and dev_test_data.sql)

| Building | Token | What the API should do |
| --- | --- | --- |
| [TEST] Building A | `6f1d2c3b-4a5e-4f60-8a7b-0c1d2e3f4a01` | All 6 language/level pairs |
| [TEST] Building B | `6f1d2c3b-4a5e-4f60-8a7b-0c1d2e3f4a02` | 5 pairs; es/simplified returns 404 not_available |
| [TEST] Building C | `6f1d2c3b-4a5e-4f60-8a7b-0c1d2e3f4a03` | 404 everywhere (nothing published) |

QR flow check: http://localhost:8081/v/6f1d2c3b-4a5e-4f60-8a7b-0c1d2e3f4a01 redirects to
`guided_viewing.html?token=...`.

## What the visitor pages need to do

- Call the API with relative URLs (`/api/v1/...`). Same origin, so no CORS.
- `guided_viewing.html`: read `token` from the query string; build the pickers from
  `available`; on `not_available`, say so and offer the listed pairs (no English fallback).
- `viewer.html`: list buildings from `GET /api/v1/locations`.
- Render API text with `textContent` (split `body` on blank lines into paragraphs). Never
  `innerHTML` with API data.
- Remove the xlsx and sql.js loading and the workbook/SQLite files from `visitor/public`.
- Point the "Administrator login" link at the admin app (`http://localhost:8080/login.php`
  locally), not `admin_login.php`.

## Deploying (later)

Point the web server's document root at `visitor/public` only. On Apache, `.htaccess` does
the routing (needs `mod_rewrite` and `AllowOverride All`). Use HTTPS, or phone cameras
won't open the QR scanner. Never expose MySQL's port 3306 or the admin app publicly.
