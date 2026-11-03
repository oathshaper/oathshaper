use oathshaper_core::flow::FlowGame;
use serde_json::{json, Value};
fn send(g: &mut FlowGame, a: Value) -> Value {
    let v = g.view();
    g.submit(json!({"schema":"flow.action/v1","generation":v["session"]["generation"],"expected_revision":v["session"]["revision"],"command_id":format!("test-{}",v["session"]["ledger_sequence"].as_str().unwrap()),"action":a})).unwrap()
}
fn ok(g: &mut FlowGame, a: Value) -> Value {
    let v = send(g, a);
    assert_eq!(v["receipt"]["status"], "accepted", "{v}");
    v
}
fn actor(g: &FlowGame, id: &str) -> Value {
    g.view()["actors"]
        .as_array()
        .unwrap()
        .iter()
        .find(|a| a["id"] == id)
        .unwrap()
        .clone()
}
fn tick(g: &mut FlowGame, to: u64) {
    for _ in 0..1000 {
        if g.view()["session"]["tick"].as_u64().unwrap() >= to {
            return;
        }
        g.observe_fixture().unwrap();
        let v = g.advance(1).unwrap();
        assert_ne!(v["stop_reason"], "rejected", "{v}");
        assert_ne!(v["stop_reason"], "paused", "{v}");
    }
    panic!("stalled {}", g.view());
}
// Close-range fixture for isolated verb/geometry tests. The real encounter's
// wider starting formation and pacing have separate regression tests below.
fn mechanics_fixture(seed: u64) -> Result<FlowGame, Box<dyn std::error::Error>> {
    let mut g = FlowGame::new(seed)?;
    let mut save: Value = serde_json::from_str(&g.save_json()?)?;
    let mut inner: Value = serde_json::from_str(save["session"].as_str().unwrap())?;
    for (id, pos) in [
        ("player", [0, 0]),
        ("mara", [-2000, 2000]),
        ("ivo", [-7000, 0]),
        ("hound", [1600, 0]),
        ("sentinel", [3000, 2000]),
        ("corsair_raider", [6000, 0]),
    ] {
        inner["state"]["actors"][id]["position"] = json!(pos);
    }
    inner["state"]["actors"]["hound"]["guard"] = json!(false);
    save["session"] = json!(inner.to_string());
    g.restore_json(&save.to_string())?;
    let frame = oathshaper_core::command::space::fixture_frame(&g.space_requests(), 1)?;
    inner["state"]["observations"] = json!(frame
        .results
        .into_iter()
        .map(|v| (v.request_id.clone(), v))
        .collect::<std::collections::BTreeMap<_, _>>());
    save["session"] = json!(inner.to_string());
    g.restore_json(&save.to_string())?;
    let token = g.view()["clock"]["restore_token"].clone();
    ok(&mut g, json!({"kind":"resume","token":token}));
    Ok(g)
}
#[test]
fn four_presets_and_atomic_gem_requirements() {
    let mut g = mechanics_fixture(1).unwrap();
    assert_eq!(actor(&g, "player")["health"]["maximum"], 160);
    let before = g.view();
    assert_eq!(
        send(
            &mut g,
            json!({"kind":"equip","item_id":"rain-1","socket":0})
        )["receipt"]["status"],
        "rejected"
    );
    assert_eq!(g.view()["inventory"], before["inventory"]);
    ok(
        &mut g,
        json!({"kind":"equip","item_id":"stone-1","socket":0}),
    );
    assert_eq!(actor(&g, "player")["health"]["maximum"], 180);
    assert_eq!(actor(&g, "player")["health"]["current"], 160);
    assert_eq!(
        send(&mut g, json!({"kind":"preset","preset":"gale"}))["receipt"]["status"],
        "rejected"
    );
    ok(&mut g, json!({"kind":"unequip","socket":0}));
    ok(&mut g, json!({"kind":"preset","preset":"gale"}));
    assert_eq!(actor(&g, "player")["chi"]["maximum"], 70);
    assert_eq!(actor(&g, "player")["chi"]["current"], 40);
}
#[test]
fn missing_verb_is_not_a_cross_style_attack() {
    let mut g = mechanics_fixture(1).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    ok(&mut g, json!({"kind":"style","style":"gale"}));
    let before = actor(&g, "player");
    assert_eq!(
        send(&mut g, json!({"kind":"attack","verb":"power"}))["receipt"]["status"],
        "rejected"
    );
    assert_eq!(actor(&g, "player"), before);
    ok(&mut g, json!({"kind":"attack","verb":"normal"}));
    assert_eq!(actor(&g, "player")["chi"]["current"], 32);
    tick(&mut g, 12);
    assert!(actor(&g, "hound")["health"]["current"].as_i64().unwrap() < 120);
}
#[test]
fn focus_pause_exit_and_support_budget_persist() {
    let mut g = mechanics_fixture(2).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    ok(&mut g, json!({"kind":"focus","enabled":true}));
    assert_eq!(actor(&g, "player")["focus"]["current"], 38);
    ok(&mut g, json!({"kind":"pause","token":"ledger"}));
    assert_eq!(g.advance(20).unwrap()["consumed_ticks"], 0);
    ok(&mut g, json!({"kind":"unpause","token":"ledger"}));
    tick(&mut g, 4);
    ok(&mut g, json!({"kind":"focus","enabled":false}));
    tick(&mut g, 5);
    assert_eq!(actor(&g, "player")["focus"]["current"], 38);
    let save = g.save_json().unwrap();
    let before = actor(&g, "player");
    g.restore_json(&save).unwrap();
    assert_eq!(g.advance(1).unwrap()["stop_reason"], "paused");
    let token = g.view()["clock"]["restore_token"].clone();
    ok(&mut g, json!({"kind":"resume","token":token}));
    assert_eq!(actor(&g, "player"), before);
}
#[test]
fn support_to_martial_power_has_real_bonus_and_paid_cancel() {
    let mut g = mechanics_fixture(3).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    ok(&mut g, json!({"kind":"style","style":"still"}));
    ok(&mut g, json!({"kind":"attack","verb":"power"}));
    assert_eq!(actor(&g, "player")["chi"]["current"], 34);
    tick(&mut g, 19);
    ok(&mut g, json!({"kind":"style","style":"stone"}));
    ok(&mut g, json!({"kind":"attack","verb":"power"}));
    tick(&mut g, 31);
    assert_eq!(actor(&g, "hound")["health"]["current"], 62);
    assert!(g.view()["logs"]
        .as_array()
        .unwrap()
        .iter()
        .any(|x| x.as_str().unwrap().contains("Resonance +24")));
}
#[test]
fn speaker_gem_changes_only_its_authored_skill_scores() {
    let mut g = mechanics_fixture(4).unwrap();
    let before = g.view()["hero"]["skill_scores"].clone();
    ok(
        &mut g,
        json!({"kind":"equip","item_id":"pearl-1","socket":0}),
    );
    let after = g.view()["hero"]["skill_scores"].clone();
    assert_eq!(
        after["charm"].as_i64().unwrap(),
        before["charm"].as_i64().unwrap() + 2
    );
    assert_eq!(after["mechanisms"], before["mechanisms"]);
}
#[test]
fn follower_mode_toggle_requires_full_new_support_interval() {
    let mut g = mechanics_fixture(5).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    ok(&mut g, json!({"kind":"style","style":"still"}));
    ok(&mut g, json!({"kind":"attack","verb":"power"}));
    tick(&mut g, 39);
    ok(&mut g, json!({"kind":"follower","mode":"attack"}));
    ok(&mut g, json!({"kind":"follower","mode":"support"}));
    tick(&mut g, 40);
    assert_eq!(actor(&g, "player")["chi"]["current"], 34);
    assert_eq!(g.view()["follower"]["support_remaining"], 12);
    tick(&mut g, 79);
    assert_eq!(actor(&g, "player")["chi"]["current"], 36);
    assert_eq!(g.view()["follower"]["support_remaining"], 10);
}
#[test]
fn startup_cancel_keeps_weapon_payment_and_restore_rejects_bad_pose() {
    let mut g = mechanics_fixture(6).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    ok(&mut g, json!({"kind":"style","style":"harbor"}));
    ok(&mut g, json!({"kind":"attack","verb":"power"}));
    ok(&mut g, json!({"kind":"style","style":"stone"}));
    assert!(actor(&g, "player")["active_action"].is_null());
    assert_eq!(actor(&g, "player")["focus"]["current"], 30);
    let saved = g.save_json().unwrap();
    let mut document: Value = serde_json::from_str(&saved).unwrap();
    let mut session: Value = serde_json::from_str(document["session"].as_str().unwrap()).unwrap();
    session["state"]["actors"]["player"]["position"] = json!([i64::MIN, 0]);
    document["session"] = json!(session.to_string());
    assert!(g.restore_json(&document.to_string()).is_err());
    assert_eq!(g.save_json().unwrap(), saved);
}
#[test]
fn duplicate_paid_action_does_not_spend_twice() {
    let mut g = mechanics_fixture(7).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    ok(&mut g, json!({"kind":"style","style":"gale"}));
    let v = g.view();
    let action = json!({"schema":"flow.action/v1","command_id":"same","generation":v["session"]["generation"],"expected_revision":v["session"]["revision"],"action":{"kind":"attack","verb":"normal"}});
    let first = g.submit(action.clone()).unwrap();
    let before = g.save_json().unwrap();
    assert_eq!(g.submit(action).unwrap()["receipt"], first["receipt"]);
    assert_eq!(g.save_json().unwrap(), before);
    assert_eq!(actor(&g, "player")["chi"]["current"], 32);
}
#[test]
fn harbor_sweep_respects_front_arc() {
    let mut g = mechanics_fixture(8).unwrap();
    let mut save: Value = serde_json::from_str(&g.save_json().unwrap()).unwrap();
    let mut session: Value = serde_json::from_str(save["session"].as_str().unwrap()).unwrap();
    session["state"]["actors"]["sentinel"]["position"] = json!([-1000, 0]);
    save["session"] = json!(session.to_string());
    g.restore_json(&save.to_string()).unwrap();
    let token = g.view()["clock"]["restore_token"].clone();
    ok(&mut g, json!({"kind":"resume","token":token}));
    ok(&mut g, json!({"kind":"start"}));
    ok(&mut g, json!({"kind":"style","style":"harbor"}));
    ok(&mut g, json!({"kind":"attack","verb":"normal"}));
    tick(&mut g, 7);
    assert_eq!(actor(&g, "hound")["health"]["current"], 96);
    assert_eq!(actor(&g, "sentinel")["health"]["current"], 96);
}

