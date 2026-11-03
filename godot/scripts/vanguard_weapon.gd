extends "res://scripts/command_weapon.gd"
## Reuse the two-hand rig and grip solver; firearm geometry is presentation only.
func configure(_main_kind: String = "carbine", _secondary_kind: String = "") -> void:
	super.configure("crossbow", "")
	if visual == null: return
	_clear(visual)
	# Geometry is local to the hand attachment and inherits the 2x character scale.
	_ellipsoid(visual, Vector3(0, .015, .09), Vector3(.07, .08, .25), _dark)
	_ellipsoid(visual, Vector3(0, -.015, -.06), Vector3(.06, .10, .12), _wood)
	_ellipsoid(visual, Vector3(0, -.045, .02), Vector3(.045, .10, .05), _dark)
	_rod(visual, Vector3(0, .025, .18), Vector3(0, .025, .35), .017, _steel)
	_rod(visual, Vector3(0, .067, .025), Vector3(0, .067, .15), .009, _bronze)
	flash = _ellipsoid(visual, Vector3(0, .025, .37), Vector3(.04, .04, .07), _glow)
	flash.hide()
	set_readied(_readied)
