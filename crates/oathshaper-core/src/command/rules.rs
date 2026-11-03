use super::*;
use crate::rpg::{Claim, ClaimTarget, Mutation, Source};
use content::*;
pub fn next(s: &mut CommandState, prefix: &str) -> String {
    s.serial += 1;
    format!("{prefix}-{}", s.serial)
}
pub fn health(r: &RpgState, id: &str) -> i64 {
    r.resources()[&resource_id(id, "health")].current
}
pub fn living(s: &CommandState, r: &RpgState, id: &str) -> bool {
    s.actors.get(id).is_some_and(|a| a.deployed) && health(r, id) > 0
}
pub fn distance(a: [i64; 2], b: [i64; 2]) -> f64 {
    ((a[0] - b[0]) as f64).hypot((a[1] - b[1]) as f64)
}
pub fn log(
    s: &mut CommandState,
    kind: &str,
    actor: Option<&str>,
    target: Option<&str>,
    text: String,
) {
    let id = next(s, "log");
    s.logs.push(Log {
        id,
        tick: s.tick,
        kind: kind.into(),
        actor_id: actor.map(str::to_owned),
        target_id: target.map(str::to_owned),
        text,
        roll: None,
        modifier: None,
        threshold: None,
        damage: None,
        healing: None,
    });
    if s.logs.len() > 200 {
        s.logs.remove(0);
    }
}
pub fn pause(s: &mut CommandState, owner: &str, context: &str, automatic: bool) -> String {
    let id = next(s, "pause");
    s.pauses.insert(
        id.clone(),
        Pause {
            owner: owner.into(),
            context: context.into(),
            automatic,
        },
    );
    for a in s.actors.values_mut() {
        a.direction = [0., 0.];
    }
    id
}
pub fn pool_change(s: &mut CommandState, r: &mut RpgState, id: &str, delta: i64) -> RuleResult {
    let old = r
        .resources()
        .get(id)
        .ok_or_else(|| err("resource", "Unknown resource"))?
        .clone();
    let amount = (old.current + delta).clamp(0, old.maximum) - old.current;
    r.apply(&[Mutation::AdjustResource {
        id: id.into(),
        delta: amount,
    }])?;
    if let Some(debt) = s.debt.get_mut(id) {
        *debt = (*debt - amount).max(0);
    }
    Ok(())
}
pub fn capacity(s: &mut CommandState, r: &mut RpgState, id: &str, max: i64) -> RuleResult {
    let mut resource = r.resources()[id].clone();
    resource.maximum = max;
    resource.current = (max - s.debt[id]).max(0);
    r.apply(&[Mutation::PutResource(resource)])?;
    Ok(())
}
pub fn release(r: &mut RpgState, action: &str) -> RuleResult {
    let ids: Vec<_> = r
        .claims()
        .values()
        .filter(|c| c.action == action)
        .map(|c| c.id.clone())
        .collect();
    r.apply(
        &ids.into_iter()
            .map(|id| Mutation::ReleaseClaim { id })
            .collect::<Vec<_>>(),
    )?;
    Ok(())
}
pub fn target_position(s: &CommandState, a: &Action) -> Option<[i64; 2]> {
    match a.target.kind.as_str() {
        "actor" => a
            .target
            .actor_id
            .as_ref()
            .and_then(|id| s.actors.get(id))
            .map(|a| a.position),
        "point" => a
            .target
            .position
            .map(|p| [(p[0] * 1000.).round() as i64, (p[1] * 1000.).round() as i64]),
        "self" | "none" => Some(s.actors[&a.actor].position),
        _ => None,
    }
}
pub fn source_weapon<'a>(r: &'a RpgState, source: &str) -> Option<&'a Item> {
    r.grants()
        .get(source)
        .and_then(|g| match &g.source {
            Source::Item { item, .. } => r.items().get(item),
            _ => None,
        })
        .filter(|i| item_def(&i.definition).is_ok_and(|d| d.category == "weapon"))
}
pub fn effective_range(r: &RpgState, id: &str, ab: &Ability, source: &str) -> i64 {
    if ab.id == "basic"
        && (id == "hound" || source_weapon(r, source).is_some_and(|i| i.definition == "crossbow"))
    {
        15000
    } else {
        ab.range
    }
}

