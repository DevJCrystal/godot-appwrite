class_name AppwriteRealtime
extends Node

signal connected
signal disconnected(code: int, reason: String)
signal message_received(message: Dictionary)

const PING_INTERVAL_MS := 20_000
const MAX_RETRY_DELAY_MS := 30_000
const SUBSCRIPTION_ID_PREFIX := "godot_"

var _client: AppwriteClient
var _ws: WebSocketPeer
var _app_connected := false
var _should_connect := false
var _reconnect_at_ms := 0
var _retry_delay_ms := 1_000
var _last_ping_ms := 0
var _debug := false

var _subscriptions: Dictionary[String, Dictionary] = {}
var _sent_subscriptions: Dictionary[String, bool] = {}
var _next_subscription_id := 1


func _init(client: AppwriteClient) -> void:
	_client = client


func set_debug(enabled: bool) -> AppwriteRealtime:
	_debug = enabled
	return self


## Returns a local subscription ID. Pass Query strings to filter on the server.
func subscribe(channels: Array[String], callback: Callable = Callable(), queries: Array = []) -> int:
	var normalized: Array[String] = []
	for channel in channels:
		var name := channel.strip_edges()
		if not name.is_empty() and not normalized.has(name):
			normalized.append(name)
	if normalized.is_empty():
		push_warning("AppwriteRealtime.subscribe: channels is empty")
		return -1

	var id := _next_subscription_id
	_next_subscription_id += 1
	_subscriptions[SUBSCRIPTION_ID_PREFIX + str(id)] = {
		"channels": normalized,
		"queries": queries.duplicate(),
		"callback": callback
	}
	_should_connect = true
	if get_connected():
		_sync_subscriptions()
	return id


func unsubscribe(subscription_id: int) -> void:
	if not _subscriptions.erase(SUBSCRIPTION_ID_PREFIX + str(subscription_id)):
		return
	if get_connected():
		_sync_subscriptions()
	if _subscriptions.is_empty():
		disconnect_now()


func clear_subscriptions() -> void:
	_subscriptions.clear()
	disconnect_now()


## Reopen the socket using the existing subscriptions and current session.
func connect_now() -> void:
	_should_connect = not _subscriptions.is_empty()
	_reconnect_at_ms = 0
	_retry_delay_ms = 1_000
	_close_socket()


## Close the socket and retain subscriptions for a later connect_now().
func disconnect_now() -> void:
	_should_connect = false
	_reconnect_at_ms = 0
	_retry_delay_ms = 1_000
	_close_socket()


## True after Appwrite's initial handshake and after sending any pending subscriptions.
func get_connected() -> bool:
	return _app_connected and _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _ws == null:
		if _should_connect and now >= _reconnect_at_ms:
			_open_socket()
		return

	_ws.poll()
	if _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		var code := _ws.get_close_code()
		var reason := _ws.get_close_reason()
		_ws = null
		_app_connected = false
		_sent_subscriptions.clear()
		if code == 1008:
			_should_connect = false
		if _should_connect:
			_schedule_retry()
		disconnected.emit(code, reason)
		return

	while _ws.get_ready_state() == WebSocketPeer.STATE_OPEN and _ws.get_available_packet_count() > 0:
		var message: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if message is Dictionary:
			_handle_message(message)

	if get_connected() and now - _last_ping_ms >= PING_INTERVAL_MS:
		_send("ping")
		_last_ping_ms = now


func _open_socket() -> void:
	var endpoint := _client._endpoint
	var project := _client._project_id
	if endpoint.is_empty() or project.is_empty():
		_should_connect = false
		push_warning("AppwriteRealtime: missing endpoint or project ID")
		return

	var url := "%s/realtime?project=%s" % [endpoint, project.uri_encode()]
	if not _client._environment_id.is_empty():
		url += "&environment=" + _client._environment_id.uri_encode()
	var tls: TLSOptions
	if endpoint.begins_with("https://"):
		url = "wss://" + url.substr("https://".length())
		tls = _client._get_tls_options(endpoint)
	elif endpoint.begins_with("http://"):
		url = "ws://" + url.substr("http://".length())

	_ws = WebSocketPeer.new()
	_ws.handshake_headers = _build_ws_headers()
	if _debug:
		print("AppwriteRealtime: connecting to ", url)
	var error := _ws.connect_to_url(url, tls)
	if error != OK:
		_ws = null
		_schedule_retry()
		push_warning("AppwriteRealtime: connect_to_url failed (error %d)" % error)