#[test]
fn projectile_restore_validates_complete_snapshot_atomically() {
    let mut g = mechanics_fixture(20).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    ok(&mut g, json!({"kind":"focus","enabled":true}));
    ok(&mut g, json!({"kind":"style","style":"gale"}));
    ok(&mut g, json!({"kind":"attack","verb":"normal"}));
    tick(&mut g, 7);
    let saved = g.save_json().unwrap();
    let document: Value = serde_json::from_str(&saved).unwrap();
    let session: Value = serde_json::from_str(document["session"].as_str().unwrap()).unwrap();
    assert!(!session["state"]["projectiles"]
        .as_array()
        .unwrap()
        .is_empty());
    for (field, value) in [
        ("owner", json!("missing")),
        ("target", json!("missing")),
        ("target", json!("player")),
        ("destination", json!([i64::MIN, 0])),
        ("remaining", json!(0)),
        ("remaining", json!(u64::MAX)),
        ("damage", json!(-1)),
        ("damage", json!(i64::MAX)),
        ("id", json!("")),
        ("id", json!("action-999999")),
    ] {
        let mut bad = document.clone();
        let mut inner = session.clone();
        inner["state"]["projectiles"][0][field] = value;
        bad["session"] = json!(inner.to_string());
        assert!(
            g.restore_json(&bad.to_string()).is_err(),
            "accepted {field}"
        );
        assert_eq!(g.save_json().unwrap(), saved);
    }
    let mut duplicate = session.clone();
    let projectile = duplicate["state"]["projectiles"][0].clone();
    duplicate["state"]["projectiles"]
        .as_array_mut()
        .unwrap()
        .push(projectile);
    let mut bad = document.clone();
    bad["session"] = json!(duplicate.to_string());
    assert!(g.restore_json(&bad.to_string()).is_err());
    assert_eq!(g.save_json().unwrap(), saved);
    g.restore_json(&saved).unwrap();
    let token = g.view()["clock"]["restore_token"].clone();
    ok(&mut g, json!({"kind":"resume","token":token}));
    tick(&mut g, 14);
}

