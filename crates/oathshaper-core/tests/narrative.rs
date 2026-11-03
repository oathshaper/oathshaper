use oathshaper_core::*;
fn story() -> Story {
    load_story_json(include_str!("../../../godot/content/lantern_quay.json")).unwrap()
}
fn choice<'a>(view: &'a DialogueView, id: &str) -> Option<&'a ChoiceView> {
    view.choices.iter().find(|choice| choice.id == id)
}
fn recruit(n: &mut NarrativeSession) {
    n.begin_at("clerk_greeting").unwrap();
    n.choose("ask_robbery").unwrap();
    n.begin_at("mara_greeting").unwrap();
    n.choose("accept_help").unwrap();
}
#[test]
fn validation_rejects_broken_link() {
    let mut s = story();
    s.nodes[0].choices[0].next = "missing".into();
    assert!(s.validate().unwrap_err().contains("does not exist"));
}
#[test]
fn responses_validate_return_links_and_reject_automatic_cycles() {
    let mut s = story();
    let response = s.nodes.iter().position(|n| n.id == "mara_thanks").unwrap();
    s.nodes[response].return_to = Some("missing".into());
    assert!(s
        .validate()
        .unwrap_err()
        .contains("return_to target 'missing'"));
    s.nodes[response].return_to = Some("mara_thanks".into());
    assert!(s.validate().unwrap_err().contains("question menu"));
    s.nodes[response].return_to = Some("tide_gate".into());
    assert!(s.validate().unwrap_err().contains("question menu"));
    s.nodes[response].return_to = Some("mara_greeting".into());
    s.nodes[response].choices = s.nodes[0].choices.clone();
    assert!(s
        .validate()
        .unwrap_err()
        .contains("cannot also have choices"));
}
#[test]
fn every_response_returns_to_its_authored_menu_without_effects() {
    let source = story();
    for node in source.nodes.iter().filter(|n| n.return_to.is_some()) {
        let mut session = NarrativeSession::new(source.clone()).unwrap();
        let response = session.begin_at(&node.id).unwrap();
        assert!(response.choices.is_empty());
        assert_eq!(response.return_to, node.return_to);
        let before = session.state().clone();
        let menu = session.finish_response().unwrap();
        assert_eq!(&menu.node_id, node.return_to.as_ref().unwrap());
        assert!(menu.in_dialogue && menu.return_to.is_none());
        assert_eq!(session.state().flags, before.flags);
        assert_eq!(session.state().moral, before.moral);
        assert_eq!(session.state().affinity, before.affinity);
        let after = session.state().clone();
        assert!(session.finish_response().is_err());
        assert_eq!(session.state(), &after);
    }
}
#[test]
fn saved_response_resumes_and_returns_without_repeating_its_choice() {
    let mut session = NarrativeSession::new(story()).unwrap();
    assert!(session.finish_response().is_err());
    session.begin();
    session.choose("share_oil").unwrap();
    let mut restored = NarrativeSession::new(story()).unwrap();
    restored.load_json(&session.save_json().unwrap()).unwrap();
    assert_eq!(restored.view().return_to.as_deref(), Some("mara_greeting"));
    restored.finish_response().unwrap();
    assert_eq!(restored.state().moral, 2);
    assert_eq!(restored.state().affinity["ivo"], 1);
    assert!(choice(&restored.view(), "share_oil").is_none());
    restored.end();
    let ended = restored.state().clone();
    assert!(restored.finish_response().is_err());
    assert_eq!(restored.state(), &ended);
}
#[test]
fn choice_changes_later_line_and_cannot_repeat() {
    let mut n = NarrativeSession::new(story()).unwrap();
    assert!(n.begin().text.contains("tower"));
    let view = n.choose("share_oil").unwrap();
    assert!(view.text.contains("fill the reservoir"));
    assert_eq!(n.state().moral, 2);
    assert_eq!(n.state().affinity["ivo"], 1);
    n.end();
    assert!(n.begin().text.contains("tower"));
    assert!(n.choose("share_oil").is_err());
}
#[test]
fn keeping_oil_cannot_farm_moral() {
    let mut n = NarrativeSession::new(story()).unwrap();
    n.begin();
    n.choose("keep_oil").unwrap();
    n.end();
    n.begin();
    assert!(n.choose("keep_oil").is_err());
    assert_eq!(n.state().moral, -1);
}
#[test]
fn spent_and_closed_branch_choices_disappear_from_views() {
    let mut shared = NarrativeSession::new(story()).unwrap();
    let first = shared.begin();
    assert!(choice(&first, "share_oil").unwrap().enabled);
    assert!(choice(&first, "keep_oil").unwrap().enabled);
    assert!(choice(&first, "ask_for_favor").unwrap().enabled);
    shared.choose("share_oil").unwrap();
    shared.end();
    let mara = shared.begin();
    assert!(choice(&mara, "share_oil").is_none());
    assert!(choice(&mara, "keep_oil").is_none());
    assert!(choice(&mara, "ask_for_favor").unwrap().enabled);
    assert!(shared
        .choose("share_oil")
        .unwrap_err()
        .contains("no longer available"));

    recruit(&mut shared);
    let ivo = shared.begin_at("ivo_gate").unwrap();
    assert!(choice(&ivo, "open_gate").unwrap().enabled);
    shared.choose("open_gate").unwrap();
    assert!(choice(&shared.begin_at("ivo_gate").unwrap(), "open_gate").is_none());

    let clerk = shared.begin_at("clerk_greeting").unwrap();
    assert!(choice(&clerk, "open_shortcut").unwrap().enabled);
    shared.choose("open_shortcut").unwrap();
    assert!(choice(&shared.begin_at("clerk_greeting").unwrap(), "open_shortcut").is_none());

    shared.begin_at("cabinet_greeting").unwrap();
    shared.choose("take_records").unwrap();
    let cabinet = shared.begin_at("cabinet_greeting").unwrap();
    assert!(choice(&cabinet, "take_records").is_none());
    assert!(choice(&cabinet, "leave_records").unwrap().enabled);

    let save = shared.save_json().unwrap();
    let mut restored = NarrativeSession::new(story()).unwrap();
    restored.load_json(&save).unwrap();
    assert_eq!(restored.view(), shared.view());

    let mut kept = NarrativeSession::new(story()).unwrap();
    kept.begin();
    kept.choose("keep_oil").unwrap();
    let closed_mara = kept.begin_at("mara_greeting").unwrap();
    assert!(choice(&closed_mara, "share_oil").is_none());
    assert!(choice(&closed_mara, "keep_oil").is_none());
    assert!(choice(&closed_mara, "ask_theft").unwrap().enabled);
    assert!(choice(&closed_mara, "ask_lamp").unwrap().enabled);
    assert!(choice(&closed_mara, "leave").unwrap().enabled);
    assert!(
        !choice(&kept.begin_at("ivo_gate").unwrap(), "open_gate")
            .unwrap()
            .enabled
    );
    assert!(
        choice(&kept.begin_at("clerk_greeting").unwrap(), "open_shortcut")
            .unwrap()
            .enabled
    );
}
#[test]
fn asked_ivo_choice_is_disabled_as_completed_and_survives_save() {
    let mut session = NarrativeSession::new(story()).unwrap();
    session.begin();
    session.choose("share_oil").unwrap();
    let mara = session.begin_at("mara_greeting").unwrap();
    assert!(choice(&mara, "ask_for_favor").unwrap().enabled);
    assert_eq!(
        session.choose("ask_for_favor").unwrap().node_id,
        "tide_gate"
    );
    assert!(session.state().flags["ivo_where_asked"]);
    let mara = session.finish_response().unwrap();
    let asked = choice(&mara, "ask_for_favor").unwrap();
    assert!(!asked.enabled);
    assert!(asked.completed);
    assert_eq!(asked.locked_reason.as_deref(), Some("Already asked"));
    assert!(session.choose("return_pay").is_err());

    let save = session.save_json().unwrap();
    let mut restored = NarrativeSession::new(story()).unwrap();
    restored.load_json(&save).unwrap();
    let asked = choice(&restored.view(), "ask_for_favor").unwrap().clone();
    assert!(!asked.enabled && asked.completed);
    assert_eq!(asked.locked_reason.as_deref(), Some("Already asked"));
}

