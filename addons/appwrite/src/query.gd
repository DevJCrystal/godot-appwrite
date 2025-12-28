class_name Query

## Appwrite v1.8+ query strings are JSON-serialized objects.
## This matches the official Web SDK Query.toString() implementation.
## Example:
##   Query.equal("title", ["Iron Man"])
## returns:
##   {"method":"equal","attribute":"title","values":["Iron Man"]}

static func _to_query(method: String, attribute: Variant = null, values: Variant = null) -> String:
	var obj: Dictionary = {
		"method": method,
	}
	if attribute != null:
		obj["attribute"] = attribute
	if values != null:
		if typeof(values) == TYPE_ARRAY:
			obj["values"] = values
		else:
			obj["values"] = [values]
	return JSON.stringify(obj)


static func equal(attribute: String, value: Variant) -> String:
	return _to_query("equal", attribute, value)


static func not_equal(attribute: String, value: Variant) -> String:
	return _to_query("notEqual", attribute, value)


static func less_than(attribute: String, value: Variant) -> String:
	return _to_query("lessThan", attribute, value)


static func less_than_equal(attribute: String, value: Variant) -> String:
	return _to_query("lessThanEqual", attribute, value)


static func greater_than(attribute: String, value: Variant) -> String:
	return _to_query("greaterThan", attribute, value)


static func greater_than_equal(attribute: String, value: Variant) -> String:
	return _to_query("greaterThanEqual", attribute, value)


static func between(attribute: String, start: Variant, end: Variant) -> String:
	return _to_query("between", attribute, [start, end])


static func search(attribute: String, value: String) -> String:
	return _to_query("search", attribute, value)


static func contains(attribute: String, value: Variant) -> String:
	return _to_query("contains", attribute, value)


static func not_contains(attribute: String, value: Variant) -> String:
	return _to_query("notContains", attribute, value)


static func starts_with(attribute: String, value: String) -> String:
	return _to_query("startsWith", attribute, value)


static func not_starts_with(attribute: String, value: String) -> String:
	return _to_query("notStartsWith", attribute, value)


static func ends_with(attribute: String, value: String) -> String:
	return _to_query("endsWith", attribute, value)


static func not_ends_with(attribute: String, value: String) -> String:
	return _to_query("notEndsWith", attribute, value)


static func is_null(attribute: String) -> String:
	return _to_query("isNull", attribute)


static func is_not_null(attribute: String) -> String:
	return _to_query("isNotNull", attribute)


static func order_asc(attribute: String) -> String:
	return _to_query("orderAsc", attribute)


static func order_desc(attribute: String) -> String:
	return _to_query("orderDesc", attribute)


static func order_random() -> String:
	return _to_query("orderRandom")


static func limit(value: int) -> String:
	return _to_query("limit", null, value)


static func offset(value: int) -> String:
	return _to_query("offset", null, value)


static func cursor_after(document_id: String) -> String:
	return _to_query("cursorAfter", null, document_id)


static func cursor_before(document_id: String) -> String:
	return _to_query("cursorBefore", null, document_id)


static func select(attributes: Array) -> String:
	return _to_query("select", null, attributes)


static func or_query(queries: Array[String]) -> String:
	var parsed: Array = []
	for q in queries:
		var v: Variant = JSON.parse_string(q)
		if typeof(v) == TYPE_DICTIONARY:
			parsed.append(v)
		else:
			# If one of the inputs isn't valid JSON, pass it through as-is.
			parsed.append(q)
	return _to_query("or", null, parsed)


static func and_query(queries: Array[String]) -> String:
	var parsed: Array = []
	for q in queries:
		var v: Variant = JSON.parse_string(q)
		if typeof(v) == TYPE_DICTIONARY:
			parsed.append(v)
		else:
			parsed.append(q)
	return _to_query("and", null, parsed)