pub fn availability(
    s: &CommandState,
    r: &RpgState,
    actor: &str,
    ability_id: &str,
    source: &str,
) -> RuleResult {
    let a = s
        .actors
        .get(actor)
        .ok_or_else(|| err("actor", "Unknown actor"))?;
    if !living(s, r, actor) {
        return Err(err("incapacitated", "Actor is not deployed and conscious"));
    }
    if a.conditions.contains_key("stun") {
        return Err(err("stun", "Actor is disabled"));
    }
    let ab = ability(ability_id)?;
    if ab.magic && a.conditions.contains_key("silence") {
        return Err(err("silence", "Magic is silenced"));
    }
    if ab.magic
        && ab.id != "mend"
        && r.bindings()
            .get(actor)
            .and_then(|b| b.get("body"))
            .and_then(|i| r.items().get(i))
            .is_some_and(|i| i.definition == "heavy_armor")
    {
        return Err(err("armor", "Heavy armor blocks this power"));
    }
    if ability_id == "dressing" {
        let i = r
            .items()
            .get(source)
            .ok_or_else(|| err("item", "Dressing source is missing"))?;
        if i.definition != "dressing" || i.owner != "party_pack" {
            return Err(err("item", "Dressing is inaccessible"));
        }
    } else {
        let g = r
            .grants()
            .get(source)
            .ok_or_else(|| err("source", "Ability source is no longer available"))?;
        if g.recipient != actor || g.ability != ability_id {
            return Err(err("source", "Source does not grant this actor's action"));
        }
    }
    if ab.id == "veil"
        && r.bindings()
            .get(actor)
            .and_then(|b| b.get("body"))
            .and_then(|i| r.items().get(i))
            .is_some_and(|i| i.definition != "robe")
    {
        return Err(err("armor", "Storm veil requires unarmored clothing"));
    }
    if ability_id == "lunge" && !a.feats.iter().any(|f| f.starts_with("single_blade_")) {
        return Err(err("feat", "Single blade training is required"));
    }
    if ability_id == "lunge" && a.conditions.contains_key("root") {
        return Err(err("root", "Root prevents a lunging advance"));
    }
    if ability_id == "pinning_bolt"
        && !a
            .feats
            .iter()
            .any(|f| f == "marksmanship_i" || f == "marksmanship_ii")
    {
        return Err(err("feat", "Marksmanship is required"));
    }
    Ok(())
}
fn validate_target(
    s: &CommandState,
    r: &RpgState,
    actor: &str,
    ab: &Ability,
    t: &Target,
) -> RuleResult {
    if t.position
        .is_some_and(|p| p.iter().any(|n| !n.is_finite() || n.abs() > 100.))
    {
        return Err(err("target", "Invalid target coordinates"));
    }
    match ab.target {
        "point" => {
            if t.kind != "point" || t.position.is_none() || t.actor_id.is_some() {
                return Err(err("target", "Select a ground point"));
            }
        }
        "self" => {
            if t.kind != "self" || t.actor_id.is_some() || t.position.is_some() {
                return Err(err("target", "Self action requires a self target"));
            }
        }
        _ => {
            if t.kind != "actor" || t.position.is_some() {
                return Err(err("target", "Select an actor"));
            }
            let id = t
                .actor_id
                .as_deref()
                .ok_or_else(|| err("target", "Missing actor target"))?;
            if !living(s, r, id) {
                return Err(err("target", "Target is unavailable"));
            }
            let ally = s.actors[id].faction == s.actors[actor].faction;
            if !ally && s.actors[actor].faction == "party" && !super::combat::observable(s, id) {
                return Err(err("target", "Target is outside current party knowledge"));
            }
            if (ab.target == "ally") != ally {
                return Err(err("target", "Wrong target relationship"));
            }
            if ["mend", "dressing"].contains(&ab.id) && s.actors[id].body == "construct" {
                return Err(err("body", "Biological healing cannot repair a construct"));
            }
            if ab.id == "disrupt_device" && s.actors[id].body != "construct" {
                return Err(err("body", "Disrupt requires a device"));
            }
        }
    }
    Ok(())
}
pub fn enqueue(
    s: &mut CommandState,
    r: &mut RpgState,
    actor: &str,
    ability_id: &str,
    source: &str,
    target: &Target,
    ai: bool,
) -> RuleResult<String> {
    availability(s, r, actor, ability_id, source)?;
    let ab = ability(ability_id)?;
    validate_target(s, r, actor, &ab, target)?;
    if !ai {
        let replaced: Vec<_> = s.actors[actor]
            .queue
            .iter()
            .filter(|q| q.ai)
            .map(|q| q.id.clone())
            .collect();
        for id in &replaced {
            release(r, id)?;
        }
        s.actors.get_mut(actor).unwrap().queue.retain(|q| !q.ai);
        // Take over an AI approach before it spends anything. Paid windup /
        // recovery stays committed unless the player explicitly stops it.
        if s.actors[actor]
            .active
            .as_ref()
            .is_some_and(|a| a.ai && a.phase == "approach")
        {
            let old = s.actors.get_mut(actor).unwrap().active.take().unwrap();
            release(r, &old.id)?;
        }
        if ab.target == "enemy" {
            s.selected_target = target.actor_id.clone();
        }
    }
    if s.actors[actor].queue.len() >= 4 {
        return Err(err("queue_full", "Four future orders are already queued"));
    }
    let id = next(s, "action");
    let mut mutations = vec![];
    if ab.cost > 0 {
        mutations.push(Mutation::Reserve(Claim {
            id: format!("{id}:cost"),
            owner: actor.into(),
            action: id.clone(),
            target: ClaimTarget::Resource {
                resource: resource_id(
                    actor,
                    if ab.id == "disrupt_device" {
                        "battery"
                    } else {
                        "focus"
                    },
                ),
                amount: ab.cost,
            },
        }));
    }
    if ab.id == "dressing" {
        mutations.push(Mutation::Reserve(Claim {
            id: format!("{id}:item"),
            owner: actor.into(),
            action: id.clone(),
            target: ClaimTarget::Item {
                item: source.into(),
                quantity: 1,
            },
        }));
    } else if let Some(Grant {
        source: Source::Item { item, .. },
        ..
    }) = r.grants().get(source)
    {
        mutations.push(Mutation::Reserve(Claim {
            id: format!("{id}:source"),
            owner: actor.into(),
            action: id.clone(),
            target: ClaimTarget::ItemRead { item: item.clone() },
        }));
        for (slot, bound) in r.bindings().get(actor).into_iter().flatten() {
            if bound == item {
                mutations.push(Mutation::Reserve(Claim {
                    id: format!("{id}:slot:{slot}"),
                    owner: actor.into(),
                    action: id.clone(),
                    target: ClaimTarget::BindingRead {
                        actor: actor.into(),
                        slot: slot.clone(),
                        item: item.clone(),
                    },
                }));
            }
        }
    }
    r.apply(&mutations)?;
    s.actors.get_mut(actor).unwrap().queue.push(Action {
        id: id.clone(),
        sequence: s.serial,
        ability: ability_id.into(),
        source: source.into(),
        actor: actor.into(),
        target: target.clone(),
        phase: "waiting".into(),
        activation: None,
        impact: None,
        recovery: None,
        deadline: None,
        paid: 0,
        paid_item: false,
        ai,
        path: vec![],
        approach_travel_mm: 0,
    });
    Ok(id)
}
fn clear(s: &mut CommandState, r: &mut RpgState, actor: &str) -> RuleResult {
    let actions = std::mem::take(
        &mut s
            .actors
            .get_mut(actor)
            .ok_or_else(|| err("actor", "Unknown actor"))?
            .queue,
    );
    for a in actions {
        release(r, &a.id)?
    }
    Ok(())
}
pub(super) fn camp(s: &CommandState) -> RuleResult {
    if s.phase != "camp"
        || s.rest_until.is_some()
        || s.actors
            .values()
            .any(|a| a.active.is_some() || !a.queue.is_empty())
    {
        return Err(err("camp", "A settled camp is required"));
    }
    Ok(())
}

