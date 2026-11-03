use oathshaper_core::command::CommandGame;
use serde_json::{json, Value};
fn input(game: &CommandGame, action: Value) -> Value {
    let v = game.view();
    json!({"schema":"command.action/v1","command_id":format!("test-{}",v["session"]["ledger_sequence"].as_str().unwrap()),"generation":v["session"]["generation"],"expected_revision":v["session"]["revision"],"action":action})
}
fn submit(game: &mut CommandGame, action: Value) -> Value {
    let command = input(game, action);
    game.submit(command).unwrap()
}
fn accepted(game: &mut CommandGame, action: Value) -> Value {
    let result = submit(game, action);
    assert_eq!(result["receipt"]["status"], "accepted", "{result}");
    result
}
fn actor(game: &CommandGame, id: &str) -> Value {
    game.view()["actors"]
        .as_array()
        .unwrap()
        .iter()
        .find(|a| a["id"] == id)
        .unwrap()
        .clone()
}
fn target(id: &str) -> Value {
    json!({"kind":"actor","actor_id":id,"position":null})
}
fn enqueue(
    game: &mut CommandGame,
    actor_id: &str,
    ability: &str,
    source: &str,
    target: Value,
) -> Value {
    accepted(
        game,
        json!({"kind":"queue.enqueue","actor_id":actor_id,"ability_id":ability,"source_id":source,"target":target}),
    )
}
fn start(game: &mut CommandGame) {
    accepted(
        game,
        json!({"kind":"encounter.start","encounter_id":"garden_patrol"}),
    );
}
fn resume(game: &mut CommandGame) {
    let reasons = game.view()["clock"]["pause_reasons"]
        .as_array()
        .unwrap()
        .clone();
    for p in reasons {
        accepted(
            game,
            json!({"kind":if p["acknowledgeable"]==true{"pause.acknowledge"}else{"pause.release"},"token":p["token"]}),
        );
    }
}
fn tick_to(game: &mut CommandGame, until: u64) {
    for _ in 0..((until + 1) * 5 + 20) {
        if game.view()["session"]["tick"].as_u64().unwrap() >= until {
            return;
        }
        game.observe_fixture().unwrap();
        let result = game.advance(1).unwrap();
        assert_ne!(result["stop_reason"], "rejected", "{result}");
        assert_ne!(result["stop_reason"], "paused", "{result}");
    }
    panic!("tick progress stalled: {}", game.view())
}
#[test]
fn cmd01_reservations_nested_pause_and_durable_rejection() {
    let mut g = CommandGame::new(41).unwrap();
    start(&mut g);
    let p = accepted(
        &mut g,
        json!({"kind":"pause.acquire","owner":"ledger","context_id":"sheet"}),
    );
    enqueue(
        &mut g,
        "mara",
        "binding_current",
        "learned:mara:binding_current:1",
        json!({"kind":"point","actor_id":null,"position":[2.,0.]}),
    );
    enqueue(
        &mut g,
        "mara",
        "gale_arc",
        "learned:mara:gale_arc:1",
        target("hound"),
    );
    let mend = enqueue(
        &mut g,
        "mara",
        "mend",
        "learned:mara:mend:1",
        target("player"),
    );
    assert_eq!(
        actor(&g, "mara")["focus"],
        json!({"current":56,"maximum":56,"reserved":44,"free":12,"debt":0})
    );
    let rejected = input(
        &g,
        json!({"kind":"queue.enqueue","actor_id":"mara","ability_id":"veil","source_id":"learned:mara:veil:1","target":{"kind":"self","actor_id":null,"position":null}}),
    );
    let first = g.submit(rejected.clone()).unwrap();
    assert_eq!(first["receipt"]["status"], "rejected");
    accepted(
        &mut g,
        json!({"kind":"queue.remove","actor_id":"mara","action_id":mend["receipt"]["action_id"]}),
    );
    assert_eq!(actor(&g, "mara")["focus"]["reserved"], 28);
    assert_eq!(g.submit(rejected).unwrap()["receipt"], first["receipt"]);
    accepted(
        &mut g,
        json!({"kind":"pause.release","token":p["receipt"]["pause_token"]}),
    );
    assert_eq!(g.view()["clock"]["paused"], true);
    assert_eq!(g.advance(5).unwrap()["consumed_ticks"], 0);
}
#[test]
fn cmd02_paid_stop_keeps_cost_and_readiness() {
    let mut g = CommandGame::new(2).unwrap();
    start(&mut g);
    enqueue(
        &mut g,
        "mara",
        "gale_arc",
        "learned:mara:gale_arc:1",
        target("hound"),
    );
    resume(&mut g);
    tick_to(&mut g, 5);
    assert_eq!(actor(&g, "mara")["focus"]["current"], 46);
    accepted(
        &mut g,
        json!({"kind":"queue.stop_clear","actor_id":"mara","confirm_paid_cost":true}),
    );
    assert!(actor(&g, "mara")["active_action"].is_null());
    assert_eq!(actor(&g, "mara")["focus"]["current"], 46);
    enqueue(
        &mut g,
        "mara",
        "gale_arc",
        "learned:mara:gale_arc:1",
        target("hound"),
    );
    tick_to(&mut g, 29);
    assert!(actor(&g, "mara")["active_action"].is_null());
    tick_to(&mut g, 30);
    assert_eq!(actor(&g, "mara")["active_action"]["activation_at"], 30);
}
#[test]
fn cmd05_equipment_is_atomic_and_projection_authors_occupancy() {
    let mut g = CommandGame::new(3).unwrap();
    let bad = submit(
        &mut g,
        json!({"kind":"equipment.apply","actor_id":"player","expected_binding_version":"1","changes":[{"slot_id":"main_hand","item_id":"staff-9"}],"cancel_action_ids":[]}),
    );
    assert_eq!(bad["receipt"]["status"], "rejected");
    assert_eq!(actor(&g, "player")["stats"]["defense"], 15);
    let option = g.view()["equipment"]["options"]
        .as_array()
        .unwrap()
        .iter()
        .find(|o| o["item_id"] == "staff-9")
        .unwrap()["action"]
        .clone();
    accepted(&mut g, option);
    assert_eq!(actor(&g, "player")["stats"]["defense"], 14);
    assert_eq!(actor(&g, "player")["appearance"]["main_hand"], "staff");
    assert_eq!(g.view()["inventory"]["capacity"], Value::Null);
}
#[test]
fn cmd07_source_and_biological_target_rules() {
    let mut g = CommandGame::new(4).unwrap();
    start(&mut g);
    let result = submit(
        &mut g,
        json!({"kind":"queue.enqueue","actor_id":"mara","ability_id":"mend","source_id":"learned:mara:mend:1","target":target("sentinel")}),
    );
    assert_eq!(result["receipt"]["status"], "rejected");
    let result = submit(
        &mut g,
        json!({"kind":"queue.enqueue","actor_id":"clerk","ability_id":"gale_arc","source_id":"learned:mara:gale_arc:1","target":target("hound")}),
    );
    assert_eq!(result["receipt"]["status"], "rejected");
    assert_eq!(actor(&g, "mara")["focus"]["current"], 56);
}
#[test]
fn cmd08_selection_possession_and_reserve_are_separate() {
    let mut g = CommandGame::new(5).unwrap();
    accepted(&mut g, json!({"kind":"party.select","actor_id":"mara"}));
    assert_eq!(g.view()["party"]["possessed_id"], "player");
    accepted(
        &mut g,
        json!({"kind":"party.possess","actor_id":"clerk","select":true}),
    );
    assert_eq!(g.view()["party"]["recipient_id"], "clerk");
    accepted(&mut g, json!({"kind":"party.inspect","actor_id":"ivo"}));
    assert_eq!(g.view()["party"]["recipient_id"], "clerk");
    let rejected = submit(
        &mut g,
        json!({"kind":"party.possess","actor_id":"ivo","select":true}),
    );
    assert_eq!(rejected["receipt"]["status"], "rejected");
    assert_eq!(g.view()["party"]["recipient_id"], "clerk");
}
#[test]
fn cmd10_paid_windup_restore_is_atomic_and_fences_old_inputs() {
    let mut g = CommandGame::new(6).unwrap();
    start(&mut g);
    enqueue(
        &mut g,
        "mara",
        "gale_arc",
        "learned:mara:gale_arc:1",
        target("hound"),
    );
    resume(&mut g);
    tick_to(&mut g, 5);
    let saved = g.save_json().unwrap();
    let stale = input(&g, json!({"kind":"party.select","actor_id":"mara"}));
    let hp = actor(&g, "hound")["health"]["current"].clone();
    g.restore_json(&saved).unwrap();
    assert!(g.submit(stale).is_err());
    assert_eq!(g.advance(1).unwrap()["stop_reason"], "paused");
    resume(&mut g);
    tick_to(&mut g, 10);
    assert!(actor(&g, "hound")["health"]["current"].as_i64().unwrap() < hp.as_i64().unwrap());
    assert_eq!(actor(&g, "mara")["focus"]["current"], 46);
    let before = g.view();
    let mut corrupt: Value = serde_json::from_str(&saved).unwrap();
    let mut session: Value = serde_json::from_str(corrupt["session"].as_str().unwrap()).unwrap();
    session["state"]["debt"]["mara:focus"] = json!(0);
    corrupt["session"] = json!(session.to_string());
    assert!(g.restore_json(&corrupt.to_string()).is_err());
    assert_eq!(g.view(), before);
}
#[test]
fn cmd12_crafting_and_currency_are_one_transaction() {
    let mut g = CommandGame::new(7).unwrap();
    let command = input(
        &g,
        json!({"kind":"craft","actor_id":"clerk","recipe_id":"arc_edge"}),
    );
    let first = g.submit(command.clone()).unwrap();
    assert_eq!(first["receipt"]["status"], "accepted");
    assert_eq!(g.view()["inventory"]["currency"]["credits"], 80);
    let after = g.view();
    assert_eq!(g.submit(command).unwrap()["receipt"], first["receipt"]);
    assert_eq!(g.view(), after);
    let second = submit(
        &mut g,
        json!({"kind":"craft","actor_id":"clerk","recipe_id":"arc_edge"}),
    );
    assert_eq!(second["receipt"]["status"], "rejected");
    assert_eq!(g.view()["inventory"]["currency"]["credits"], 80);
}
#[test]
fn cmd13_shared_consumable_claims_reject_overreservation() {
    let mut g = CommandGame::new(8).unwrap();
    start(&mut g);
    for _ in 0..2 {
        accepted(
            &mut g,
            json!({"kind":"inventory.use","actor_id":"clerk","item_id":"dressing-stack-1","target":target("player")}),
        );
    }
    let result = submit(
        &mut g,
        json!({"kind":"inventory.use","actor_id":"mara","item_id":"dressing-stack-1","target":target("player")}),
    );
    assert_eq!(result["receipt"]["status"], "rejected");
    let item = g.view()["inventory"]["items"]
        .as_array()
        .unwrap()
        .iter()
        .find(|i| i["id"] == "dressing-stack-1")
        .unwrap()
        .clone();
    assert_eq!(item["reserved"], 2);
    assert_eq!(item["free"], 0);
}
#[test]
fn native_space_frame_rejects_stale_and_duplicate_observations() {
    let mut g = CommandGame::new(9).unwrap();
    let requests = g.space_requests();
    let mut frame = oathshaper_core::command::space::fixture_frame(&requests, 1).unwrap();
    frame.generation = "old".into();
    assert!(g.observe_space(frame).is_err());
    g.observe_fixture().unwrap();
    assert_eq!(g.advance(1).unwrap()["consumed_ticks"], 1);
    let frame = oathshaper_core::command::space::fixture_frame(&g.space_requests(), 1).unwrap();
    assert!(g.observe_space(frame).is_err());
}
#[test]
fn preview_has_no_mutation_and_rejects_unknown_action_fields() {
    let mut g = CommandGame::new(10).unwrap();
    let before = g.save_json().unwrap();
    let v = g.view();
    let p=g.preview(json!({"schema":"command.preview/v1","generation":v["session"]["generation"],"expected_revision":v["session"]["revision"],"action":{"kind":"shop.buy","stock_id":"dressing","quantity":1}})).unwrap();
    assert_eq!(p["available"], true);
    assert_eq!(g.save_json().unwrap(), before);
    let invalid = input(
        &g,
        json!({"kind":"party.select","actor_id":"mara","damage":999}),
    );
    assert!(g.submit(invalid).is_err());
}