#[test]
fn turning_palm_cooldown_only_blocks_area_and_still_remains_shared() {
    let mut g = mechanics_fixture(21).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    ok(&mut g, json!({"kind":"move","direction":[1,0]}));
    tick(&mut g, 1);
    ok(&mut g, json!({"kind":"move","direction":[0,0]}));
    ok(&mut g, json!({"kind":"attack","verb":"area"}));
    ok(&mut g, json!({"kind":"style","style":"gale"}));
    ok(&mut g, json!({"kind":"style","style":"stone"}));
    let saved = g.save_json().unwrap();
    assert_eq!(
        send(&mut g, json!({"kind":"attack","verb":"area"}))["receipt"]["status"],
        "rejected"
    );
    ok(&mut g, json!({"kind":"attack","verb":"normal"}));
    g.restore_json(&saved).unwrap();
    let token = g.view()["clock"]["restore_token"].clone();
    ok(&mut g, json!({"kind":"resume","token":token}));
    ok(&mut g, json!({"kind":"attack","verb":"power"}));
    ok(&mut g, json!({"kind":"style","style":"still"}));
    ok(&mut g, json!({"kind":"attack","verb":"normal"}));
    ok(&mut g, json!({"kind":"style","style":"gale"}));
    ok(&mut g, json!({"kind":"style","style":"still"}));
    assert_eq!(
        send(&mut g, json!({"kind":"attack","verb":"power"}))["receipt"]["status"],
        "rejected"
    );
}

