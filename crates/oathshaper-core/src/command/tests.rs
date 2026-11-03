use super::*;
fn send(g: &mut CommandGame, action: Value) -> Value {
    let v = g.view();
    let result=g.submit(json!({"schema":"command.action/v1","generation":v["session"]["generation"],"expected_revision":v["session"]["revision"],"command_id":format!("fixture-{}",v["session"]["ledger_sequence"].as_str().unwrap()),"action":action})).unwrap();
    assert_eq!(result["receipt"]["status"], "accepted", "{result}");
    result
}
fn order(g: &mut CommandGame, actor: &str, ability: &str, source: &str, target: Target) {
    send(
        g,
        json!({"kind":"queue.enqueue","actor_id":actor,"ability_id":ability,"source_id":source,"target":target}),
    );
}
fn tick(g: &mut CommandGame, to: u64) {
    for _ in 0..500 {
        if g.session.state().tick >= to {
            return;
        }
        g.observe_fixture().unwrap();
        let result = g.advance(1).unwrap();
        assert_ne!(result["stop_reason"], "rejected", "{result}");
        assert_ne!(result["stop_reason"], "paused", "{result}");
    }
    panic!("tick stalled")
}
#[test]
fn cmd03_three_sentry_garden_reconciles_deterministic_damage_and_rewards() {
    fn run() -> CommandGame {
        let mut g = CommandGame::new(31).unwrap();
        send(
            &mut g,
            json!({"kind":"encounter.start","encounter_id":"garden_patrol"}),
        );
        order(
            &mut g,
            "mara",
            "binding_current",
            "learned:mara:binding_current:1",
            Target {
                kind: "point".into(),
                actor_id: None,
                position: Some([2., 0.]),
            },
        );
        order(
            &mut g,
            "mara",
            "gale_arc",
            "learned:mara:gale_arc:1",
            Target::actor("hound"),
        );
        order(
            &mut g,
            "clerk",
            "disrupt_device",
            "item:tool-clerk:disrupt_device",
            Target::actor("sentinel"),
        );
        for _ in 0..600 {
            if g.session.state().phase != "encounter" {
                break;
            }
            let pauses: Vec<_> = g
                .session
                .state()
                .pauses
                .iter()
                .map(|(id, p)| (id.clone(), p.clone()))
                .collect();
            for (id, pause) in pauses {
                assert!(pause.automatic && pause.owner != "defeat");
                send(&mut g, json!({"kind":"pause.acknowledge","token":id}));
            }
            let player = &g.session.state().actors["player"];
            if player.active.is_none()
                && player.queue.is_empty()
                && rules::health(g.session.rpg(), "player") > 0
            {
                let target = ["hound", "corsair_raider", "sentinel"]
                    .into_iter()
                    .find(|id| rules::health(g.session.rpg(), id) > 0)
                    .unwrap();
                order(
                    &mut g,
                    "player",
                    "basic",
                    "item:sabre-4:basic",
                    Target::actor(target),
                );
            }
            g.observe_fixture().unwrap();
            let advanced = g.advance(1).unwrap();
            assert_ne!(advanced["stop_reason"], "rejected", "{advanced}");
        }
        g
    }
    let g = run();
    let again = run();
    assert_eq!(g.session.state().phase, "victory");
    assert_eq!(
        serde_json::to_value(g.session.state()).unwrap(),
        serde_json::to_value(again.session.state()).unwrap()
    );
    assert_eq!(g.session.rpg(), again.session.rpg());
    for id in content::ENEMIES {
        assert_eq!(rules::health(g.session.rpg(), id), 0);
    }
    assert_eq!(g.session.rpg().resources()["party:credits"].current, 145);
    assert_eq!(g.session.state().actors["clerk"].xp, 1800);
    assert_eq!(g.session.rpg().resources()["clerk:battery"].current, 2);
    assert!(g.session.state().reward.is_some());
    assert!(g
        .session
        .rpg()
        .items()
        .values()
        .all(|i| i.definition != "trial_seal"));
    assert!(g.session.rpg().claims().is_empty());
    let attacks: Vec<_> = g
        .session
        .state()
        .logs
        .iter()
        .filter(|l| l.kind == "attack")
        .collect();
    assert!(attacks.len() >= 12);
    for attack in attacks {
        let die = attack.roll.unwrap();
        assert!((1..=20).contains(&die));
        let hit =
            die == 20 || (die != 1 && die + attack.modifier.unwrap() >= attack.threshold.unwrap());
        assert_eq!(attack.damage.unwrap() > 0, hit, "{}", attack.text);
    }
    // Exact replay above verifies determinism; camera staging and AI triage may
    // legitimately change combat duration and surviving health.
    assert!(g.session.state().tick < 600);
    assert!(rules::health(g.session.rpg(), "player") > 0);
    assert!(g.session.rpg().resources()["mara:focus"].current >= 0);
}

fn fixture(state: CommandState, rpg: RpgState) -> CommandGame {
    fixture_seed(state, rpg, 73)
}

fn fixture_seed(mut state: CommandState, rpg: RpgState, seed: u64) -> CommandGame {
    let frame = space::fixture_frame(&space::requests(&state, 0, 0), 1).unwrap();
    state.observations = frame
        .results
        .into_iter()
        .map(|r| (r.request_id.clone(), r))
        .collect();
    let mut g = CommandGame::new(seed).unwrap();
    g.session = Session::new(
        CommandProfile,
        state,
        rpg,
        seed,
        "command-trial",
        &mut g.host,
    )
    .unwrap();
    g.leases().unwrap();
    g
}

#[test]
fn party_deployment_previews_commits_and_preserves_identity_across_start_and_restore() {
    let mut g = CommandGame::new(117).unwrap();
    for action in [
        json!({"kind":"party.possess", "actor_id":"clerk", "select":true}),
        json!({"kind":"party.inspect", "actor_id":"clerk"}),
        json!({"kind":"party.camera", "actor_id":"clerk"}),
        json!({"kind":"target.select", "target_id":"clerk"}),
    ] {
        send(&mut g, action);
    }
    let action = json!({"kind":"party.deploy", "actor_ids":["player","mara","ivo"]});
    let before = g.save_json().unwrap();
    let v = g.view();
    let preview = g.preview(json!({"schema":"command.preview/v1", "generation":v["session"]["generation"], "expected_revision":v["session"]["revision"], "action":action})).unwrap();
    assert_eq!(preview["available"], true);
    assert_eq!(g.save_json().unwrap(), before);
    assert_eq!(
        preview["view"]["party"]["deployed_ids"],
        json!(["player", "mara", "ivo"])
    );
    send(&mut g, action);
    let state = g.session.state();
    assert_eq!(state.recipient, "player");
    assert_eq!(state.inspected, "player");
    assert_eq!(state.possessed.as_deref(), Some("player"));
    assert_eq!(state.camera.as_deref(), Some("player"));
    assert!(state.selected_target.is_none());
    assert_eq!(
        ["player", "mara", "ivo"].map(|id| state.actors[id].position),
        [[0, 0], [-2000, 0], [-2000, 2000]]
    );
    assert!(!state.actors["clerk"].deployed);
    assert_eq!(g.session.rpg().bindings()["ivo"]["main_hand"], "mace-ivo");
    assert_eq!(rules::health(g.session.rpg(), "ivo"), 86);
    let saved = g.save_json().unwrap();
    let mut restored = CommandGame::new(0).unwrap();
    restored.restore_json(&saved).unwrap();
    assert_eq!(
        restored.view()["party"]["deployed_ids"],
        json!(["player", "mara", "ivo"])
    );
    let token = restored.restore_token.clone().unwrap();
    send(
        &mut restored,
        json!({"kind":"pause.acknowledge","token":token}),
    );
    send(
        &mut restored,
        json!({"kind":"encounter.start", "encounter_id":"garden_patrol"}),
    );
    assert_eq!(
        restored.view()["party"]["deployed_ids"],
        json!(["player", "mara", "ivo"])
    );
    assert_eq!(
        restored.session.state().actors["ivo"].position,
        [-2000, 2000]
    );
    let checkpoint: Value = serde_json::from_str(restored.checkpoint.as_ref().unwrap()).unwrap();
    assert_eq!(checkpoint["state"]["actors"]["ivo"]["deployed"], true);
    assert_eq!(checkpoint["state"]["actors"]["clerk"]["deployed"], false);
    send(
        &mut g,
        json!({"kind":"party.deploy","actor_ids":["clerk","player","mara"]}),
    );
    assert_eq!(
        g.view()["party"]["deployed_ids"],
        json!(["player", "mara", "clerk"])
    );
    assert_eq!(g.session.state().actors["clerk"].position, [-2000, 2000]);
    assert!(!g.session.state().actors["ivo"].deployed);
}