#[test]
fn staged_geometry_cursor_survives_ai_invalidation_and_restore() {
    let mut g = CommandGame::new(51).unwrap();
    start(&mut g);
    resume(&mut g);
    assert_eq!(g.next_observation_sequence("headless-garden"), 1);
    g.observe_fixture().unwrap();
    assert_eq!(g.advance(1).unwrap()["stop_reason"], "waiting_for_space");
    assert_eq!(g.next_observation_sequence("headless-garden"), 1);
    g.observe_fixture().unwrap();
    g.advance(1).unwrap();
    assert_eq!(g.next_observation_sequence("headless-garden"), 2);
    let save = g.save_json().unwrap();
    g.restore_json(&save).unwrap();
    assert_eq!(g.next_observation_sequence("headless-garden"), 2);
}

#[test]
fn restore_prompt_retires_manual_and_nested_ui_pause_ownership() {
    let mut g = CommandGame::new(91).unwrap();
    start(&mut g);
    enqueue(
        &mut g,
        "mara",
        "gale_arc",
        "learned:mara:gale_arc:1",
        target("hound"),
    );
    resume(&mut g);
    tick_to(&mut g, 5);
    for owner in ["manual", "ledger", "selector"] {
        accepted(
            &mut g,
            json!({"kind":"pause.acquire","owner":owner,"context_id":owner}),
        );
    }
    let before = actor(&g, "mara");
    let saved = g.save_json().unwrap();
    g.restore_json(&saved).unwrap();
    let token = g.view()["clock"]["pause_reasons"]
        .as_array()
        .unwrap()
        .iter()
        .find(|p| p["owner"] == "restore")
        .unwrap()["token"]
        .clone();
    accepted(&mut g, json!({"kind":"pause.acknowledge","token":token}));
    assert_eq!(g.view()["clock"]["paused"], false);
    assert_eq!(actor(&g, "mara")["active_action"], before["active_action"]);
    assert_eq!(actor(&g, "mara")["focus"], before["focus"]);
    g.observe_fixture().unwrap();
    assert_eq!(g.advance(1).unwrap()["consumed_ticks"], 1);
}