#[test]
fn spoken_topics_stay_completed_after_return_reentry_and_save_without_custom_flags() {
    let mut source = story();
    // The general behavior must not depend on each author remembering a flag.
    for node in &mut source.nodes {
        for choice in &mut node.choices {
            choice.disable_when.clear();
        }
    }
    let mut session = NarrativeSession::new(source.clone()).unwrap();
    session.begin();
    session.choose("share_oil").unwrap();
    for (menu, topic) in [
        ("mara_greeting", "ask_for_favor"),
        ("clerk_greeting", "ask_about_records"),
        ("ivo_gate", "ask_about_gate"),
        ("vendor_greeting", "ask_directions"),
        ("vendor_greeting", "ask_about_tower"),
    ] {
        assert!(
            choice(&session.begin_at(menu).unwrap(), topic)
                .unwrap()
                .enabled
        );
        session.choose(topic).unwrap();
        assert!(session.state().chosen_choices[menu].contains(topic));
        let returned = session.finish_response().unwrap();
        let asked = choice(&returned, topic).unwrap();
        assert!(!asked.enabled && asked.completed, "{menu}/{topic}");
        assert_eq!(asked.locked_reason.as_deref(), Some("Already asked"));
        let before = session.state().clone();
        assert!(session.choose_with_events(topic).is_err());
        assert_eq!(session.state(), &before, "rejected repeats are atomic");
        session.choose("leave").unwrap();
        let reentered = session.begin_at(menu).unwrap();
        assert!(choice(&reentered, "leave").unwrap().enabled);
        assert!(!choice(&reentered, topic).unwrap().enabled);
    }
    let mut restored = NarrativeSession::new(source).unwrap();
    restored.load_json(&session.save_json().unwrap()).unwrap();
    assert_eq!(restored.state(), session.state());
    for (menu, topic) in [
        ("mara_greeting", "ask_for_favor"),
        ("clerk_greeting", "ask_about_records"),
        ("ivo_gate", "ask_about_gate"),
    ] {
        let view = restored.begin_at(menu).unwrap();
        assert!(!choice(&view, topic).unwrap().enabled);
        assert!(choice(&view, topic).unwrap().completed);
    }
}

