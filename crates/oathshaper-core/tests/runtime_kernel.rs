//! Executable foundation contracts. These adapters are test-only, not registered game profiles.
use oathshaper_core::{rpg::*, runtime::*};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::BTreeSet;

fn resource(id: &str, current: i64) -> Resource {
    Resource {
        id: id.into(),
        owner: id.into(),
        unit: "point".into(),
        minimum: 0,
        maximum: 20,
        current,
    }
}
fn item(id: &str, quantity: u32) -> Item {
    Item {
        id: id.into(),
        definition: "wand/v1".into(),
        owner: "A".into(),
        parent: None,
        quantity,
        stack_key: "plain/v1".into(),
        protected: false,
    }
}
fn equip(actor: &str, id: &str, slots: &[&str]) -> Mutation {
    Mutation::Equip {
        actor: actor.into(),
        item: id.into(),
        slots: slots.iter().map(|s| (*s).into()).collect(),
    }
}
fn investment(id: &str, dependencies: &[&str]) -> Investment {
    Investment {
        id: id.into(),
        actor: "A".into(),
        definition: id.into(),
        awarded_at: 1,
        currency: "skill".into(),
        amount: 1,
        prerequisites: dependencies.iter().map(|s| (*s).into()).collect(),
    }
}
fn claim(id: &str, target: ClaimTarget) -> Claim {
    Claim {
        id: id.into(),
        owner: "A".into(),
        action: "pending".into(),
        target,
    }
}
fn reserve(id: &str, resource: &str, amount: i64) -> Mutation {
    Mutation::Reserve(claim(
        id,
        ClaimTarget::Resource {
            resource: resource.into(),
            amount,
        },
    ))
}
fn source() -> Source {
    Source::Item {
        item: "wand".into(),
        equipped: true,
    }
}
fn gear() -> RpgState {
    let mut state = RpgState::default();
    state
        .apply(&[
            Mutation::PutResource(resource("A", 10)),
            Mutation::PutResource(resource("B", 10)),
            Mutation::PutResource(resource("C", 7)),
            Mutation::InsertItem(item("wand", 1)),
            equip("A", "wand", &["left", "right"]),
            Mutation::AddInvestment(investment("learn-fire", &[])),
            Mutation::AddGrant(Grant {
                id: "item-fire".into(),
                recipient: "A".into(),
                ability: "fire".into(),
                source: source(),
            }),
            Mutation::AddGrant(Grant {
                id: "learned-fire".into(),
                recipient: "A".into(),
                ability: "fire".into(),
                source: Source::Investment {
                    investment: "learn-fire".into(),
                },
            }),
        ])
        .unwrap();
    state
}
fn lease<P: Profile>(
    session: &mut Session<P>,
    host: &mut HostAuthority,
    actors: &[&str],
    observer: &str,
    role: Role,
) -> String {
    session
        .issue_lease(
            host,
            Principal {
                id: "operator".into(),
                role,
            },
            observer,
            LeaseScope {
                actors: actors.iter().map(|a| (*a).into()).collect(),
                system_commands: true,
                advance: true,
            },
        )
        .unwrap()
}
fn env<P: Profile, T>(
    session: &Session<P>,
    lease: &str,
    id: &str,
    actor: Option<&str>,
    payload: T,
) -> Envelope<T> {
    Envelope {
        generation: session.generation(),
        epoch: session.epoch(),
        id: id.into(),
        lease: lease.into(),
        expected_revision: session.revision(),
        actor: actor.map(str::to_owned),
        payload,
    }
}

#[test]
fn invalid_claims_cannot_be_consumed_into_credit_or_erased_before_validation() {
    let mut r = RpgState::default();
    r.apply(&[Mutation::PutResource(resource("mana", 10))])
        .unwrap();
    let before = r.clone();
    for amount in [-7, 0, i64::MIN, 11, i64::MAX] {
        assert!(
            r.apply(&[
                reserve("bad", "mana", amount),
                Mutation::ConsumeClaim { id: "bad".into() }
            ])
            .is_err(),
            "amount {amount}"
        );
        assert_eq!(r, before);
    }
    assert!(r
        .apply(&[Mutation::AdjustResource {
            id: "mana".into(),
            delta: i64::MAX
        }])
        .is_err());
    assert!(r
        .apply(&[
            Mutation::AdjustResource {
                id: "mana".into(),
                delta: -11
            },
            Mutation::AdjustResource {
                id: "mana".into(),
                delta: 11
            }
        ])
        .is_err());
    assert_eq!(r, before);
    r.apply(&[
        reserve("own", "mana", 4),
        reserve("other", "mana", 6),
        Mutation::ConsumeClaim { id: "own".into() },
    ])
    .unwrap();
    assert_eq!(r.resources()["mana"].current, 6);
    assert_eq!(r.available("mana").unwrap(), 0);
    assert_eq!(r.claims().len(), 1);
}

#[test]
fn quantity_claims_consume_only_their_share_and_overflow_is_atomic() {
    let mut r = RpgState::default();
    r.apply(&[Mutation::InsertItem(item("stack", 5))]).unwrap();
    let before = r.clone();
    for quantity in [0, 6, u32::MAX] {
        assert!(r
            .apply(&[
                Mutation::Reserve(claim(
                    "bad",
                    ClaimTarget::Item {
                        item: "stack".into(),
                        quantity
                    }
                )),
                Mutation::ConsumeClaim { id: "bad".into() }
            ])
            .is_err());
        assert_eq!(r, before);
    }
    r.apply(&[
        Mutation::Reserve(claim(
            "first",
            ClaimTarget::Item {
                item: "stack".into(),
                quantity: 2,
            },
        )),
        Mutation::Reserve(claim(
            "second",
            ClaimTarget::Item {
                item: "stack".into(),
                quantity: 3,
            },
        )),
        Mutation::ConsumeClaim { id: "first".into() },
    ])
    .unwrap();
    assert_eq!(r.items()["stack"].quantity, 3);
    assert_eq!(r.claims().len(), 1);
    r.apply(&[Mutation::ConsumeClaim {
        id: "second".into(),
    }])
    .unwrap();
    assert!(r.items().is_empty());
    r.apply(&[
        Mutation::InsertItem(item("max", u32::MAX)),
        Mutation::InsertItem(item("one", 1)),
    ])
    .unwrap();
    let before = r.clone();
    assert!(r
        .apply(&[Mutation::MergeItems {
            from: "one".into(),
            into: "max".into()
        }])
        .is_err());
    assert_eq!(r, before);
}

