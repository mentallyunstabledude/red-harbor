extends Node
## Screenshot harness for visual QA (run under xvfb, never headless).
## User args start after the `--` separator and use key=value:
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 \
##       res://tests/capture.tscn -- --scene=office --out=/tmp/shot.png
## The reference still (K1's visual regression pin):
##   ... -- --scene=office --ref=save     writes tests/ref/office_ref.png
##   ... -- --scene=office --ref=check    diffs against it, exit 2 on drift

const SCENES := {
        "menu": "res://scenes/menu.tscn",
        "office": "res://scenes/office.tscn",
}

var _args: Dictionary = {}
var _shot_count := 0


func _ready() -> void:
        for a in OS.get_cmdline_user_args():
                if a.find("=") != -1:
                        var kv := a.split("=", true, 1)
                        _args[kv[0].trim_prefix("--")] = kv[1]
                else:
                        _args[a.trim_prefix("--")] = "1"
        Run.ensure_case()
        var which: String = _args.get("scene", "office")
        var path: String = SCENES.get(which, which)
        print("CAPTURE: loading ", path)
        await get_tree().process_frame          # root is busy during _ready
        var inst: Node = load(path).instantiate()
        if _args.has("clock") and inst.get("qa_clock") != null:
                inst.set("qa_clock", float(_args["clock"]))
        if _args.has("seed") and inst.get("deal_seed") != null:
                inst.set("deal_seed", int(_args["seed"]))
        get_tree().root.add_child(inst)
        await get_tree().process_frame
        await get_tree().process_frame
        if _args.has("pause"):
                (inst.get("_pause") as Node).open_menu()
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        if _args.has("sub"):
                inst.call("_flash_sub", _args["sub"])
        if _args.has("pos"):
                # drop the PI somewhere else and let the follow cam drift over
                var pp := str(_args["pos"]).split(",")
                var p: Node3D = inst.get("_player")
                p.position = Vector3(float(pp[0]), 0.1, float(pp[1]))
        if _args.has("yaw"):
                inst.set("_yaw", float(_args["yaw"]))
        if _args.has("pitch"):
                inst.set("_pitch", float(_args["pitch"]))
        if _args.has("walk"):
                Input.action_press(str(_args["walk"]))   # hold a move key
        if _args.has("strip"):
                for part in str(_args["strip"]).split(","):
                        _strip(inst, part.strip_edges())
                        await get_tree().process_frame
        await _frames(int(_args.get("wait", 20)))
        await RenderingServer.frame_post_draw
        RenderingServer.force_draw(false, 2.0)
        if _args.has("probe"):
                var v: SubViewport = inst.get("_view").get("_view")
                var img := v.get_texture().get_image()
                print("PROBE viewport ", v.size, " px=", img.get_pixel(240, 135), img.get_pixel(10, 10))
        if _args.has("pixel"):
                # debug read: one tube pixel, as x,y fractions of the frame
                var pv: SubViewport = inst.get("_view").get("_view")
                var pimg := pv.get_texture().get_image()
                var pf := str(_args["pixel"]).split(",")
                var ppos := Vector2i(int(float(pf[0]) * 480.0), int(float(pf[1]) * 270.0))
                print("PIXEL ", ppos, " = ", pimg.get_pixel(ppos.x, ppos.y))
        if _args.has("ray"):
                # debug pick: raycast from the camera through a screen fraction
                var fr := str(_args["ray"]).split(",")
                var uv := Vector2(float(fr[0]), float(fr[1]))
                var cam: Camera3D = inst.get("_view").camera
                print("RAY cam=", cam.global_position, " basis_z=", -cam.global_basis.z)
                var dir := _ray_normal(cam, uv)
                var space: PhysicsDirectSpaceState3D = inst.get_world_3d().direct_space_state
                var q := PhysicsRayQueryParameters3D.create(
                                cam.global_position, cam.global_position + dir * 60.0)
                var hit: Dictionary = space.intersect_ray(q)
                print("RAY hit=", hit)
        # grab the frame while the scene is alive, then tear the scene down
        # cleanly (bus down, players freed) so nothing leaks at cleanup
        var img := get_viewport().get_texture().get_image()
        await _quiet(inst)
        inst.queue_free()
        for i in 6:
                await get_tree().process_frame
        if _args.has("ref"):
                # the committed still: pin the frame once, then diff forever
                var ok := _ref(img, str(_args["ref"]), str(_args.get("scene", "office")))
                get_tree().quit(0 if ok else 2)
                return
        _snap(img, str(_args.get("out", "/tmp/shot.png")))
        get_tree().quit()


