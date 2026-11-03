extends SceneTree
const SLOT = preload('res://scripts/character_model_slot.gd')
var actors: Array[CharacterBody3D] = []
var camera: Camera3D
var tick := 0
var label: Label
var out := ''
func _initialize(): call_deferred('run')
func run():
 out=OS.get_cmdline_user_args()[0].trim_suffix('/')+'/'
 var stage := Node3D.new();root.add_child(stage)
 var env := WorldEnvironment.new(); var e := Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color('#3a444a');e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=.65;env.environment=e;stage.add_child(env)
 var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);light.light_energy=1.4;stage.add_child(light)
 var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(40,40);ground.mesh=plane;stage.add_child(ground)
 var material:=StandardMaterial3D.new();material.albedo_color=Color('#68767d');material.roughness=1;ground.material_override=material
 var names = ["player", "mara", "ivo"]
 for i in range(3):
  var actor:=CharacterBody3D.new();actor.position=Vector3((i-1)*2.2,0,0);stage.add_child(actor);actors.append(actor)
  var slot:=SLOT.new();slot.name="ModelSlot";slot.randomize_standing_motion=false;slot.model_scale=Vector3.ONE*2;slot.model_offset=Vector3.ZERO
  slot.rigged_model_path="res://assets/meshes/rigged/"+names[i]+"_rigged.glb";actor.add_child(slot)
  var model:Node3D=slot.get_node("ImportedModel")
  model.position.y -= slot._mesh_bottom_local(model)*2
  var title:=Label3D.new();title.text=["Tessa", "Mara", "Ivo"][i];title.font_size=36;title.pixel_size=.006;title.position.y=2.2;title.billboard=BaseMaterial3D.BILLBOARD_ENABLED;actor.add_child(title)
 camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=32
 var canvas:=CanvasLayer.new();root.add_child(canvas);label=Label.new();label.position=Vector2(20,20);label.add_theme_font_size_override('font_size',24);canvas.add_child(label)
 process_frame.connect(step)
func step():
 tick+=1
 var part: int=(tick-1)/120
 if part>=4:quit();return
 var speed: float=[1.5,1.5,4.5,4.5][part]
 for a in actors:a.velocity=Vector3(0,0,-speed)
 label.text='Same speed: %.1f m/s / %s' % [speed,'front' if part%2==0 else 'rear']
 camera.position=Vector3(0,2.6,8 if part%2==0 else -8);camera.look_at(Vector3(0,1,0))
 if tick%120 in [30,60,90]:
  for a in actors:
   var ap:AnimationPlayer=a.get_node("ModelSlot")._animation_player
   print(ap.current_animation, " ", ap.current_animation_position, " ", ap.speed_scale)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+'party-gaits-%03d.png'%tick)
