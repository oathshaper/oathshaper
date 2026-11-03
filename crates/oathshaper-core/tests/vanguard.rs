use oathshaper_core::vanguard::{Frame, Intent, VanguardGame};
use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet};
fn send(g: &mut VanguardGame, value: Value) -> Value {
    g.submit(serde_json::from_value::<Intent>(value).unwrap())
        .unwrap()
}
fn frame(g: &VanguardGame, aim: Option<&str>, sight: bool) -> Frame {
    let v = g.view();
    let actors = v["actors"].as_object().unwrap();
    Frame {
        tick: v["tick"].as_u64().unwrap(),
        sequence: v["sequence"].as_u64().unwrap() + 1,
        positions: actors
            .iter()
            .map(|(id, a)| {
                (
                    id.clone(),
                    serde_json::from_value(a["position"].clone()).unwrap(),
                )
            })
            .collect::<BTreeMap<_, _>>(),
        sight: if sight {
            actors
                .keys()
                .flat_map(|a| {
                    actors
                        .keys()
                        .filter(move |b| *b != a)
                        .map(move |b| format!("{a}:{b}"))
                })
                .collect()
        } else {
            BTreeSet::new()
        },
        aim: aim.map(str::to_string),
        cover: BTreeSet::new(),
    }
}
fn tick(g: &mut VanguardGame, n: usize, aim: Option<&str>, sight: bool) {
    for _ in 0..n {
        let f = frame(g, aim, sight);
        assert_eq!(g.advance(f).unwrap()["receipt"]["status"], "accepted");
    }
}
fn start() -> VanguardGame {
    let mut g = VanguardGame::new().unwrap();
    send(&mut g, json!({"kind":"begin"}));
    tick(&mut g, 1, Some("hound"), true);
    g
}
#[test]
fn powered_shots_require_drawn_weapon_and_exposed_cover() {
    for covered in [false, true] {
        let mut g = start();
        if covered {
            let mut f = frame(&g, Some("hound"), true);
            f.cover.insert("player".into());
            g.advance(f).unwrap();
            send(&mut g, json!({"kind":"cover"}));
        } else {
            send(&mut g, json!({"kind":"holster"}));
            tick(&mut g, 18, Some("hound"), true);
        }
        let before = g.view();
        let receipt = send(
            &mut g,
            json!({"kind":"power","actor":"player","power":"concussive_shot","target":"hound"}),
        );
        assert_eq!(receipt["receipt"]["status"], "rejected");
        assert_eq!(g.view()["actors"], before["actors"]);
        assert_eq!(g.view()["shots"], before["shots"]);
    }
}
#[test]
fn extreme_observed_coordinates_reject_without_advancing_authority() {
    for position in [[i32::MAX, 0], [i32::MIN, i32::MAX]] {
        let mut g = start();
        let before = g.view();
        let mut f = frame(&g, Some("hound"), true);
        f.positions.insert("player".into(), position);
        let result = g.advance(f).unwrap();
        assert_eq!(result["receipt"]["status"], "rejected");
        let after = g.view();
        assert_eq!(after["actors"], before["actors"]);
        assert_eq!(after["tick"], before["tick"]);
        assert_eq!(after["sequence"], before["sequence"]);
    }
}
#[test]
fn pause_owners_freeze_heat_cooldown_and_tick() {
    let mut g = start();
    send(&mut g, json!({"kind":"trigger","pressed":true}));
    tick(&mut g, 1, None, false);
    send(
        &mut g,
        json!({"kind":"pause","owner":"wheel","paused":true}),
    );
    send(&mut g, json!({"kind":"pause","owner":"menu","paused":true}));
    let old = g.view();
    tick(&mut g, 120, None, false);
    assert_eq!(g.view()["tick"], old["tick"]);
    assert_eq!(g.view()["actors"], old["actors"]);
    send(
        &mut g,
        json!({"kind":"pause","owner":"wheel","paused":false}),
    );
    assert_eq!(g.view()["paused"], true);
    send(
        &mut g,
        json!({"kind":"pause","owner":"menu","paused":false}),
    );
    assert_eq!(g.view()["paused"], false);
}
#[test]
fn overheat_latches_until_thirty_and_switch_does_not_reset() {
    let mut g = start();
    send(&mut g, json!({"kind":"trigger","pressed":true}));
    tick(&mut g, 92, None, false);
    let v = g.view();
    assert_eq!(v["actors"]["player"]["weapons"][0]["latched"], true);
    assert_eq!(v["actors"]["player"]["weapons"][0]["heat"], 6000);
    send(&mut g, json!({"kind":"trigger","pressed":false}));
    tick(&mut g, 6, None, false);
    let heat = g.view()["actors"]["player"]["weapons"][0]["heat"].clone();
    assert_eq!(
        send(&mut g, json!({"kind":"swap"}))["receipt"]["status"],
        "accepted"
    );
    assert_eq!(g.view()["actors"]["player"]["weapons"][0]["heat"], heat);
    tick(&mut g, 210, None, false);
    assert_eq!(g.view()["actors"]["player"]["weapons"][0]["latched"], true);
    tick(&mut g, 30, None, false);
    assert_eq!(g.view()["actors"]["player"]["weapons"][0]["latched"], false);
}
#[test]
fn stale_and_teleport_observations_are_atomic() {
    let mut g = start();
    let mut f = frame(&g, None, false);
    f.tick = 0;
    let before = g.view();
    assert_eq!(g.advance(f).unwrap()["receipt"]["status"], "rejected");
    assert_eq!(g.view(), before);
    let mut f = frame(&g, None, false);
    f.positions.insert("player".into(), [13000, 0]);
    assert_eq!(g.advance(f).unwrap()["receipt"]["status"], "rejected");
    assert_eq!(g.view(), before);
    tick(&mut g, 1, None, false);
}
#[test]
fn shields_gate_biotics_and_overload_has_no_health_overflow() {
    let mut g = start();
    assert_eq!(
        send(
            &mut g,
            json!({"kind":"power","actor":"ivo","power":"kinetic_throw","target":"hound"})
        )["receipt"]["status"],
        "rejected"
    );
    assert_eq!(
        send(
            &mut g,
            json!({"kind":"power","actor":"mara","power":"arc_overload","target":"hound"})
        )["receipt"]["status"],
        "accepted"
    );
    tick(&mut g, 13, Some("hound"), true);
    let v = g.view();
    assert_eq!(v["actors"]["hound"]["shields"], 0);
    assert!(
        v["actors"]["mara"]["cooldowns"]["arc_overload"]
            .as_u64()
            .unwrap()
            > v["tick"].as_u64().unwrap()
    );
    tick(&mut g, 6, Some("hound"), true);
    assert_eq!(
        send(
            &mut g,
            json!({"kind":"power","actor":"ivo","power":"kinetic_throw","target":"hound"})
        )["receipt"]["status"],
        "accepted"
    );
    tick(&mut g, 13, Some("hound"), true);
    assert!(
        g.view()["actors"]["hound"]["stunned"].as_u64().unwrap()
            > g.view()["tick"].as_u64().unwrap()
    );
}
#[test]
fn preactivation_invalidation_costs_nothing_but_effect_miss_keeps_cooldown() {
    let mut g = start();
    send(
        &mut g,
        json!({"kind":"power","actor":"mara","power":"arc_overload","target":"hound"}),
    );
    tick(&mut g, 1, None, false);
    assert!(g.view()["actors"]["mara"]["cooldowns"]
        .as_object()
        .unwrap()
        .is_empty());
    tick(&mut g, 1, Some("hound"), true);
    send(
        &mut g,
        json!({"kind":"power","actor":"mara","power":"arc_overload","target":"hound"}),
    );
    tick(&mut g, 1, Some("hound"), true);
    tick(&mut g, 12, None, false);
    assert!(g.view()["actors"]["mara"]["cooldowns"]
        .get("arc_overload")
        .is_some());
    assert_eq!(g.view()["actors"]["hound"]["shields"], 3600);
}
#[test]
fn modules_change_real_emission_cost_and_combat_edits_reject() {
    let mut g = VanguardGame::new().unwrap();
    assert_eq!(
        send(
            &mut g,
            json!({"kind":"equip","actor":"player","module":"damage"})
        )["receipt"]["status"],
        "accepted"
    );
    send(&mut g, json!({"kind":"begin"}));
    send(&mut g, json!({"kind":"trigger","pressed":true}));
    tick(&mut g, 1, Some("hound"), true);
    assert_eq!(g.view()["actors"]["player"]["weapons"][0]["heat"], 1200);
    assert_eq!(g.view()["actors"]["hound"]["shields"], 2400);
    assert_eq!(
        send(
            &mut g,
            json!({"kind":"equip","actor":"player","module":"cooling"})
        )["receipt"]["status"],
        "rejected"
    );
}
#[test]
fn channel_claim_prevents_duplicate_power_and_cancel_retains_activated_cost() {
    let mut g = start();
    let intent = json!({"kind":"power","actor":"mara","power":"arc_overload","target":"hound"});
    assert_eq!(
        send(&mut g, intent.clone())["receipt"]["status"],
        "accepted"
    );
    assert_eq!(send(&mut g, intent)["receipt"]["status"], "rejected");
    tick(&mut g, 1, Some("hound"), true);
    let cd = g.view()["actors"]["mara"]["cooldowns"].clone();
    send(&mut g, json!({"kind":"cancel","actor":"mara"}));
    assert_eq!(g.view()["actors"]["mara"]["cooldowns"], cd);
    assert!(g.view()["actors"]["mara"]["pending"].is_null());
}