#[test]
fn review_start_replay_preserves_original_checkpoint() {
    let mut g = CommandGame::new(201).unwrap();
    let command = input(
        &g,
        json!({"kind":"encounter.start","encounter_id":"garden_patrol"}),
    );
    let first = g.submit(command.clone()).unwrap();
    let before = g.save_json().unwrap();
    let saved: Value = serde_json::from_str(&before).unwrap();
    let checkpoint: Value = serde_json::from_str(saved["checkpoint"].as_str().unwrap()).unwrap();
    assert_eq!(checkpoint["state"]["phase"], "camp");
    assert_eq!(g.submit(command).unwrap()["receipt"], first["receipt"]);
    assert_eq!(g.save_json().unwrap(), before);
}
#[test]
fn review_restore_ack_is_atomic_and_identical_retry_is_durable() {
    let mut g = CommandGame::new(202).unwrap();
    let old = input(&g, json!({"kind":"party.select","actor_id":"mara"}));
    g.submit(old.clone()).unwrap();
    g.restore_json(&g.save_json().unwrap()).unwrap();
    let token = g.view()["clock"]["pause_reasons"]
        .as_array()
        .unwrap()
        .iter()
        .find(|p| p["owner"] == "restore")
        .unwrap()["token"]
        .clone();
    let mut bad = input(&g, json!({"kind":"pause.acknowledge","token":token}));
    bad["command_id"] = old["command_id"].clone();
    let before = g.save_json().unwrap();
    assert!(g.submit(bad).is_err());
    assert_eq!(g.save_json().unwrap(), before);
    assert_eq!(g.view()["session"]["phase"], "restore_prompt");
    assert_eq!(
        submit(&mut g, json!({"kind":"party.select","actor_id":"clerk"}))["receipt"]["status"],
        "rejected"
    );
    assert_eq!(g.view()["party"]["recipient_id"], "mara");
    let ack = input(&g, json!({"kind":"pause.acknowledge","token":token}));
    let first = g.submit(ack.clone()).unwrap();
    assert_eq!(first["receipt"]["status"], "accepted");
    let before = g.save_json().unwrap();
    assert_eq!(g.submit(ack).unwrap()["receipt"], first["receipt"]);
    assert_eq!(g.save_json().unwrap(), before);
    assert_eq!(g.view()["clock"]["paused"], false);
}
fn corrupt_session(save: &str, alter: impl FnOnce(&mut Value)) -> String {
    let mut outer: Value = serde_json::from_str(save).unwrap();
    let mut session: Value = serde_json::from_str(outer["session"].as_str().unwrap()).unwrap();
    alter(&mut session);
    outer["session"] = json!(session.to_string());
    outer.to_string()
}
#[test]
fn review_restore_requires_complete_item_and_equipment_claims() {
    let mut g = CommandGame::new(203).unwrap();
    start(&mut g);
    accepted(
        &mut g,
        json!({"kind":"inventory.use","actor_id":"clerk","item_id":"dressing-stack-1","target":target("player")}),
    );
    let before = g.save_json().unwrap();
    for remove_item in [false, true] {
        let candidate = corrupt_session(&before, |s| {
            s["rpg"]["claims"] = json!({});
            if remove_item {
                s["rpg"]["items"]
                    .as_object_mut()
                    .unwrap()
                    .remove("dressing-stack-1");
            }
        });
        assert!(g.restore_json(&candidate).is_err());
        assert_eq!(g.save_json().unwrap(), before);
    }
    let mut g = CommandGame::new(204).unwrap();
    start(&mut g);
    enqueue(
        &mut g,
        "player",
        "lunge",
        "item:sabre-4:lunge",
        target("hound"),
    );
    let before = g.save_json().unwrap();
    let candidate = corrupt_session(&before, |s| s["rpg"]["claims"] = json!({}));
    assert!(g.restore_json(&candidate).is_err());
    assert_eq!(g.save_json().unwrap(), before);
}
#[test]
fn review_restore_rejects_extreme_coordinates_without_panicking() {
    let mut g = CommandGame::new(205).unwrap();
    let before = g.save_json().unwrap();
    for coordinate in [i64::MIN, i64::MAX] {
        let candidate = corrupt_session(&before, |s| {
            s["state"]["actors"]["player"]["position"] = json!([coordinate, 0])
        });
        let result =
            std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| g.restore_json(&candidate)));
        assert!(result.unwrap().is_err());
        assert_eq!(g.save_json().unwrap(), before);
    }
}
