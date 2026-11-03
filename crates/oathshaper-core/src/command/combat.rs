use super::*;
use crate::rpg::{ClaimTarget, Mutation};
use content::*;
use rules::*;
fn disabled(s: &CommandState, id: &str) -> bool {
    s.actors[id].conditions.contains_key("stun")
}
pub fn visible(s: &CommandState, from: &str, to: &str) -> bool {
    s.observations
        .get(&format!("los:{from}:{to}"))
        .is_some_and(|o| o.valid && o.visible == Some(true) && o.clear == Some(true))
}
pub(super) fn observable(s: &CommandState, target: &str) -> bool {
    s.actors.get(target).is_some_and(|a| a.faction == "party")
        || content::PARTY
            .iter()
            .any(|id| s.actors[*id].deployed && visible(s, id, target))
}
fn action_clear(s: &CommandState, a: &Action) -> bool {
    let key = if let Some(target) = &a.target.actor_id {
        format!("los:{}:{target}", a.actor)
    } else {
        format!("los:{}:{}", a.actor, a.id)
    };
    a.target.kind == "self"
        || (a.target.kind == "actor"
            && a.target.actor_id.as_deref() == Some(a.actor.as_str())
            && ability(&a.ability).is_ok_and(|ability| ability.target == "ally"))
        || s.observations
            .get(&key)
            .is_some_and(|o| o.valid && o.clear == Some(true))
}
pub fn pump(s: &mut CommandState, r: &mut RpgState) -> RuleResult {
    if !s.pauses.is_empty() {
        return Ok(());
    }
    // A defeated target can invalidate an entire queued sequence. Retire it in
    // one pass, so Resume does not pause once for every obsolete strike.
    let mut invalid = vec![];
    for actor in INITIATIVE {
        for action in &s.actors[actor].queue {
            if validate_live_target(s, r, action).is_err() {
                invalid.push(action.clone());
            }
        }
    }
    let mut interrupted = false;
    for action in invalid {
        s.actors
            .get_mut(&action.actor)
            .unwrap()
            .queue
            .retain(|queued| queued.id != action.id);
        release(r, &action.id)?;
        interrupted |= !action.ai;
        log(
            s,
            "failed",
            Some(&action.actor),
            None,
            "Obsolete queued order removed: target incapacitated".into(),
        );
    }
    if interrupted {
        pause(s, "action_failed", "obsolete-orders", true);
        return Ok(());
    }
    for actor in INITIATIVE {
        if !living(s, r, actor)
            || disabled(s, actor)
            || s.actors[actor].active.is_some()
            || s.tick < s.actors[actor].ready
            || s.actors[actor].queue.is_empty()
        {
            continue;
        }
        let mut action = s.actors.get_mut(actor).unwrap().queue.remove(0);
        let ab = ability(&action.ability)?;
        if availability(s, r, actor, &action.ability, &action.source).is_err()
            || validate_live_target(s, r, &action).is_err()
        {
            release(r, &action.id)?;
            if !action.ai {
                pause(s, "action_failed", &action.id, true);
            }
            log(
                s,
                "failed",
                Some(actor),
                None,
                "Queued target or source became unavailable".into(),
            );
            continue;
        }
        let pos =
            target_position(s, &action).ok_or_else(|| err("target", "Missing action target"))?;
        if distance(s.actors[actor].position, pos)
            > effective_range(r, actor, &ab, &action.source) as f64
            || !action_clear(s, &action)
        {
            action.phase = "approach".into();
            action.deadline = Some(s.tick + 60);
            action.path = s
                .observations
                .get(&format!("path:{actor}:{}", action.id))
                .map(|o| o.path_mm.clone())
                .unwrap_or_default();
            s.actors.get_mut(actor).unwrap().active = Some(action);
            continue;
        }
        activate(s, r, &mut action)?;
        s.actors.get_mut(actor).unwrap().active = Some(action);
    }
    Ok(())
}
fn validate_live_target(s: &CommandState, r: &RpgState, a: &Action) -> RuleResult {
    if let Some(id) = &a.target.actor_id {
        if !living(s, r, id) {
            return Err(err("target", "Target is incapacitated"));
        }
    }
    Ok(())
}
fn activate(s: &mut CommandState, r: &mut RpgState, a: &mut Action) -> RuleResult {
    let claims: Vec<_> = r
        .claims()
        .values()
        .filter(|c| c.action == a.id)
        .cloned()
        .collect();
    for c in claims {
        match &c.target {
            ClaimTarget::Resource { resource, amount } => {
                r.apply(&[Mutation::ConsumeClaim { id: c.id.clone() }])?;
                *s.debt
                    .get_mut(resource)
                    .ok_or_else(|| err("debt", "Missing resource debt"))? += *amount;
                a.paid += amount
            }
            ClaimTarget::Item { .. } => {
                r.apply(&[Mutation::ConsumeClaim { id: c.id }])?;
                a.paid_item = true
            }
            _ => {}
        }
    }
    if a.ability == "disrupt_device" {
        s.actors.get_mut(&a.actor).unwrap().device_uses += 1;
    }
    a.phase = "windup".into();
    a.activation = Some(s.tick);
    let (windup, recovery) = ability(&a.ability)?.timing();
    a.impact = Some(s.tick + windup);
    a.recovery = Some(s.tick + recovery);
    a.deadline = None;
    s.actors.get_mut(&a.actor).unwrap().ready = s.tick + recovery;
    if a.ability == "lunge" && !s.actors[&a.actor].conditions.contains_key("root") {
        if let Some(target) = target_position(s, a) {
            let from = s.actors[&a.actor].position;
            let distance = distance(from, target);
            if distance > 1000. {
                let amount = (distance - 1000.).min(2000.);
                let to = [
                    from[0] + ((target[0] - from[0]) as f64 * amount / distance).round() as i64,
                    from[1] + ((target[1] - from[1]) as f64 * amount / distance).round() as i64,
                ];
                if s.observations
                    .get(&format!("path:{}:{}", a.actor, a.id))
                    .is_some_and(|p| p.valid && p.clear == Some(true))
                {
                    s.actors.get_mut(&a.actor).unwrap().position =
                        space::uncrowded_step(s, &a.actor, to);
                }
            }
        }
    }
    log(
        s,
        "activation",
        Some(&a.actor),
        a.target.actor_id.as_deref(),
        format!(
            "{} activated; impact {}, recovery {}",
            a.ability,
            s.tick + windup,
            s.tick + recovery
        ),
    );
    Ok(())
}
#[cfg(test)]
thread_local! { pub(super) static RECORDED_ROLLS: std::cell::RefCell<std::collections::VecDeque<i64>> = const { std::cell::RefCell::new(std::collections::VecDeque::new()) }; }
fn roll(entropy: &mut Entropy, sides: u64) -> RuleResult<i64> {
    let value = entropy.below(sides)? as i64 + 1;
    #[cfg(test)]
    if let Some(recorded) = RECORDED_ROLLS.with(|rolls| rolls.borrow_mut().pop_front()) {
        assert!((1..=sides as i64).contains(&recorded));
        return Ok(recorded);
    }
    Ok(value)
}
pub(super) fn damage(
    s: &mut CommandState,
    r: &mut RpgState,
    target: &str,
    amount: i64,
    kind: &str,
) -> RuleResult<i64> {
    let mut amount = amount.max(0);
    if kind == "physical" && s.actors[target].conditions.contains_key("brace") {
        amount /= 2;
        s.actors.get_mut(target).unwrap().conditions.remove("brace");
    }
    if ["arc", "frost"].contains(&kind) {
        let ward = s.actors.get_mut(target).unwrap();
        let absorbed = amount.min(ward.ward_remaining);
        ward.ward_remaining -= absorbed;
        amount -= absorbed;
    }
    let hp = health(r, target);
    let actual = amount.min(hp);
    pool_change(s, r, &resource_id(target, "health"), -actual)?;
    if health(r, target) == 0 {
        cancel_actor(s, r, target)?;
    }
    Ok(actual)
}
fn cancel_actor(s: &mut CommandState, r: &mut RpgState, id: &str) -> RuleResult {
    let a = s.actors.get_mut(id).unwrap();
    let mut actions = std::mem::take(&mut a.queue);
    actions.extend(a.active.take());
    a.direction = [0., 0.];
    for action in actions {
        release(r, &action.id)?;
    }
    Ok(())
}
fn interrupt(s: &mut CommandState, r: &mut RpgState, id: &str) -> RuleResult {
    if s.actors[id]
        .active
        .as_ref()
        .is_some_and(|a| a.phase == "windup" || a.phase == "approach")
    {
        let a = s.actors.get_mut(id).unwrap().active.take().unwrap();
        release(r, &a.id)?;
        log(
            s,
            "interrupt",
            Some(id),
            None,
            format!(
                "{} interrupted; paid cost and readiness retained",
                a.ability
            ),
        );
    }
    Ok(())
}
fn impact(s: &mut CommandState, r: &mut RpgState, e: &mut Entropy, a: &Action) -> RuleResult {
    let ab = ability(&a.ability)?;
    if validate_live_target(s, r, a).is_err()
        || !action_clear(s, a)
        || target_position(s, a).is_none_or(|p| {
            distance(s.actors[&a.actor].position, p)
                > if a.ability == "lunge" {
                    2001.
                } else {
                    effective_range(r, &a.actor, &ab, &a.source) as f64 + 1.
                }
        })
    {
        log(
            s,
            "miss",
            Some(&a.actor),
            a.target.actor_id.as_deref(),
            "Paid action missed: target, range or line of sight changed".into(),
        );
        return Ok(());
    }
    let dc = 10 + i64::from(s.actors[&a.actor].level / 2) + s.actors[&a.actor].attributes["spirit"];
    match a.ability.as_str() {
        "binding_current" => {
            let center = target_position(s, a).unwrap();
            let targets: Vec<_> = s
                .actors
                .values()
                .filter(|t| {
                    t.faction != s.actors[&a.actor].faction
                        && living(s, r, &t.id)
                        && distance(t.position, center) <= 2000.
                })
                .map(|t| t.id.clone())
                .collect();
            for target in targets {
                let die = roll(e, 20)?;
                let modifier = if target == "hound" { 1 } else { 0 };
                if die + modifier < dc {
                    s.actors
                        .get_mut(&target)
                        .unwrap()
                        .conditions
                        .insert("root".into(), s.tick + 60);
                }
                log(
                    s,
                    "save",
                    Some(&a.actor),
                    Some(&target),
                    format!("Will {die}+{modifier} vs {dc}"),
                );
            }
        }
        "gale_arc" => {
            let target = a.target.actor_id.as_deref().unwrap();
            let die = roll(e, 20)?;
            let modifier = if target == "hound" { 2 } else { 0 };
            let base = 14;
            let amount = if die + modifier >= dc { base / 2 } else { base };
            let actual = damage(s, r, target, amount, "arc")?;
            log(
                s,
                "damage",
                Some(&a.actor),
                Some(target),
                format!(
                    "{}: Reflex {die}+{modifier} vs {dc}; {actual} damage",
                    ab.name
                ),
            );
            let log = s.logs.last_mut().unwrap();
            log.roll = Some(die);
            log.modifier = Some(modifier);
            log.threshold = Some(dc);
            log.damage = Some(actual);
        }
        "mend" | "dressing" => {
            let target = a.target.actor_id.as_deref().unwrap();
            if s.actors[target].body == "construct" {
                log(
                    s,
                    "miss",
                    Some(&a.actor),
                    Some(target),
                    "Biological healing cannot repair this target".into(),
                );
                return Ok(());
            }
            let caster = &s.actors[&a.actor];
            let amount = 12
                + caster.attributes["spirit"]
                + i64::from(caster.skills.get("medicine").copied().unwrap_or(0));
            let before = health(r, target);
            pool_change(s, r, &resource_id(target, "health"), amount)?;
            let healed = health(r, target) - before;
            log(
                s,
                "healing",
                Some(&a.actor),
                Some(target),
                format!("Healed {healed} Health"),
            );
            s.logs.last_mut().unwrap().healing = Some(healed);
        }
        "disrupt_device" => {
            let target = a.target.actor_id.as_deref().unwrap();
            let caster = &s.actors[&a.actor];
            let modifier = i64::from(caster.skills.get("devices").copied().unwrap_or(0))
                + caster.attributes["intellect"]
                + if caster.classes.get("scout").copied().unwrap_or(0) >= 3 {
                    2
                } else {
                    0
                };
            let die = roll(e, 20)?;
            if die + modifier >= 14 && !s.actors[target].conditions.contains_key("stun_immunity") {
                s.actors
                    .get_mut(target)
                    .unwrap()
                    .conditions
                    .insert("stun".into(), s.tick + 60);
                interrupt(s, r, target)?;
            }
            log(
                s,
                "device",
                Some(&a.actor),
                Some(target),
                format!("Devices {die}+{modifier} vs 14"),
            );
        }
        "gust" => {
            let target = a.target.actor_id.as_deref().unwrap();
            let die = roll(e, 20)?;
            let modifier = s.actors[target].attributes["body"];
            let from = s.actors[&a.actor].position;
            let origin = s.actors[target].position;
            if die + modifier < dc {
                for n in 1..=8 {
                    if s.observations
                        .get(&format!("push:{}:{n}", a.id))
                        .is_some_and(|q| q.valid && q.clear == Some(true))
                    {
                        s.actors.get_mut(target).unwrap().position =
                            space::push_endpoint(from, origin, n);
                    } else {
                        break;
                    }
                }
            }
            log(
                s,
                "push",
                Some(&a.actor),
                Some(target),
                format!("Gust Fortitude {die}+{modifier} vs {dc}; no damage"),
            );
        }
        "veil" => {
            let origin = s.actors[&a.actor].position;
            let faction = s.actors[&a.actor].faction.clone();
            for actor in s.actors.values_mut() {
                if actor.deployed
                    && actor.faction == faction
                    && health(r, &actor.id) > 0
                    && distance(origin, actor.position) <= 5000.
                    && actor.ward_strength < 12
                {
                    actor.ward_strength = 12;
                    actor.ward_remaining = 12;
                    actor.conditions.insert("ward".into(), s.tick + 90);
                }
            }
        }
        "brace" => {
            s.actors
                .get_mut(&a.actor)
                .unwrap()
                .conditions
                .insert("brace".into(), s.tick + 60);
        }
        _ => {
            let target = a.target.actor_id.as_deref().unwrap();
            let weapon = source_weapon(r, &a.source);
            let actor = &s.actors[&a.actor];
            let mut modifier = if actor.faction == "hostile" {
                attack(s, r, &a.actor)
            } else {
                let bab: i64 = actor
                    .classes
                    .iter()
                    .map(|(c, l)| match c.as_str() {
                        "arms" | "blade_adept" => i64::from(*l),
                        "storm_mystic" => i64::from(*l / 2),
                        _ => i64::from(*l * 3 / 4),
                    })
                    .sum();
                bab + actor.attributes[if weapon.is_some_and(|i| i.definition == "crossbow") {
                    "agility"
                } else {
                    "might"
                }] + if weapon.is_some_and(|i| i.definition == "sabre")
                    && actor.feats.iter().any(|f| f == "single_blade_i")
                {
                    1
                } else {
                    0
                }
            };
            if a.ability == "lunge"
                || (a.ability == "pinning_bolt"
                    && !s.actors[&a.actor]
                        .feats
                        .iter()
                        .any(|f| f == "marksmanship_ii"))
            {
                modifier -= 2;
            }
            let defense = defense(s, r, target);
            let die = roll(e, 20)?;
            let mut actual = 0;
            if die == 20 || (die != 1 && die + modifier >= defense) {
                let amount = if a.actor == "hound" {
                    6
                } else if a.actor == "sentinel" {
                    8
                } else if a.actor == "corsair_raider" {
                    if a.ability == "lunge" {
                        10
                    } else {
                        6
                    }
                } else {
                    let weapon = source_weapon(r, &a.source);
                    let die = roll(
                        e,
                        if weapon.is_some_and(|i| i.definition == "staff") {
                            6
                        } else if weapon.is_none() {
                            4
                        } else {
                            8
                        },
                    )?;
                    let upgrade_bonus = weapon
                        .and_then(|i| s.upgrades.get(&i.id))
                        .map(|_| 2)
                        .unwrap_or(0);
                    upgrade_bonus
                        + die
                        + s.actors[&a.actor].attributes[if weapon
                            .is_some_and(|i| i.definition == "crossbow")
                        {
                            "agility"
                        } else {
                            "might"
                        }]
                        + if a.ability == "lunge" { 4 } else { 0 }
                };
                actual = damage(
                    s,
                    r,
                    target,
                    amount,
                    if a.actor == "hound" {
                        "arc"
                    } else {
                        "physical"
                    },
                )?;
                if a.ability == "pinning_bolt" && health(r, target) > 0 {
                    s.actors
                        .get_mut(target)
                        .unwrap()
                        .conditions
                        .insert("slow".into(), s.tick + 30);
                }
                if a.ability == "shield_bash"
                    && health(r, target) > 0
                    && !s.actors[target].conditions.contains_key("stun_immunity")
                {
                    s.actors
                        .get_mut(target)
                        .unwrap()
                        .conditions
                        .insert("stun".into(), s.tick + 15);
                    interrupt(s, r, target)?;
                }
            }
            log(
                s,
                "attack",
                Some(&a.actor),
                Some(target),
                format!(
                    "{}: {die}+{modifier} vs Defense {defense}; {actual} damage",
                    ab.name
                ),
            );
            let log = s.logs.last_mut().unwrap();
            log.roll = Some(die);
            log.modifier = Some(modifier);
            log.threshold = Some(defense);
            log.damage = Some(actual);
        }
    }
    Ok(())
}
pub fn step(tx: &mut Transaction<CommandState>, step: &CommandStep) -> RuleResult {
    if !tx.state.pauses.is_empty() && !step.observation_only {
        return Err(err("paused", "Simulation is paused"));
    }
    if step.observation_only && step.frame.is_none() {
        return Err(err(
            "observation",
            "A geometry refresh requires an observed frame",
        ));
    }
    if let Some(frame) = &step.frame {
        let sequence = frame
            .sequence
            .parse()
            .map_err(|_| err("observation", "Invalid sequence"))?;
        if !tx.observe(&frame.producer_id, sequence)? {
            return Err(err("observation", "Already consumed geometry frame"));
        }
        tx.state
            .observation_sequence
            .insert(frame.producer_id.clone(), sequence);
        tx.state.observations = frame
            .results
            .iter()
            .map(|r| (r.request_id.clone(), r.clone()))
            .collect();
    }
    if step.observation_only {
        return Ok(());
    }
    let controlled_had_orders = tx.state.possessed.as_ref().is_some_and(|id| {
        tx.state.actors[id].active.is_some() || !tx.state.actors[id].queue.is_empty()
    });
    if step.pump_only {
        pump(&mut tx.state, &mut tx.rpg)?;
        if controlled_had_orders {
            pause_for_orders(&mut tx.state, &tx.rpg);
        }
        return Ok(());
    }
    let separation: Vec<_> = tx
        .state
        .actors
        .values()
        .filter(|a| a.deployed)
        .map(|a| {
            (
                a.id.clone(),
                a.position,
                space::separation_endpoint(&tx.state, &a.id),
            )
        })
        .collect();
    tx.state.tick += 1;
    let s = &mut tx.state;
    for a in s.actors.values_mut() {
        let stunned = a.conditions.get("stun").is_some_and(|t| *t <= s.tick);
        a.conditions.retain(|_, t| *t > s.tick);
        if !a.conditions.contains_key("ward") {
            a.ward_strength = 0;
            a.ward_remaining = 0;
        }
        if stunned {
            a.conditions.insert("stun_immunity".into(), s.tick + 30);
        }
    }
    for id in INITIATIVE {
        let action = tx.state.actors[id].active.clone();
        if let Some(mut action) = action {
            if action.phase == "windup"
                && action.impact == Some(tx.state.tick)
                && living(&tx.state, &tx.rpg, id)
                && !disabled(&tx.state, id)
            {
                let key = format!("{}:impact", action.id);
                if tx.occurrence(key)? {
                    impact(&mut tx.state, &mut tx.rpg, &mut tx.entropy, &action)?;
                }
                action.phase = "recovery".into();
                if tx.state.actors[id]
                    .active
                    .as_ref()
                    .is_some_and(|a| a.id == action.id)
                {
                    tx.state.actors.get_mut(id).unwrap().active = Some(action);
                }
            }
        }
    }
    let s = &mut tx.state;
    let r = &mut tx.rpg;
    for id in INITIATIVE {
        if let Some(mut a) = s.actors[id].active.clone() {
            if a.phase == "recovery" && a.recovery.is_some_and(|t| t <= s.tick) {
                release(r, &a.id)?;
                s.actors.get_mut(id).unwrap().active = None;
            } else if a.phase == "approach" {
                if a.deadline.is_some_and(|t| t <= s.tick)
                    || validate_live_target(s, r, &a).is_err()
                    || a.ai
                        && s.actors[id].faction == "party"
                        && a.approach_travel_mm >= 6000
                        && (target_position(s, &a).is_none_or(|p| {
                            distance(s.actors[id].position, p)
                                > effective_range(r, id, &ability(&a.ability).unwrap(), &a.source)
                                    as f64
                                    + 1.
                        }) || !action_clear(s, &a))
                {
                    release(r, &a.id)?;
                    s.actors.get_mut(id).unwrap().active = None;
                    if !a.ai {
                        pause(s, "action_failed", &a.id, true);
                    }
                    log(
                        s,
                        "failed",
                        Some(id),
                        None,
                        "Approach expired or target disappeared".into(),
                    );
                    continue;
                }
                let ab = ability(&a.ability)?;
                let target = target_position(s, &a).unwrap();
                let range = effective_range(r, id, &ab, &a.source) as f64;
                if !s.actors[id].conditions.contains_key("root") {
                    let staging = s
                        .observations
                        .get(&format!("staging:{id}:{}", a.id))
                        .filter(|o| range <= 2500. && o.valid && o.clear == Some(true));
                    if let Some(path) = staging.or_else(|| {
                        s.observations
                            .get(&format!("path:{id}:{}", a.id))
                            .filter(|o| o.valid && o.clear == Some(true))
                    }) {
                        let from = s.actors[id].position;
                        let next = path
                            .path_mm
                            .iter()
                            .copied()
                            .find(|p| distance(*p, from) > 1.)
                            .unwrap_or(target);
                        let d = distance(from, next);
                        let remaining = if action_clear(s, &a) {
                            (distance(from, target) - range).max(0.)
                        } else {
                            f64::INFINITY
                        };
                        let speed = if s.actors[id].conditions.contains_key("slow") {
                            150.0_f64
                        } else {
                            300.0_f64
                        };
                        let budget = if a.ai && s.actors[id].faction == "party" {
                            (6000 - a.approach_travel_mm).max(0) as f64
                        } else {
                            f64::INFINITY
                        };
                        let travel = speed.min(d).min(remaining).min(budget);
                        a.approach_travel_mm += travel.round() as i64;
                        if d > 0. {
                            let to = [
                                from[0] + ((next[0] - from[0]) as f64 * travel / d).round() as i64,
                                from[1] + ((next[1] - from[1]) as f64 * travel / d).round() as i64,
                            ];
                            s.actors.get_mut(id).unwrap().position =
                                space::uncrowded_step(s, id, to);
                        }
                    }
                }
                if distance(s.actors[id].position, target) <= range + 1. && action_clear(s, &a) {
                    activate(s, r, &mut a)?;
                }
                s.actors.get_mut(id).unwrap().active = Some(a);
            }
        }
    }
    for id in PARTY {
        let a = &s.actors[id];
        if a.active.is_none()
            && living(s, r, id)
            && !a.conditions.contains_key("root")
            && !a.conditions.contains_key("stun")
        {
            let from = a.position;
            let direction = a.direction;
            let to = [
                from[0] + (direction[0] * 300.).round() as i64,
                from[1] + (direction[1] * 300.).round() as i64,
            ];
            if s.observations
                .get(&format!("movement:{id}"))
                .is_some_and(|r| r.valid && r.clear == Some(true))
            {
                s.actors.get_mut(id).unwrap().position = space::uncrowded_step(s, id, to);
            }
        }
    }
    for (id, from, to) in separation {
        let actor = &s.actors[&id];
        if from == to
            || actor.position != from
            || !living(s, r, &id)
            || actor.conditions.contains_key("root")
            || actor.conditions.contains_key("stun")
            || actor.active.as_ref().is_some_and(|a| a.phase == "windup")
        {
            continue;
        }
        if s.observations
            .get(&format!("separation:{id}:{}:{}", from[0], from[1]))
            .is_some_and(|o| o.valid && o.clear == Some(true))
        {
            s.actors.get_mut(&id).unwrap().position = space::uncrowded_step(s, &id, to);
        }
    }
    if s.rest_until.is_some_and(|t| t <= s.tick) {
        let ids: Vec<_> = s
            .debt
            .keys()
            .filter(|id| PARTY.iter().any(|a| id.starts_with(&format!("{a}:"))))
            .cloned()
            .collect();
        for id in ids {
            s.debt.insert(id.clone(), 0);
            capacity(s, r, &id, r.resources()[&id].maximum)?;
        }
        for a in s.actors.values_mut() {
            a.conditions.clear();
            a.ward_strength = 0;
            a.ward_remaining = 0;
        }
        s.rest_until = None;
        log(
            s,
            "rest",
            None,
            None,
            "Camp rest restored Health, Focus and tool charges".into(),
        );
    }
    if s.phase == "encounter" && s.retreat_requested {
        let at_exit = PARTY
            .iter()
            .filter(|id| s.actors[**id].deployed && health(r, id) > 0)
            .all(|id| distance(s.actors[*id].position, [-6500, 0]) <= 1000.);
        let unseen = ENEMIES.iter().filter(|id| health(r, id) > 0).all(|enemy| {
            PARTY
                .iter()
                .filter(|id| s.actors[**id].deployed && health(r, id) > 0)
                .all(|id| !visible(s, enemy, id))
        });
        if at_exit && unseen {
            let since = *s.retreat_since.get_or_insert(s.tick);
            if s.tick >= since + 30 {
                for id in INITIATIVE {
                    cancel_actor(s, r, id)?;
                }
                for id in PARTY {
                    if s.actors[id].deployed && health(r, id) == 0 {
                        pool_change(s, r, &resource_id(id, "health"), 1)?;
                        s.actors.get_mut(id).unwrap().position = [-6500, 0];
                    }
                }
                s.phase = "exploration".into();
                s.outcome = Some("retreat".into());
                s.retreat_requested = false;
                s.retreat_since = None;
                log(
                    s,
                    "retreat",
                    None,
                    None,
                    "Party reached the exit unseen for three seconds; no reward granted".into(),
                );
            }
        } else {
            s.retreat_since = None;
        }
    }
    if s.phase == "encounter" {
        if ENEMIES.iter().all(|id| health(r, id) == 0) {
            for id in INITIATIVE {
                cancel_actor(s, r, id)?;
            }
            for id in PARTY {
                if s.actors[id].deployed && health(r, id) == 0 {
                    pool_change(s, r, &resource_id(id, "health"), 1)?;
                }
                s.actors.get_mut(id).unwrap().xp += 300;
            }
            r.apply(&[Mutation::AdjustResource {
                id: "party:credits".into(),
                delta: 45,
            }])?;
            // Receipt tracks XP/currency. The payroll is looted separately in
            // the campaign; victory must not materialize the old seal item.
            s.reward = Some(format!("garden-reward-{}", s.encounter));
            s.phase = "victory".into();
            s.outcome = Some("victory".into());
            log(
                s,
                "victory",
                None,
                None,
                "Victory: 300 XP, 45 credits".into(),
            );
        } else if PARTY
            .iter()
            .filter(|id| s.actors[**id].deployed)
            .all(|id| health(r, id) == 0)
        {
            s.phase = "defeat".into();
            s.outcome = Some("defeat".into());
            pause(s, "defeat", "encounter", true);
        }
    }
    if controlled_had_orders {
        pause_for_orders(s, r);
    }
    pump(s, r)
}