#[test]
fn paused_deployed_party_can_refresh_geometry_and_queue_without_advancing_combat() {
    let mut g = CommandGame::new(118).unwrap();
    send(
        &mut g,
        json!({"kind":"party.deploy","actor_ids":["player","mara","ivo"]}),
    );
    send(
        &mut g,
        json!({"kind":"encounter.start","encounter_id":"garden_patrol"}),
    );
    assert!(g.view()["targets"]
        .as_array()
        .unwrap()
        .iter()
        .all(|t| t["relation"] != "enemy"));
    let before_state = g.session.state().clone();
    let before_rpg = g.session.rpg().clone();
    g.observe_fixture().unwrap();
    let result = g.advance(0).unwrap();
    assert_eq!(result["consumed_ticks"], 0);
    assert_eq!(result["stop_reason"], "complete");
    assert_eq!(result["view"]["clock"]["paused"], true);
    assert_eq!(g.session.state().tick, before_state.tick);
    assert_eq!(
        serde_json::to_value(&g.session.state().actors).unwrap(),
        serde_json::to_value(&before_state.actors).unwrap()
    );
    assert_eq!(
        serde_json::to_value(&g.session.state().pauses).unwrap(),
        serde_json::to_value(&before_state.pauses).unwrap()
    );
    assert_eq!(g.session.rpg(), &before_rpg);
    assert_eq!(
        result["view"]["targets"]
            .as_array()
            .unwrap()
            .iter()
            .filter(|t| t["relation"] == "enemy")
            .count(),
        3
    );
    order(
        &mut g,
        "mara",
        "gale_arc",
        "learned:mara:gale_arc:1",
        Target::actor("hound"),
    );
    let queued = serde_json::to_value(&g.session.state().actors).unwrap();
    let reserved = g.session.rpg().clone();
    g.observe_fixture().unwrap();
    g.advance(0).unwrap();
    assert_eq!(
        serde_json::to_value(&g.session.state().actors).unwrap(),
        queued
    );
    assert_eq!(g.session.rpg(), &reserved);
    assert!(g.session.state().actors["mara"].active.is_none());
    assert_eq!(g.session.rpg().reserved("mara:focus").unwrap(), 10);
    assert_eq!(g.session.rpg().resources()["mara:focus"].current, 56);
    assert_eq!(g.advance(1).unwrap()["stop_reason"], "paused");

    // A receipt changes the revision; an older staged frame cannot be committed.
    g.observe_fixture().unwrap();
    send(&mut g, json!({"kind":"party.inspect","actor_id":"ivo"}));
    let before_sequence = g.session.state().observation_sequence.clone();
    assert_eq!(g.advance(0).unwrap()["stop_reason"], "waiting_for_space");
    assert_eq!(g.session.state().observation_sequence, before_sequence);
    g.observe_fixture().unwrap();
    assert_eq!(g.advance(0).unwrap()["stop_reason"], "complete");
    let save = g.save_json().unwrap();
    g.restore_json(&save).unwrap();
    g.observe_fixture().unwrap();
    assert_eq!(
        g.advance(0).unwrap()["stop_reason"],
        "paused",
        "refresh must not release the restore barrier"
    );
    let token = g.restore_token.clone().unwrap();
    send(&mut g, json!({"kind":"pause.acknowledge","token":token}));
    g.observe_fixture().unwrap();
    assert_eq!(g.advance(0).unwrap()["stop_reason"], "complete");
    assert_eq!(g.session.state().tick, 0);
}

#[test]
fn invalid_or_unsettled_party_changes_leave_the_roster_and_resources_untouched() {
    for actor_ids in [
        vec!["player", "mara", "mara"],
        vec!["mara", "clerk", "ivo"],
        vec!["player", "mara"],
        vec!["player", "mara", "clerk", "ivo"],
        vec!["player", "mara", "sentinel"],
        vec!["player", "mara", "missing"],
    ] {
        let (mut s, mut r) = content::initial().unwrap();
        let before_s = serde_json::to_value(&s).unwrap();
        let before_r = r.clone();
        assert!(rules::command(
            &mut s,
            &mut r,
            &CommandIntent::Deploy {
                actor_ids: actor_ids.into_iter().map(str::to_owned).collect()
            },
            false
        )
        .is_err());
        assert_eq!(serde_json::to_value(&s).unwrap(), before_s);
        assert_eq!(r, before_r);
    }
    for blocked in ["dead", "combat", "movement", "rest", "queue"] {
        let (mut s, mut r) = content::initial().unwrap();
        match blocked {
            "dead" => rules::pool_change(&mut s, &mut r, "ivo:health", -86).unwrap(),
            "combat" => s.phase = "encounter".into(),
            "movement" => s.actors.get_mut("player").unwrap().direction = [1., 0.],
            "rest" => s.rest_until = Some(50),
            "queue" => rules::command(
                &mut s,
                &mut r,
                &CommandIntent::Enqueue {
                    actor_id: "player".into(),
                    ability_id: "brace".into(),
                    source_id: "item:buckler-2:brace".into(),
                    target: Target {
                        kind: "self".into(),
                        actor_id: None,
                        position: None,
                    },
                },
                false,
            )
            .unwrap(),
            _ => unreachable!(),
        }
        let before_s = serde_json::to_value(&s).unwrap();
        let before_r = r.clone();
        assert!(
            rules::command(
                &mut s,
                &mut r,
                &CommandIntent::Deploy {
                    actor_ids: vec!["player".into(), "mara".into(), "ivo".into()]
                },
                false
            )
            .is_err(),
            "{blocked}"
        );
        assert_eq!(serde_json::to_value(&s).unwrap(), before_s, "{blocked}");
        assert_eq!(r, before_r, "{blocked}");
    }
}