fn impact_geometry_case(projectile: bool, move_clear: bool, old_clear: bool, new_clear: bool) {
    let mut g = mechanics_fixture(22).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    tick(&mut g, 1); // Avoid the separate AI decision boundary in this observation probe.
    ok(&mut g, json!({"kind":"attack","verb":"power"}));
    let mut save: Value = serde_json::from_str(&g.save_json().unwrap()).unwrap();
    let mut inner: Value = serde_json::from_str(save["session"].as_str().unwrap()).unwrap();
    for id in [
        "player",
        "mara",
        "ivo",
        "hound",
        "sentinel",
        "corsair_raider",
    ] {
        inner["state"]["actors"][id]["direction"] = json!([0, 0]);
        if id != "player" {
            inner["state"]["actors"][id]["active"] = Value::Null;
        }
    }
    inner["state"]["actors"]["hound"]["direction"] = json!([0, 1000]);
    inner["state"]["actors"]["hound"]["guard"] = json!(false);
    let destination = inner["state"]["actors"]["hound"]["position"].clone();
    if projectile {
        let id = inner["state"]["actors"]["player"]["active"]["id"].clone();
        inner["state"]["actors"]["player"]["active"] = Value::Null;
        inner["state"]["projectiles"] = json!([{"id":id,"owner":"player","target":"hound","destination":destination,"remaining":2,"damage":24}]);
    } else {
        let action = &mut inner["state"]["actors"]["player"]["active"];
        action["elapsed"] = json!(action["startup"].as_u64().unwrap() - 2);
    }
    save["session"] = json!(inner.to_string());
    g.restore_json(&save.to_string()).unwrap();
    let token = g.view()["clock"]["restore_token"].clone();
    ok(&mut g, json!({"kind":"resume","token":token}));
    let requests = g.space_requests();
    let mut frame = oathshaper_core::command::space::fixture_frame(
        &requests,
        g.next_observation_sequence("headless-garden"),
    )
    .unwrap();
    let old_z = destination[1].as_i64().unwrap();
    let mut variants = 0;
    for result in &mut frame.results {
        let request = requests.iter().find(|q| q.id == result.request_id).unwrap();
        if request.id == "move:hound" {
            result.clear = Some(move_clear);
        }
        if request.kind == "los"
            && request.actor_id == "player"
            && request.target_actor_id.as_deref() == Some("hound")
        {
            variants += 1;
            result.clear = Some(if request.to_mm[1] == old_z {
                old_clear
            } else {
                new_clear
            });
        }
    }
    assert_eq!(
        variants, 2,
        "Host must observe both possible target endpoints"
    );
    g.observe_space(frame).unwrap();
    assert_eq!(g.advance(1).unwrap()["consumed_ticks"], 1);
    let landed = if move_clear { new_clear } else { old_clear };
    assert_eq!(
        actor(&g, "hound")["health"]["current"].as_i64().unwrap() < 120,
        landed
    );
    assert_eq!(
        actor(&g, "hound")["position"][1].as_f64().unwrap(),
        (old_z + if move_clear { 90 } else { 0 }) as f64 / 1000.0
    );
}