func _quiet(inst: Node) -> void:
        # take the office bus down before quitting so the mix playbacks die
        # with the scene, not at ObjectDB cleanup
        for key in ["_snd_room", "_snd_fan", "_snd_radio", "_snd_shelf", "_snd_step"]:
                var p: Node = inst.get(key)
                if p != null:
                        p.stop()
        for i in 8:
                await get_tree().process_frame


func _ref(img: Image, mode: String, scene: String) -> bool:
        var path := ProjectSettings.globalize_path("res://tests/ref/%s_ref.png" % scene)
        DirAccess.make_dir_recursive_absolute(path.get_base_dir())
        if mode == "save":
                img.save_png(path)
                print("REF: saved ", path, " ", img.get_size())
                return true
        if not FileAccess.file_exists(path):
                print("REF: no reference at ", path, " - run --ref=save first")
                return false
        var ref := Image.load_from_file(path)
        if ref == null or ref.get_size() != img.get_size():
                print("REF: DRIFT (size mismatch)")
                return false
        var a := img.get_data()
        var b := ref.get_data()
        if a.size() != b.size():
                print("REF: DRIFT (format mismatch)")
                return false
        var drift := 0
        var px := a.size() / 4
        for i in range(0, a.size(), 4):
                if absi(a[i] - b[i]) > 8 or absi(a[i + 1] - b[i + 1]) > 8 \
                                or absi(a[i + 2] - b[i + 2]) > 8:
                        drift += 1
        var pct := 100.0 * drift / float(px)
        if pct <= 0.5:
                print("REF: MATCH (%.2f%% off)" % pct)
                return true
        print("REF: DRIFT %.2f%% of pixels beyond 8/255" % pct)
        return false


func _ray_normal(cam: Camera3D, uv: Vector2) -> Vector3:
        # the tube upscales 480x270 to the window; pick in tube pixels
        return cam.project_ray_normal(Vector2(uv.x * 480.0, uv.y * 270.0)).normalized()


func _strip(inst: Node, part: String) -> void:
        match part:
                "pause":
                        if inst.get("_pause") != null:
                                (inst.get("_pause") as Node).queue_free()
                "player":
                        if inst.get("_player") != null:
                                (inst.get("_player") as Node).queue_free()
                "hud":
                        if inst.get("_hud") != null:
                                (inst.get("_hud") as Node).queue_free()
                "grain":
                        for c in inst.get_children():
                                if c is CanvasLayer and c.layer == 60:
                                        c.queue_free()
                "marks":
                        for m in inst.get("_room").get("_markers"):
                                (m as MeshInstance3D).visible = false
        print("CAPTURE: stripped ", part)


func _frames(n: int) -> void:
        for i in n:
                await get_tree().process_frame


func _snap(img: Image, path: String) -> void:
        img.save_png(path)
        print("CAPTURE: saved ", path, " ", img.get_size())
        var colors := {}
        for y in [0, 180, 360, 540, 710]:
                for x in [0, 320, 640, 960, 1270]:
                        var c := img.get_pixel(x, y)
                        colors[c.to_html()] = colors.get(c.to_html(), 0) + 1
        print("CAPTURE: samples ", colors)