/// Edge-triggered: resuming an empty queue deliberately lets companions act.
/// A later completed/cleared order raises a new pause, never a per-tick loop.
pub(super) fn pause_for_orders(s: &mut CommandState, r: &RpgState) {
    if s.phase != "encounter" || s.retreat_requested {
        return;
    }
    // An action failure already explains why orders stopped. A second empty
    // queue token would make the same interruption look like two different ones.
    if s.pauses.values().any(|p| p.owner == "action_failed") {
        return;
    }
    let Some(id) = s.possessed.clone() else {
        return;
    };
    let actor = &s.actors[&id];
    if living(s, r, &id)
        && actor.active.is_none()
        && actor.queue.is_empty()
        && !s.pauses.values().any(|p| p.owner == "orders_empty")
    {
        pause(s, "orders_empty", &id, true);
    }
}

pub fn ai(s: &CommandState, r: &RpgState, actor: &str) -> Vec<CommandIntent> {
    let Some(a) = s.actors.get(actor) else {
        return vec![];
    };
    if s.phase != "encounter"
        || !s.pauses.is_empty()
        || !living(s, r, actor)
        || disabled(s, actor)
        || a.active.is_some()
        || !a.queue.is_empty()
        || s.tick < a.ready
        || a.hold
        || a.empty_policy == "hold"
        || s.possessed.as_deref() == Some(actor)
    {
        return vec![];
    }
    // A support companion must spend its reserve to save an ally, even when no
    // enemy is currently visible. Manual orders and possession still win above.
    if a.empty_policy == "role" && a.policy != "conservative" && r.has_ability(actor, "mend") {
        let mut wounded: Vec<_> = s
            .actors
            .values()
            .filter(|t| {
                t.faction == a.faction
                    && t.body != "construct"
                    && living(s, r, &t.id)
                    && health(r, &t.id) * 2 < r.resources()[&resource_id(&t.id, "health")].maximum
                    && distance(a.position, t.position) <= 8000.
                    && (t.id == actor || visible(s, actor, &t.id))
                    && !s.actors.values().any(|healer| {
                        healer
                            .active
                            .iter()
                            .chain(healer.queue.iter())
                            .any(|order| {
                                order.ability == "mend"
                                    && order.target.actor_id.as_deref() == Some(t.id.as_str())
                                    && order.phase != "recovery"
                            })
                    })
            })
            .collect();
        wounded.sort_by(|x, y| {
            // Compare fractions exactly: a large health pool should not mask danger.
            (health(r, &x.id) * r.resources()[&resource_id(&y.id, "health")].maximum)
                .cmp(&(health(r, &y.id) * r.resources()[&resource_id(&x.id, "health")].maximum))
                .then(x.id.cmp(&y.id))
        });
        for ally in wounded {
            for grant in r
                .grants()
                .values()
                .filter(|g| g.recipient == actor && g.ability == "mend")
            {
                let command = CommandIntent::Enqueue {
                    actor_id: actor.into(),
                    ability_id: "mend".into(),
                    source_id: grant.id.clone(),
                    target: Target::actor(&ally.id),
                };
                if rules::command(&mut s.clone(), &mut r.clone(), &command, true).is_ok() {
                    return vec![command];
                }
            }
        }
    }
    let mut enemies: Vec<_> = s
        .actors
        .values()
        .filter(|t| t.faction != a.faction && living(s, r, &t.id) && visible(s, actor, &t.id))
        .collect();
    enemies.sort_by(|x, y| {
        distance(a.position, x.position)
            .total_cmp(&distance(a.position, y.position))
            .then(x.id.cmp(&y.id))
    });
    let Some(enemy) = enemies.first() else {
        return vec![];
    };
    if a.faction == "party"
        && a.policy != "conservative"
        && health(r, actor) * 4 < r.resources()[&resource_id(actor, "health")].maximum
    {
        if let Some(item) = r.items().values().find(|i| {
            i.definition == "dressing"
                && i.owner == "party_pack"
                && i.quantity
                    > r.claims()
                        .values()
                        .filter_map(|c| match &c.target {
                            ClaimTarget::Item { item, quantity } if item == &i.id => {
                                Some(*quantity)
                            }
                            _ => None,
                        })
                        .sum::<u32>()
        }) {
            return vec![CommandIntent::Use {
                actor_id: actor.into(),
                item_id: item.id.clone(),
                target: Target::actor(actor),
            }];
        }
    }
    let mut ability_id = "basic";
    let mut target = Target::actor(&enemy.id);
    if a.empty_policy == "assist" {
        if let Some(id) = &s.selected_target {
            if enemies.iter().any(|e| e.id == *id) {
                target = Target::actor(id);
            }
        }
    }
    if a.empty_policy == "role" {
        let has = |id: &str| r.has_ability(actor, id);
        let free = r.available(&resource_id(actor, "focus")).unwrap_or(0);
        let floor =
            if a.policy == "balanced" {
                // Keep one Mend available; emergency healing above may use it.
                ((r.resources()[&resource_id(actor, "focus")].maximum + 4) / 5)
                    .max(if has("mend") { 16 } else { 0 })
            } else {
                0
            };
        if a.policy != "conservative" && has("binding_current") && free >= 18 + floor {
            if let Some(center) = enemies.iter().find(|center| {
                distance(a.position, center.position) <= 10000.
                    && enemies
                        .iter()
                        .filter(|t| {
                            !t.conditions.contains_key("root")
                                && !t.conditions.contains_key("stun")
                                && distance(center.position, t.position) <= 2000.
                        })
                        .count()
                        >= 2
            }) {
                ability_id = "binding_current";
                target = Target {
                    kind: "point".into(),
                    actor_id: None,
                    position: Some([
                        center.position[0] as f64 / 1000.,
                        center.position[1] as f64 / 1000.,
                    ]),
                };
            }
        }
        if ability_id == "basic"
            && a.policy != "conservative"
            && has("disrupt_device")
            && (a.policy == "spend" || a.device_uses == 0)
            && r.available(&resource_id(actor, "battery")).unwrap_or(0) > 0
        {
            if let Some(machine) = enemies.iter().find(|t| {
                t.body == "construct"
                    && !t.conditions.contains_key("stun")
                    && !t.conditions.contains_key("stun_immunity")
                    && t.active.as_ref().is_some_and(|action| {
                        action.phase == "windup"
                            && action
                                .target
                                .actor_id
                                .as_ref()
                                .is_some_and(|id| s.actors[id].faction == a.faction)
                    })
            }) {
                ability_id = "disrupt_device";
                target = Target::actor(&machine.id);
            }
        }
        if ability_id == "basic"
            && has("brace")
            && !a.conditions.contains_key("brace")
            && enemies.iter().any(|t| {
                distance(t.position, a.position) <= 2000.
                    && t.active.as_ref().is_some_and(|action| {
                        action.phase == "windup" && action.target.actor_id.as_deref() == Some(actor)
                    })
            })
        {
            ability_id = "brace";
            target = Target {
                kind: "self".into(),
                actor_id: None,
                position: None,
            };
        }
        // Each sentry uses the same legal actions and resource reservations as
        // the party; these are authored role preferences, not free AI attacks.
        if actor == "hound" && has("gale_arc") && free >= 10 {
            ability_id = "gale_arc";
        } else if actor == "corsair_raider"
            && has("lunge")
            && !a.conditions.contains_key("root")
            && distance(a.position, enemy.position) > 2000.
        {
            ability_id = "lunge";
        }
    }
    let fallback = Target::actor(&enemy.id);
    for (candidate, aimed) in [(ability_id, target), ("basic", fallback)] {
        let mut grants: Vec<_> = r
            .grants()
            .values()
            .filter(|g| g.recipient == actor && g.ability == candidate)
            .collect();
        grants.sort_by_key(|g| !matches!(g.source, Source::Item { .. }));
        for grant in grants {
            if a.faction == "party" && candidate == "basic" {
                let range = effective_range(r, actor, &ability("basic").unwrap(), &grant.id) as f64;
                let chosen = &s.actors[aimed.actor_id.as_deref().unwrap()];
                if distance(a.position, chosen.position) > range + 6000. {
                    continue;
                }
            }
            let command = CommandIntent::Enqueue {
                actor_id: actor.into(),
                ability_id: candidate.into(),
                source_id: grant.id.clone(),
                target: aimed.clone(),
            };
            if rules::command(&mut s.clone(), &mut r.clone(), &command, true).is_ok() {
                return vec![command];
            }
        }
    }
    vec![]
}