#[test]
fn melee_impact_uses_committed_pose_los_and_blocked_sweep_fallback() {
    impact_geometry_case(false, true, true, false);
    impact_geometry_case(false, true, false, true);
    impact_geometry_case(false, false, true, false);
}
#[test]
fn projectile_impact_uses_committed_pose_los_and_blocked_sweep_fallback() {
    impact_geometry_case(true, true, true, false);
    impact_geometry_case(true, true, false, true);
    impact_geometry_case(true, false, true, false);
}

#[test]
fn turning_palm_push_uses_sweep_from_the_committed_endpoint_pair() {
    for new_clear in [false, true] {
        let mut g = mechanics_fixture(23).unwrap();
        ok(&mut g, json!({"kind":"start"}));
        ok(&mut g, json!({"kind":"move","direction":[1,0]}));
        tick(&mut g, 1);
        ok(&mut g, json!({"kind":"attack","verb":"area"}));
        let mut save: Value = serde_json::from_str(&g.save_json().unwrap()).unwrap();
        let mut inner: Value = serde_json::from_str(save["session"].as_str().unwrap()).unwrap();
        for id in ["player", "hound"] {
            inner["state"]["actors"][id]["direction"] = json!([0, 1000]);
        }
        inner["state"]["actors"]["hound"]["guard"] = json!(false);
        inner["state"]["actors"]["hound"]["active"] = Value::Null;
        let action = &mut inner["state"]["actors"]["player"]["active"];
        action["elapsed"] = json!(action["startup"].as_u64().unwrap() - 2);
        save["session"] = json!(inner.to_string());
        g.restore_json(&save.to_string()).unwrap();
        let token = g.view()["clock"]["restore_token"].clone();
        ok(&mut g, json!({"kind":"resume","token":token}));
        ok(&mut g, json!({"kind":"move","direction":[0,1]}));
        let requests = g.space_requests();
        let mut frame = oathshaper_core::command::space::fixture_frame(
            &requests,
            g.next_observation_sequence("headless-garden"),
        )
        .unwrap();
        let mut variants = 0;
        for result in &mut frame.results {
            let q = requests.iter().find(|q| q.id == result.request_id).unwrap();
            if q.id.starts_with("push:player:hound:") {
                variants += 1;
                result.clear = Some(if q.from_mm[1] == 90 {
                    new_clear
                } else {
                    !new_clear
                });
            }
        }
        assert_eq!(variants, 4);
        g.observe_space(frame).unwrap();
        assert_eq!(g.advance(1).unwrap()["consumed_ticks"], 1);
        let at = actor(&g, "hound")["position"].clone();
        let traveled = (at[0].as_f64().unwrap() - 1.6).hypot(at[1].as_f64().unwrap() - 0.09);
        assert_eq!(traveled > 0.9, new_clear);
    }
}

#[test]
fn authored_flow_roster_and_opening_are_readable() {
    let mut g = FlowGame::new(41).unwrap();
    let v = g.view();
    assert_eq!(v["actors"].as_array().unwrap().len(), 6);
    for (id, model) in [
        ("hound", "lantern_sentinel"),
        ("sentinel", "iron_sentinel"),
        ("corsair_raider", "crimson_corsair"),
    ] {
        assert_eq!(actor(&g, id)["appearance"]["model"], model);
    }
    assert_eq!(actor(&g, "ivo")["appearance"]["offhand"], "buckler");
    ok(&mut g, json!({"kind":"start"}));
    tick(&mut g, 59);
    for id in ["player", "mara", "ivo"] {
        let a = actor(&g, id);
        assert_eq!(
            a["health"]["current"], a["health"]["maximum"],
            "No hits during opening: {id}"
        );
    }
    tick(&mut g, 300);
    for id in ["player", "mara", "ivo"] {
        assert_eq!(
            actor(&g, id)["conscious"],
            true,
            "{id} fell in the first fifteen seconds"
        );
    }
    assert_eq!(g.view()["session"]["phase"], "encounter");
    assert!(
        actor(&g, "mara")["chi"]["current"].as_i64().unwrap() < 40,
        "Mara must actually spend Chi healing an injured ally"
    );
}