#[test]
fn new_sentries_have_authored_models_roles_costs_and_counterplay() {
    let (mut s, r) = content::initial().unwrap();
    s.phase = "encounter".into();
    s.actors.get_mut("sentinel").unwrap().position = [1500, 0];
    let g = fixture(s, r);
    let mut s = g.session.state().clone();
    let mut r = g.session.rpg().clone();
    for (id, model, hp, defense) in [
        ("sentinel", "iron_sentinel", 48, 16),
        ("hound", "lantern_sentinel", 30, 13),
        ("corsair_raider", "crimson_corsair", 36, 14),
    ] {
        let view = g.view();
        let actor = view["actors"]
            .as_array()
            .unwrap()
            .iter()
            .find(|a| a["id"] == id)
            .unwrap();
        assert_eq!(actor["appearance"]["model"], model);
        assert_eq!(rules::health(&r, id), hp);
        assert_eq!(content::defense(&s, &r, id), defense);
    }
    assert_eq!(
        rules::effective_range(
            &r,
            "sentinel",
            &content::ability("basic").unwrap(),
            "learned:sentinel:basic:1"
        ),
        2000
    );
    assert_eq!(
        rules::effective_range(
            &r,
            "hound",
            &content::ability("basic").unwrap(),
            "learned:hound:basic:1"
        ),
        15000
    );
    let lantern = combat::ai(&s, &r, "hound").remove(0);
    assert!(
        matches!(&lantern, CommandIntent::Enqueue { ability_id, .. } if ability_id == "gale_arc")
    );
    rules::command(&mut s, &mut r, &lantern, true).unwrap();
    assert_eq!(r.available("hound:focus").unwrap(), 10);
    assert_eq!(r.reserved("hound:focus").unwrap(), 10);
    assert!(
        matches!(&combat::ai(&s, &r, "corsair_raider")[0], CommandIntent::Enqueue { ability_id, .. } if ability_id == "lunge")
    );
    s.actors
        .get_mut("corsair_raider")
        .unwrap()
        .conditions
        .insert("root".into(), 100);
    assert!(
        matches!(&combat::ai(&s, &r, "corsair_raider")[0], CommandIntent::Enqueue { ability_id, .. } if ability_id == "basic")
    );
    assert_eq!(
        rules::availability(
            &s,
            &r,
            "corsair_raider",
            "lunge",
            "learned:corsair_raider:lunge:1"
        )
        .unwrap_err()
        .reason
        .code,
        "root"
    );
    rules::command(
        &mut s,
        &mut r,
        &CommandIntent::Enqueue {
            actor_id: "player".into(),
            ability_id: "basic".into(),
            source_id: "item:sabre-4:basic".into(),
            target: Target::actor("sentinel"),
        },
        false,
    )
    .unwrap();
    combat::pump(&mut s, &mut r).unwrap();
    assert!(
        matches!(&combat::ai(&s, &r, "sentinel")[0], CommandIntent::Enqueue { ability_id, .. } if ability_id == "brace")
    );
    assert_eq!(r.resources()["hound:focus"].current, 10);
    assert_eq!(r.reserved("hound:focus").unwrap(), 0);
}

#[test]
fn ai_retargets_dead_targets_without_pausing_but_manual_failures_still_pause() {
    for is_ai in [true, false] {
        let (mut s, r) = content::initial().unwrap();
        s.phase = "encounter".into();
        let g = fixture(s, r);
        let mut s = g.session.state().clone();
        let mut r = g.session.rpg().clone();
        rules::command(
            &mut s,
            &mut r,
            &CommandIntent::Enqueue {
                actor_id: "mara".into(),
                ability_id: "gale_arc".into(),
                source_id: "learned:mara:gale_arc:1".into(),
                target: Target::actor("hound"),
            },
            is_ai,
        )
        .unwrap();
        assert_eq!(r.reserved("mara:focus").unwrap(), 10);
        rules::pool_change(&mut s, &mut r, "hound:health", -30).unwrap();
        combat::pump(&mut s, &mut r).unwrap();
        assert_eq!(s.pauses.is_empty(), is_ai);
        assert!(s.actors["mara"].queue.is_empty());
        assert_eq!(r.reserved("mara:focus").unwrap(), 0);
        assert_eq!(r.resources()["mara:focus"].current, 56);
    }
}