#[test]
fn choice_history_is_scoped_to_menu_and_navigation_remains_repeatable() {
    let mut source = story();
    for node in &mut source.nodes {
        if let Some(topic) = node
            .choices
            .iter_mut()
            .find(|c| ["ask_about_gate", "ask_about_tower"].contains(&c.id.as_str()))
        {
            topic.id = "ask".into();
        }
    }
    let mut session = NarrativeSession::new(source).unwrap();
    session.begin_at("ivo_gate").unwrap();
    session.choose("ask").unwrap();
    session.finish_response().unwrap();
    assert!(!choice(&session.view(), "ask").unwrap().enabled);
    assert!(
        choice(&session.begin_at("vendor_greeting").unwrap(), "ask")
            .unwrap()
            .enabled
    );
    session.choose("ask").unwrap();
    for _ in 0..3 {
        session.begin_at("cabinet_greeting").unwrap();
        session.choose("leave_records").unwrap();
        session.choose("look_again").unwrap();
        assert!(choice(&session.view(), "leave_records").unwrap().enabled);
        session.choose("leave").unwrap();
    }
}

#[test]
fn explicitly_repeatable_spoken_topic_remains_available() {
    let mut source = story();
    source
        .nodes
        .iter_mut()
        .find(|n| n.id == "ivo_gate")
        .unwrap()
        .choices
        .iter_mut()
        .find(|c| c.id == "ask_about_gate")
        .unwrap()
        .repeatable = true;
    let mut session = NarrativeSession::new(source).unwrap();
    session.begin_at("ivo_gate").unwrap();
    for _ in 0..3 {
        session.choose("ask_about_gate").unwrap();
        let returned = session.finish_response().unwrap();
        let asked = choice(&returned, "ask_about_gate").unwrap();
        assert!(asked.enabled && !asked.completed);
    }
}