#[test]
fn harbor_blade_draws_the_sabre_and_other_styles_empty_the_hand() {
    let mut g = FlowGame::new(43).unwrap();
    ok(&mut g, json!({"kind":"style","style":"harbor"}));
    assert_eq!(actor(&g, "player")["appearance"]["main_hand"], "sabre");
    assert_eq!(actor(&g, "mara")["appearance"]["main_hand"], "staff");
    for style in ["stone", "gale", "still"] {
        ok(&mut g, json!({"kind":"style","style":style}));
        assert_eq!(actor(&g, "player")["appearance"]["main_hand"], "unarmed");
    }
}

#[test]
fn fallen_target_hands_off_without_overriding_live_manual_selection() {
    let mut g = mechanics_fixture(44).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    // A living manual target remains selected even with a closer opponent.
    ok(&mut g, json!({"kind":"target","actor_id":"corsair_raider"}));
    tick(&mut g, 1);
    assert_eq!(g.view()["hero"]["target_id"], "corsair_raider");
    ok(&mut g, json!({"kind":"target","actor_id":"hound"}));
    for _ in 0..300 {
        if !actor(&g, "hound")["conscious"].as_bool().unwrap() {
            break;
        }
        if actor(&g, "player")["active_action"].is_null() {
            send(&mut g, json!({"kind":"attack","verb":"power"}));
        }
        g.observe_fixture().unwrap();
        g.advance(1).unwrap();
    }
    assert_eq!(actor(&g, "hound")["conscious"], false);
    let selected = g.view()["hero"]["target_id"].as_str().unwrap().to_owned();
    assert_ne!(selected, "hound");
    assert_eq!(actor(&g, &selected)["conscious"], true);
    assert_eq!(g.view()["party"]["selected_target_id"], selected);

    // An older v2 save can contain the fallen target: display and subsequent
    // attack admission must agree on the replacement before another tick.
    let mut save: Value = serde_json::from_str(&g.save_json().unwrap()).unwrap();
    let mut inner: Value = serde_json::from_str(save["session"].as_str().unwrap()).unwrap();
    inner["state"]["target"] = json!("hound");
    inner["state"]["actors"]["player"]["active"] = Value::Null;
    save["session"] = json!(inner.to_string());
    g.restore_json(&save.to_string()).unwrap();
    assert_eq!(g.view()["hero"]["target_id"], selected);
    let token = g.view()["clock"]["restore_token"].clone();
    ok(&mut g, json!({"kind":"resume","token":token}));
    ok(&mut g, json!({"kind":"style","style":"gale"}));
    assert!(g.view()["verbs"][0]["available"].as_bool().unwrap());
    ok(&mut g, json!({"kind":"attack","verb":"normal"}));
    assert_eq!(
        actor(&g, "player")["active_action"]["target"]["actor_id"],
        selected
    );
}