#[test]
fn stale_two_enemy_saves_and_missing_new_roster_fail_atomically_before_projection() {
    let mut g = CommandGame::new(991).unwrap();
    let before = g.save_json().unwrap();
    for stale_manifest in [true, false] {
        let mut wrapper: Value = serde_json::from_str(&before).unwrap();
        let mut session: Value =
            serde_json::from_str(wrapper["session"].as_str().unwrap()).unwrap();
        if stale_manifest {
            session["manifest"]["version"] = json!(3);
            session["manifest"]["content_hash"] = json!("command-garden/v3");
        }
        session["state"]["actors"]
            .as_object_mut()
            .unwrap()
            .remove("corsair_raider");
        wrapper["session"] = json!(session.to_string());
        let result = g.restore_json(&wrapper.to_string());
        assert!(result.is_err());
        let error = result.unwrap_err();
        assert_eq!(
            error.reason.code,
            if stale_manifest { "save" } else { "state" }
        );
        assert_eq!(g.save_json().unwrap(), before);
    }
}
#[test]
fn cmd17_capacity_shrink_revalidates_whole_claims_in_admission_order() {
    let (mut state, mut rpg) = content::initial().unwrap();
    rules::command(
        &mut state,
        &mut rpg,
        &CommandIntent::Equip {
            actor_id: "mara".into(),
            expected_binding_version: "1".into(),
            changes: vec![SlotChange {
                slot_id: "focus_tool".into(),
                item_id: Some("lens-17".into()),
            }],
            cancel_action_ids: vec![],
        },
        false,
    )
    .unwrap();
    rules::pool_change(&mut state, &mut rpg, "mara:focus", -40).unwrap();
    let mut g = fixture(state, rpg);
    send(
        &mut g,
        json!({"kind":"encounter.start","encounter_id":"garden_patrol"}),
    );
    order(
        &mut g,
        "mara",
        "binding_current",
        "learned:mara:binding_current:1",
        Target {
            kind: "point".into(),
            actor_id: None,
            position: Some([2., 0.]),
        },
    );
    order(
        &mut g,
        "mara",
        "gale_arc",
        "learned:mara:gale_arc:1",
        Target::actor("hound"),
    );
    order(
        &mut g,
        "mara",
        "mend",
        "learned:mara:mend:1",
        Target::actor("player"),
    );
    let ids: Vec<_> = g.session.state().actors["mara"]
        .queue
        .iter()
        .rev()
        .map(|a| a.id.clone())
        .collect();
    send(
        &mut g,
        json!({"kind":"queue.reorder","actor_id":"mara","action_ids":ids}),
    );
    let result = g.revoke_item_source("lens-17").unwrap();
    assert_eq!(result["receipt"]["status"], "accepted", "{result}");
    assert_eq!(g.session.rpg().resources()["mara:focus"].current, 16);
    assert_eq!(g.session.rpg().reserved("mara:focus").unwrap(), 10);
    assert_eq!(g.session.state().debt["mara:focus"], 40);
    assert_eq!(g.session.state().actors["mara"].queue.len(), 1);
    assert_eq!(
        g.session.state().actors["mara"].queue[0].ability,
        "gale_arc"
    );
    let save = g.save_json().unwrap();
    g.restore_json(&save).unwrap();
    assert_eq!(g.session.rpg().available("mara:focus").unwrap(), 6);
}
#[test]
fn cmd04_lens_removal_preserves_hidden_depletion_and_ghost() {
    let (mut s, mut r) = content::initial().unwrap();
    rules::command(
        &mut s,
        &mut r,
        &CommandIntent::Equip {
            actor_id: "player".into(),
            expected_binding_version: "1".into(),
            changes: vec![SlotChange {
                slot_id: "focus_tool".into(),
                item_id: Some("lens-17".into()),
            }],
            cancel_action_ids: vec![],
        },
        false,
    )
    .unwrap();
    rules::pool_change(&mut s, &mut r, "player:focus", -18).unwrap();
    let mut g = fixture(s, r);
    send(
        &mut g,
        json!({"kind":"equipment.apply","actor_id":"player","expected_binding_version":"2","changes":[{"slot_id":"focus_tool","item_id":null}],"cancel_action_ids":[]}),
    );
    assert_eq!(g.session.rpg().resources()["player:focus"].current, 0);
    assert_eq!(g.session.state().debt["player:focus"], 18);
    assert!(g.view()["actions"]
        .as_array()
        .unwrap()
        .iter()
        .any(|a| a["id"] == "gust" && a["ghost"] == true));
    send(
        &mut g,
        json!({"kind":"equipment.apply","actor_id":"player","expected_binding_version":"3","changes":[{"slot_id":"focus_tool","item_id":"lens-17"}],"cancel_action_ids":[]}),
    );
    assert_eq!(g.session.rpg().resources()["player:focus"].current, 12);
}
#[test]
fn cmd06_level7_preserves_health_debt_and_rejects_99_credit_respec() {
    let (mut s, mut r) = content::initial().unwrap();
    s.actors.get_mut("clerk").unwrap().xp = 2100;
    rules::pool_change(&mut s, &mut r, "clerk:health", -8).unwrap();
    s.respec_cost = 100;
    r.apply(&[crate::rpg::Mutation::AdjustResource {
        id: "party:credits".into(),
        delta: -1,
    }])
    .unwrap();
    let mut g = fixture(s, r);
    send(&mut g, json!({"kind":"party.inspect","actor_id":"clerk"}));
    let level = g.view()["progression"]["presets"][0]["action"].clone();
    send(&mut g, level);
    assert_eq!(g.session.rpg().resources()["clerk:health"].maximum, 69);
    assert_eq!(rules::health(g.session.rpg(), "clerk"), 61);
    assert_eq!(g.session.state().actors["clerk"].skills["devices"], 6);
    let before = g.save_json().unwrap();
    let plan = progression::presets(g.session.state(), g.session.rpg(), "clerk")
        .into_iter()
        .find(|(id, _, _)| id == "investigator")
        .unwrap()
        .2;
    let result = g.session.preview(&g.player, Some("clerk"), &plan).unwrap();
    assert_eq!(result["available"], false);
    assert_eq!(g.save_json().unwrap(), before);
}
#[test]
fn cmd15_six_serial_builds_have_distinct_rules_and_no_respec_refill() {
    let (mut s, mut r) = content::initial().unwrap();
    rules::pool_change(&mut s, &mut r, "player:health", -13).unwrap();
    let mut g = fixture(s, r);
    let mut results = BTreeSet::new();
    for preset in [
        "arms",
        "scout",
        "infiltrator",
        "blade_adept",
        "storm_mystic",
        "investigator",
    ] {
        let command = progression::presets(g.session.state(), g.session.rpg(), "player")
            .into_iter()
            .find(|(id, _, _)| id == preset)
            .unwrap()
            .2;
        let result = g
            .session
            .preview(&g.player, Some("player"), &command)
            .unwrap();
        assert_eq!(result["available"], true, "{preset}: {result}");
        send(&mut g, serde_json::to_value(command).unwrap());
        assert_eq!(g.session.state().debt["player:health"], 13);
        let a = &g.session.state().actors["player"];
        results.insert((
            a.classes.keys().cloned().collect::<Vec<_>>(),
            g.session.rpg().resources()["player:focus"].maximum,
            a.unspent,
        ));
    }
    assert_eq!(results.len(), 6);
    let mut illegal = progression::presets(g.session.state(), g.session.rpg(), "player")
        .remove(0)
        .2;
    if let CommandIntent::Respec { levels, .. } = &mut illegal {
        levels[0].feats = vec!["single_blade_ii".into()];
    }
    let result = g
        .session
        .preview(&g.player, Some("player"), &illegal)
        .unwrap();
    assert_eq!(result["available"], false);
}
#[test]
fn cmd19_helper_supplies_complete_check_without_changing_speaker() {
    let mut g = CommandGame::new(81).unwrap();
    let command = CommandIntent::Assist {
        actor_id: "player".into(),
        interaction_id: "charter".into(),
        helper_id: None,
    };
    assert_eq!(
        g.session
            .preview(&g.player, Some("player"), &command)
            .unwrap()["available"],
        false
    );
    send(
        &mut g,
        json!({"kind":"dialogue.assist","actor_id":"player","interaction_id":"charter","helper_id":"mara"}),
    );
    let log = g.session.state().logs.last().unwrap();
    assert_eq!(log.actor_id.as_deref(), Some("mara"));
    assert!(log.text.contains("18") && log.text.contains("speaker player"));
}