/// Explanation is a pure projection of the same current AI inputs.
pub(super) fn ai_reason(s: &CommandState, r: &RpgState, actor: &str) -> String {
    let a = &s.actors[actor];
    if !living(s, r, actor) {
        return "Unavailable: reserve or incapacitated".into();
    }
    if s.phase != "encounter" {
        return "Holding outside an encounter".into();
    }
    if !s.pauses.is_empty() {
        return "Paused; queued orders preserved".into();
    }
    if s.possessed.as_deref() == Some(actor) {
        return "Directly possessed; waiting for player orders".into();
    }
    if a.active.is_some() || !a.queue.is_empty() {
        return "Executing committed orders".into();
    }
    if a.hold || a.empty_policy == "hold" {
        return "Hold after orders enabled".into();
    }
    if disabled(s, actor) {
        return "Disabled by Stun".into();
    }
    if s.tick < a.ready {
        return format!("Recovering until tick {}", a.ready);
    }
    if let Some(command) = ai(s, r, actor).first() {
        return match command {
            CommandIntent::Enqueue {
                ability_id, target, ..
            } => format!(
                "Ready: {} against {}",
                ability(ability_id).map(|v| v.name).unwrap_or(ability_id),
                target.actor_id.as_deref().unwrap_or("chosen ground")
            ),
            CommandIntent::Use { .. } => "Health below 25%: use an available dressing".into(),
            _ => "Ready for role action".into(),
        };
    }
    if s.actors
        .values()
        .any(|t| t.faction != a.faction && living(s, r, &t.id) && visible(s, actor, &t.id))
    {
        "Holding: visible enemies need more than 6 m of travel beyond weapon reach".into()
    } else {
        "Holding: no conscious enemy is currently visible".into()
    }
}