#[test]
fn old_saves_keep_authored_completion_and_do_not_invent_unrecorded_conversations() {
    let mut session = NarrativeSession::new(story()).unwrap();
    session.begin();
    session.choose("share_oil").unwrap();
    session.finish_response().unwrap();
    session.choose("ask_for_favor").unwrap();
    session.begin_at("clerk_greeting").unwrap();
    session.choose("ask_about_records").unwrap();
    recruit(&mut session);
    session.begin_at("ivo_gate").unwrap();
    session.choose("open_gate").unwrap();
    let mut legacy: serde_json::Value =
        serde_json::from_str(&session.save_json().unwrap()).unwrap();
    legacy["state"]
        .as_object_mut()
        .unwrap()
        .remove("chosen_choices");
    let mut restored = NarrativeSession::new(story()).unwrap();
    restored.load_json(&legacy.to_string()).unwrap();
    assert!(restored.state().chosen_choices.is_empty());
    let mara = restored.begin_at("mara_greeting").unwrap();
    assert!(choice(&mara, "ask_for_favor").is_none()); // Recruited: no stale rendezvous topic.
    let clerk = restored.begin_at("clerk_greeting").unwrap();
    assert!(!choice(&clerk, "ask_about_records").unwrap().enabled);
    assert!(choice(&clerk, "ask_about_records").unwrap().completed);
    let ivo = restored.begin_at("ivo_gate").unwrap();
    assert!(choice(&ivo, "open_gate").is_none());
    // The gate's preparation topic expires; this does not invent a recorded choice.
    assert!(choice(&ivo, "ask_about_gate").is_none());
    assert!(restored.state().chosen_choices.is_empty());
    let clerk = restored.begin_at("clerk_greeting").unwrap();
    assert!(choice(&clerk, "open_shortcut").unwrap().enabled);
}

#[test]
fn invalid_choice_history_does_not_replace_a_live_session() {
    let mut session = NarrativeSession::new(story()).unwrap();
    let before = session.state().clone();
    for history in [
        serde_json::json!({"missing_node": ["leave"]}),
        serde_json::json!({"mara_greeting": ["missing_choice"]}),
    ] {
        let mut save: serde_json::Value =
            serde_json::from_str(&session.save_json().unwrap()).unwrap();
        save["state"]["chosen_choices"] = history;
        assert!(session
            .load_json(&save.to_string())
            .unwrap_err()
            .contains("choice history"));
        assert_eq!(session.state(), &before);
    }
}