#[test]
fn cmd08_explicit_order_replaces_ai_atomically_and_invalid_replacement_preserves_it() {
    let mut g = CommandGame::new(103).unwrap();
    send(
        &mut g,
        json!({"kind":"encounter.start","encounter_id":"garden_patrol"}),
    );
    let receipt = g
        .session
        .submit(Envelope {
            generation: g.session.generation(),
            epoch: g.session.epoch(),
            id: "ai-gale".into(),
            lease: g.ai.clone(),
            expected_revision: g.session.revision(),
            actor: Some("mara".into()),
            payload: CommandIntent::Enqueue {
                actor_id: "mara".into(),
                ability_id: "gale_arc".into(),
                source_id: "learned:mara:gale_arc:1".into(),
                target: Target::actor("hound"),
            },
        })
        .unwrap();
    assert_eq!(receipt.status, Status::Accepted);
    let id = g.session.state().actors["mara"].queue[0].id.clone();
    let invalid = CommandIntent::Enqueue {
        actor_id: "mara".into(),
        ability_id: "mend".into(),
        source_id: "learned:mara:mend:1".into(),
        target: Target::actor("sentinel"),
    };
    assert_eq!(
        g.session
            .preview(&g.player, Some("mara"), &invalid)
            .unwrap()["available"],
        false
    );
    assert_eq!(g.session.state().actors["mara"].queue[0].id, id);
    assert_eq!(g.session.rpg().reserved("mara:focus").unwrap(), 10);
    order(
        &mut g,
        "mara",
        "binding_current",
        "learned:mara:binding_current:1",
        Target {
            kind: "point".into(),
            actor_id: None,
            position: Some([2., 0.]),
        },
    );
    assert_eq!(g.session.state().actors["mara"].queue.len(), 1);
    assert_eq!(g.session.rpg().reserved("mara:focus").unwrap(), 18);
}
#[test]
fn cmd11_defeat_retry_restores_complete_checkpoint_and_fences_callbacks() {
    let (mut s, mut r) = content::initial().unwrap();
    rules::command(
        &mut s,
        &mut r,
        &CommandIntent::Deploy {
            actor_ids: vec!["player".into(), "mara".into(), "ivo".into()],
        },
        false,
    )
    .unwrap();
    for id in content::PARTY {
        if s.actors[id].deployed {
            let hp = rules::health(&r, id);
            rules::pool_change(&mut s, &mut r, &content::resource_id(id, "health"), 1 - hp)
                .unwrap();
            s.actors.get_mut(id).unwrap().hold = true;
        }
    }
    let mut g = fixture(s, r);
    send(
        &mut g,
        json!({"kind":"encounter.start","encounter_id":"garden_patrol"}),
    );
    let token = g.view()["clock"]["pause_reasons"][0]["token"].clone();
    send(&mut g, json!({"kind":"pause.acknowledge","token":token}));
    for _ in 0..800 {
        if g.session.state().phase == "defeat" {
            break;
        }
        g.observe_fixture().unwrap();
        g.advance(1).unwrap();
    }
    assert_eq!(g.session.state().phase, "defeat");
    let old_generation = g.session.generation();
    let id = g.session.state().checkpoint_id.clone().unwrap();
    send(&mut g, json!({"kind":"encounter.retry","checkpoint_id":id}));
    assert_ne!(g.session.generation(), old_generation);
    assert_eq!(g.session.state().phase, "camp");
    assert_eq!(g.session.rpg().items()["dressing-stack-1"].quantity, 2);
    assert_eq!(g.session.rpg().resources()["party:credits"].current, 100);
    assert!(g.session.state().reward.is_none());
    assert!(g.session.rpg().claims().is_empty());
    assert_eq!(
        g.view()["party"]["deployed_ids"],
        json!(["player", "mara", "ivo"])
    );
    assert_eq!(g.session.state().actors["ivo"].position, [-2000, 2000]);
}
#[test]
fn cmd14_blocked_approach_expires_once_and_releases_reservation() {
    let mut g = CommandGame::new(104).unwrap();
    send(
        &mut g,
        json!({"kind":"encounter.start","encounter_id":"garden_patrol"}),
    );
    for id in ["mara", "clerk"] {
        send(
            &mut g,
            json!({"kind":"ai.configure","actor_id":id,"policy":"conservative","empty_policy":"hold","hold_after_orders":true}),
        );
    }
    order(
        &mut g,
        "mara",
        "gale_arc",
        "learned:mara:gale_arc:1",
        Target::actor("hound"),
    );
    let token = g.view()["clock"]["pause_reasons"][0]["token"].clone();
    send(&mut g, json!({"kind":"pause.acknowledge","token":token}));
    for _ in 0..180 {
        if !g.session.state().pauses.is_empty() {
            break;
        }
        let mut frame = space::fixture_frame(
            &g.space_requests(),
            g.next_observation_sequence("headless-garden"),
        )
        .unwrap();
        for result in &mut frame.results {
            if result.request_id.starts_with("path:mara:") {
                result.clear = Some(false);
                result.path_mm.clear();
            }
            if result.request_id == "los:mara:hound" {
                result.clear = Some(false);
                result.visible = Some(false);
            }
        }
        g.observe_space(frame).unwrap();
        g.advance(1).unwrap();
    }
    assert_eq!(g.session.state().tick, 60);
    assert!(g.session.state().actors["mara"].active.is_none());
    assert_eq!(g.session.rpg().reserved("mara:focus").unwrap(), 0);
    assert_eq!(g.session.rpg().resources()["mara:focus"].current, 56);
    assert_eq!(
        g.session
            .state()
            .pauses
            .values()
            .filter(|p| p.owner == "action_failed")
            .count(),
        1
    );
}
#[test]
fn cmd16_rest_is_pending_work_and_exit_preview_is_read_only() {
    let mut g = CommandGame::new(105).unwrap();
    send(&mut g, json!({"kind":"camp.rest","camp_id":"garden_camp"}));
    let before = g.save_json().unwrap();
    assert_eq!(
        g.session
            .preview(&g.player, None, &CommandIntent::Exit)
            .unwrap()["available"],
        false
    );
    assert_eq!(g.save_json().unwrap(), before);
    tick(&mut g, 50);
    assert_eq!(
        g.session
            .preview(&g.player, None, &CommandIntent::Exit)
            .unwrap()["available"],
        true
    );
}
#[test]
fn ai_budget_uses_two_mobile_targets_and_unarmed_does_not_inherit_bow_range() {
    let (mut s, r) = content::initial().unwrap();
    s.phase = "encounter".into();
    s.actors.get_mut("sentinel").unwrap().position = [3000, 0];
    let g = fixture(s, r);
    let commands = g.session.ai_commands(&g.ai, "mara").unwrap();
    assert!(
        matches!(&commands[0],CommandIntent::Enqueue{ability_id,..}if ability_id=="binding_current")
    );
    let ab = content::ability("basic").unwrap();
    assert_eq!(
        rules::effective_range(g.session.rpg(), "clerk", &ab, "learned:clerk:basic:1"),
        2000
    );
    assert_eq!(
        rules::effective_range(g.session.rpg(), "clerk", &ab, "item:crossbow-clerk:basic"),
        15000
    );
}

#[test]
fn review_in_range_occluded_order_follows_valid_path_to_firing_position() {
    let (mut state, rpg) = content::initial().unwrap();
    state.phase = "encounter".into();
    for a in state.actors.values_mut() {
        a.hold = true;
    }
    state.actors.get_mut("clerk").unwrap().position = [2000, 5000];
    state.actors.get_mut("sentinel").unwrap().position = [9500, 5000];
    state.actors.get_mut("player").unwrap().position = [9000, 2000];
    let mut g = fixture(state, rpg);
    order(
        &mut g,
        "clerk",
        "basic",
        "item:crossbow-clerk:basic",
        Target::actor("sentinel"),
    );
    let frame = space::fixture_frame(&g.space_requests(), 1).unwrap();
    let path = frame
        .results
        .iter()
        .find(|r| r.request_id.starts_with("path:clerk:"))
        .unwrap();
    assert_eq!(path.clear, Some(true));
    assert!(path.path_mm.len() > 2);
    assert_eq!(
        frame
            .results
            .iter()
            .find(|r| r.request_id == "los:clerk:sentinel")
            .unwrap()
            .clear,
        Some(false)
    );
    tick(&mut g, 10);
    assert_ne!(g.session.state().actors["clerk"].position, [2000, 5000]);
    tick(&mut g, 55);
    assert!(g
        .session
        .state()
        .logs
        .iter()
        .any(|l| l.actor_id.as_deref() == Some("clerk") && l.kind == "attack"));
}
#[test]
fn review_heavy_trained_mend_accepts_gale_and_silenced_mend_reject() {
    let (mut s, mut r) = content::initial().unwrap();
    s.actors
        .get_mut("mara")
        .unwrap()
        .feats
        .extend(["medium_training".into(), "heavy_training".into()]);
    rules::command(
        &mut s,
        &mut r,
        &CommandIntent::Equip {
            actor_id: "ivo".into(),
            expected_binding_version: "1".into(),
            changes: vec![SlotChange {
                slot_id: "body".into(),
                item_id: None,
            }],
            cancel_action_ids: vec![],
        },
        false,
    )
    .unwrap();
    rules::command(
        &mut s,
        &mut r,
        &CommandIntent::Equip {
            actor_id: "mara".into(),
            expected_binding_version: "1".into(),
            changes: vec![SlotChange {
                slot_id: "body".into(),
                item_id: Some("armor-ivo".into()),
            }],
            cancel_action_ids: vec![],
        },
        false,
    )
    .unwrap();
    s.phase = "encounter".into();
    let mut g = fixture(s.clone(), r.clone());
    order(
        &mut g,
        "mara",
        "mend",
        "learned:mara:mend:1",
        Target::actor("player"),
    );
    assert_eq!(
        rules::availability(&s, &r, "mara", "gale_arc", "learned:mara:gale_arc:1")
            .unwrap_err()
            .reason
            .code,
        "armor"
    );
    s.actors
        .get_mut("mara")
        .unwrap()
        .conditions
        .insert("silence".into(), 60);
    assert_eq!(
        rules::availability(&s, &r, "mara", "mend", "learned:mara:mend:1")
            .unwrap_err()
            .reason
            .code,
        "silence"
    );
}