#[test]
fn ownership_cycles_protected_items_and_split_merge_are_checked() {
    let mut r = RpgState::default();
    let mut protected = item("quest", 1);
    protected.protected = true;
    r.apply(&[
        Mutation::InsertItem(item("bag", 1)),
        Mutation::InsertItem(item("stack", 5)),
        Mutation::InsertItem(protected),
    ])
    .unwrap();
    let before = r.clone();
    assert!(r
        .apply(&[Mutation::TransferItem {
            item: "bag".into(),
            owner: "A".into(),
            parent: Some("bag".into())
        }])
        .is_err());
    assert!(r
        .apply(&[Mutation::ConsumeItem {
            item: "quest".into(),
            quantity: 1
        }])
        .is_err());
    assert_eq!(r, before);
    r.apply(&[Mutation::SplitItem {
        item: "stack".into(),
        quantity: 2,
        new_id: "split".into(),
    }])
    .unwrap();
    assert_eq!(
        (r.items()["stack"].quantity, r.items()["split"].quantity),
        (3, 2)
    );
    r.apply(&[Mutation::MergeItems {
        from: "split".into(),
        into: "stack".into(),
    }])
    .unwrap();
    assert_eq!(r, before);
}

#[test]
fn grants_follow_the_recipient_or_an_explicit_remote_emitter_and_report_all_removals() {
    let mut r = gear();
    r.apply(&[Mutation::AddGrant(Grant {
        id: "aura".into(),
        recipient: "C".into(),
        ability: "ward".into(),
        source: Source::EquippedBy {
            item: "wand".into(),
            actor: "A".into(),
        },
    })])
    .unwrap();
    assert!(r.has_ability("C", "ward"));
    let changes = r
        .apply(&[
            Mutation::Unequip {
                actor: "A".into(),
                slots: vec!["left".into(), "right".into()],
            },
            Mutation::TransferItem {
                item: "wand".into(),
                owner: "B".into(),
                parent: None,
            },
            equip("B", "wand", &["left"]),
        ])
        .unwrap();
    assert_eq!(
        changes
            .revoked_grants
            .iter()
            .map(|g| g.id.as_str())
            .collect::<BTreeSet<_>>(),
        BTreeSet::from(["aura", "item-fire"])
    );
    assert!(r.has_ability("A", "fire"));
    assert!(!r.grants().contains_key("item-fire"));
    assert!(!r.has_ability("C", "ward"));
    let changes = r
        .apply(&[Mutation::RevokeSource(Source::Investment {
            investment: "learn-fire".into(),
        })])
        .unwrap();
    assert_eq!(changes.revoked_grants[0].id, "learned-fire");
    assert!(!r.has_ability("A", "fire"));
    assert!(r
        .apply(&[Mutation::AddGrant(Grant {
            id: "wrong".into(),
            recipient: "A".into(),
            ability: "fire".into(),
            source: source()
        })])
        .is_err());
}

#[test]
fn old_slots_old_items_and_shared_readers_block_exclusive_gear_edits() {
    let mut r = gear();
    r.apply(&[Mutation::Reserve(claim(
        "right",
        ClaimTarget::Binding {
            actor: "A".into(),
            slot: "right".into(),
        },
    ))])
    .unwrap();
    let before = r.clone();
    assert!(r.apply(&[equip("A", "wand", &["left"])]).is_err());
    assert_eq!(r, before);
    r.apply(&[
        Mutation::ReleaseClaim { id: "right".into() },
        Mutation::Reserve(claim(
            "queue-1",
            ClaimTarget::ItemRead {
                item: "wand".into(),
            },
        )),
        Mutation::Reserve(claim(
            "queue-2",
            ClaimTarget::BindingRead {
                actor: "A".into(),
                slot: "left".into(),
                item: "wand".into(),
            },
        )),
        Mutation::InsertItem(item("new", 1)),
    ])
    .unwrap();
    assert_eq!(r.items()["wand"].quantity, 1);
    assert_eq!(r.claims().len(), 2);
    let before = r.clone();
    assert!(r.apply(&[equip("A", "new", &["left"])]).is_err());
    assert!(r
        .apply(&[Mutation::Unequip {
            actor: "A".into(),
            slots: vec!["right".into()]
        }])
        .is_err());
    assert_eq!(r, before);
    r.apply(&[
        Mutation::ReleaseClaim {
            id: "queue-1".into(),
        },
        Mutation::ReleaseClaim {
            id: "queue-2".into(),
        },
        equip("A", "new", &["left"]),
    ])
    .unwrap();
    assert_eq!(r.bindings()["A"]["left"], "new");
}

