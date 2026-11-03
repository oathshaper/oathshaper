extends SceneTree
## Matched-phase comparison of the current skin, retarget and original donor.
const SLOT = preload("res://scripts/character_model_slot.gd")
var cameras: Camera3D
var models: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var tick := 0
func _initialize(): call_deferred("run")
func run():
	var world := Node3D.new(); root.add_child(world)
	var env := WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("263138")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE; env.environment.ambient_light_energy=.65
	world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);world.add_child(light)
	var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(20,20);floor.mesh=plane
	world.add_child(floor)
	cameras=Camera3D.new();world.add_child(cameras);cameras.position=Vector3(0,2.2,-8.5)
	cameras.look_at(Vector3(0,1,0));cameras.fov=42
	for i in 3:
		var actor:=Node3D.new();world.add_child(actor);actor.position.x=(i-1)*2.2
		models.append(actor)
		if i==0:
			var slot:=SLOT.new();slot.name="ModelSlot";slot.model_scale=Vector3.ONE*2;slot.model_offset=Vector3.ZERO
			slot.rigged_model_path="res://assets/meshes/rigged/player_rigged.glb"
			slot.rotation.y=PI;actor.add_child(slot);slot.set_process(false)
			slot.get_node("ImportedModel").position.y=.95
			players.append(slot._animation_player)
		else:
			var doc:=GLTFDocument.new();var state:=GLTFState.new()
			var path: String = "res://../tools/rigging/sources/quaternius/UAL1_Standard.glb" if i==2 else "res://../.artifacts/animation-library/tessa_library_candidate.glb"
			if doc.append_from_file(ProjectSettings.globalize_path(path),state)!=OK:
				push_error("Bake the comparison first with tools/rigging/retarget_library.py")
				quit(1);return
			var source:=doc.generate_scene(state);actor.add_child(source)
			source.scale=Vector3.ONE*(1.08 if i==2 else 2.0);source.rotation.y=PI
			if i==1: source.position.y=.95
			players.append(source.find_children("*","AnimationPlayer",true,false)[0])
		var label:=Label3D.new();label.text=["Installed Tessa","Quaternius → Tessa","Quaternius donor"][i]
		label.position=Vector3(0,2.25,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=44;label.pixel_size=.0025
		actor.add_child(label)
	process_frame.connect(step)
func step():
	tick+=1
	if tick>600: quit();return
	var section:=mini((tick-1)/200,2)
	var clip=["Idle","Walk","Run"][section]
	var donor=["Idle_Loop","Walk_Loop","Jog_Fwd_Loop"][section]
	var phase:=fposmod((tick-1)%200/60.0/[2.5,1.0,.71][section],1.0)
	for i in 3:
		var anim:=players[i];var wanted=donor if i==2 else clip
		anim.play(wanted,0);anim.speed_scale=0;anim.seek(anim.get_animation(wanted).length*phase,true)
		models[i].rotation.y=PI/3 if (tick-1)%200>=100 else 0.0
	if tick in [50,125,205,220,235,250,305,320,335,350,405,420,435,450,505,520,535,550]:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oath-library-%03d.png" % tick)
