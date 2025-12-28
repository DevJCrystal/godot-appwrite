extends Node

const Helpers := preload("res://tests/test_helpers.gd")

func _env_bool(name: String, default_value: bool = false) -> bool:
	var raw := OS.get_environment(name).strip_edges().to_lower()
	if raw.is_empty():
		return default_value
	return raw == "true" or raw == "1" or raw == "yes" or raw == "y"


func _ready():
	print("--- Starting Appwrite BIG Test ---")
	randomize()

	var database_id := OS.get_environment("APPWRITE_DATABASE_ID").strip_edges()
	var table_id := OS.get_environment("APPWRITE_TABLE_ID").strip_edges()
	var function_id := OS.get_environment("APPWRITE_FUNCTION_ID").strip_edges()

	if database_id.is_empty() or table_id.is_empty() or function_id.is_empty():
		print("⚠️ Skipping: APPWRITE_DATABASE_ID / APPWRITE_TABLE_ID / APPWRITE_FUNCTION_ID must be set.")
		print("--- Test Finished ---")
		return

	# This test creates a brand new user and must log in as that user.
	# If a previous session cookie is still active (e.g. persisted session),
	# Appwrite will reject creating a new session with `user_session_already_exists`.
	#
	# Default behavior: start fresh.
	var reuse_existing_session := _env_bool("APPWRITE_BIG_TEST_REUSE_SESSION", false)
	if not reuse_existing_session and Appwrite.has_method("clear_cookies"):
		Appwrite.clear_cookies()
	else:
		# If caller insists on reuse, at least ensure we're not currently logged in.
		var me_check: Dictionary = await Appwrite.account.get_current()
		if int(me_check.get("status_code", 0)) == 200:
			await Appwrite.account.delete_session("current")
			if Appwrite.has_method("clear_cookies"):
				Appwrite.clear_cookies()

	# 1) Create a new account
	var email := "big_test_user_%d@example.com" % (randi() % 10000000)
	var password := "password123"
	print("Creating user: ", email)
	var created_user: Dictionary = await Appwrite.account.create("unique()", email, password)
	if int(created_user.get("status_code", 0)) != 201:
		print("❌ FAILED create user.")
		print("Status Code: ", created_user.get("status_code", 0))
		print("Error: ", created_user.get("data", {}))
		print("--- Test Finished ---")
		return
	print("✅ User created.")

	# 2) Login
	print("Logging in...")
	# Guard: if a session is somehow active, remove it.
	var me_before_login: Dictionary = await Appwrite.account.get_current()
	if int(me_before_login.get("status_code", 0)) == 200:
		await Appwrite.account.delete_session("current")
		if Appwrite.has_method("clear_cookies"):
			Appwrite.clear_cookies()

	var login: Dictionary = await Appwrite.account.create_email_session(email, password)
	if int(login.get("status_code", 0)) != 201:
		print("❌ FAILED login.")
		print("Status Code: ", login.get("status_code", 0))
		print("Error: ", login.get("data", {}))
		print("--- Test Finished ---")
		return
	print("✅ Logged in.")

	# 3) Verify session
	var me_resp: Dictionary = await Appwrite.account.get_current()
	if int(me_resp.get("status_code", 0)) != 200:
		print("❌ FAILED get current account.")
		print("Status Code: ", me_resp.get("status_code", 0))
		print("Error: ", me_resp.get("data", {}))
		print("--- Test Finished ---")
		return
	var me_data: Variant = me_resp.get("data")
	var me: Dictionary = me_data if typeof(me_data) == TYPE_DICTIONARY else {}
	print("✅ Current user: ", me.get("email", "<missing>"))

	# 4) List Documents (accessible)
	print("Listing documents (accessible to this user)...")
	var list_before: Dictionary = await Appwrite.databases.list_documents(database_id, table_id)
	if int(list_before.get("status_code", 0)) != 200:
		print("❌ FAILED list documents.")
		print("Status Code: ", list_before.get("status_code", 0))
		print("Error: ", list_before.get("data", {}))
		print("Hint: check table permissions and document security.")
		print("--- Test Finished ---")
		return
	var list_before_data: Variant = list_before.get("data")
	var list_before_dict: Dictionary = list_before_data if typeof(list_before_data) == TYPE_DICTIONARY else {}
	print("✅ List OK. total=", list_before_dict.get("total", "<missing>"))

	# 5) Create Document
	print("Creating document...")
	var doc_marker := "Big Test Doc %d" % (randi() % 1000000)
	var doc_data: Dictionary = {
		"testing": doc_marker,
	}
	var created_doc: Dictionary = await Appwrite.databases.create_document(database_id, table_id, "unique()", doc_data, [])
	if int(created_doc.get("status_code", 0)) != 201:
		print("❌ FAILED create document.")
		print("Status Code: ", created_doc.get("status_code", 0))
		print("Error: ", created_doc.get("data", {}))
		print("Hint: if your table requires attributes, add them to the payload.")
		print("--- Test Finished ---")
		return
	var created_doc_data: Variant = created_doc.get("data")
	var created_doc_dict: Dictionary = created_doc_data if typeof(created_doc_data) == TYPE_DICTIONARY else {}
	var doc_id := str(created_doc_dict.get("$id", ""))
	print("✅ Document created: ", doc_id)

	# 6) List Document
	# List by query on a known attribute, with a fallback to plain list+scan.
	print("Listing created document (by 'testing' query)...")
	var list_one: Dictionary = await Appwrite.databases.list_documents(
		database_id,
		table_id,
		[Query.equal("testing", [doc_marker]), Query.limit(10)]
	)
	if int(list_one.get("status_code", 0)) != 200:
		print("⚠️ Query list failed; falling back to plain list+scan.")
		print("Status Code: ", list_one.get("status_code", 0))
		print("Error: ", list_one.get("data", {}))
		list_one = await Appwrite.databases.list_documents(database_id, table_id)
		if int(list_one.get("status_code", 0)) != 200:
			print("❌ FAILED list documents (fallback).")
			print("Status Code: ", list_one.get("status_code", 0))
			print("Error: ", list_one.get("data", {}))
			print("--- Test Finished ---")
			return

	var list_one_data: Variant = list_one.get("data")
	var list_one_dict: Dictionary = list_one_data if typeof(list_one_data) == TYPE_DICTIONARY else {}
	var docs: Variant = list_one_dict.get("documents")
	var found := false
	var count := 0
	if typeof(docs) == TYPE_ARRAY:
		var arr := docs as Array
		count = arr.size()
		for d in arr:
			if typeof(d) == TYPE_DICTIONARY and str((d as Dictionary).get("$id", "")) == doc_id:
				found = true
				break
	print("✅ List returned documents=", count, " found_created=", found)

	# 7) Get Document
	print("Getting created document...")
	var got: Dictionary = await Appwrite.databases.get_document(database_id, table_id, doc_id)
	if int(got.get("status_code", 0)) != 200:
		print("❌ FAILED get document.")
		print("Status Code: ", got.get("status_code", 0))
		print("Error: ", got.get("data", {}))
		print("--- Test Finished ---")
		return
	print("✅ Got document.")

	# 8) Delete Document
	print("Deleting document...")
	var deleted: Dictionary = await Appwrite.databases.delete_document(database_id, table_id, doc_id)
	if int(deleted.get("status_code", 0)) != 204:
		print("❌ FAILED delete document.")
		print("Status Code: ", deleted.get("status_code", 0))
		print("Error: ", deleted.get("data", {}))
		print("--- Test Finished ---")
		return
	print("✅ Deleted document.")

	# 9) Run Function and await output
	print("Executing function: ", function_id)
	var payload := {
		"testing": "from_big_test",
	}
	var exec_resp: Dictionary = await Appwrite.functions.create_execution(function_id, payload)
	if int(exec_resp.get("status_code", 0)) != 201:
		print("❌ FAILED create execution.")
		print("Status Code: ", exec_resp.get("status_code", 0))
		print("Error: ", exec_resp.get("data", {}))
		print("--- Test Finished ---")
		return

	var exec_data: Variant = exec_resp.get("data")
	var exec: Dictionary = exec_data if typeof(exec_data) == TYPE_DICTIONARY else {}
	var execution_id := str(exec.get("$id", ""))
	var status := str(exec.get("status", ""))
	var final_exec_resp: Dictionary = exec_resp
	if not execution_id.is_empty() and status != "completed" and status != "failed" and status != "canceled":
		print("Waiting for function execution to complete...")
		final_exec_resp = await Appwrite.functions.wait_for_execution(function_id, execution_id)

	var final_data_raw: Variant = final_exec_resp.get("data")
	var final_data: Dictionary = final_data_raw if typeof(final_data_raw) == TYPE_DICTIONARY else {}
	print("✅ Function final status: ", final_data.get("status", "<missing>"))
	print("Function responseStatusCode: ", final_data.get("responseStatusCode", "<missing>"))
	print("Function responseBody: ", final_data.get("responseBody", ""))

	# 10) Logout
	print("Logging out...")
	var logout: Dictionary = await Appwrite.account.delete_session("current")
	if int(logout.get("status_code", 0)) != 204:
		print("❌ FAILED logout.")
		print("Status Code: ", logout.get("status_code", 0))
		print("Error: ", logout.get("data", {}))
		print("--- Test Finished ---")
		return
	print("✅ Logged out.")

	# 11) Verify 401
	var me_after: Dictionary = await Appwrite.account.get_current()
	if int(me_after.get("status_code", 0)) == 401:
		print("✅ Verified logged out (401).")
	else:
		print("⚠️ Unexpected status after logout: ", me_after.get("status_code", 0))
		print("Response: ", me_after.get("data", {}))

	print("--- BIG Test Finished ---")
