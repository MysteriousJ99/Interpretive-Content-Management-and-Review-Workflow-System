<?php
declare(strict_types=1);

/*
 * Public, read-only content API (docs/api.md).
 *
 * Security model:
 *   - In database mode this connects as `cms_public_api`, which can only SELECT from
 *     v_published_content. Drafts, in-review, approved-but-unpublished and archived rows
 *     are not in that view, so they cannot be returned even if this code had a bug.
 *   - GET/HEAD only. No write endpoints exist.
 *   - Unknown token and "not published" look the same (404), so the API never reveals
 *     that unpublished content exists.
 *   - Every query is a prepared statement. Request values are validated before use.
 */

const TOKEN_PATTERN = '/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/';
const LANG_PATTERN  = '/^[a-z]{2,10}$/';
const LEVEL_PATTERN = '/^[a-z_]{2,20}$/';

// Display order for the pickers. Codes not listed here sort after these, alphabetically.
const LANG_ORDER  = ['en', 'es', 'fr'];
const LEVEL_ORDER = ['college', 'simplified'];

interface ContentSource
{
    /** @return array<int, array{token: string, location: string}> buildings with any published content */
    public function listLocations(): array;

    /** @return array<int, array<string, mixed>> all published view rows for one token (empty if none) */
    public function rowsForToken(string $token): array;
}

/** Reads v_published_content through the least-privilege cms_public_api account. */
final class DatabaseSource implements ContentSource
{
    private PDO $pdo;

    public function __construct(array $db)
    {
        $dsn = "mysql:host={$db['host']};port={$db['port']};dbname={$db['name']};charset=utf8mb4";
        $this->pdo = new PDO($dsn, $db['user'], $db['pass'], [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
            PDO::ATTR_TIMEOUT            => 5,
        ]);
    }

    public function listLocations(): array
    {
        return $this->pdo->query(
            'SELECT token, MIN(location_name) AS location
               FROM v_published_content
              GROUP BY token
              ORDER BY location'
        )->fetchAll();
    }

    public function rowsForToken(string $token): array
    {
        $st = $this->pdo->prepare(
            'SELECT token, location_name, section_code, section_order,
                    language_code, audience_code, heading, body
               FROM v_published_content
              WHERE token = ?'
        );
        $st->execute([$token]);
        return $st->fetchAll();
    }
}

/** Serves visitor/mock/published_content.json (same shape as the view) so the front end works without MySQL. */
final class MockSource implements ContentSource
{
    private array $rows;

    public function __construct(string $file)
    {
        $data = json_decode((string)file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
        $this->rows = $data['rows'];
    }

    public function listLocations(): array
    {
        $out = [];
        foreach ($this->rows as $r) {
            $out[$r['token']] = ['token' => $r['token'], 'location' => $r['location_name']];
        }
        $out = array_values($out);
        usort($out, fn($a, $b) => strcmp($a['location'], $b['location']));
        return $out;
    }

    public function rowsForToken(string $token): array
    {
        return array_values(array_filter($this->rows, fn($r) => $r['token'] === $token));
    }
}

// ---------------------------------------------------------------------------------------

function send_json(int $status, array $body, array $extraHeaders = []): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('X-Content-Type-Options: nosniff');
    header('Cache-Control: no-store');
    header('Referrer-Policy: no-referrer');
    header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'");
    foreach ($extraHeaders as $h) {
        header($h);
    }
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
}

function order_key(string $code, array $preferred): array
{
    $i = array_search($code, $preferred, true);
    return [$i === false ? count($preferred) : $i, $code];
}

/** Language/level pairs that have published content, in display order. */
function available_pairs(array $rows): array
{
    $pairs = [];
    foreach ($rows as $r) {
        $pairs[$r['language_code'] . '|' . $r['audience_code']] =
            ['lang' => $r['language_code'], 'level' => $r['audience_code']];
    }
    $pairs = array_values($pairs);
    usort($pairs, fn($a, $b) =>
        [order_key($a['lang'], LANG_ORDER), order_key($a['level'], LEVEL_ORDER)]
        <=> [order_key($b['lang'], LANG_ORDER), order_key($b['level'], LEVEL_ORDER)]);
    return $pairs;
}

function make_source(array $config): ContentSource
{
    if (($config['mode'] ?? 'database') === 'mock') {
        return new MockSource(__DIR__ . '/../mock/published_content.json');
    }
    return new DatabaseSource($config['db']);
}

/**
 * Entry point. $path is the URL path (e.g. /api/v1/locations/<token>/content).
 */
function handle_api_request(string $method, string $path, array $query, ?array $config): void
{
    if ($method !== 'GET' && $method !== 'HEAD') {
        send_json(405, ['error' => 'method_not_allowed'], ['Allow: GET, HEAD']);
        return;
    }
    if ($config === null) {
        error_log('Public API: missing visitor/config.php (copy visitor/config.sample.php).');
        send_json(500, ['error' => 'server_error']);
        return;
    }

    // Match on the end of the path so the site also works from a subfolder.
    if (!preg_match('#/api/v1/(.*?)/?$#', $path, $m)) {
        send_json(404, ['error' => 'not_found']);
        return;
    }
    $parts = $m[1] === '' ? [] : explode('/', $m[1]);

    try {
        // GET /api/v1/locations
        if ($parts === ['locations']) {
            $source = make_source($config);
            send_json(200, ['locations' => $source->listLocations()]);
            return;
        }

        if (count($parts) < 2 || count($parts) > 3 || $parts[0] !== 'locations'
            || (count($parts) === 3 && $parts[2] !== 'content')) {
            send_json(404, ['error' => 'not_found']);
            return;
        }

        $token = strtolower($parts[1]);
        if (!preg_match(TOKEN_PATTERN, $token)) {
            send_json(404, ['error' => 'not_found']);
            return;
        }

        // Validate lang/level before touching the database.
        if (count($parts) === 3) {
            $lang  = $query['lang']  ?? null;
            $level = $query['level'] ?? null;
            if (!is_string($lang) || !is_string($level)
                || !preg_match(LANG_PATTERN, $lang) || !preg_match(LEVEL_PATTERN, $level)) {
                send_json(400, ['error' => 'bad_request', 'message' => 'lang and level are required, e.g. ?lang=en&level=college']);
                return;
            }
        }

        $source = make_source($config);
        $rows = $source->rowsForToken($token);
        if (!$rows) {
            // Unknown token, or nothing published: same answer either way.
            send_json(404, ['error' => 'not_found']);
            return;
        }
        $location  = $rows[0]['location_name'];
        $available = available_pairs($rows);

        // GET /api/v1/locations/{token}
        if (count($parts) === 2) {
            send_json(200, ['location' => $location, 'available' => $available]);
            return;
        }

        // GET /api/v1/locations/{token}/content?lang=..&level=..
        $sections = array_values(array_filter($rows,
            fn($r) => $r['language_code'] === $lang && $r['audience_code'] === $level));
        if (!$sections) {
            send_json(404, ['error' => 'not_available', 'location' => $location, 'available' => $available]);
            return;
        }
        usort($sections, fn($a, $b) => (int)$a['section_order'] <=> (int)$b['section_order']);

        send_json(200, [
            'location' => $location,
            'language' => $lang,
            'level'    => $level,
            'sections' => array_map(fn($r) => [
                'code'    => $r['section_code'],
                'heading' => $r['heading'],
                'body'    => $r['body'],
            ], $sections),
        ]);
    } catch (Throwable $t) {
        error_log('Public API error: ' . $t->getMessage());
        send_json(500, ['error' => 'server_error']);
    }
}