fn place_party(s: &mut CommandState) {
    let mut places = [[0, 0], [-2000, 0], [-2000, 2000]].into_iter();
    for id in PARTY {
        let actor = s.actors.get_mut(id).unwrap();
        actor.position = if actor.deployed {
            places.next().unwrap()
        } else {
            [-3500, 1000]
        };
        actor.direction = [0., 0.];
    }
}

pub fn command(s: &mut CommandState, r: &mut RpgState, c: &CommandIntent, ai: bool) -> RuleResult {
    match c {
        CommandIntent::Deploy { actor_ids } => {
            camp(s)?;
            if s.actors.values().any(|a| a.direction != [0., 0.]) {
                return Err(err("camp", "Stop moving before changing companions"));
            }
            let selected: BTreeSet<_> = actor_ids.iter().map(String::as_str).collect();
            if actor_ids.len() != 3
                || selected.len() != 3
                || !selected.contains("player")
                || selected.iter().any(|id| !PARTY.contains(id))
            {
                return Err(err(
                    "party",
                    "Choose the player and two distinct roster companions",
                ));
            }
            if selected.iter().any(|id| health(r, id) <= 0) {
                return Err(err("party", "Only conscious companions can join the party"));
            }
            for id in PARTY {
                s.actors.get_mut(id).unwrap().deployed = selected.contains(id);
            }
            if !selected.contains(s.recipient.as_str()) {
                s.recipient = "player".into();
            }
            if !selected.contains(s.inspected.as_str()) {
                s.inspected = "player".into();
            }
            if s.possessed
                .as_ref()
                .is_some_and(|id| !selected.contains(id.as_str()))
            {
                s.possessed = Some("player".into());
            }
            if s.camera
                .as_ref()
                .is_some_and(|id| PARTY.contains(&id.as_str()) && !selected.contains(id.as_str()))
            {
                s.camera = Some("player".into());
            }
            if s.selected_target
                .as_ref()
                .is_some_and(|id| PARTY.contains(&id.as_str()) && !selected.contains(id.as_str()))
            {
                s.selected_target = None;
            }
            place_party(s);
            s.observations.clear();
        }
        CommandIntent::TargetSelect { target_id } => {
            if target_id.as_ref().is_some_and(|id| {
                !s.actors.contains_key(id) || !super::combat::observable(s, id) || !living(s, r, id)
            }) {
                return Err(err("target", "Target is outside current knowledge"));
            }
            s.selected_target = target_id.clone();
        }
        CommandIntent::RevokeItem { item_id } => super::progression::revoke_item(s, r, item_id)?,
        CommandIntent::Respec {
            actor_id,
            expected_build_version,
            initial_attributes,
            levels,
            unbind_item_ids,
        } => super::progression::respec(
            s,
            r,
            actor_id,
            expected_build_version,
            initial_attributes,
            levels,
            unbind_item_ids,
        )?,
        CommandIntent::Dismantle { actor_id, item_id } => {
            camp(s)?;
            if !living(s, r, actor_id) {
                return Err(err("actor", "Crafter must be deployed and conscious"));
            }
            let item = r
                .items()
                .get(item_id)
                .ok_or_else(|| err("item", "Unknown item"))?;
            if item.definition != "arc_edge" || item.owner != "party_pack" {
                return Err(err(
                    "salvage",
                    "Only an accessible arc edge can use this salvage recipe",
                ));
            }
            let id = next(s, "salvage");
            r.apply(&[
                Mutation::ConsumeItem {
                    item: item_id.clone(),
                    quantity: 1,
                },
                Mutation::InsertItem(Item {
                    id,
                    definition: "scrap".into(),
                    owner: "party_pack".into(),
                    quantity: 2,
                    parent: None,
                    stack_key: "scrap".into(),
                    protected: false,
                }),
            ])?;
        }
        CommandIntent::Upgrade {
            actor_id,
            host_item_id,
            upgrade_item_id,
        } => {
            camp(s)?;
            if s.actors
                .get(actor_id)
                .and_then(|a| a.skills.get("devices"))
                .copied()
                .unwrap_or(0)
                < 4
            {
                return Err(err("training", "Four Devices ranks required"));
            }
            let host = r
                .items()
                .get(host_item_id)
                .ok_or_else(|| err("item", "Missing weapon"))?;
            let upgrade = r
                .items()
                .get(upgrade_item_id)
                .ok_or_else(|| err("item", "Missing upgrade"))?;
            if host.definition!="sabre"||host.owner!="party_pack"||upgrade.definition!="arc_edge"||s.upgrades.contains_key(host_item_id)||r.claims().values().any(|c|matches!(&c.target,ClaimTarget::ItemRead{item}|ClaimTarget::BindingRead{item,..} if item==host_item_id)){return Err(err("upgrade","Upgrade slot or source is unavailable"))}
            r.apply(&[Mutation::ConsumeItem {
                item: upgrade_item_id.clone(),
                quantity: 1,
            }])?;
            s.upgrades.insert(host_item_id.clone(), "arc_edge".into());
        }
        CommandIntent::ResumeRestore { token } => {
            if token
                .strip_prefix("restore:")
                .and_then(|n| n.parse::<u64>().ok())
                .is_none()
            {
                return Err(err("restore", "Invalid host restore acknowledgement"));
            }
            s.pauses.retain(|_, p| p.automatic);
            for a in s.actors.values_mut() {
                a.direction = [0., 0.];
            }
        }
        CommandIntent::Select { actor_id } | CommandIntent::Possess { actor_id, .. } => {
            if !PARTY.contains(&actor_id.as_str()) || !living(s, r, actor_id) {
                return Err(err(
                    "actor",
                    "Only conscious deployed party actors can be selected",
                ));
            }
            match c {
                CommandIntent::Select { .. } => s.recipient = actor_id.clone(),
                CommandIntent::Possess { select, .. } => {
                    s.possessed = Some(actor_id.clone());
                    s.camera = Some(actor_id.clone());
                    if *select {
                        s.recipient = actor_id.clone()
                    }
                    for a in s.actors.values_mut() {
                        a.direction = [0., 0.]
                    }
                }
                _ => {}
            }
        }
        CommandIntent::Inspect { actor_id } => {
            if !PARTY.contains(&actor_id.as_str()) {
                return Err(err("actor", "Only roster actors are inspectable"));
            }
            s.inspected = actor_id.clone();
        }
        CommandIntent::Camera { actor_id } => {
            if actor_id
                .as_ref()
                .is_some_and(|id| !s.actors.contains_key(id))
            {
                return Err(err("actor", "Unknown camera actor"));
            }
            s.camera = actor_id.clone()
        }
        CommandIntent::Pause { owner, context_id } => {
            if !["manual", "ledger", "selector", "targeting", "dialogue"].contains(&owner.as_str())
                || context_id.is_empty()
                || s.pauses
                    .values()
                    .any(|p| p.owner == *owner && p.context == *context_id)
            {
                return Err(err("pause", "Invalid or duplicate pause context"));
            }
            pause(s, owner, context_id, false);
        }
        CommandIntent::Release { token } | CommandIntent::Acknowledge { token } => {
            let p = s
                .pauses
                .get(token)
                .ok_or_else(|| err("pause", "Unknown pause token"))?;
            if matches!(c, CommandIntent::Release { .. }) == p.automatic || p.owner == "defeat" {
                return Err(err("pause", "This pause requires its owning operation"));
            }
            s.pauses.remove(token);
        }
        CommandIntent::Start { encounter_id } => {
            camp(s)?;
            if encounter_id != "garden_patrol" {
                return Err(err("encounter", "Unknown encounter"));
            }
            s.encounter += 1;
            s.retreat_requested = false;
            s.retreat_since = None;
            s.selected_target = None;
            for a in s.actors.values_mut() {
                a.device_uses = 0;
            }
            s.checkpoint_id = Some(format!("checkpoint-{}", s.encounter));
            s.phase = "encounter".into();
            s.outcome = None;
            s.reward = None;
            place_party(s);
            for (id, p) in [
                ("player", [0, 0]),
                ("hound", [2000, 0]),
                ("sentinel", [6000, 2000]),
                ("corsair_raider", [4000, -2000]),
            ] {
                let a = s.actors.get_mut(id).unwrap();
                a.position = p;
                a.ready = s.tick;
                a.conditions.clear();
                if !PARTY.contains(&id) {
                    for unit in ["health", "focus", "battery"] {
                        let rid = resource_id(id, unit);
                        s.debt.insert(rid.clone(), 0);
                        capacity(s, r, &rid, r.resources()[&rid].maximum)?;
                    }
                }
            }
            for id in PARTY {
                let actor = s.actors.get_mut(id).unwrap();
                actor.ready = s.tick;
                actor.conditions.clear();
                actor.ward_strength = 0;
                actor.ward_remaining = 0;
            }
            pause(s, "contact", "encounter", true);
        }
        CommandIntent::Retry { checkpoint_id } => {
            if s.phase != "defeat" || s.checkpoint_id.as_ref() != Some(checkpoint_id) {
                return Err(err("retry", "No matching defeated encounter checkpoint"));
            }
        }
        CommandIntent::Retreat { encounter_id } => {
            if s.phase != "encounter" || encounter_id != "garden_patrol" {
                return Err(err("encounter", "No matching encounter"));
            }
            s.retreat_requested = true;
            s.retreat_since = None;
        }
        CommandIntent::Camp { camp_id } => {
            if camp_id != "garden_camp"
                || !["victory", "exploration", "camp"].contains(&s.phase.as_str())
                || s.actors
                    .values()
                    .any(|a| a.active.is_some() || !a.queue.is_empty())
            {
                return Err(err("camp", "Cannot enter camp yet"));
            }
            s.phase = "camp".into();
            s.pauses.retain(|_, p| !p.automatic);
        }
        CommandIntent::Rest { camp_id } => {
            camp(s)?;
            if camp_id != "garden_camp" {
                return Err(err("camp", "Unknown camp"));
            }
            s.rest_until = Some(s.tick + 50);
        }
        CommandIntent::Enqueue {
            actor_id,
            ability_id,
            source_id,
            target,
        } => {
            enqueue(s, r, actor_id, ability_id, source_id, target, ai)?;
        }
        CommandIntent::Use {
            actor_id,
            item_id,
            target,
        } => {
            enqueue(s, r, actor_id, "dressing", item_id, target, ai)?;
        }
        CommandIntent::Remove {
            actor_id,
            action_id,
        } => {
            let a = s
                .actors
                .get_mut(actor_id)
                .ok_or_else(|| err("actor", "Unknown actor"))?;
            let index = a
                .queue
                .iter()
                .position(|a| a.id == *action_id)
                .ok_or_else(|| err("queue", "Only future orders can be removed"))?;
            a.queue.remove(index);
            release(r, action_id)?;
            if s.possessed.as_deref() == Some(actor_id) {
                super::combat::pause_for_orders(s, r);
            }
        }
        CommandIntent::Reorder {
            actor_id,
            action_ids,
        } => {
            let a = s
                .actors
                .get_mut(actor_id)
                .ok_or_else(|| err("actor", "Unknown actor"))?;
            if action_ids.len() != a.queue.len()
                || action_ids.iter().collect::<BTreeSet<_>>().len() != action_ids.len()
                || action_ids
                    .iter()
                    .any(|id| !a.queue.iter().any(|a| a.id == *id))
            {
                return Err(err(
                    "queue",
                    "Reorder must contain every future action exactly once",
                ));
            }
            a.queue = action_ids
                .iter()
                .map(|id| a.queue.iter().find(|a| a.id == *id).unwrap().clone())
                .collect();
        }
        CommandIntent::Clear { actor_id } => {
            clear(s, r, actor_id)?;
            if s.possessed.as_deref() == Some(actor_id) {
                super::combat::pause_for_orders(s, r);
            }
        }
        CommandIntent::Stop {
            actor_id,
            confirm_paid_cost,
        } => {
            if !confirm_paid_cost {
                return Err(err(
                    "confirm",
                    "Confirm paid cost and recovery are retained",
                ));
            }
            clear(s, r, actor_id)?;
            if let Some(a) = s.actors.get_mut(actor_id).unwrap().active.take() {
                release(r, &a.id)?;
            }
            if s.possessed.as_deref() == Some(actor_id) {
                super::combat::pause_for_orders(s, r);
            }
        }
        CommandIntent::Move {
            actor_id,
            direction,
        } => {
            if s.possessed.as_ref() != Some(actor_id)
                || !living(s, r, actor_id)
                || !s.pauses.is_empty()
                || s.actors[actor_id].active.is_some()
                || s.actors[actor_id].conditions.contains_key("root")
                || direction.iter().any(|n| !n.is_finite())
                || direction[0].hypot(direction[1]) > 1.001
            {
                return Err(err("movement", "Movement is currently unavailable"));
            }
            s.actors.get_mut(actor_id).unwrap().direction = *direction;
        }
        CommandIntent::Ai {
            actor_id,
            policy,
            empty_policy,
            hold_after_orders,
        } => {
            if !["conservative", "balanced", "spend"].contains(&policy.as_str())
                || !["role", "assist", "basic", "hold"].contains(&empty_policy.as_str())
            {
                return Err(err("ai", "Unknown AI policy"));
            }
            let a = s
                .actors
                .get_mut(actor_id)
                .ok_or_else(|| err("actor", "Unknown actor"))?;
            a.policy = policy.clone();
            a.empty_policy = empty_policy.clone();
            a.hold = *hold_after_orders;
        }
        CommandIntent::Equip {
            actor_id,
            expected_binding_version,
            changes,
            cancel_action_ids,
        } => equip(
            s,
            r,
            actor_id,
            expected_binding_version,
            changes,
            cancel_action_ids,
        )?,
        CommandIntent::Transfer {
            item_id,
            quantity,
            from_container_id,
            to_container_id,
        } => {
            camp(s)?;
            if !["party_pack", "camp_storage"].contains(&to_container_id.as_str()) {
                return Err(err("container", "Nested or unknown container"));
            }
            let item = r
                .items()
                .get(item_id)
                .ok_or_else(|| err("item", "Unknown instance"))?
                .clone();
            if item.owner != *from_container_id || *quantity == 0 || *quantity > item.quantity {
                return Err(err("item", "Invalid transfer quantity or owner"));
            }
            if *quantity == item.quantity {
                r.apply(&[Mutation::TransferItem {
                    item: item_id.clone(),
                    owner: to_container_id.clone(),
                    parent: None,
                }])?;
            } else {
                let id = next(s, "stack");
                r.apply(&[
                    Mutation::SplitItem {
                        item: item_id.clone(),
                        quantity: *quantity,
                        new_id: id.clone(),
                    },
                    Mutation::TransferItem {
                        item: id,
                        owner: to_container_id.clone(),
                        parent: None,
                    },
                ])?;
            }
        }
        CommandIntent::Level {
            actor_id,
            expected_build_version,
            class_id,
            skills,
            feats,
            powers,
            attributes,
            unbind_item_ids,
        } => {
            camp(s)?;
            let a = s
                .actors
                .get_mut(actor_id)
                .ok_or_else(|| err("actor", "Unknown actor"))?;
            let level = a.level + 1;
            if a.build_version.to_string() != *expected_build_version
                || level > 20
                || a.xp < 100 * level * (level - 1) / 2
            {
                return Err(err("progression", "Level or build version is unavailable"));
            }
            if !a.classes.contains_key(class_id)
                || !powers.is_empty()
                || !attributes.is_empty()
                || !unbind_item_ids.is_empty()
            {
                return Err(err(
                    "progression",
                    "This allocation requires an implemented serial build plan",
                ));
            }
            let points = match class_id.as_str() {
                "arms" => 2,
                "scout" => 4,
                _ => {
                    return Err(err(
                        "progression",
                        "Path leveling is not available in this slice",
                    ))
                }
            } + a.attributes["intellect"].max(0) as u32;
            let spent: u32 = skills.iter().map(|c| c.ranks).sum();
            if spent > points + a.unspent
                || skills.iter().map(|c| &c.id).collect::<BTreeSet<_>>().len() != skills.len()
                || skills.iter().any(|c| {
                    ![
                        "devices",
                        "medicine",
                        "lore",
                        "insight",
                        "stealth",
                        "survival",
                        "athletics",
                        "diplomacy",
                    ]
                    .contains(&c.id.as_str())
                        || a.skills.get(&c.id).copied().unwrap_or(0) + c.ranks > level + 2
                })
            {
                return Err(err("progression", "Invalid skill allocation"));
            }
            if feats.len() > usize::from(level % 3 == 1)
                || feats.iter().any(|f| {
                    f != "marksmanship_ii"
                        || level < 7
                        || !a.feats.iter().any(|f| f == "marksmanship_i")
                })
            {
                return Err(err("progression", "Feat prerequisite not met"));
            }
            a.level = level;
            *a.classes.get_mut(class_id).unwrap() += 1;
            a.build_version += 1;
            a.unspent += points - spent;
            for choice in skills {
                *a.skills.entry(choice.id.clone()).or_default() += choice.ranks;
            }
            a.feats.extend(feats.clone());
            let gain = if class_id == "arms" { 8 } else { 6 } + a.attributes["body"];
            let rid = resource_id(actor_id, "health");
            capacity(s, r, &rid, r.resources()[&rid].maximum + gain)?;
        }
        CommandIntent::Craft {
            actor_id,
            recipe_id,
        } => {
            camp(s)?;
            if recipe_id != "arc_edge"
                || s.actors
                    .get(actor_id)
                    .and_then(|a| a.skills.get("devices"))
                    .copied()
                    .unwrap_or(0)
                    < 4
            {
                return Err(err(
                    "recipe",
                    "Arc edge requires four purchased Devices ranks",
                ));
            }
            let scrap = r
                .items()
                .values()
                .find(|i| i.definition == "scrap" && i.owner == "party_pack" && i.quantity >= 4)
                .ok_or_else(|| err("recipe", "Four scrap are required"))?
                .id
                .clone();
            let id = next(s, "arc-edge");
            r.apply(&[
                Mutation::ConsumeItem {
                    item: scrap,
                    quantity: 4,
                },
                Mutation::AdjustResource {
                    id: "party:credits".into(),
                    delta: -20,
                },
                Mutation::InsertItem(Item {
                    id,
                    definition: "arc_edge".into(),
                    owner: "party_pack".into(),
                    parent: None,
                    quantity: 1,
                    stack_key: "arc_edge".into(),
                    protected: false,
                }),
            ])?;
        }
        CommandIntent::Buy { stock_id, quantity } => {
            camp(s)?;
            if stock_id != "dressing" || *quantity == 0 || *quantity > 10 {
                return Err(err("stock", "Unknown or excessive stock quantity"));
            }
            let id = next(s, "dressing");
            r.apply(&[
                Mutation::AdjustResource {
                    id: "party:credits".into(),
                    delta: -8 * i64::from(*quantity),
                },
                Mutation::InsertItem(Item {
                    id,
                    definition: "dressing".into(),
                    owner: "party_pack".into(),
                    parent: None,
                    quantity: *quantity,
                    stack_key: "dressing".into(),
                    protected: false,
                }),
            ])?;
        }
        CommandIntent::Sell { item_id, quantity } => {
            camp(s)?;
            let i = r
                .items()
                .get(item_id)
                .ok_or_else(|| err("item", "Unknown item"))?;
            if i.owner != "party_pack" {
                return Err(err("item", "Item inaccessible"));
            }
            let value = item_def(&i.definition)?.price / 2;
            r.apply(&[
                Mutation::ConsumeItem {
                    item: item_id.clone(),
                    quantity: *quantity,
                },
                Mutation::AdjustResource {
                    id: "party:credits".into(),
                    delta: value * i64::from(*quantity),
                },
            ])?;
        }
        CommandIntent::Skill {
            actor_id,
            interaction_id,
        }
        | CommandIntent::Assist {
            actor_id,
            interaction_id,
            ..
        } => {
            camp(s)?;
            let checker = if let CommandIntent::Assist { helper_id, .. } = c {
                helper_id.as_deref().unwrap_or(actor_id)
            } else {
                actor_id
            };
            if !living(s, r, checker) || s.completed.contains(interaction_id) {
                return Err(err(
                    "interaction",
                    "Checker unavailable or consequence already committed",
                ));
            }
            let (skill, attr, dc) = match interaction_id.as_str() {
                "charter" => ("diplomacy", "presence", 17),
                "workbench_lock" => ("devices", "intellect", 16),
                _ => return Err(err("interaction", "Unknown interaction")),
            };
            let a = &s.actors[checker];
            let total = 10
                + i64::from(a.skills.get(skill).copied().unwrap_or(0))
                + a.attributes[attr]
                + if skill == "devices" && a.classes.get("scout").copied().unwrap_or(0) >= 3 {
                    2
                } else {
                    0
                };
            if total < dc {
                return Err(err(
                    "skill",
                    "Skill check failed; improve rank, tool or route before retry",
                ));
            }
            s.completed.push(interaction_id.clone());
            log(
                s,
                "skill",
                Some(checker),
                None,
                format!("{checker}: 10 + modifiers = {total}, DC {dc}; speaker player"),
            );
        }
        CommandIntent::Exit => camp(s)?,
    }
    Ok(())
}
fn equip(
    s: &mut CommandState,
    r: &mut RpgState,
    actor: &str,
    version: &str,
    changes: &[SlotChange],
    cancel: &[String],
) -> RuleResult {
    camp(s)?;
    let a = s
        .actors
        .get(actor)
        .ok_or_else(|| err("actor", "Unknown actor"))?;
    if a.binding_version.to_string() != version {
        return Err(err("binding", "Stale equipment binding"));
    }
    if !cancel.is_empty() {
        return Err(err(
            "queue",
            "Camp must settle orders before changing worn equipment",
        ));
    }
    let mut bindings = r.bindings().get(actor).cloned().unwrap_or_default();
    let mut seen = BTreeSet::new();
    for change in changes {
        if !SLOTS.contains(&change.slot_id.as_str()) || !seen.insert(change.slot_id.clone()) {
            return Err(err("slot", "Unknown or duplicate slot"));
        }
        if let Some(item) = &change.item_id {
            let i = r
                .items()
                .get(item)
                .ok_or_else(|| err("item", "Unknown equipment instance"))?;
            let def = item_def(&i.definition)?;
            if i.owner != "party_pack"
                || !def.slots.contains(&change.slot_id.as_str())
                || a.body != "humanoid"
            {
                return Err(err("body", "Equipment does not fit this actor or slot"));
            }
            if !super::progression::gear_legal(a, &i.definition) {
                return Err(err("training", "Equipment training is missing"));
            }
            if i.definition == "heavy_armor" && !a.feats.iter().any(|f| f == "heavy_training") {
                return Err(err("training", "Heavy armor training required"));
            }
            bindings.insert(change.slot_id.clone(), item.clone());
        } else {
            bindings.remove(&change.slot_id);
        }
    }
    for item in bindings.values().collect::<BTreeSet<_>>() {
        let def = item_def(&r.items()[item].definition)?;
        if def
            .slots
            .iter()
            .any(|slot| bindings.get(*slot) != Some(item))
        {
            return Err(err("occupancy", "Include every occupied slot in this plan"));
        }
    }
    let mut mutations = vec![Mutation::Unequip {
        actor: actor.into(),
        slots: SLOTS.iter().map(|s| (*s).into()).collect(),
    }];
    for item in bindings.values().collect::<BTreeSet<_>>() {
        mutations.push(Mutation::Equip {
            actor: actor.into(),
            item: item.clone(),
            slots: bindings
                .iter()
                .filter(|(_, i)| *i == item)
                .map(|(s, _)| s.clone())
                .collect(),
        });
    }
    let removed = r.apply(&mutations)?;
    for grant in removed.revoked_grants {
        s.lost_grants.insert(grant.id.clone(), grant);
    }
    for item in bindings.values().collect::<BTreeSet<_>>() {
        grant_item(r, actor, item)?;
    }
    s.actors.get_mut(actor).unwrap().binding_version += 1;
    super::progression::recompute(s, r, actor)?;
    Ok(())
}