struct Recipe;
impl RecipePolicy for Recipe {
    fn prepare(&self, state: &RpgState, actor: &str, recipe: &str) -> ServiceResult<Vec<Mutation>> {
        if actor != "A" || recipe != "tonic" || !state.has_ability("A", "fire") {
            return Err(ServiceError("unknown recipe or prerequisite".into()));
        }
        Ok(vec![
            Mutation::ConsumeItem {
                item: "scrap".into(),
                quantity: 1,
            },
            Mutation::AdjustResource {
                id: "A".into(),
                delta: -2,
            },
            Mutation::InsertItem(item("tonic", 1)),
        ])
    }
}
#[test]
fn recipe_and_dependency_respec_failures_preserve_the_complete_service_state() {
    let mut r = gear();
    r.apply(&[Mutation::InsertItem(item("scrap", 2))]).unwrap();
    let before = r.clone();
    let full = |state: &RpgState| {
        if state.items().len() <= 2 {
            Ok(())
        } else {
            Err(ServiceError("full".into()))
        }
    };
    assert!(r.craft("A", "tonic", &Recipe, &full).is_err());
    assert_eq!(r, before);
    r.craft("A", "tonic", &Recipe, &|_: &RpgState| Ok(()))
        .unwrap();
    assert_eq!(r.resources()["A"].current, 8);
    assert_eq!(r.items()["scrap"].quantity, 1);
    r.apply(&[Mutation::AddInvestment(investment(
        "advanced",
        &["learn-fire"],
    ))])
    .unwrap();
    let before = r.clone();
    assert!(r
        .apply(&[Mutation::RemoveInvestment {
            id: "learn-fire".into()
        }])
        .is_err());
    assert_eq!(r, before);
    assert!(r
        .apply(&[
            Mutation::AddInvestment(investment("cycle-a", &["cycle-b"])),
            Mutation::AddInvestment(investment("cycle-b", &["cycle-a"]))
        ])
        .is_err());
    assert_eq!(r, before);
    let changes = r
        .apply(&[
            Mutation::RemoveInvestment {
                id: "advanced".into(),
            },
            Mutation::RemoveInvestment {
                id: "learn-fire".into(),
            },
        ])
        .unwrap();
    assert!(changes
        .revoked_grants
        .iter()
        .any(|g| g.id == "learned-fire"));
    assert!(r.has_ability("A", "fire"));
    let mut deep = RpgState::default();
    let nodes: Vec<_> = (0..2000)
        .map(|n| {
            let mut entry = investment(&format!("n{n}"), &[]);
            if n > 0 {
                entry.prerequisites.insert(format!("n{}", n - 1));
            }
            Mutation::AddInvestment(entry)
        })
        .collect();
    deep.apply(&nodes).unwrap(); // No recursive walk or arbitrary class-level dependency is imposed.
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ProbeCommand {
    fail: bool,
}
struct Probe;
impl Profile for Probe {
    type State = u64;
    type Command = ProbeCommand;
    type Advance = ProbeCommand;
    type View = Value;
    type Preview = ();
    fn manifest(&self) -> Manifest {
        Manifest::minimal("probe", 1, "fixture-v2")
    }
    fn preview(
        &self,
        _: &ReadContext<'_, u64>,
        _: Option<&str>,
        _: &ProbeCommand,
    ) -> RuleResult<()> {
        Ok(())
    }
    fn prepare_command(
        &self,
        tx: &mut Transaction<u64>,
        _: Option<&str>,
        cmd: &ProbeCommand,
    ) -> RuleResult {
        tx.entropy.below(6)?;
        tx.observe("pose", 1)?;
        if tx.occurrence("probe/hit")? {
            tx.state += 1;
        }
        tx.emit("secret", 42, Visibility::only("secret"))?;
        if cmd.fail {
            Err(RuleError::new("hidden-cause", "secret immunity").private("secret"))
        } else {
            Ok(())
        }
    }
    fn prepare_advance(&self, tx: &mut Transaction<u64>, cmd: &ProbeCommand) -> RuleResult {
        self.prepare_command(tx, None, cmd)
    }
    fn project(&self, ctx: &ReadContext<'_, u64>) -> Value {
        if ctx.observer == "secret" {
            json!({"count":ctx.state,"hidden":42})
        } else {
            json!({"count":ctx.state})
        }
    }
    fn validate(&self, _: &u64, _: &RpgState) -> RuleResult {
        Ok(())
    }
    fn quiescent(&self, _: &u64, _: &RpgState) -> bool {
        true
    }
    fn decide_ai(&self, _: &ReadContext<'_, u64>, _: &str) -> Vec<ProbeCommand> {
        vec![ProbeCommand { fail: false }]
    }
}
#[test]
fn rejected_candidates_roll_back_entropy_observations_occurrences_and_retry_is_terminal() {
    let mut host = HostAuthority::default();
    let mut s = Session::new(Probe, 0, RpgState::default(), 7, "s", &mut host).unwrap();
    let public = lease(&mut s, &mut host, &["A"], "public", Role::Player);
    assert!(s
        .preview(&public, Some("A"), &ProbeCommand { fail: false })
        .is_ok());
    assert_eq!(s.entropy_draws(), 0);
    let rejected = env(
        &s,
        &public,
        "rejected",
        Some("A"),
        ProbeCommand { fail: true },
    );
    let receipt = s.submit(rejected.clone()).unwrap();
    assert_eq!(receipt.status, Status::Rejected);
    assert_eq!(receipt.reason.unwrap().code, "unavailable");
    assert_eq!(
        (
            *s.state(),
            s.revision(),
            s.entropy_draws(),
            s.ledger_sequence()
        ),
        (0, 0, 0, 1)
    );
    let saved: Value = serde_json::from_str(&s.save_json().unwrap()).unwrap();
    assert_eq!(saved["observation_positions"], json!({}));
    assert_eq!(saved["occurrences"], json!([]));
    let accepted = env(
        &s,
        &public,
        "accepted",
        Some("A"),
        ProbeCommand { fail: false },
    );
    assert!(s.submit(accepted.clone()).unwrap().events.is_empty());
    assert_eq!(s.submit(rejected).unwrap().status, Status::Rejected); // dedup precedes stale revision.
    assert_eq!(
        (*s.state(), s.entropy_draws(), s.ledger_sequence()),
        (1, 1, 2)
    );
    let secret = lease(&mut s, &mut host, &["A"], "secret", Role::Player);
    let mut cached = accepted.clone();
    cached.lease = secret.clone();
    assert_eq!(s.submit(cached).unwrap().events.len(), 1);
    assert!(s.view(&public).unwrap().get("hidden").is_none());
    assert_eq!(s.view(&secret).unwrap()["hidden"], 42);
    let mut changed = accepted;
    changed.payload.fail = true;
    assert!(s.submit(changed).is_err());
    assert_eq!(s.ledger_sequence(), 2);
}
#[test]
fn npc_decisions_use_normal_authority_and_identical_streams_produce_identical_saves() {
    let mut host = HostAuthority::default();
    let mut a = Session::new(Probe, 0, RpgState::default(), 123, "s", &mut host).unwrap();
    let mut b = Session::new(Probe, 0, RpgState::default(), 123, "s", &mut host).unwrap();
    let al = lease(&mut a, &mut host, &["A"], "public", Role::Ai);
    let bl = lease(&mut b, &mut host, &["A"], "public", Role::Ai);
    assert!(a.ai_commands(&al, "B").is_err());
    assert!(a
        .submit(env(
            &a,
            &al,
            "illegal",
            Some("B"),
            ProbeCommand { fail: false }
        ))
        .is_err());
    assert_eq!(a.ledger_sequence(), 0);
    let decision = a.ai_commands(&al, "A").unwrap().remove(0);
    a.submit(env(&a, &al, "ai-1", Some("A"), decision.clone()))
        .unwrap();
    b.submit(env(&b, &bl, "ai-1", Some("A"), decision)).unwrap();
    assert_eq!(a.save_json().unwrap(), b.save_json().unwrap());
    let mut entropy = Entropy::seeded(0);
    assert_eq!(entropy.next_u64().unwrap(), 0xe220a8397b1dcdaf);
    assert!(entropy.below(0).is_err());
}
#[test]
fn malformed_fingerprints_and_ledger_corruption_never_replace_the_live_session() {
    let mut host = HostAuthority::default();
    let mut s = Session::new(Probe, 0, RpgState::default(), 7, "s", &mut host).unwrap();
    let l = lease(&mut s, &mut host, &["A"], "public", Role::Player);
    s.submit(env(&s, &l, "one", Some("A"), ProbeCommand { fail: false }))
        .unwrap();
    let original = s.save_json().unwrap();
    let generation = s.generation();
    for mutation in 0..9 {
        let mut value: Value = serde_json::from_str(&original).unwrap();
        match mutation {
            0 => value["receipts"]["one"]["fingerprint"] = json!({}),
            1 => value["receipts"]["one"]["fingerprint"]["principal"]["id"] = json!("other"),
            2 => {
                value["receipts"]["one"]["fingerprint"]["payload"] =
                    json!({"fail":false,"unknown":5})
            }
            3 => value["receipts"]["one"]["fingerprint"]["participants"] = json!(["B"]),
            4 => value["receipts"]["one"]["ledger_sequence"] = json!(9),
            5 => value["revision"] = json!(4),
            6 => value["receipts"] = json!({}),
            7 => value["manifest"]["content_hash"] = json!("changed"),
            _ => {
                value["receipts"] = json!({});
                value["epoch_base_ledger"] = json!(1);
                value["epoch_base_revision"] = json!(1);
            }
        }
        assert!(
            s.restore_json(&value.to_string(), &mut host).is_err(),
            "mutation {mutation}"
        );
        assert_eq!(s.generation(), generation);
        assert_eq!(s.save_json().unwrap(), original);
        assert!(s.view(&l).is_ok());
    }
}
#[test]
fn restore_rotates_authority_cached_retry_survives_and_closed_epochs_cannot_reexecute() {
    let mut host = HostAuthority::default();
    let mut s = Session::new(Probe, 0, RpgState::default(), 7, "s", &mut host).unwrap();
    let l = lease(&mut s, &mut host, &["A"], "public", Role::Player);
    let old = env(&s, &l, "one", Some("A"), ProbeCommand { fail: false });
    s.submit(old.clone()).unwrap();
    let save = s.save_json().unwrap();
    s.restore_json(&save, &mut host).unwrap();
    assert!(s.restored_paused());
    assert!(s.view(&l).is_err());
    assert!(s.submit(old.clone()).is_err());
    assert_eq!(s.ledger_sequence(), 1);
    let fresh = lease(&mut s, &mut host, &["A"], "public", Role::Player);
    let mut retry = old;
    retry.generation = s.generation();
    retry.lease = fresh.clone();
    assert_eq!(s.submit(retry).unwrap().status, Status::Accepted);
    assert_eq!(s.ledger_sequence(), 1);
    let paused = env(
        &s,
        &fresh,
        "paused",
        Some("A"),
        ProbeCommand { fail: false },
    );
    assert_eq!(s.submit(paused.clone()).unwrap().status, Status::Rejected);
    s.resume_after_restore();
    assert_eq!(s.submit(paused).unwrap().status, Status::Rejected);
    let old_epoch = env(
        &s,
        &fresh,
        "old-epoch",
        Some("A"),
        ProbeCommand { fail: false },
    );
    s.close_epoch().unwrap();
    assert!(s.submit(old_epoch).is_err());
    let compacted = s.save_json().unwrap();
    s.restore_json(&compacted, &mut host).unwrap();
    assert_eq!(s.epoch(), 2);
}

#[test]
fn restore_acknowledgement_admission_and_pause_commit_atomically() {
    let mut host = HostAuthority::default();
    let mut s = Session::new(Probe, 0, RpgState::default(), 7, "resume", &mut host).unwrap();
    let l = lease(&mut s, &mut host, &["A"], "public", Role::Player);
    let first = env(&s, &l, "prior", Some("A"), ProbeCommand { fail: false });
    s.submit(first.clone()).unwrap();
    let save = s.save_json().unwrap();
    s.restore_json(&save, &mut host).unwrap();
    let fresh = lease(&mut s, &mut host, &["A"], "public", Role::Player);
    let mut retry = first;
    retry.generation = s.generation();
    retry.lease = fresh.clone();
    assert_eq!(s.resume_and_submit(retry).unwrap().status, Status::Accepted);
    assert!(
        s.restored_paused(),
        "a historical accepted receipt is not a new acknowledgement"
    );
    let conflicting = env(&s, &fresh, "prior", Some("A"), ProbeCommand { fail: true });
    assert!(s.resume_and_submit(conflicting).is_err());
    assert!(s.restored_paused(), "admission failure keeps the barrier");
    let invalid = env(
        &s,
        &fresh,
        "bad-ack",
        Some("A"),
        ProbeCommand { fail: true },
    );
    assert_eq!(
        s.resume_and_submit(invalid.clone()).unwrap().status,
        Status::Rejected
    );
    assert!(s.restored_paused(), "profile rejection keeps the barrier");
    assert_eq!(
        s.resume_and_submit(invalid).unwrap().status,
        Status::Rejected
    );
    assert!(s.restored_paused(), "cached rejection keeps the barrier");
    let stale = env(
        &s,
        &fresh,
        "stale-ack",
        Some("A"),
        ProbeCommand { fail: false },
    );
    let mut stale = stale;
    stale.expected_revision = 0;
    assert_eq!(s.resume_and_submit(stale).unwrap().status, Status::Rejected);
    assert!(s.restored_paused());
    let good = env(&s, &fresh, "ack", Some("A"), ProbeCommand { fail: false });
    let accepted = s.resume_and_submit(good.clone()).unwrap();
    assert_eq!(accepted.status, Status::Accepted);
    assert!(!s.restored_paused());
    assert_eq!(s.resume_and_submit(good).unwrap(), accepted);
    assert!(!s.restored_paused());
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
struct TurnState {
    actions: u8,
    pending: bool,
    reaction: bool,
    effects: u32,
    phase: String,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "kind", deny_unknown_fields)]
enum TurnCommand {
    Cast {
        target: String,
    },
    React,
    Group {
        members: Vec<String>,
        target: String,
    },
    Seal,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
enum TurnAdvance {
    Resolve,
    ExecuteInterval,
}
struct Turn;
impl Profile for Turn {
    type State = TurnState;
    type Command = TurnCommand;
    type Advance = TurnAdvance;
    type View = TurnState;
    type Preview = ();
    fn manifest(&self) -> Manifest {
        Manifest::new("test-turn", 1, "turn-v2")
    }
    fn participants(&self, actor: Option<&str>, command: &TurnCommand) -> BTreeSet<String> {
        match command {
            TurnCommand::Group { members, .. } => members
                .iter()
                .cloned()
                .chain(actor.map(str::to_owned))
                .collect(),
            _ => actor.map(str::to_owned).into_iter().collect(),
        }
    }
    fn preview(
        &self,
        _: &ReadContext<'_, TurnState>,
        _: Option<&str>,
        _: &TurnCommand,
    ) -> RuleResult<()> {
        Ok(())
    }
    fn prepare_command(
        &self,
        tx: &mut Transaction<TurnState>,
        actor: Option<&str>,
        command: &TurnCommand,
    ) -> RuleResult {
        match command {
            TurnCommand::Cast { .. } => {
                if actor != Some("A") || tx.state.actions < 2 || tx.state.pending {
                    return Err(RuleError::new("turn", "Not ready"));
                }
                tx.rpg.apply(&[
                    reserve("cast", "A", 6),
                    Mutation::ConsumeClaim { id: "cast".into() },
                    Mutation::Reserve(claim(
                        "cast-source",
                        ClaimTarget::ItemRead {
                            item: "wand".into(),
                        },
                    )),
                ])?;
                tx.state.actions -= 2;
                tx.state.pending = true;
            }
            TurnCommand::React => {
                if actor != Some("B") || !tx.state.pending || !tx.state.reaction {
                    return Err(RuleError::new("reaction", "No reaction window"));
                }
                tx.state.reaction = false;
                tx.state.pending = false;
                tx.rpg.apply(&[Mutation::ReleaseClaim {
                    id: "cast-source".into(),
                }])?;
            }
            TurnCommand::Group { members, .. } => {
                tx.authority().require(members.iter().map(String::as_str))?;
                let mut plan = Vec::new();
                for member in members {
                    plan.push(reserve(&format!("mp-{member}"), member, 8));
                    plan.push(Mutation::Reserve(claim(
                        &format!("ready-{member}"),
                        ClaimTarget::Actor {
                            actor: member.clone(),
                        },
                    )));
                }
                for member in members {
                    plan.push(Mutation::ConsumeClaim {
                        id: format!("mp-{member}"),
                    });
                    plan.push(Mutation::ReleaseClaim {
                        id: format!("ready-{member}"),
                    });
                }
                tx.rpg.apply(&plan)?;
                tx.state.effects += 1;
            }
            TurnCommand::Seal => {
                if tx.state.phase != "planning" {
                    return Err(RuleError::new("phase", "Plan already sealed"));
                }
                tx.state.phase = "execution".into();
            }
        }
        Ok(())
    }
    fn prepare_advance(
        &self,
        tx: &mut Transaction<TurnState>,
        advance: &TurnAdvance,
    ) -> RuleResult {
        match advance {
            TurnAdvance::Resolve => {
                if tx.state.pending {
                    tx.state.effects += 1;
                    tx.state.pending = false;
                    tx.rpg.apply(&[Mutation::ReleaseClaim {
                        id: "cast-source".into(),
                    }])?;
                }
            }
            TurnAdvance::ExecuteInterval => {
                if tx.state.phase != "execution" || tx.state.pending {
                    return Err(RuleError::new("phase", "Resolve reaction before interval"));
                }
                tx.state.phase = "planning".into();
                tx.state.actions = 3;
            }
        }
        Ok(())
    }
    fn project(&self, ctx: &ReadContext<'_, TurnState>) -> TurnState {
        ctx.state.clone()
    }
    fn validate(&self, state: &TurnState, rpg: &RpgState) -> RuleResult {
        if state.actions > 3
            || (state.pending
                && (!rpg.claims().contains_key("cast-source")
                    || !rpg.grants().contains_key("item-fire")))
        {
            return Err(RuleError::new(
                "pending",
                "Broken pending cast source/claim",
            ));
        }
        Ok(())
    }
    fn quiescent(&self, state: &TurnState, _: &RpgState) -> bool {
        !state.pending && state.phase == "planning"
    }
}
fn turn_state() -> TurnState {
    TurnState {
        actions: 3,
        pending: false,
        reaction: true,
        effects: 0,
        phase: "planning".into(),
    }
}
#[test]
fn turn_activity_pays_before_reaction_and_hybrid_interval_has_an_explicit_barrier() {
    let mut host = HostAuthority::default();
    let mut s = Session::new(Turn, turn_state(), gear(), 0, "turn", &mut host).unwrap();
    let l = lease(&mut s, &mut host, &["A", "B"], "player", Role::Player);
    s.submit(env(
        &s,
        &l,
        "cast",
        Some("A"),
        TurnCommand::Cast {
            target: "enemy".into(),
        },
    ))
    .unwrap();
    assert_eq!(
        (s.state().actions, s.rpg().resources()["A"].current),
        (1, 4)
    );
    assert!(s.ensure_quiescent().is_err());
    let saved = s.save_json().unwrap();
    let mut bad: Value = serde_json::from_str(&saved).unwrap();
    bad["rpg"]["claims"] = json!({});
    assert!(s.restore_json(&bad.to_string(), &mut host).is_err());
    assert_eq!(s.save_json().unwrap(), saved);
    s.submit(env(&s, &l, "seal", Some("A"), TurnCommand::Seal))
        .unwrap();
    assert_eq!(
        s.advance(env(&s, &l, "early", None, TurnAdvance::ExecuteInterval))
            .unwrap()
            .status,
        Status::Rejected
    );
    s.submit(env(&s, &l, "react", Some("B"), TurnCommand::React))
        .unwrap();
    s.advance(env(&s, &l, "resolve", None, TurnAdvance::Resolve))
        .unwrap();
    assert_eq!(
        (
            s.state().effects,
            s.state().actions,
            s.rpg().resources()["A"].current
        ),
        (0, 1, 4)
    );
    s.advance(env(&s, &l, "interval", None, TurnAdvance::ExecuteInterval))
        .unwrap();
    assert_eq!(s.state().actions, 3);
    s.ensure_quiescent().unwrap();
}
#[test]
fn joint_resources_and_every_controlled_participant_are_atomic_but_targets_need_no_lease() {
    let mut host = HostAuthority::default();
    let mut s = Session::new(Turn, turn_state(), gear(), 0, "turn", &mut host).unwrap();
    let all = lease(&mut s, &mut host, &["A", "B", "C"], "player", Role::Player);
    let group = TurnCommand::Group {
        members: vec!["A".into(), "B".into(), "C".into()],
        target: "enemy-with-no-control-lease".into(),
    };
    let before = s.rpg().clone();
    let receipt = s
        .submit(env(&s, &all, "poor", Some("A"), group.clone()))
        .unwrap();
    assert_eq!(receipt.status, Status::Rejected);
    assert_eq!(s.rpg(), &before);
    assert_eq!(s.state().effects, 0);
    let mut rich = gear();
    rich.apply(&[Mutation::AdjustResource {
        id: "C".into(),
        delta: 1,
    }])
    .unwrap();
    let mut s = Session::new(Turn, turn_state(), rich, 0, "rich", &mut host).unwrap();
    let all = lease(&mut s, &mut host, &["A", "B", "C"], "player", Role::Player);
    let limited = lease(&mut s, &mut host, &["A", "B"], "player", Role::Player);
    let before = s.save_json().unwrap();
    assert!(s
        .submit(env(&s, &limited, "unauthorized", Some("A"), group.clone()))
        .is_err());
    assert_eq!(s.save_json().unwrap(), before);
    assert_eq!(
        s.submit(env(&s, &all, "success", Some("A"), group))
            .unwrap()
            .status,
        Status::Accepted
    );
    assert_eq!(
        (
            s.rpg().resources()["A"].current,
            s.rpg().resources()["B"].current,
            s.rpg().resources()["C"].current
        ),
        (2, 2, 0)
    );
    assert!(s.rpg().claims().is_empty());
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
struct Pending {
    due: u64,
    ready: u64,
    canceled: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
struct ContinuousState {
    tick: u64,
    pending: Option<Pending>,
    impacts: u32,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
enum ContinuousCommand {
    Start,
    Interrupt,
    LoseSource,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Tick {
    at: u64,
    observation: u64,
    reject: bool,
}
struct Continuous;
impl Profile for Continuous {
    type State = ContinuousState;
    type Command = ContinuousCommand;
    type Advance = Tick;
    type View = ContinuousState;
    type Preview = ();
    fn manifest(&self) -> Manifest {
        Manifest::new("test-continuous", 1, "continuous-v2")
    }
    fn preview(
        &self,
        _: &ReadContext<'_, ContinuousState>,
        _: Option<&str>,
        _: &ContinuousCommand,
    ) -> RuleResult<()> {
        Ok(())
    }
    fn prepare_command(
        &self,
        tx: &mut Transaction<ContinuousState>,
        _: Option<&str>,
        cmd: &ContinuousCommand,
    ) -> RuleResult {
        match cmd {
            ContinuousCommand::Start => {
                if tx.state.pending.is_some() || !tx.rpg.grants().contains_key("item-fire") {
                    return Err(RuleError::new("ready", "Action unavailable"));
                }
                tx.rpg.apply(&[
                    Mutation::AdjustResource {
                        id: "A".into(),
                        delta: -3,
                    },
                    Mutation::Reserve(claim(
                        "delivery",
                        ClaimTarget::ItemRead {
                            item: "wand".into(),
                        },
                    )),
                ])?;
                tx.state.pending = Some(Pending {
                    due: tx.state.tick + 2,
                    ready: tx.state.tick + 4,
                    canceled: false,
                });
            }
            ContinuousCommand::Interrupt | ContinuousCommand::LoseSource => {
                if let Some(pending) = &mut tx.state.pending {
                    pending.canceled = true;
                }
                if tx.rpg.claims().contains_key("delivery") {
                    tx.rpg.apply(&[Mutation::ReleaseClaim {
                        id: "delivery".into(),
                    }])?;
                }
                if matches!(cmd, ContinuousCommand::LoseSource) {
                    let changes = tx.rpg.apply(&[Mutation::Unequip {
                        actor: "A".into(),
                        slots: vec!["left".into(), "right".into()],
                    }])?;
                    assert!(changes.revoked_grants.iter().any(|g| g.id == "item-fire"));
                }
            }
        }
        Ok(())
    }
    fn prepare_advance(&self, tx: &mut Transaction<ContinuousState>, tick: &Tick) -> RuleResult {
        if !tx.observe("physics", tick.observation)? {
            return Ok(());
        }
        if tick.at < tx.state.tick {
            return Err(RuleError::new("time", "Time moved backwards"));
        }
        tx.state.tick = tick.at;
        tx.entropy.below(20)?;
        if let Some(pending) = tx.state.pending.clone() {
            if !pending.canceled
                && tick.at >= pending.due
                && tx.occurrence(format!("impact/{}", pending.due))?
            {
                tx.state.impacts += 1;
            }
            if tick.at >= pending.ready {
                tx.state.pending = None;
                if tx.rpg.claims().contains_key("delivery") {
                    tx.rpg.apply(&[Mutation::ReleaseClaim {
                        id: "delivery".into(),
                    }])?;
                }
            }
        }
        if tick.reject {
            return Err(RuleError::new(
                "observation",
                "Rejected canonical observation",
            ));
        }
        Ok(())
    }
    fn project(&self, ctx: &ReadContext<'_, ContinuousState>) -> ContinuousState {
        ctx.state.clone()
    }
    fn validate(&self, state: &ContinuousState, rpg: &RpgState) -> RuleResult {
        if state.pending.as_ref().is_some_and(|p| !p.canceled)
            && (!rpg.claims().contains_key("delivery") || !rpg.grants().contains_key("item-fire"))
        {
            return Err(RuleError::new("pending", "Missing active source"));
        }
        Ok(())
    }
    fn validate_restore(&self, ctx: &RestoreContext<'_, ContinuousState>) -> RuleResult {
        self.validate(ctx.state, ctx.rpg)?;
        if ctx.state.tick > 0 && !ctx.observation_positions.contains_key("physics") {
            return Err(RuleError::new(
                "restore",
                "Missing canonical observation history",
            ));
        }
        Ok(())
    }
    fn quiescent(&self, state: &ContinuousState, _: &RpgState) -> bool {
        state.pending.is_none()
    }
}
fn continuous(host: &mut HostAuthority) -> Session<Continuous> {
    Session::new(
        Continuous,
        ContinuousState {
            tick: 0,
            pending: None,
            impacts: 0,
        },
        gear(),
        42,
        "continuous",
        host,
    )
    .unwrap()
}
#[test]
fn continuous_paid_action_observation_rollback_and_duplicate_impact_are_deterministic() {
    let mut host = HostAuthority::default();
    let mut s = continuous(&mut host);
    let l = lease(&mut s, &mut host, &["A"], "player", Role::Player);
    s.submit(env(&s, &l, "start", Some("A"), ContinuousCommand::Start))
        .unwrap();
    assert_eq!(s.rpg().resources()["A"].current, 7);
    assert_eq!(
        s.advance(env(
            &s,
            &l,
            "bad",
            None,
            Tick {
                at: 2,
                observation: 1,
                reject: true
            }
        ))
        .unwrap()
        .status,
        Status::Rejected
    );
    assert_eq!(
        (s.state().tick, s.state().impacts, s.entropy_draws()),
        (0, 0, 0)
    );
    s.advance(env(
        &s,
        &l,
        "impact",
        None,
        Tick {
            at: 2,
            observation: 1,
            reject: false,
        },
    ))
    .unwrap();
    s.advance(env(
        &s,
        &l,
        "duplicate",
        None,
        Tick {
            at: 2,
            observation: 1,
            reject: false,
        },
    ))
    .unwrap();
    s.advance(env(
        &s,
        &l,
        "next",
        None,
        Tick {
            at: 3,
            observation: 2,
            reject: false,
        },
    ))
    .unwrap();
    assert_eq!(s.state().impacts, 1);
    let save = s.save_json().unwrap();
    let mut bad: Value = serde_json::from_str(&save).unwrap();
    bad["observation_positions"] = json!({});
    assert!(s.restore_json(&bad.to_string(), &mut host).is_err());
    assert_eq!(s.save_json().unwrap(), save);
    s.restore_json(&save, &mut host).unwrap();
    let l = lease(&mut s, &mut host, &["A"], "player", Role::Player);
    s.resume_after_restore();
    s.advance(env(
        &s,
        &l,
        "recover",
        None,
        Tick {
            at: 4,
            observation: 3,
            reject: false,
        },
    ))
    .unwrap();
    assert!(s.state().pending.is_none());
    assert_eq!(s.rpg().resources()["A"].current, 7);
}
#[test]
fn interruption_and_source_loss_preserve_paid_cost_and_original_recovery_with_learned_grants() {
    for command in [ContinuousCommand::Interrupt, ContinuousCommand::LoseSource] {
        let mut host = HostAuthority::default();
        let mut s = continuous(&mut host);
        let l = lease(&mut s, &mut host, &["A"], "player", Role::Player);
        s.submit(env(&s, &l, "start", Some("A"), ContinuousCommand::Start))
            .unwrap();
        s.submit(env(&s, &l, "interrupt", Some("A"), command))
            .unwrap();
        assert_eq!(s.state().pending.as_ref().unwrap().ready, 4);
        assert_eq!(s.rpg().resources()["A"].current, 7);
        assert!(s.rpg().has_ability("A", "fire"));
        assert_eq!(
            s.submit(env(
                &s,
                &l,
                "too-early",
                Some("A"),
                ContinuousCommand::Start
            ))
            .unwrap()
            .status,
            Status::Rejected
        );
        s.advance(env(
            &s,
            &l,
            "finish",
            None,
            Tick {
                at: 4,
                observation: 1,
                reject: false,
            },
        ))
        .unwrap();
        assert_eq!(s.state().impacts, 0);
        assert!(s.state().pending.is_none());
        assert!(s.rpg().claims().is_empty());
    }
}

struct Bare {
    manifest: Manifest,
}
impl Profile for Bare {
    type State = bool;
    type Command = bool;
    type Advance = ();
    type View = bool;
    type Preview = ();
    fn manifest(&self) -> Manifest {
        self.manifest.clone()
    }
    fn preview(&self, _: &ReadContext<'_, bool>, _: Option<&str>, _: &bool) -> RuleResult<()> {
        Ok(())
    }
    fn prepare_command(
        &self,
        tx: &mut Transaction<bool>,
        _: Option<&str>,
        value: &bool,
    ) -> RuleResult {
        tx.state = *value;
        Ok(())
    }
    fn prepare_advance(&self, _: &mut Transaction<bool>, _: &()) -> RuleResult {
        Ok(())
    }
    fn project(&self, ctx: &ReadContext<'_, bool>) -> bool {
        *ctx.state
    }
    fn validate(&self, _: &bool, _: &RpgState) -> RuleResult {
        Ok(())
    }
    fn quiescent(&self, _: &bool, _: &RpgState) -> bool {
        true
    }
}
#[test]
fn custom_providers_replace_or_omit_services_without_mandatory_health_clock_or_inventory() {
    let mut manifest = Manifest::minimal("bare", 1, "bare-v2");
    manifest.providers.push(ProviderSpec::new(
        "custom.pool",
        "custom.pool",
        "rpg.resources/v1",
    ));
    manifest.providers.push(ProviderSpec::new(
        "custom.space",
        "custom.space",
        "probe.space/v1",
    ));
    manifest
        .required_capabilities
        .extend(["rpg.resources/v1".into(), "probe.space/v1".into()]);
    let mut host = HostAuthority::default();
    let mut s = Session::new(
        Bare {
            manifest: manifest.clone(),
        },
        false,
        RpgState::default(),
        0,
        "bare",
        &mut host,
    )
    .unwrap();
    let l = lease(&mut s, &mut host, &[], "observer", Role::Player);
    s.submit(env(&s, &l, "toggle", None, true)).unwrap();
    assert!(s.view(&l).unwrap());
    assert!(s.rpg().items().is_empty());
    let mut missing = manifest.clone();
    missing.required_capabilities.insert("missing/v1".into());
    assert!(missing.validate().is_err());
    let mut duplicate = manifest.clone();
    duplicate
        .providers
        .push(ProviderSpec::new("other", "other", "probe.space/v1"));
    assert!(duplicate.validate().is_err());
    let mut overlap = manifest.clone();
    overlap.providers.push(ProviderSpec::new(
        "overlap",
        "custom.space.child",
        "other/v1",
    ));
    assert!(overlap.validate().is_err());
    assert!(Session::new(Bare { manifest }, false, gear(), 0, "bad", &mut host).is_err());
    // Cannot silently use an omitted built-in service.
}
#[test]
fn pending_noncombat_claim_blocks_transition_and_failed_destination_keeps_source_session() {
    let mut host = HostAuthority::default();
    let mut rpg = RpgState::default();
    rpg.apply(&[
        Mutation::InsertItem(item("material", 1)),
        Mutation::Reserve(claim(
            "crafting",
            ClaimTarget::Item {
                item: "material".into(),
                quantity: 1,
            },
        )),
    ])
    .unwrap();
    let s = Session::new(
        Bare {
            manifest: Manifest::new("bare", 1, "b"),
        },
        false,
        rpg,
        0,
        "barrier",
        &mut host,
    )
    .unwrap();
    let before = s.save_json().unwrap();
    assert!(s.prepare_transition(|_, _| Ok(())).is_err());
    assert_eq!(s.save_json().unwrap(), before);
    let s = Session::new(
        Bare {
            manifest: Manifest::minimal("bare", 1, "b"),
        },
        false,
        RpgState::default(),
        0,
        "settled",
        &mut host,
    )
    .unwrap();
    let before = s.save_json().unwrap();
    let result: RuleResult<()> = s.prepare_transition(|_, _| {
        Err(RuleError::new(
            "destination",
            "Mandatory story item has no mapping",
        ))
    });
    assert!(result.is_err());
    assert_eq!(s.save_json().unwrap(), before);
}

#[test]
fn source_read_claims_conflict_with_exclusive_claims_in_either_admission_order() {
    for reverse in [false, true] {
        let mut r = gear();
        let read = Mutation::Reserve(claim(
            "read",
            ClaimTarget::ItemRead {
                item: "wand".into(),
            },
        ));
        let exclusive = Mutation::Reserve(claim(
            "exclusive",
            ClaimTarget::Binding {
                actor: "A".into(),
                slot: "left".into(),
            },
        ));
        let plan = if reverse {
            vec![exclusive, read]
        } else {
            vec![read, exclusive]
        };
        let before = r.clone();
        assert!(r.apply(&plan).is_err());
        assert_eq!(r, before);
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
struct CustomState {
    charge: u32,
    pulses: u32,
}
struct CustomProvider;
impl Profile for CustomProvider {
    type State = CustomState;
    type Command = u32;
    type Advance = u32;
    type View = CustomState;
    type Preview = bool;
    fn manifest(&self) -> Manifest {
        let mut m = Manifest::minimal("custom", 1, "custom-v1");
        let mut provider = ProviderSpec::new("custom.sim", "custom.sim", "rpg.resources/v1");
        provider.provides.insert("custom.pulses/v1".into());
        provider.requires.insert("runtime.core/v1".into());
        m.providers.push(provider);
        m.required_capabilities
            .extend(["rpg.resources/v1".into(), "custom.pulses/v1".into()]);
        m
    }
    fn preview(
        &self,
        c: &ReadContext<'_, CustomState>,
        _: Option<&str>,
        amount: &u32,
    ) -> RuleResult<bool> {
        Ok(c.state.charge >= *amount)
    }
    fn prepare_command(
        &self,
        t: &mut Transaction<CustomState>,
        _: Option<&str>,
        amount: &u32,
    ) -> RuleResult {
        t.state.charge = t
            .state
            .charge
            .checked_sub(*amount)
            .ok_or_else(|| RuleError::new("charge", "Insufficient custom charge"))?;
        Ok(())
    }
    fn prepare_advance(&self, t: &mut Transaction<CustomState>, pulses: &u32) -> RuleResult {
        t.state.pulses = t
            .state
            .pulses
            .checked_add(*pulses)
            .ok_or_else(|| RuleError::new("pulses", "Pulse count overflow"))?;
        Ok(())
    }
    fn project(&self, c: &ReadContext<'_, CustomState>) -> CustomState {
        c.state.clone()
    }
    fn validate(&self, s: &CustomState, r: &RpgState) -> RuleResult {
        if s.charge > 10 || !r.resources().is_empty() {
            Err(RuleError::new("custom", "Invalid replacement state"))
        } else {
            Ok(())
        }
    }
}
#[test]
fn replacement_resource_and_custom_time_operators_execute_in_the_registered_profile() {
    let mut host = HostAuthority::default();
    let mut s = Session::new(
        CustomProvider,
        CustomState {
            charge: 10,
            pulses: 0,
        },
        RpgState::default(),
        0,
        "custom",
        &mut host,
    )
    .unwrap();
    let l = lease(&mut s, &mut host, &[], "public", Role::System);
    assert!(s.preview(&l, None, &4).unwrap());
    s.submit(env(&s, &l, "spend", None, 4)).unwrap();
    s.advance(env(&s, &l, "pulse", None, 7)).unwrap();
    assert_eq!(
        s.state(),
        &CustomState {
            charge: 6,
            pulses: 7
        }
    );
    assert!(s.rpg().resources().is_empty());
    assert_eq!(
        s.submit(env(&s, &l, "too-much", None, 7)).unwrap().status,
        Status::Rejected
    );
    assert_eq!(s.state().charge, 6);
    let save = s.save_json().unwrap();
    s.restore_json(&save, &mut host).unwrap();
    assert_eq!(s.state().pulses, 7);
}

#[test]
fn revoking_a_group_lease_before_commit_rejects_without_any_participant_spend() {
    let mut host = HostAuthority::default();
    let mut r = gear();
    r.apply(&[Mutation::AdjustResource {
        id: "C".into(),
        delta: 1,
    }])
    .unwrap();
    let mut s = Session::new(Turn, turn_state(), r, 0, "group", &mut host).unwrap();
    let all = lease(&mut s, &mut host, &["A", "B", "C"], "player", Role::Player);
    let prepared = env(
        &s,
        &all,
        "group",
        Some("A"),
        TurnCommand::Group {
            members: vec!["A".into(), "B".into(), "C".into()],
            target: "enemy".into(),
        },
    );
    let before = s.save_json().unwrap();
    s.revoke_lease(&all);
    let limited = lease(&mut s, &mut host, &["A", "B"], "player", Role::Player);
    assert!(s.submit(prepared.clone()).is_err());
    let mut retried = prepared;
    retried.lease = limited;
    assert!(s.submit(retried).is_err());
    assert_eq!(s.save_json().unwrap(), before);
}