func _build_ws_headers() -> PackedStringArray:
	var headers := PackedStringArray([
		"X-Appwrite-Project: " + _client._project_id,
		"X-Appwrite-Response-Format: " + str(_client._headers["X-Appwrite-Response-Format"])
	])
	var origin := OS.get_environment("APPWRITE_REALTIME_ORIGIN").strip_edges()
	if not origin.is_empty():
		headers.append("Origin: " + origin)
	if not _client._api_key.is_empty():
		headers.append("X-Appwrite-Key: " + _client._api_key)
	var cookie := _client._build_cookie_header()
	if not cookie.is_empty():
		headers.append("Cookie: " + cookie)
	return headers


func _close_socket() -> void:
	if _ws != null and _ws.get_ready_state() < WebSocketPeer.STATE_CLOSING:
		_ws.close(1000, "client_disconnect")


func _schedule_retry() -> void:
	_reconnect_at_ms = Time.get_ticks_msec() + _retry_delay_ms
	_retry_delay_ms = mini(_retry_delay_ms * 2, MAX_RETRY_DELAY_MS)


func _send(type: String, data: Variant = null) -> bool:
	var frame := {"type": type}
	if data != null:
		frame["data"] = data
	var error := _ws.send_text(JSON.stringify(frame))
	if error == OK:
		return true
	push_warning("AppwriteRealtime: sending %s failed (error %d)" % [type, error])
	_close_socket()
	return false


func _sync_subscriptions() -> bool:
	var removed: Array[Dictionary] = []
	for id in _sent_subscriptions:
		if not _subscriptions.has(id):
			removed.append({"subscriptionId": id})
	if not removed.is_empty():
		if not _send("unsubscribe", removed):
			return false
		for row in removed:
			_sent_subscriptions.erase(row["subscriptionId"])

	var added: Array[Dictionary] = []
	for id in _subscriptions:
		if not _sent_subscriptions.has(id):
			var subscription := _subscriptions[id]
			added.append({
				"subscriptionId": id,
				"channels": subscription["channels"],
				"queries": subscription["queries"]
			})
	if not added.is_empty():
		if not _send("subscribe", added):
			return false
		for row in added:
			_sent_subscriptions[row["subscriptionId"]] = true
	return true


func _handle_message(message: Dictionary) -> void:
	var type := str(message.get("type", ""))
	if _debug:
		print("AppwriteRealtime: received ", type)

	if type == "connected" and not _app_connected:
		var data: Variant = message.get("data")
		var user: Variant = data.get("user") if data is Dictionary else null
		var session := _client._get_realtime_session()
		if user == null and not session.is_empty():
			if not _send("authentication", {"session": session}):
				return
		if _sync_subscriptions():
			_app_connected = true
			_last_ping_ms = Time.get_ticks_msec()
			_retry_delay_ms = 1_000
			connected.emit()
	elif type == "event" and message.get("data") is Dictionary:
		message = (message["data"] as Dictionary).duplicate()
		message["type"] = "event"

	message_received.emit(message)
	if type == "event" or type.is_empty():
		_dispatch(message)


func _dispatch(message: Dictionary) -> void:
	var ids: Variant = message.get("subscriptions")
	if ids is Array:
		for id in ids:
			_call_subscription(str(id), message)
		return

	# Older event payloads may only carry channels.
	var channels: Variant = message.get("channels")
	if not channels is Array:
		return
	for id in _subscriptions.keys():
		# Callbacks may remove another subscription during dispatch.
		var subscription: Dictionary = _subscriptions.get(id, {})
		if subscription.is_empty() or not subscription["queries"].is_empty():
			continue
		for channel in subscription["channels"]:
			if channels.has(channel):
				_call_subscription(id, message)
				break


func _call_subscription(id: String, message: Dictionary) -> void:
	var subscription: Dictionary = _subscriptions.get(id, {})
	var callback: Callable = subscription.get("callback", Callable())
	if callback.is_valid():
		callback.call(message)