#[test]
fn default_ai_shoots_surviving_sentinel_after_hound_dies() {
    let mut g = CommandGame::new(20261022).unwrap();
    send(
        &mut g,
        json!({"kind":"encounter.start","encounter_id":"garden_patrol"}),
    );
    order(
        &mut g,
        "mara",
        "binding_current",
        "learned:mara:binding_current:1",
        Target {
            kind: "point".into(),
            actor_id: None,
            position: Some([2., 0.]),
        },
    );
    order(
        &mut g,
        "mara",
        "gale_arc",
        "learned:mara:gale_arc:1",
        Target::actor("hound"),
    );
    let token = g.view()["clock"]["pause_reasons"][0]["token"].clone();
    send(&mut g, json!({"kind":"pause.acknowledge","token":token}));
    for _ in 0..1000 {
        if g.session.state().phase == "victory" {
            break;
        }
        g.observe_fixture().unwrap();
        let result = g.advance(1).unwrap();
        assert_ne!(result["stop_reason"], "rejected", "{result}");
        assert_ne!(result["stop_reason"], "paused", "{result}");
    }
    assert_eq!(g.session.state().phase, "victory");
    assert!(g
        .session
        .state()
        .logs
        .iter()
        .any(|l| l.actor_id.as_deref() == Some("clerk")
            && l.target_id.as_deref() == Some("sentinel")
            && l.kind == "attack"));
}
#[test]
fn gust_push_stops_at_garden_edge_and_never_deals_damage() {
    let (mut s, mut r) = content::initial().unwrap();
    rules::command(
        &mut s,
        &mut r,
        &CommandIntent::Equip {
            actor_id: "player".into(),
            expected_binding_version: "1".into(),
            changes: vec![SlotChange {
                slot_id: "focus_tool".into(),
                item_id: Some("lens-17".into()),
            }],
            cancel_action_ids: vec![],
        },
        false,
    )
    .unwrap();
    s.phase = "encounter".into();
    for a in s.actors.values_mut() {
        a.hold = true;
    }
    s.actors.get_mut("player").unwrap().position = [11000, 0];
    s.actors.get_mut("hound").unwrap().position = [13000, 0];
    let mut g = fixture(s, r);
    order(
        &mut g,
        "player",
        "gust",
        "item:lens-17:gust",
        Target::actor("hound"),
    );
    combat::RECORDED_ROLLS.with(|v| *v.borrow_mut() = [1].into());
    tick(&mut g, 10);
    assert_eq!(g.session.state().actors["hound"].position, [13250, 0]);
    assert_eq!(rules::health(g.session.rpg(), "hound"), 30);
    assert_eq!(g.session.rpg().resources()["player:focus"].current, 18);
}
#[test]
fn veil_is_party_area_ward_and_physical_damage_does_not_consume_it() {
    let (mut s, r) = content::initial().unwrap();
    s.phase = "encounter".into();
    for a in s.actors.values_mut() {
        a.hold = true;
    }
    let mut g = fixture(s, r);
    order(
        &mut g,
        "mara",
        "veil",
        "learned:mara:veil:1",
        Target {
            kind: "self".into(),
            actor_id: None,
            position: None,
        },
    );
    tick(&mut g, 10);
    let mut state = g.session.state().clone();
    let mut rpg = g.session.rpg().clone();
    assert_eq!(state.actors["player"].ward_remaining, 12);
    assert_eq!(state.actors["clerk"].ward_remaining, 12);
    assert_eq!(state.actors["ivo"].ward_remaining, 0);
    assert_eq!(
        combat::damage(&mut state, &mut rpg, "player", 7, "physical").unwrap(),
        7
    );
    assert_eq!(state.actors["player"].ward_remaining, 12);
    assert_eq!(
        combat::damage(&mut state, &mut rpg, "player", 14, "arc").unwrap(),
        2
    );
    assert_eq!(state.actors["player"].ward_remaining, 0);
    assert_eq!(
        combat::damage(&mut state, &mut rpg, "clerk", 7, "frost").unwrap(),
        0
    );
    assert_eq!(state.actors["clerk"].ward_remaining, 5);
    let saved = g.save_json().unwrap();
    g.restore_json(&saved).unwrap();
    assert_eq!(g.session.state().actors["player"].ward_remaining, 12);
}

#[test]
fn review_self_dressing_consumes_final_unit_and_restores_paid_windup() {
    let (mut state, mut rpg) = content::initial().unwrap();
    state.phase = "encounter".into();
    for actor in state.actors.values_mut() {
        actor.hold = true;
    }
    rules::pool_change(&mut state, &mut rpg, "clerk:health", -20).unwrap();
    rpg.apply(&[crate::rpg::Mutation::ConsumeItem {
        item: "dressing-stack-1".into(),
        quantity: 1,
    }])
    .unwrap();
    let mut g = fixture(state, rpg);
    send(&mut g, json!({"kind":"party.inspect","actor_id":"clerk"}));
    let before = g.save_json().unwrap();
    let operation = dressing_operation(&g);
    assert_eq!(operation["available"], true);
    assert_eq!(operation["target_kind"], "ally");
    assert_eq!(operation["action"]["actor_id"], "clerk");
    assert_eq!(g.session.state().recipient, "player");
    assert_eq!(
        g.save_json().unwrap(),
        before,
        "projecting a usable item must not reserve it"
    );
    send(&mut g, operation["action"].clone());
    let exhausted = dressing_operation(&g);
    assert_eq!(exhausted["available"], false);
    assert!(!exhausted["reasons"].as_array().unwrap().is_empty());
    tick(&mut g, 5);
    let active = g.session.state().actors["clerk"].active.as_ref().unwrap();
    assert_eq!(active.phase, "windup");
    assert_eq!(active.activation, Some(0));
    assert!(active.paid_item);
    assert!(!g.session.rpg().items().contains_key("dressing-stack-1"));
    assert!(g.view()["inventory"]["items"]
        .as_array()
        .unwrap()
        .iter()
        .all(|item| item["id"] != "dressing-stack-1"));
    assert_eq!(rules::health(g.session.rpg(), "clerk"), 42);
    let save = g.save_json().unwrap();
    g.restore_json(&save).unwrap();
    let token = g.view()["clock"]["pause_reasons"][0]["token"].clone();
    send(&mut g, json!({"kind":"pause.acknowledge","token":token}));
    tick(&mut g, 12);
    assert_eq!(rules::health(g.session.rpg(), "clerk"), 56);
    assert!(!g.session.rpg().items().contains_key("dressing-stack-1"));
    assert_eq!(
        g.session
            .state()
            .logs
            .iter()
            .filter(|l| l.kind == "healing" && l.actor_id.as_deref() == Some("clerk"))
            .count(),
        1
    );
}

fn dressing_operation(g: &CommandGame) -> Value {
    let view = g.view();
    view["inventory"]["items"]
        .as_array()
        .unwrap()
        .iter()
        .find(|item| item["id"] == "dressing-stack-1")
        .unwrap()["operations"]
        .as_array()
        .unwrap()
        .iter()
        .find(|operation| operation["kind"] == "inventory.use")
        .unwrap()
        .clone()
}