#[test]
fn defeat_stops_the_clock_without_granting_victory() {
    let mut g = start();
    for _ in 0..2400 {
        let mut f = frame(&g, None, false);
        f.sight = BTreeSet::from(["hound:player".into(), "sentinel:player".into()]);
        g.advance(f).unwrap();
        if g.view()["status"] == "lost" {
            break;
        }
    }
    assert_eq!(g.view()["status"], "lost");
    assert_eq!(g.view()["reward"], false);
    let old = g.view()["tick"].clone();
    tick(&mut g, 60, None, true);
    assert_eq!(g.view()["tick"], old);
}

#[test]
fn powered_shot_interruption_retains_cooldown_but_emits_no_heat() {
    let mut g = start();
    let c = json!({"kind":"power","actor":"player","power":"concussive_shot","target":"hound"});
    assert_eq!(send(&mut g, c)["receipt"]["status"], "accepted");
    tick(&mut g, 1, Some("hound"), true);
    send(&mut g, json!({"kind":"cancel","actor":"player"}));
    tick(&mut g, 15, None, false);
    assert_eq!(g.view()["actors"]["player"]["weapons"][0]["heat"], 0);
    assert!(
        g.view()["actors"]["player"]["cooldowns"]["concussive_shot"]
            .as_u64()
            .unwrap()
            > g.view()["tick"].as_u64().unwrap()
    );
}

#[test]
fn holstered_fire_draws_before_emission_and_never_resets_heat() {
    let mut g = start();
    send(&mut g, json!({"kind":"holster"}));
    tick(&mut g, 18, None, false);
    assert_eq!(g.view()["draw"], false);
    send(&mut g, json!({"kind":"trigger","pressed":true}));
    assert_eq!(g.view()["draw"], true);
    tick(&mut g, 17, None, false);
    assert_eq!(g.view()["actors"]["player"]["weapons"][0]["heat"], 0);
    tick(&mut g, 1, None, false);
    assert_eq!(g.view()["actors"]["player"]["weapons"][0]["heat"], 900);
}
