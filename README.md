# Appwrite SDK for Godot 4.5+ (GDScript)

An Appwrite client SDK for Godot 4.5+ written in GDScript. Targets Appwrite Cloud and self-hosted Appwrite 2.7.4 using the `2.7.2` REST response format.

- Auth: client-safe session auth via cookies (no embedded API key)
- Services: **Account**, **TablesDB**, **Functions**, **Storage**, **Realtime**, and the legacy **Databases** service

See the [Appwrite 2.7.4 release notes](https://github.com/appwrite/appwrite/releases/tag/2.7.4) and [self-hosted upgrade guide](https://appwrite.io/docs/advanced/self-hosting/production/updates).

## Install

### Option A: Use as a Godot plugin (recommended)

1. Copy the `addons/appwrite` folder into your Godot project.
2. In Godot: `Project` → `Project Settings` → `Plugins` → enable **Appwrite SDK**.

Enabling the plugin registers an autoload singleton named `Appwrite`.

### Option B: Git submodule

From your Godot project root:

```bash
git submodule add https://github.com/DevJCrystal/godot-gdscript-appwrite-4x.git addons/appwrite_sdk
```

Then copy (or symlink) `addons/appwrite_sdk/addons/appwrite` into your project’s `addons/`.

## Configuration

This project uses environment variables loaded from a local `.env` file.

- Copy `.env.example` → `.env`
- Fill in the values

Important:
- `.env` is ignored by git on purpose (it contains secrets).

### Appwrite Cloud

Copy the API endpoint and project ID from your project settings in the Appwrite Console. Use your project's region.

```dotenv
APPWRITE_ENDPOINT=https://<REGION>.cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=<PROJECT_ID>
```

If you're using a Cloud project environment such as staging, keep the parent project's ID and add `APPWRITE_ENVIRONMENT_ID=<ENVIRONMENT_ID>`. The SDK applies it to REST requests and Realtime subscriptions. [Cloud endpoints](https://appwrite.io/docs/products/network/endpoints), [project environments](https://appwrite.io/docs/sdks#project-environments).

Use `Appwrite.set_environment(id)` to select an environment from code. Sign in and create new Realtime subscriptions after switching environments.

### Self-hosted Appwrite

Use the endpoint and project ID from your self-hosted instance.

```dotenv
APPWRITE_ENDPOINT=https://appwrite.example.com/v1
APPWRITE_PROJECT_ID=<PROJECT_ID>
```

For local development with a self-signed certificate, set `APPWRITE_SELF_SIGNED=true`. [Self-hosting guide](https://appwrite.io/docs/advanced/self-hosting).

### Tests / realtime `.env` (end-to-end)

If you want to run the included test scenes and realtime examples, you’ll typically also set:

- `APPWRITE_DATABASE_ID`, `APPWRITE_TABLE_ID`
- `APPWRITE_STORAGE_BUCKET_ID` (storage tests)
- `APPWRITE_FUNCTION_ID` (functions tests)
- `APPWRITE_TEST_EMAIL`, `APPWRITE_TEST_PASSWORD` (most tests + database realtime)

Useful debug toggles while iterating:

- `APPWRITE_DEBUG_PERSIST_SESSION=true`
- `APPWRITE_DEBUG_HTTP=true`
- `APPWRITE_DEBUG_REALTIME=true`

## Quick start

Once the plugin is enabled, you can call:

```gdscript
var res: Dictionary = await Appwrite.account.get_current()
print(res.get("status_code"), res.get("data"))
```

## Service examples

All service calls return a `Dictionary` with:

- `status_code` (int): HTTP status code (or `0` for local/network failures)
- `data` (Variant): decoded JSON response (usually a Dictionary)
- sometimes `body_bytes` for binary downloads (see Storage)

If you want a consistent pattern for handling responses, this small helper keeps example code tidy:

```gdscript
func _require_ok(resp: Dictionary, ok_codes: Array[int] = [200, 201, 204]) -> bool:
	var code := int(resp.get("status_code", 0))
	if ok_codes.has(code):
		return true

	# status_code == 0 means the request failed locally (DNS/TLS/timeout/etc).
	push_error("Appwrite request failed (%d): %s" % [code, str(resp.get("data"))])
	return false
```

### Account (login + current user)

```gdscript
# Login (creates a cookie session)
var login := await Appwrite.account.create_email_session(
	OS.get_environment("APPWRITE_TEST_EMAIL"),
	OS.get_environment("APPWRITE_TEST_PASSWORD")
)

if not _require_ok(login, [201]):
	return

# Fetch current user
var me := await Appwrite.account.get_current()
print("me status=", me.get("status_code"))
print("me data=", me.get("data"))

# Logout (optional)
# await Appwrite.account.delete_session("current")
```

### TablesDB (list + create + update + queries)

```gdscript
var db_id := OS.get_environment("APPWRITE_DATABASE_ID")
var table_id := OS.get_environment("APPWRITE_TABLE_ID")

# List the 10 rows with the highest bestScore.
var list := await Appwrite.tables_db.list_rows(db_id, table_id, [
	Query.order_desc("bestScore"),
	Query.limit(10)
])
print("list status=", list.get("status_code"))

# Create a row (rowId can be "unique()").
var created := await Appwrite.tables_db.create_row(
	db_id,
	table_id,
	"unique()",
	{
		"bestScore": 123,
		"note": "hello from godot"
	}
)
print("create status=", created.get("status_code"))

# Update a row.
var row_id := str(created.get("data", {}).get("$id", ""))
if not row_id.is_empty():
	var updated := await Appwrite.tables_db.update_row(
		db_id,
		table_id,
		row_id,
		{"bestScore": 200}
	)
	print("update status=", updated.get("status_code"))

# Filter to rows where userId matches a value.
# var filtered := await Appwrite.tables_db.list_rows(db_id, table_id, [
# 	Query.equal("userId", "some-user-id")
# ])
```

### Storage (upload + download + delete)

```gdscript
var bucket_id := OS.get_environment("APPWRITE_STORAGE_BUCKET_ID")

# Upload a file from disk (fileId can be "unique()")
var upload := await Appwrite.storage.create_file(
	bucket_id,
	"unique()",
	"res://icon.svg"
)
print("upload status=", upload.get("status_code"))

var file_id := str(upload.get("data", {}).get("$id", ""))
if not file_id.is_empty():
	# Download raw bytes
	var dl := await Appwrite.storage.download_file(bucket_id, file_id)
	var bytes := dl.get("body_bytes", PackedByteArray()) as PackedByteArray
	print("download status=", dl.get("status_code"), " bytes=", bytes.size())

	# Delete
	var del := await Appwrite.storage.delete_file(bucket_id, file_id)
	print("delete status=", del.get("status_code"))
```

### Functions (execute + wait for completion)

```gdscript
var function_id := OS.get_environment("APPWRITE_FUNCTION_ID")

# Trigger an execution (body can be a Dictionary; it will be JSON-stringified)
var exec := await Appwrite.functions.create_execution(function_id, {
	"hello": "world",
	"time": Time.get_unix_time_from_system()
})

if int(exec.get("status_code", 0)) != 201:
	push_error("Execution create failed: %s" % [str(exec.get("data"))])
	return

var execution_id := str(exec.get("data", {}).get("$id", ""))

# Wait for it to reach completed/failed/canceled
var final := await Appwrite.functions.wait_for_execution(function_id, execution_id, 60_000)
print("final status=", final.get("status_code"))
print("execution=", final.get("data"))
```

### Realtime (subscribe to row events)

```gdscript
var db_id := OS.get_environment("APPWRITE_DATABASE_ID")
var table_id := OS.get_environment("APPWRITE_TABLE_ID")

# This channel receives create, update, and delete events for rows in the table.
var channel := "tablesdb.%s.tables.%s.rows" % [db_id, table_id]

# Sign in before subscribing to protected rows.
var sub_id := Appwrite.realtime.subscribe([channel], func (msg: Dictionary) -> void:
	# Typical event payload:
	# { events:[], channels:[], subscriptions:[], timestamp:"...", payload:{...}, type:"event" }
	var payload: Variant = msg.get("payload")
	print("realtime events=", msg.get("events"))
	print("payload=", payload)
)

# Later, unsubscribe when you no longer need updates.
# Appwrite.realtime.unsubscribe(sub_id)

```

## Current progress

### ✅ Accounts

Implemented in `addons/appwrite/src/services/account.gd`.

- Create users
- Create email sessions
- Get current account (`get_current()`)
- Logout / delete session
- Cookie-based session persistence (captures `Set-Cookie`, sends `Cookie`)

Notes:
- Method name avoids Godot’s built-in `Object.get()` collision (uses `get_current()` / `get_account()` naming).

### ✅ TablesDB

Use `Appwrite.tables_db` for `create_row()`, `list_rows()`, `get_row()`, `update_row()`, and `delete_row()`. The list response contains `data.rows` and `data.total`. List and get calls accept `Query` strings for filtering or selecting columns. See the [TablesDB REST API](https://appwrite.io/docs/references/cloud/client-rest/tablesDB).

### Migrating from collections and documents

Existing collections and documents are accessible through TablesDB with their existing IDs. When switching to `Appwrite.tables_db`, use the equivalent row methods and read `data.rows` from list responses. Update Realtime channels to `tablesdb.<DATABASE_ID>.tables.<TABLE_ID>.rows`. See Appwrite's [TablesDB migration overview](https://appwrite.io/changelog/entry/2025-08-26-2).

Existing `Appwrite.databases.*_document()` calls still use the legacy REST routes and return `data.documents` for lists.

### ✅ Functions

Implemented in `addons/appwrite/src/services/functions.gd`.

- Create function executions
- Poll/wait for execution to reach a terminal status (`wait_for_execution()`)
- Returns execution output (`responseStatusCode`, `responseBody`) when available. The current Appwrite response model identifies the function with `resourceId`.

### ✅ Storage

Implemented in `addons/appwrite/src/services/storage.gd`.

- List buckets / get bucket
- List files / get file metadata
- Upload file (multipart) from bytes or from disk
- Download file bytes (`body_bytes`)
- Delete files

### ✅ Realtime

Implemented in `addons/appwrite/src/services/realtime.gd`.

- One WebSocket per client for `Appwrite.realtime.subscribe(channels, callback, queries)`
- Session auth via the same cookie jar used for REST calls
- Optional server-side filters through the third argument, an array of `Query` strings
- Automatic reconnect and resubscription after a connection drops
- The socket closes when the last subscription is removed. Call `clear_subscriptions()` when switching accounts, then subscribe again after signing in.

See [Appwrite Realtime subscriptions](https://appwrite.io/docs/apis/realtime/subscribe).

## Tests / Debug scenes

This repo includes Godot scenes under `tests/` that run end-to-end flows.

- `tests/test_accounts.tscn`: account flows
- `tests/test_databases.tscn`: TablesDB row CRUD
- `tests/test_functions.tscn`: function execution + wait
- `tests/test_storage.tscn`: upload/download/delete against a bucket
- `tests/test_queries.tscn`: query diagnostics (baseline list + filtered list)
- `tests/test_e2e.tscn`: end-to-end test
- `tests/test_ui.tscn`: simple UI runner (buttons + results log)
- `tests/test_realtime_player_docs.tscn`: live top-5 leaderboard UI (read-only)

## Examples

- `examples/realtime_monitor.tscn`: subscribes to a table's row channel and prints Realtime events.

Env vars:

- Either set `APPWRITE_REALTIME_CHANNEL` to a full channel string, OR set `APPWRITE_DATABASE_ID` + `APPWRITE_TABLE_ID`.
- If the channel requires auth (common for databases), also set `APPWRITE_TEST_EMAIL` + `APPWRITE_TEST_PASSWORD`.

Useful env flags:

- `APPWRITE_DEBUG_PERSIST_SESSION=true` keeps a cookie jar on disk to reduce repeated logins.
- `APPWRITE_DEBUG_HTTP=true` prints request details from the client.
- `APPWRITE_DEBUG_REALTIME=true` prints Realtime connection attempts and incoming frame types in the Realtime test scenes.
- `APPWRITE_TEST_PRINT_DOCS_JSON=true` prints full row JSON in the query test.

## Security / design constraints

- No API keys are embedded in the client.
- Privileged operations should be done via Appwrite **Functions**.
- If `APPWRITE_KEY` is present in your `.env`, it is ignored unless you also set `APPWRITE_ENABLE_API_KEY=true`.