#[test]
fn authored_leave_choices_end_dialogue_from_every_menu() {
    let source = story();
    for node in source.nodes.iter().filter(|node| node.return_to.is_none()) {
        let mut session = NarrativeSession::new(source.clone()).unwrap();
        let view = session.begin_at(&node.id).unwrap();
        assert!(choice(&view, "leave").unwrap().enabled, "{}", node.id);
        let outcome = session.choose_with_events("leave").unwrap();
        assert!(!outcome.view.in_dialogue);
        assert!(!session.state().in_dialogue);
        assert_eq!(session.state().current, source.start);
        assert_eq!(outcome.events.len(), 1);
        assert!(session.choose("leave").is_err());
    }
}
#[test]
fn oil_dependent_choice_remains_locked_if_other_requirements_can_change() {
    let mut source = story();
    source.nodes[0]
        .choices
        .iter_mut()
        .find(|c| c.id == "ask_for_favor")
        .unwrap()
        .when
        .push(Condition::MoralAtLeast { value: 3 });
    let mut session = NarrativeSession::new(source).unwrap();
    session.begin();
    session.choose("share_oil").unwrap();
    let view = session.begin_at("mara_greeting").unwrap();
    assert!(!choice(&view, "ask_for_favor").unwrap().enabled);
}
#[test]
fn corrupted_keys_do_not_replace_state() {
    let mut n = NarrativeSession::new(story()).unwrap();
    let original = n.state().clone();
    let save = n.save_json().unwrap().replace("oil_shared", "wrong_flag");
    assert!(n.load_json(&save).is_err());
    assert_eq!(*n.state(), original);
}
#[test]
fn locked_choice_is_atomic() {
    let mut n = NarrativeSession::new(story()).unwrap();
    n.begin();
    let before = n.state().clone();
    assert!(n.choose("return_pay").is_err());
    assert_eq!(*n.state(), before);
}
#[test]
fn save_round_trip() {
    let mut n = NarrativeSession::new(story()).unwrap();
    n.begin();
    n.choose("share_oil").unwrap();
    let save = n.save_json().unwrap();
    let mut restored = NarrativeSession::new(story()).unwrap();
    restored.load_json(&save).unwrap();
    assert_eq!(restored.state(), n.state());
    assert_eq!(restored.view(), n.view());
}

#[test]
fn clerk_lead_marks_records_and_cabinet_pickup_survives_save() {
    let mut session = NarrativeSession::new(story()).unwrap();
    session.begin_at("clerk_greeting").unwrap();
    assert_eq!(
        session.choose("ask_about_records").unwrap().node_id,
        "clerk_records"
    );
    assert!(session.state().flags["records_clue"]);
    assert!(!session.state().flags["records_collected"]);
    session.end();

    assert!(session
        .begin_at("clerk_greeting")
        .unwrap()
        .text
        .contains("payroll chest"));
    session.end();
    assert!(session
        .begin_at("cabinet_greeting")
        .unwrap()
        .text
        .contains("harbor history"));
    assert_eq!(
        session.choose("take_records").unwrap().node_id,
        "cabinet_taken"
    );
    assert!(session.state().flags["records_collected"]);
    session.finish_response().unwrap();
    assert_eq!(
        session.choose("leave_records").unwrap().node_id,
        "cabinet_left"
    );
    assert!(session.choose("take_records").is_err());

    let save = session.save_json().unwrap();
    let mut restored = NarrativeSession::new(story()).unwrap();
    restored.load_json(&save).unwrap();
    assert_eq!(restored.state(), session.state());
    restored.end();
    assert!(restored
        .begin_at("clerk_greeting")
        .unwrap()
        .text
        .contains("payroll chest"));
}

#[test]
fn begin_at_selects_an_entry_and_rejects_unknown_nodes_atomically() {
    let mut n = NarrativeSession::new(story()).unwrap();
    assert_eq!(n.begin_at("ivo_gate").unwrap().speaker, "Ivo");
    let before = n.state().clone();
    assert!(n
        .begin_at("not_an_authored_node")
        .unwrap_err()
        .contains("unknown dialogue node"));
    assert_eq!(*n.state(), before);
    n.end();
    assert!(!n.state().in_dialogue);
    assert_eq!(n.begin().node_id, "mara_greeting");
}

#[test]
fn robbery_requires_clerk_and_companion_but_not_oil_or_optional_history() {
    for oil in ["share_oil", "keep_oil"] {
        let mut n = NarrativeSession::new(story()).unwrap();
        n.begin();
        n.choose(oil).unwrap();
        assert!(
            !choice(&n.begin_at("ivo_gate").unwrap(), "open_gate")
                .unwrap()
                .enabled
        );
        recruit(&mut n);
        n.begin_at("ivo_gate").unwrap();
        assert_eq!(n.choose("open_gate").unwrap().node_id, "ivo_gate_opened");
        assert!(n.state().flags["gate_open"] && n.state().flags["robbery_known"]);
        assert!(!n.state().flags["records_collected"]);
        assert!(!n.state().flags["pay_recovered"]);
        n.begin_at("ivo_gate").unwrap();
        assert!(n.choose("open_gate").is_err());
        n.begin_at("clerk_greeting").unwrap();
        assert_eq!(
            n.choose("open_shortcut").unwrap().node_id,
            "clerk_shortcut_opened"
        );
        assert!(n.state().flags["shortcut_open"]);
        let mut restored = NarrativeSession::new(story()).unwrap();
        restored.load_json(&n.save_json().unwrap()).unwrap();
        assert_eq!(restored.state(), n.state());
    }
}

