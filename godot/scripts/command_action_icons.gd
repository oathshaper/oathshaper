extends RefCounted
## Original Oathshaper line symbols. Identical symbols in the target row and queue.
static var _cache: Dictionary = {}

static func icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var shapes := {
		"basic": '<path d="m8 25 4-4M5 28l3-3m-1-6 6 6m-1-6L25 4l3-1-1 4-13 15"/>',
		"lunge": '<path d="m6 25 19-19m-1 10 2-12-12 2M4 17h7M4 12h7M4 7h7"/>',
		"shield_bash": '<path d="m11 4 8 4v8c0 5-8 11-8 11S3 21 3 16V8zM22 9l7 7-7 7m-1-7h8"/>',
		"binding_current": '<ellipse cx="16" cy="21" rx="11" ry="6"/><path d="M10 21V9l4-5m2 17V7l4-4m1 18V11l4-3"/>',
		"gale_arc": '<path d="m19 3-12 15h9l-3 11 13-16h-9z"/>',
		"mend": '<path d="M12 4h8v8h8v8h-8v8h-8v-8H4v-8h8z"/>',
		"veil": '<path d="m16 3 11 5v8c0 6-11 13-11 13S5 22 5 16V8zM10 15l4 4 8-9"/>',
		"gust": '<path d="M3 11h18c8 0 5-9 0-6M3 17h23M3 23h15c7 0 6 8 1 5"/>',
		"disrupt_device": '<circle cx="16" cy="16" r="8"/><path d="M16 2v6m0 16v6M2 16h6m16 0h6M6 6l5 5m10 10 5 5M26 6l-5 5M6 26l5-5m8-15-6 9h6l-5 8"/>',
		"pinning_bolt": '<path d="M5 5q28 0 22 22L5 5m0 0q0 28 22 22M4 28 26 6m-9 1 10-2-2 10"/>',
		"dressing": '<rect x="5" y="5" width="22" height="22" rx="5"/><path d="M16 10v12m-6-6h12"/>',
		"brace": '<path d="m16 3 11 5v8c0 6-11 13-11 13S5 22 5 16V8zM16 8v16"/>'
	}
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><g fill="none" stroke="#d8bd80" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round">%s</g></svg>' % shapes.get(id, shapes.basic)
	var source := Image.new()
	source.load_svg_from_string(svg, 2.0)
	var texture := ImageTexture.create_from_image(source)
	_cache[id] = texture
	return texture
