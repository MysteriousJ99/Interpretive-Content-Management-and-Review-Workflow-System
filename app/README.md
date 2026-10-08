# Staff web app (plain PHP)

Admin GUI for the Interpretive Content Management and Review Workflow System.
Plain PHP 8 + PDO, no framework, no Composer, no Node. Runs on XAMPP's PHP and MariaDB.

## What it does
- **Viewers** sign in and read published content only.
- **Editors** add buildings, write content per building / section / language / reading level,
  save drafts, submit for review, archive and restore. They cannot approve or publish.
- **Administrators** do everything editors do, plus: review queue (approve, return with a comment,
  publish), and the **Users** page (create accounts, give or remove the editor role, deactivate,
  reset passwords). Every account change is logged.
- All workflow rules are enforced twice: in the app, and by database triggers (see db/).

## Setup (Windows + XAMPP)
Run these from the repo root in Command Prompt. Start MySQL in the XAMPP Control Panel first.

1. Upgrade the database (keeps your data):
   `C:\xampp\mysql\bin\mysql.exe -u root < db\migrate_v1_to_v2.sql`
   (Fresh database instead? Load `db\interpretive_cms_schema_v2.sql`.)
2. Create the app's config file:
   `copy app\config.sample.php app\config.php`
   Open `app\config.php` and make sure the password matches the `cms_admin_app` account.
3. Give your administrator account a password (the app needs one to sign in):
   `C:\xampp\php\php.exe app\tools\set_password.php your-email@example.com`
4. Start the app:
   `cd app\public`
   `C:\xampp\php\php.exe -S localhost:8080`
5. Open http://localhost:8080 and sign in. Add Will on the Users page.
   Stop the app with Ctrl+C.

If PHP says "could not find driver", open `C:\xampp\php\php.ini` and make sure
`extension=pdo_mysql` has no leading `;`.

## Security notes
- `app\config.php` holds a database password. It is git-ignored. Never commit it.
- The app connects as `cms_admin_app` (SELECT/INSERT/UPDATE only, no DELETE), not root.
- Only `app\public` should ever be served. If you use Apache instead of the command above,
  point its DocumentRoot at `app\public`, never at `app` or the repo root.
- Passwords are stored with PHP's `password_hash`. Forms use CSRF tokens, all queries are
  prepared statements, all output is HTML-escaped, and roles are re-checked on every request.

## Known limits (Sprint 2)
- No "forgot password" email. Administrators reset passwords on the Users page.
- Sign-in has only a short delay against password guessing, no lockout.
- The public visitor page and QR retrieval API are not in this app yet (Sprint 3, see docs/api.md).
- Sessions use PHP's default file storage.