#[test]
fn pay_chest_collection_and_return_are_distinct_persistent_choices() {
    let mut n = NarrativeSession::new(story()).unwrap();
    assert!(choice(&n.begin(), "return_pay").is_none());
    n.begin_at("pay_loot").unwrap();
    n.choose("take_pay").unwrap();
    assert!(n.state().flags["pay_recovered"]);
    assert!(!n.state().flags["pay_returned"]);
    n.begin_at("clerk_greeting").unwrap();
    assert_eq!(n.choose("return_pay").unwrap().node_id, "clerk_paid");
    assert!(n.state().flags["pay_returned"]);
    let mut restored = NarrativeSession::new(story()).unwrap();
    restored.load_json(&n.save_json().unwrap()).unwrap();
    assert!(choice(&restored.begin_at("clerk_greeting").unwrap(), "return_pay").is_none());
    assert!(choice(&restored.begin_at("pay_loot").unwrap(), "take_pay").is_none());
}

#[test]
fn duplicate_ids_and_unknown_variables_are_reported() {
    let mut reserved_node = story();
    let mut terminal = reserved_node.nodes[1].clone();
    terminal.id = EXIT_TARGET.into();
    reserved_node.nodes.push(terminal);
    assert!(reserved_node
        .validate()
        .unwrap_err()
        .contains("reserved $exit target"));

    let mut duplicate_node = story();
    duplicate_node.nodes[1].id = duplicate_node.nodes[0].id.clone();
    assert!(duplicate_node
        .validate()
        .unwrap_err()
        .contains("duplicate node"));

    let mut duplicate_choice = story();
    duplicate_choice.nodes[0].choices[1].id = duplicate_choice.nodes[0].choices[0].id.clone();
    assert!(duplicate_choice
        .validate()
        .unwrap_err()
        .contains("duplicate choice"));

    let mut unknown_flag = story();
    unknown_flag.nodes[0].choices[0].when.push(Condition::Flag {
        id: "unlisted".into(),
        value: false,
    });
    assert!(unknown_flag
        .validate()
        .unwrap_err()
        .contains("unknown flag"));

    let mut unknown_hide_flag = story();
    unknown_hide_flag.nodes[0].choices[1].hide_when[0].push(Condition::Flag {
        id: "unlisted".into(),
        value: true,
    });
    assert!(unknown_hide_flag
        .validate()
        .unwrap_err()
        .contains("unknown flag"));

    let mut empty_hide_case = story();
    empty_hide_case.nodes[0].choices[0].hide_when.push(vec![]);
    assert!(empty_hide_case
        .validate()
        .unwrap_err()
        .contains("hide_when group cannot be empty"));

    let mut empty_disable_case = story();
    empty_disable_case.nodes[0]
        .choices
        .iter_mut()
        .find(|c| c.id == "ask_for_favor")
        .unwrap()
        .disable_when[0]
        .when
        .clear();
    assert!(empty_disable_case
        .validate()
        .unwrap_err()
        .contains("disable_when needs conditions and a reason"));

    let mut unknown_disable_flag = story();
    unknown_disable_flag.nodes[0]
        .choices
        .iter_mut()
        .find(|c| c.id == "ask_for_favor")
        .unwrap()
        .disable_when[0]
        .when[0] = Condition::Flag {
        id: "unlisted".into(),
        value: true,
    };
    assert!(unknown_disable_flag
        .validate()
        .unwrap_err()
        .contains("unknown flag"));

    let mut unknown_companion = story();
    unknown_companion.nodes[0].choices[0]
        .effects
        .push(Effect::AddAffinity {
            companion: "unlisted".into(),
            amount: 1,
        });
    assert!(unknown_companion
        .validate()
        .unwrap_err()
        .contains("unknown companion"));
}