#[test]
fn inventory_use_offer_uses_inspected_actor_and_real_queue_availability() {
    for blocked in ["reserve", "dead", "storage", "queue_full"] {
        let (mut s, mut r) = content::initial().unwrap();
        match blocked {
            "reserve" => s.inspected = "ivo".into(),
            "dead" => rules::pool_change(&mut s, &mut r, "player:health", -80).unwrap(),
            "storage" => rules::command(
                &mut s,
                &mut r,
                &CommandIntent::Transfer {
                    item_id: "dressing-stack-1".into(),
                    quantity: 2,
                    from_container_id: "party_pack".into(),
                    to_container_id: "camp_storage".into(),
                },
                false,
            )
            .unwrap(),
            "queue_full" => {
                for _ in 0..4 {
                    rules::command(
                        &mut s,
                        &mut r,
                        &CommandIntent::Enqueue {
                            actor_id: "player".into(),
                            ability_id: "brace".into(),
                            source_id: "item:buckler-2:brace".into(),
                            target: Target {
                                kind: "self".into(),
                                actor_id: None,
                                position: None,
                            },
                        },
                        false,
                    )
                    .unwrap();
                }
            }
            _ => unreachable!(),
        }
        let g = fixture(s, r);
        let before = g.save_json().unwrap();
        let operation = dressing_operation(&g);
        assert_eq!(operation["available"], false, "{blocked}");
        assert!(
            !operation["reasons"].as_array().unwrap().is_empty(),
            "{blocked}"
        );
        assert_eq!(g.save_json().unwrap(), before, "{blocked}");
    }
}
#[test]
fn review_self_mend_pays_and_heals_but_silence_still_rejects() {
    let (mut state, mut rpg) = content::initial().unwrap();
    state.phase = "encounter".into();
    for actor in state.actors.values_mut() {
        actor.hold = true;
    }
    rules::pool_change(&mut state, &mut rpg, "mara:health", -25).unwrap();
    let mut g = fixture(state.clone(), rpg.clone());
    order(
        &mut g,
        "mara",
        "mend",
        "learned:mara:mend:1",
        Target::actor("mara"),
    );
    tick(&mut g, 5);
    assert_eq!(
        g.session.state().actors["mara"]
            .active
            .as_ref()
            .unwrap()
            .phase,
        "windup"
    );
    assert_eq!(g.session.rpg().resources()["mara:focus"].current, 40);
    tick(&mut g, 10);
    assert_eq!(rules::health(g.session.rpg(), "mara"), 43);
    state
        .actors
        .get_mut("mara")
        .unwrap()
        .conditions
        .insert("silence".into(), 60);
    let g = fixture(state, rpg);
    let intent = CommandIntent::Enqueue {
        actor_id: "mara".into(),
        ability_id: "mend".into(),
        source_id: "learned:mara:mend:1".into(),
        target: Target::actor("mara"),
    };
    assert_eq!(
        g.session.preview(&g.player, Some("mara"), &intent).unwrap()["available"],
        false
    );
}

#[test]
fn controlled_last_order_pauses_once_and_companions_act_without_player_orders() {
    let mut g = CommandGame::new(119).unwrap();
    send(
        &mut g,
        json!({"kind":"encounter.start","encounter_id":"garden_patrol"}),
    );
    order(
        &mut g,
        "player",
        "brace",
        "item:buckler-2:brace",
        Target {
            kind: "self".into(),
            actor_id: None,
            position: None,
        },
    );
    let contact = g.session.state().pauses.keys().next().unwrap().clone();
    send(&mut g, json!({"kind":"pause.acknowledge","token":contact}));
    for _ in 0..150 {
        g.observe_fixture().unwrap();
        g.advance(1).unwrap();
        if !g.session.state().pauses.is_empty() {
            break;
        }
    }
    let state = g.session.state();
    let pause = state
        .pauses
        .values()
        .find(|p| p.owner == "orders_empty")
        .expect("Last controlled action pauses");
    assert_eq!(pause.context, "player");
    assert!(state.actors["player"].active.is_none());
    assert!(state.actors["player"].queue.is_empty());
    assert!(state
        .logs
        .iter()
        .any(|l| l.kind == "activation" && l.actor_id.as_deref() == Some("mara")));
    assert!(state
        .logs
        .iter()
        .any(|l| l.kind == "activation" && l.actor_id.as_deref() == Some("clerk")));
    let before = state.tick;
    let saved = g.save_json().unwrap();
    let mut restored = CommandGame::new(0).unwrap();
    restored.restore_json(&saved).unwrap();
    assert!(restored
        .session
        .state()
        .pauses
        .values()
        .any(|p| p.owner == "orders_empty"));
    let token = g.session.state().pauses.keys().next().unwrap().clone();
    send(&mut g, json!({"kind":"pause.acknowledge","token":token}));
    tick(&mut g, before + 5);
    assert!(
        g.session.state().pauses.is_empty(),
        "Resume with no orders must not repause every tick"
    );
}

#[test]
fn obsolete_attacks_are_cleared_together_without_repeated_resume_pauses() {
    let (mut state, rpg) = content::initial().unwrap();
    state.phase = "encounter".into();
    for actor in state.actors.values_mut() {
        actor.hold = true;
    }
    let mut game = fixture(state, rpg);
    for _ in 0..3 {
        order(
            &mut game,
            "player",
            "basic",
            "item:sabre-4:basic",
            Target::actor("hound"),
        );
    }
    let mut state = game.session.state().clone();
    let mut rpg = game.session.rpg().clone();
    rules::pool_change(&mut state, &mut rpg, "hound:health", -30).unwrap();
    combat::pump(&mut state, &mut rpg).unwrap();
    assert!(
        state.actors["player"].queue.is_empty(),
        "All queued strikes at the defeated target should retire together"
    );
    combat::pause_for_orders(&mut state, &rpg);
    assert_eq!(
        state.pauses.len(),
        1,
        "One interruption explains the invalid orders; no redundant needs-orders pause"
    );
    let mut game = fixture(state, rpg);
    let token = game.session.state().pauses.keys().next().unwrap().clone();
    send(&mut game, json!({"kind":"pause.acknowledge","token":token}));
    tick(&mut game, 5);
    assert!(
        game.session.state().pauses.is_empty(),
        "Resume must not rediscover another stale attack every tick"
    );
}

#[test]
fn companion_rejected_preferred_power_falls_back_and_takeover_releases_ai_approach() {
    let (mut s, r) = content::initial().unwrap();
    s.phase = "encounter".into();
    s.actors
        .get_mut("mara")
        .unwrap()
        .conditions
        .insert("silence".into(), 100);
    s.actors.get_mut("sentinel").unwrap().position = [2000, 1000];
    let g = fixture(s, r);
    let mut s = g.session.state().clone();
    let mut r = g.session.rpg().clone();
    let commands = combat::ai(&s, &r, "mara");
    assert!(
        matches!(&commands[0], CommandIntent::Enqueue { ability_id, .. } if ability_id == "basic")
    );
    rules::command(&mut s, &mut r, &commands[0], true).unwrap();
    combat::pump(&mut s, &mut r).unwrap();
    assert_eq!(s.actors["mara"].active.as_ref().unwrap().phase, "approach");
    let ai_id = s.actors["mara"].active.as_ref().unwrap().id.clone();
    rules::command(
        &mut s,
        &mut r,
        &CommandIntent::Possess {
            actor_id: "mara".into(),
            select: true,
        },
        false,
    )
    .unwrap();
    assert_eq!(s.camera.as_deref(), Some("mara"));
    rules::command(
        &mut s,
        &mut r,
        &CommandIntent::Enqueue {
            actor_id: "mara".into(),
            ability_id: "basic".into(),
            source_id: "item:staff-mara:basic".into(),
            target: Target::actor("sentinel"),
        },
        false,
    )
    .unwrap();
    assert!(s.actors["mara"].active.is_none());
    assert!(!s.actors["mara"].queue[0].ai);
    assert!(r.claims().values().all(|c| c.action != ai_id));
    rules::command(
        &mut s,
        &mut r,
        &CommandIntent::Clear {
            actor_id: "mara".into(),
        },
        false,
    )
    .unwrap();
    assert!(s
        .pauses
        .values()
        .any(|p| p.owner == "orders_empty" && p.context == "mara"));
}

