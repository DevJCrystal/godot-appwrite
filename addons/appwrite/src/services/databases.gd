class_name AppwriteDatabases
extends RefCounted

## Compatibility service for Appwrite's legacy collection and document API.

var _client: AppwriteClient

func _init(client: AppwriteClient):
	_client = client


# -------------------------------------------------------------------------
# Databases
# -------------------------------------------------------------------------

func list_databases(queries: Array = []) -> Dictionary:
	var path := "/databases"
	path = Query._append_to_path(path, queries)
	return await _client.call_api(HTTPClient.METHOD_GET, path)

func get_database(database_id: String) -> Dictionary:
	var path := "/databases/%s" % database_id
	return await _client.call_api(HTTPClient.METHOD_GET, path)


# -------------------------------------------------------------------------
# Legacy collection metadata (server API).
# -------------------------------------------------------------------------

func list_tables(database_id: String, queries: Array = []) -> Dictionary:
	var path := "/databases/%s/collections" % database_id
	path = Query._append_to_path(path, queries)
	return await _client.call_api(HTTPClient.METHOD_GET, path)

func get_table(database_id: String, table_id: String) -> Dictionary:
	var path := "/databases/%s/collections/%s" % [database_id, table_id]
	return await _client.call_api(HTTPClient.METHOD_GET, path)


# -------------------------------------------------------------------------
# Documents
# -------------------------------------------------------------------------

## Create a document.
## - document_id: use "unique()" to let Appwrite generate.
## - data: Dictionary/Array is sent as JSON.
## - permissions: array of permission strings (optional). If omitted, collection defaults apply.
func create_document(
	database_id: String,
	table_id: String,
	document_id: String,
	data: Dictionary,
	permissions: Array[String] = []
) -> Dictionary:
	var path := "/databases/%s/collections/%s/documents" % [database_id, table_id]
	var payload: Dictionary = {
		"documentId": document_id,
		"data": data
	}
	if permissions.size() > 0:
		payload["permissions"] = permissions
	return await _client.call_api(HTTPClient.METHOD_POST, path, {}, payload)


## List documents the current user has access to.
## If queries are provided, Appwrite will apply them after permission checks.
func list_documents(database_id: String, table_id: String, queries: Array = []) -> Dictionary:
	var path := "/databases/%s/collections/%s/documents" % [database_id, table_id]
	return await _client.call_api(HTTPClient.METHOD_GET, Query._append_to_path(path, queries))


func get_document(database_id: String, table_id: String, document_id: String) -> Dictionary:
	var path := "/databases/%s/collections/%s/documents/%s" % [database_id, table_id, document_id]
	return await _client.call_api(HTTPClient.METHOD_GET, path)


func update_document(
	database_id: String,
	table_id: String,
	document_id: String,
	data: Dictionary,
	permissions: Array[String] = []
) -> Dictionary:
	var path := "/databases/%s/collections/%s/documents/%s" % [database_id, table_id, document_id]
	var payload: Dictionary = {
		"data": data
	}
	if permissions.size() > 0:
		payload["permissions"] = permissions
	return await _client.call_api(HTTPClient.METHOD_PATCH, path, {}, payload)


func delete_document(database_id: String, table_id: String, document_id: String) -> Dictionary:
	var path := "/databases/%s/collections/%s/documents/%s" % [database_id, table_id, document_id]
	return await _client.call_api(HTTPClient.METHOD_DELETE, path)
