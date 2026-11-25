class_name AppwriteTablesDB
extends RefCounted

## Client-side row operations for Appwrite TablesDB.

var _client: AppwriteClient


func _init(client: AppwriteClient) -> void:
	_client = client


## Use "unique()" to let Appwrite generate a row ID.
## Omit permissions to use Appwrite's defaults.
func create_row(
	database_id: String,
	table_id: String,
	row_id: String,
	data: Dictionary,
	permissions: Variant = null
) -> Dictionary:
	var body := _row_data(data, permissions)
	body["rowId"] = row_id
	return await _client.call_api(HTTPClient.METHOD_POST, _rows_path(database_id, table_id), {}, body)


## Returns an Appwrite RowList with "rows" and "total" in the response data.
func list_rows(database_id: String, table_id: String, queries: Array = []) -> Dictionary:
	var path := Query._append_to_path(_rows_path(database_id, table_id), queries)
	return await _client.call_api(HTTPClient.METHOD_GET, path)


func get_row(database_id: String, table_id: String, row_id: String, queries: Array = []) -> Dictionary:
	var path := Query._append_to_path(_row_path(database_id, table_id, row_id), queries)
	return await _client.call_api(HTTPClient.METHOD_GET, path)


## Omit permissions to retain current permissions, or pass [] to clear them.
func update_row(
	database_id: String,
	table_id: String,
	row_id: String,
	data: Dictionary,
	permissions: Variant = null
) -> Dictionary:
	return await _client.call_api(
		HTTPClient.METHOD_PATCH, _row_path(database_id, table_id, row_id), {}, _row_data(data, permissions)
	)


func delete_row(database_id: String, table_id: String, row_id: String) -> Dictionary:
	return await _client.call_api(HTTPClient.METHOD_DELETE, _row_path(database_id, table_id, row_id))


func _rows_path(database_id: String, table_id: String) -> String:
	return "/tablesdb/%s/tables/%s/rows" % [database_id.uri_encode(), table_id.uri_encode()]


func _row_path(database_id: String, table_id: String, row_id: String) -> String:
	return _rows_path(database_id, table_id) + "/" + row_id.uri_encode()


func _row_data(data: Dictionary, permissions: Variant) -> Dictionary:
	var body := {"data": data}
	if permissions != null:
		body["permissions"] = permissions
	return body