#[test]
fn support_ai_uses_last_heal_before_crowd_control_and_restores_health() {
    let (mut s, mut r) = content::initial().unwrap();
    s.phase = "encounter".into();
    for actor in s.actors.values_mut() {
        actor.hold = true;
    }
    s.actors.get_mut("mara").unwrap().hold = false;
    s.actors.get_mut("sentinel").unwrap().position = [2000, 1000];
    rules::pool_change(&mut s, &mut r, "player:health", -65).unwrap();
    rules::pool_change(&mut s, &mut r, "mara:focus", -36).unwrap();
    let mut g = fixture(s, r);
    let commands = combat::ai(g.session.state(), g.session.rpg(), "mara");
    assert!(
        matches!(&commands[0], CommandIntent::Enqueue { ability_id, target, .. }
        if ability_id == "mend" && target.actor_id.as_deref() == Some("player"))
    );
    tick(&mut g, 15);
    assert!(
        rules::health(g.session.rpg(), "player") > 15,
        "Heal must reach impact"
    );
    assert_eq!(g.session.rpg().resources()["mara:focus"].current, 4);
}

#[test]
fn separation_is_bounded_geometry_checked_and_does_not_move_rooted_actor() {
    let (mut s, r) = content::initial().unwrap();
    s.phase = "encounter".into();
    for a in s.actors.values_mut() {
        a.hold = true;
    }
    s.actors.get_mut("player").unwrap().position = [0, 0];
    s.actors.get_mut("mara").unwrap().position = [0, 0];
    s.actors
        .get_mut("mara")
        .unwrap()
        .conditions
        .insert("root".into(), 100);
    let mut g = fixture(s, r);
    tick(&mut g, 20);
    assert_eq!(g.session.state().actors["mara"].position, [0, 0]);
    assert!(rules::distance(g.session.state().actors["player"].position, [0, 0]) > 1000.);
    assert!(rules::distance(g.session.state().actors["player"].position, [0, 0]) <= 1800.);
    let (mut s, r) = content::initial().unwrap();
    for a in s.actors.values_mut() {
        a.hold = true;
    }
    // A planter immediately to the west rejects the proposed repulsion step.
    s.actors.get_mut("player").unwrap().position = [-900, 5000];
    s.actors.get_mut("mara").unwrap().position = [-400, 5000];
    let mut g = fixture(s, r);
    tick(&mut g, 1);
    assert_eq!(g.session.state().actors["player"].position, [-900, 5000]);
}

#[test]
fn transient_stun_does_not_retire_valid_queued_orders() {
    let (mut s, r) = content::initial().unwrap();
    s.phase = "encounter".into();
    for actor in s.actors.values_mut() {
        actor.hold = true;
    }
    let mut game = fixture(s, r);
    order(
        &mut game,
        "player",
        "basic",
        "item:sabre-4:basic",
        Target::actor("hound"),
    );
    let mut s = game.session.state().clone();
    let mut r = game.session.rpg().clone();
    s.actors
        .get_mut("player")
        .unwrap()
        .conditions
        .insert("stun".into(), 10);
    let queue = s.actors["player"].queue.clone();
    combat::pump(&mut s, &mut r).unwrap();
    assert_eq!(s.actors["player"].queue.len(), queue.len());
    assert_eq!(s.actors["player"].queue[0].id, queue[0].id);
    assert!(s.pauses.is_empty());
}

#[test]
fn shield_bash_interrupts_with_short_windup_and_retains_long_recovery() {
    let mut hits = 0;
    let mut misses = 0;
    for (seed, immune) in (1..=16).flat_map(|seed| [(seed, false), (seed, true)]) {
        let (mut state, mut rpg) = content::initial().unwrap();
        state.phase = "encounter".into();
        for actor in state.actors.values_mut() {
            actor.hold = true;
        }
        state.actors.get_mut("player").unwrap().position = [0, 0];
        state.actors.get_mut("corsair_raider").unwrap().position = [1700, 0];
        if immune {
            state
                .actors
                .get_mut("corsair_raider")
                .unwrap()
                .conditions
                .insert("stun_immunity".into(), 100);
        }
        state.observations = space::fixture_frame(&space::requests(&state, 0, 0), 1)
            .unwrap()
            .results
            .into_iter()
            .map(|r| (r.request_id.clone(), r))
            .collect();
        rules::enqueue(
            &mut state,
            &mut rpg,
            "corsair_raider",
            "basic",
            "learned:corsair_raider:basic:1",
            &Target::actor("player"),
            true,
        )
        .unwrap();
        rules::enqueue(
            &mut state,
            &mut rpg,
            "player",
            "shield_bash",
            "item:buckler-2:shield_bash",
            &Target::actor("corsair_raider"),
            false,
        )
        .unwrap();
        let mut g = fixture_seed(state, rpg, seed);
        tick(&mut g, 1);
        let a = g.session.state().actors["player"].active.as_ref().unwrap();
        let impact = a.impact.unwrap();
        assert_eq!(impact - a.activation.unwrap(), 6);
        assert_eq!(a.recovery.unwrap() - a.activation.unwrap(), 36);
        // The authored timings must round-trip during a paid windup.
        let saved = g.save_json().unwrap();
        CommandGame::new(1).unwrap().restore_json(&saved).unwrap();
        tick(&mut g, impact);
        let state = g.session.state();
        let hit = state
            .logs
            .iter()
            .find(|l| l.kind == "attack" && l.actor_id.as_deref() == Some("player"))
            .unwrap();
        assert!(hit.text.starts_with("Shield bash"));
        let landed = hit.damage.unwrap() > 0;
        if landed {
            hits += 1;
        } else {
            misses += 1;
        }
        let enemy = &state.actors["corsair_raider"];
        if immune || !landed {
            assert!(!enemy.conditions.contains_key("stun"));
            assert!(enemy.active.is_some());
        } else {
            assert_eq!(enemy.conditions["stun"], impact + 15);
            assert!(
                enemy.active.is_none(),
                "Bash interrupts the pending enemy strike"
            );
            assert!(
                enemy.ready > state.tick,
                "Interruption does not erase committed recovery"
            );
        }
        assert_eq!(
            state.actors["player"].active.as_ref().unwrap().phase,
            "recovery"
        );
        assert!(rules::availability(
            state,
            g.session.rpg(),
            "player",
            "shield_bash",
            "learned:player:basic:1"
        )
        .is_err());
    }
    assert!(
        hits > 0 && misses > 0,
        "Seed fixtures exercise both hit and miss behavior"
    );
}
