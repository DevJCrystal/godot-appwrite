class_name TestHelpers
extends RefCounted

static func _env_bool(name: String, default_value: bool = false) -> bool:
	var raw := OS.get_environment(name).strip_edges().to_lower()
	if raw.is_empty():
		return default_value
	return raw == "true" or raw == "1" or raw == "yes" or raw == "y"


static func should_clear_cookies() -> bool:
	# When session persistence is enabled, default to NOT clearing.
	var persist_enabled := _env_bool("APPWRITE_DEBUG_PERSIST_SESSION", false)
	return _env_bool("APPWRITE_TEST_CLEAR_COOKIES", not persist_enabled)


static func should_logout() -> bool:
	# Default to false when session persistence is enabled.
	var persist_enabled := _env_bool("APPWRITE_DEBUG_PERSIST_SESSION", false)
	return _env_bool("APPWRITE_TEST_LOGOUT", not persist_enabled)


static func ensure_logged_in() -> Dictionary:
	var auth_email := OS.get_environment("APPWRITE_TEST_EMAIL").strip_edges()
	var auth_password := OS.get_environment("APPWRITE_TEST_PASSWORD").strip_edges()
	if auth_email.is_empty() or auth_password.is_empty():
		return {
			"ok": false,
			"status_code": 0,
			"error": "Missing APPWRITE_TEST_EMAIL / APPWRITE_TEST_PASSWORD"
		}

	# 1) Try reusing an existing cookie session.
	var me: Dictionary = await Appwrite.account.get_current()
	if int(me.get("status_code", 0)) == 200:
		return {"ok": true, "me": me, "reused": true}

	# 2) Otherwise login.
	var login: Dictionary = await Appwrite.account.create_email_session(auth_email, auth_password)
	if int(login.get("status_code", 0)) != 201:
		return {"ok": false, "status_code": int(login.get("status_code", 0)), "error": login.get("data", {})}

	me = await Appwrite.account.get_current()
	if int(me.get("status_code", 0)) != 200:
		return {"ok": false, "status_code": int(me.get("status_code", 0)), "error": me.get("data", {})}

	return {"ok": true, "me": me, "reused": false}
