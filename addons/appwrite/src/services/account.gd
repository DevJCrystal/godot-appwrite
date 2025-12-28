class_name AppwriteAccount
extends RefCounted

## The Account service allows you to authenticate and manage user accounts.

var _client: AppwriteClient

func _init(client: AppwriteClient):
	_client = client

# -------------------------------------------------------------------------
# Authentication
# -------------------------------------------------------------------------

## Create a new user account.
## [param user_id]: Choose a custom ID or use "unique()" for auto-generation.
func create(user_id: String, email: String, password: String, name: String = "") -> Dictionary:
	var path = "/account"
	var params = {
		"userId": user_id,
		"email": email,
		"password": password
	}
	if name != "":
		params["name"] = name
		
	return await _client.call_api(HTTPClient.METHOD_POST, path, {}, params)

## Login with Email and Password.
## Creates a session (cookie) that allows subsequent authorized requests.
func create_email_session(email: String, password: String) -> Dictionary:
	var path = "/account/sessions/email"
	var params = {
		"email": email,
		"password": password
	}
	
	return await _client.call_api(HTTPClient.METHOD_POST, path, {}, params)


## Alias for create_email_session (matches Appwrite naming in many SDKs).
func create_email_password_session(email: String, password: String) -> Dictionary:
	return await create_email_session(email, password)

## Get the currently logged-in user.
func get_account() -> Dictionary:
	var path = "/account"
	return await _client.call_api(HTTPClient.METHOD_GET, path)


## Alias for get_account (cannot be named `get()` because it conflicts with Object.get).
func get_current() -> Dictionary:
	return await get_account()

## Logout (Delete current session).
func delete_session(session_id: String = "current") -> Dictionary:
	var path = "/account/sessions/" + session_id
	return await _client.call_api(HTTPClient.METHOD_DELETE, path)


## List sessions for the current user.
func list_sessions() -> Dictionary:
	var path = "/account/sessions"
	return await _client.call_api(HTTPClient.METHOD_GET, path)


## Get a single session by ID (or "current").
func get_session(session_id: String = "current") -> Dictionary:
	var path = "/account/sessions/" + session_id
	return await _client.call_api(HTTPClient.METHOD_GET, path)


## Logout everywhere (delete all sessions).
func delete_sessions() -> Dictionary:
	var path = "/account/sessions"
	return await _client.call_api(HTTPClient.METHOD_DELETE, path)