#[test]
fn invalid_ranges_and_unknown_json_fields_are_rejected() {
    let mut invalid = story();
    invalid.moral.initial = invalid.moral.max + 1;
    assert!(invalid.validate().unwrap_err().contains("moral range"));
    let source = include_str!("../../../godot/content/lantern_quay.json");
    let unknown = source.replacen("\"schema\": 1,", "\"schema\": 1, \"typo\": true,", 1);
    assert!(load_story_json(&unknown)
        .unwrap_err()
        .contains("unknown field"));
}

#[test]
fn multi_effect_failure_is_atomic() {
    let mut s = story();
    s.nodes[0]
        .choices
        .iter_mut()
        .find(|c| c.id == "share_oil")
        .unwrap()
        .effects
        .push(Effect::AddMoral { amount: i32::MAX });
    let mut n = NarrativeSession::new(s).unwrap();
    n.begin();
    let before = n.state().clone();
    assert!(n.choose("share_oil").is_err());
    assert_eq!(*n.state(), before);
}

#[test]
fn malformed_and_incompatible_saves_preserve_live_session() {
    let mut n = NarrativeSession::new(story()).unwrap();
    n.begin();
    let before = n.state().clone();
    assert!(n.load_json("{").is_err());
    let mut wrong_revision: serde_json::Value =
        serde_json::from_str(&n.save_json().unwrap()).unwrap();
    wrong_revision["revision"] = serde_json::json!(3);
    assert!(n.load_json(&wrong_revision.to_string()).is_err());
    let unknown_node = n
        .save_json()
        .unwrap()
        .replace("mara_greeting", "missing_node");
    assert!(n.load_json(&unknown_node).is_err());
    assert_eq!(*n.state(), before);
}

#[test]
fn identical_inputs_produce_identical_saves() {
    let source = story();
    let mut a = NarrativeSession::new(source.clone()).unwrap();
    let mut b = NarrativeSession::new(source).unwrap();
    for session in [&mut a, &mut b] {
        session.begin();
        session.choose("share_oil").unwrap();
        session.end();
        session.begin();
        session.choose("ask_for_favor").unwrap();
    }
    assert_eq!(a.save_json().unwrap(), b.save_json().unwrap());
}

#[test]
fn committed_choices_emit_stable_events_only_after_success() {
    let mut n = NarrativeSession::new(story()).unwrap();
    n.begin();
    assert!(n.choose_with_events("return_pay").is_err());
    let outcome = n.choose_with_events("share_oil").unwrap();
    assert_eq!(outcome.view.node_id, "mara_thanks");
    assert_eq!(
        outcome.events,
        vec![NarrativeEvent::ChoiceCommitted {
            story_id: "lantern_quay".into(),
            node_id: "mara_greeting".into(),
            choice_id: "share_oil".into(),
        }]
    );
}

#[test]
fn world_outcome_changes_only_declared_fact_and_expires_preparation() {
    let mut session = NarrativeSession::new(story()).unwrap();
    let original = session.state().clone();
    assert!(session.set_world_flag("unknown_fact", true).is_err());
    assert_eq!(session.state(), &original);
    session.set_world_flag("raiders_defeated", true).unwrap();
    let mut expected = original;
    expected.flags.insert("raiders_defeated".into(), true);
    assert_eq!(session.state(), &expected);
    let ivo = session.begin_at("ivo_gate").unwrap();
    for id in ["ask_about_gate", "ask_sentries", "open_gate"] {
        assert!(choice(&ivo, id).is_none());
    }
    assert!(ivo.text.contains("guards are down"));
}