#[test]
fn authored_flow_can_be_won_with_support_and_reacting_to_guard() {
    let mut g = FlowGame::new(42).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    let mut decision = u64::MAX;
    for _ in 0..4000 {
        let v = g.view();
        if v["session"]["phase"] == "victory" {
            break;
        }
        if v["session"]["phase"] == "surrender" {
            ok(&mut g, json!({"kind":"surrender","accept":true}));
            break;
        }
        assert_ne!(v["session"]["phase"], "defeat");
        let t = v["session"]["tick"].as_u64().unwrap();
        if t.is_multiple_of(5) && t != decision {
            decision = t;
            let hero = actor(&g, "player");
            let x = hero["position"][0].as_f64().unwrap();
            let z = hero["position"][1].as_f64().unwrap();
            let distance = |a: &Value| {
                (a["position"][0].as_f64().unwrap() - x)
                    .hypot(a["position"][1].as_f64().unwrap() - z)
            };
            if let Some(target) = v["actors"]
                .as_array()
                .unwrap()
                .iter()
                .filter(|a| a["faction"] == "hostile" && a["conscious"] == true)
                .min_by(|a, b| distance(a).total_cmp(&distance(b)))
            {
                ok(&mut g, json!({"kind":"target","actor_id":target["id"]}));
                let d = distance(target);
                let direction = if d > 1.4 {
                    [
                        (target["position"][0].as_f64().unwrap() - x) / d,
                        (target["position"][1].as_f64().unwrap() - z) / d,
                    ]
                } else {
                    [0., 0.]
                };
                ok(&mut g, json!({"kind":"move","direction":direction}));
                if hero["active_action"].is_null() {
                    send(
                        &mut g,
                        json!({"kind":"attack","verb":if target["guard"]==true{"power"}else{"normal"}}),
                    );
                }
            }
        }
        g.observe_fixture().unwrap();
        let advance = g.advance(1).unwrap();
        assert_ne!(advance["stop_reason"], "rejected");
    }
    assert_eq!(g.view()["encounter"]["won"], true);
    assert_eq!(g.view()["hero"]["target_id"], "");
    assert_eq!(g.view()["party"]["selected_target_id"], "");
    let seconds = g.view()["session"]["tick"].as_u64().unwrap() as f64 * 0.05;
    println!(
        "Flow support-route victory: {seconds:.2}s; Mara {}, Ivo {}",
        actor(&g, "mara")["health"]["current"],
        actor(&g, "ivo")["health"]["current"]
    );
    assert!(
        (12. ..90.).contains(&seconds),
        "Encounter resolved outside the demo pacing budget: {seconds}"
    );
    assert_eq!(actor(&g, "mara")["conscious"], true);
}

#[test]
fn idle_dodge_ends_without_latching_backward_walk() {
    let mut g = FlowGame::new(50).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    let before = actor(&g, "player")["position"].clone();
    ok(&mut g, json!({"kind":"dodge"}));
    tick(&mut g, 12);
    let landed = actor(&g, "player")["position"].clone();
    assert_ne!(before, landed, "Idle dodge still travels");
    tick(&mut g, 35);
    assert_eq!(
        actor(&g, "player")["position"],
        landed,
        "No idle drift after dodge"
    );
    ok(&mut g, json!({"kind":"move","direction":[0,1]}));
    tick(&mut g, 36);
    assert_ne!(
        actor(&g, "player")["position"],
        landed,
        "Fresh movement still works"
    );
}
#[test]
fn harbor_basic_is_free_and_focus_recovers_on_simulation_clock() {
    let mut g = mechanics_fixture(51).unwrap();
    ok(&mut g, json!({"kind":"start"}));
    ok(&mut g, json!({"kind":"style","style":"harbor"}));
    ok(&mut g, json!({"kind":"attack","verb":"normal"}));
    assert_eq!(actor(&g, "player")["focus"]["current"], 40);
    // Cancel windup and exhaust Focus with paid power attacks, before time moves.
    for _ in 0..4 {
        ok(&mut g, json!({"kind":"style","style":"stone"}));
        ok(&mut g, json!({"kind":"style","style":"harbor"}));
        ok(&mut g, json!({"kind":"attack","verb":"power"}));
    }
    ok(&mut g, json!({"kind":"style","style":"stone"}));
    ok(&mut g, json!({"kind":"style","style":"harbor"}));
    assert_eq!(actor(&g, "player")["focus"]["current"], 0);
    ok(&mut g, json!({"kind":"attack","verb":"normal"}));
    tick(&mut g, 39);
    assert_eq!(actor(&g, "player")["focus"]["current"], 0);
    ok(&mut g, json!({"kind":"pause","token":"manual"}));
    assert_eq!(g.advance(100).unwrap()["consumed_ticks"], 0);
    assert_eq!(actor(&g, "player")["focus"]["current"], 0);
    let save = g.save_json().unwrap();
    g.restore_json(&save).unwrap();
    let token = g.view()["clock"]["restore_token"].clone();
    ok(&mut g, json!({"kind":"resume","token":token}));
    tick(&mut g, 40);
    assert_eq!(actor(&g, "player")["focus"]["current"], 1);
    tick(&mut g, 55);
    assert_eq!(actor(&g, "player")["focus"]["current"], 4);
    ok(&mut g, json!({"kind":"focus","enabled":true}));
    tick(&mut g, 60);
    assert_eq!(
        actor(&g, "player")["focus"]["current"],
        0,
        "No recovery during slow time"
    );
}
