extends Node

const Helpers := preload("res://tests/test_helpers.gd")

signal finished(result: Dictionary)

func _finish(ok: bool, skipped: bool = false, details: Dictionary = {}) -> void:
	var out := details.duplicate()
	out["name"] = "Databases"
	out["ok"] = ok
	out["skipped"] = skipped
	emit_signal("finished", out)

func _ready():
	print("--- Starting Appwrite Databases Test ---")
	
	var database_id := OS.get_environment("APPWRITE_DATABASE_ID").strip_edges()
	var table_id := OS.get_environment("APPWRITE_TABLE_ID").strip_edges()
	if database_id.is_empty() or table_id.is_empty():
		print("⚠️ Skipping: APPWRITE_DATABASE_ID / APPWRITE_TABLE_ID not set.")
		print("Add them to .env to run this test.")
		print("--- Test Finished ---")
		_finish(true, true, {"reason": "Missing APPWRITE_DATABASE_ID / APPWRITE_TABLE_ID"})
		return

	# Auth: required unless your table allows guests.
	var auth_email := OS.get_environment("APPWRITE_TEST_EMAIL").strip_edges()
	var auth_password := OS.get_environment("APPWRITE_TEST_PASSWORD").strip_edges()
	if auth_email.is_empty() or auth_password.is_empty():
		print("⚠️ Skipping: APPWRITE_TEST_EMAIL / APPWRITE_TEST_PASSWORD not set.")
		print("This test needs a user to login so it can create/list rows via permissions.")
		print("--- Test Finished ---")
		_finish(true, true, {"reason": "Missing APPWRITE_TEST_EMAIL / APPWRITE_TEST_PASSWORD"})
		return

	# Only clear cookies if explicitly requested (or if persistence is disabled).
	if Helpers.should_clear_cookies() and Appwrite.has_method("clear_cookies"):
		Appwrite.clear_cookies()

	print("Authenticating (reuse session if available)...")
	var auth := await Helpers.ensure_logged_in()
	if not bool(auth.get("ok", false)):
		print("❌ FAILED auth.")
		print("Status Code: ", auth.get("status_code", 0))
		print("Error: ", auth.get("error", {}))
		print("--- Test Finished ---")
		_finish(false, false, {"error": auth.get("error", {})})
		return
	print("✅ Authenticated. Reused session=", auth.get("reused", false))
	var me_resp: Dictionary = auth.get("me", {})
	var me_data: Variant = me_resp.get("data")
	var me: Dictionary = me_data if typeof(me_data) == TYPE_DICTIONARY else {}
	var my_user_id := str(me.get("$id", ""))
	print("Me ID: ", my_user_id)

	print("Creating row...")
	randomize()
	var row_data := {
		"testing": "Test Row %d" % (randi() % 1000000)
	}
	var created := await Appwrite.tables_db.create_row(database_id, table_id, "unique()", row_data)
	if int(created.get("status_code", 0)) != 201:
		print("❌ FAILED create row.")
		print("Status Code: ", created.get("status_code", 0))
		print("Error: ", created.get("data", {}))
		print("Hint: check table permissions, row security, and column schema.")
		print("--- Test Finished ---")
		_finish(false, false, {"error": created.get("data", {})})
		return
	var created_data: Variant = created.get("data")
	var created_dict: Dictionary = created_data if typeof(created_data) == TYPE_DICTIONARY else {}
	var row_id := str(created_dict.get("$id", ""))
	print("✅ Row created: ", row_id)

	print("Listing accessible rows...")
	var listed = await Appwrite.tables_db.list_rows(database_id, table_id)
	if int(listed.get("status_code", 0)) != 200:
		await Appwrite.tables_db.delete_row(database_id, table_id, row_id)
		print("❌ FAILED list rows.")
		print("Status Code: ", listed.get("status_code", 0))
		print("Error: ", listed.get("data", {}))
		print("--- Test Finished ---")
		_finish(false, false, {"error": listed.get("data", {})})
		return
	var listed_data: Variant = listed.get("data")
	var listed_dict: Dictionary = listed_data if typeof(listed_data) == TYPE_DICTIONARY else {}
	var total := int(listed_dict.get("total", -1))
	print("✅ List returned. total=", total)

	print("Updating created row...")
	var updated_value := str(row_data["testing"]) + " updated"
	var updated := await Appwrite.tables_db.update_row(database_id, table_id, row_id, {"testing": updated_value})
	if updated.get("status_code") != 200:
		await Appwrite.tables_db.delete_row(database_id, table_id, row_id)
		print("❌ FAILED update row.")
		_finish(false, false, {"error": updated.get("data", {})})
		return

	print("Getting updated row...")
	var got = await Appwrite.tables_db.get_row(database_id, table_id, row_id)
	if int(got.get("status_code", 0)) != 200:
		await Appwrite.tables_db.delete_row(database_id, table_id, row_id)
		print("❌ FAILED get row.")
		print("Status Code: ", got.get("status_code", 0))
		print("Error: ", got.get("data", {}))
		print("--- Test Finished ---")
		_finish(false, false, {"error": got.get("data", {})})
		return
	var got_data: Variant = got.get("data")
	var got_dict: Dictionary = got_data if typeof(got_data) == TYPE_DICTIONARY else {}
	print("✅ Got row. testing=", got_dict.get("testing", ""))

	print("Deleting created row...")
	var deleted = await Appwrite.tables_db.delete_row(database_id, table_id, row_id)
	if int(deleted.get("status_code", 0)) != 204:
		print("❌ FAILED delete row.")
		print("Status Code: ", deleted.get("status_code", 0))
		print("Error: ", deleted.get("data", {}))
		print("--- Test Finished ---")
		_finish(false, false, {"error": deleted.get("data", {})})
		return
	print("✅ Deleted.")
	if got_dict.get("testing") != updated_value:
		_finish(false, false, {"error": "Row did not contain the updated value", "data": got_dict})
		return

	print("--- Test Finished ---")
	_finish(true)
