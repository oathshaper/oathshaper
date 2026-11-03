use super::*;
use rules::*;
pub(super) fn ai(s: &State, r: &RpgState, id: &str) -> Vec<FlowIntent> {
    let a = &s.actors[id];
    if s.phase != "encounter"
        || !s.pauses.is_empty()
        || !alive(s, r, id)
        || a.active.is_some()
        || a.stun > s.tick
        || a.last_ai == s.tick
        || s.tick < s.encounter_start + 60
    {
        return vec![];
    }
    if id == "mara" && s.follower_mode == "support" {
        if let Some(enemy) = s
            .actors
            .values()
            .filter(|b| {
                b.faction == "hostile"
                    && alive(s, r, &b.id)
                    && distance(a.position, b.position) < 2400.
            })
            .min_by(|x, y| {
                distance(a.position, x.position).total_cmp(&distance(a.position, y.position))
            })
        {
            return vec![FlowIntent::Ai {
                actor_id: id.into(),
                target: enemy.id.clone(),
                attack: false,
                retreat: true,
            }];
        }
    }
    let target = if id == "mara" {
        if s.follower_mode == "support" {
            if distance(a.position, s.actors["player"].position) > 5000. || a.direction != [0, 0] {
                "player".to_owned()
            } else {
                return vec![];
            }
        } else {
            s.actors
                .values()
                .filter(|b| b.faction == "hostile" && alive(s, r, &b.id) && clear(s, id, &b.id))
                .min_by(|a1, b1| {
                    distance(a.position, a1.position).total_cmp(&distance(a.position, b1.position))
                })
                .map(|b| b.id.clone())
                .unwrap_or_else(|| "player".into())
        }
    } else if id == "ivo" {
        s.actors
            .values()
            .filter(|b| b.faction == "hostile" && alive(s, r, &b.id))
            .min_by(|x, y| {
                distance(a.position, x.position).total_cmp(&distance(a.position, y.position))
            })
            .map(|b| b.id.clone())
            .unwrap_or_else(|| "player".into())
    } else {
        // Choose a nearby threat. Ivo draws attention while he holds the front;
        // nobody is scripted to hunt the healer regardless of position.
        let threat =
            |b: &Actor| distance(a.position, b.position) * if b.id == "ivo" { 0.65 } else { 1.0 };
        s.actors
            .values()
            .filter(|b| b.faction == "party" && alive(s, r, &b.id))
            .min_by(|x, y| threat(x).total_cmp(&threat(y)))
            .map(|b| b.id.clone())
            .unwrap_or_else(|| "player".into())
    };
    if !alive(s, r, &target) {
        return vec![];
    }
    let range = if id == "mara" && amount(r, id, "chi") >= 8 {
        12000.
    } else {
        1700.
    };
    let attack = s.actors[&target].faction != a.faction
        && s.cooldowns.get(&format!("ai:{id}")).copied().unwrap_or(0) <= s.tick
        && distance(a.position, s.actors[&target].position) <= range
        && clear(s, id, &target);
    vec![FlowIntent::Ai {
        actor_id: id.into(),
        target,
        attack,
        retreat: false,
    }]
}
fn hit(tx: &mut Transaction<State>, source: &str, target: &str, action: &Action) -> RuleResult {
    if !alive(&tx.state, &tx.rpg, target) || !tx.occurrence(format!("{}:{target}", action.id))? {
        return Ok(());
    }
    let s = &mut tx.state;
    let r = &mut tx.rpg;
    let victim = &s.actors[target];
    let dodge = target == "player"
        && s.tick >= victim.dodge_started + 2
        && s.tick < victim.dodge_started + 5
        && s.tick < victim.dodge_until;
    if dodge {
        log(s, format!("{} evaded the hit.", victim.name));
        return Ok(());
    }
    let direction = toward(victim.position, s.actors[source].position);
    let front = (direction[0] * victim.facing[0] + direction[1] * victim.facing[1]) >= 342_000;
    let blocked = victim.guard && front && !action.power;
    if blocked {
        log(s, format!("{} blocked.", victim.name));
        return Ok(());
    }
    let breaks = victim.guard && action.power;
    let combo =
        source == "player" && action.style == "stone" && action.power && victim.setup > s.tick;
    let mut damage = action.damage;
    if combo {
        damage += 24;
    }
    if damage > 0 {
        change(r, target, "health", -damage)?;
        log(
            s,
            format!(
                "{} → {}: {} damage{}",
                s.actors[source].name,
                s.actors[target].name,
                damage,
                if combo { " · Resonance +24" } else { "" }
            ),
        );
        if target == "player" {
            s.healing = false;
        }
    }
    let control = rank(s, "still", "control") as u64;
    let actor = s.actors.get_mut(target).unwrap();
    if combo {
        actor.setup = 0;
        actor.spent = s.tick + 160;
    }
    if breaks {
        actor.guard = false;
        if actor.resolve <= s.tick {
            actor.stun = s.tick + 7;
            actor.resolve = s.tick + 107;
        }
    } else if damage > 0 && actor.resolve <= s.tick && actor.reaction_until <= s.tick {
        actor.stun = s.tick + 3;
        actor.reaction_until = s.tick + 10;
    }
    if (damage > 0 || breaks) && actor.active.as_ref().is_some_and(|a| !a.fired && a.power) {
        actor.active = None;
    }
    if action.style == "still" {
        if actor.resolve <= s.tick {
            actor.slow = s.tick + 20 + 10 * control;
        }
        if action.power && actor.spent <= s.tick && actor.setup <= s.tick {
            actor.setup = s.tick + 60 + 10 * control;
        }
    }
    if action.verb == "area"
        && s.observations
            .get(&space::pose_query(
                "push",
                source,
                target,
                s.actors[source].position,
                s.actors[target].position,
            ))
            .is_some_and(|r| r.clear == Some(true))
    {
        let direction = toward(s.actors[source].position, s.actors[target].position);
        let a = s.actors.get_mut(target).unwrap();
        a.position = [a.position[0] + direction[0], a.position[1] + direction[1]];
    }
    if amount(r, target, "health") == 0 {
        let a = s.actors.get_mut(target).unwrap();
        a.active = None;
        a.direction = [0, 0];
        a.guard = false;
        let name = a.name.clone();
        log(s, format!("{name} is down."));
    }
    Ok(())
}
pub(super) fn reward(s: &mut State, r: &mut RpgState) -> RuleResult {
    if s.rewarded {
        return Ok(());
    }
    s.rewarded = true;
    s.phase = "victory".into();
    s.focus = false;
    s.healing = false;
    s.pauses.clear();
    s.projectiles.clear();
    for a in s.actors.values_mut() {
        a.active = None;
        a.direction = [0, 0];
    }
    change(r, "party", "copper", 80)?;
    s.xp += 100;
    while s.level < 10 && s.xp >= 100 * s.level * (s.level + 1) / 2 {
        s.level += 1;
        s.style_points += 3;
        s.attribute_points += 2;
    }
    r.apply(&[Mutation::InsertItem(Item {
        id: "garden-tide-shard".into(),
        definition: "tide_shard".into(),
        owner: "player".into(),
        parent: None,
        quantity: 1,
        stack_key: "tide_shard".into(),
        protected: true,
    })])?;
    log(s, "Guards defeated: 80 copper, 100 XP, one Tide shard.");
    Ok(())
}
pub(super) fn step(tx: &mut Transaction<State>, frame: &SpaceFrame) -> RuleResult {
    if !tx.state.pauses.is_empty() {
        return Err(err("pause", "Flow is paused"));
    }
    let sequence = frame
        .sequence
        .parse()
        .map_err(|_| err("geometry", "Invalid sequence"))?;
    if !tx.observe(&frame.producer_id, sequence)? {
        return Err(err("geometry", "Observation already consumed"));
    }
    tx.state.cursors.insert(frame.producer_id.clone(), sequence);
    tx.state.observations = frame
        .results
        .iter()
        .map(|r| (r.request_id.clone(), r.clone()))
        .collect();
    let movement: BTreeMap<_, _> = tx
        .state
        .actors
        .iter()
        .map(|(id, a)| (id.clone(), space::movement(&tx.state, a)))
        .collect();
    tx.state.tick += 1;
    let tick = tx.state.tick;
    if tx.state.phase != "encounter" {
        return Ok(());
    }
    if tx.state.focus && tick >= tx.state.focus_due {
        if amount(&tx.rpg, "player", "focus") >= 2 {
            pay(&mut tx.rpg, "player", "focus", 2)?;
            tx.state.focus_due += 5;
            tx.state
                .cooldowns
                .insert("focus:recovery".into(), tick + 40);
        } else {
            tx.state.focus = false;
            log(
                &mut tx.state,
                "Focus exhausted; hostile speed returns to normal.",
            );
        }
    }
    // Four Focus per second after two seconds without spending it. The due
    // tick lives in the serialized cooldown map; pause never advances it.
    if !tx.state.focus
        && alive(&tx.state, &tx.rpg, "player")
        && tick >= *tx.state.cooldowns.get("focus:recovery").unwrap_or(&0)
    {
        change(&mut tx.rpg, "player", "focus", 1)?;
        tx.state.cooldowns.insert("focus:recovery".into(), tick + 5);
    }
    // The complete story cast is present before the confrontation begins.
    if tick.is_multiple_of(60)
        && tx.state.follower_mode == "support"
        && alive(&tx.state, &tx.rpg, "mara")
        && amount(&tx.rpg, "mara", "chi") >= 6
    {
        let patient = ["player", "mara", "ivo"]
            .into_iter()
            .filter(|id| {
                alive(&tx.state, &tx.rpg, id)
                    && amount(&tx.rpg, id, "health") * 100
                        < tx.rpg.resources()[&rid(id, "health")].maximum * 75
                    && distance(
                        tx.state.actors["mara"].position,
                        tx.state.actors[*id].position,
                    ) <= 8000.
                    && (*id == "mara" || clear(&tx.state, "mara", id))
            })
            .min_by_key(|id| {
                amount(&tx.rpg, id, "health") * 100 / tx.rpg.resources()[&rid(id, "health")].maximum
            });
        if let Some(id) = patient {
            pay(&mut tx.rpg, "mara", "chi", 6)?;
            change(&mut tx.rpg, id, "health", 20)?;
            let name = tx.state.actors[id].name.clone();
            log(&mut tx.state, format!("Mara heals {name} for 20 Health."));
        }
    }
    if tick >= tx.state.support_due {
        tx.state.support_due += 40;
        if tx.state.follower_mode == "support"
            && tx.state.support_left > 0
            && alive(&tx.state, &tx.rpg, "mara")
            && distance(
                tx.state.actors["player"].position,
                tx.state.actors["mara"].position,
            ) <= 8000.
            && clear(&tx.state, "mara", "player")
        {
            let missing = tx.rpg.resources()[&rid("player", "chi")].maximum
                - amount(&tx.rpg, "player", "chi");
            let gain = missing.min(2).min(tx.state.support_left);
            change(&mut tx.rpg, "player", "chi", gain)?;
            tx.state.support_left -= gain;
            if gain > 0 {
                log(&mut tx.state, format!("Mara restores {gain} Chi."));
            }
        }
    }
    for id in [
        "player",
        "mara",
        "ivo",
        "hound",
        "sentinel",
        "corsair_raider",
    ] {
        if !alive(&tx.state, &tx.rpg, id) {
            continue;
        }
        let to = movement[id];
        if tx
            .state
            .observations
            .get(&format!("move:{id}"))
            .is_some_and(|q| q.clear == Some(true))
        {
            let a = tx.state.actors.get_mut(id).unwrap();
            a.position = to;
            if a.direction != [0, 0] {
                a.facing = a.direction;
            }
        }
    }
    let mut impacts = vec![];
    for id in [
        "player",
        "mara",
        "ivo",
        "hound",
        "sentinel",
        "corsair_raider",
    ] {
        if !alive(&tx.state, &tx.rpg, id) {
            continue;
        }
        let rate = if tx.state.focus && tx.state.actors[id].faction == "hostile" {
            1
        } else {
            2
        };
        let Some(mut a) = tx.state.actors[id].active.clone() else {
            continue;
        };
        if tx.state.actors[id].stun > tick && !a.fired {
            continue;
        }
        a.elapsed += rate;
        if !a.fired && a.elapsed >= a.startup {
            a.fired = true;
            impacts.push((id.to_owned(), a.clone()));
        }
        if a.elapsed >= a.startup + a.recovery {
            tx.state.actors.get_mut(id).unwrap().active = None;
        } else {
            tx.state.actors.get_mut(id).unwrap().active = Some(a);
        }
    }
    impacts.sort_by(|a, b| a.1.id.cmp(&b.1.id));
    for (source, a) in impacts {
        if !alive(&tx.state, &tx.rpg, &source) {
            continue;
        }
        if a.projectile {
            let destination = tx.state.actors[&a.target].position;
            let flight = (distance(tx.state.actors[&source].position, destination) / 600.)
                .ceil()
                .max(1.) as u64;
            tx.state.projectiles.push(Projectile {
                id: a.id,
                owner: source,
                target: a.target,
                destination,
                remaining: flight * 2,
                damage: a.damage,
            });
            continue;
        }
        let targets: Vec<_> = if a.verb == "area" || (a.style == "harbor" && a.verb == "normal") {
            tx.state
                .actors
                .values()
                .filter(|t| t.faction != tx.state.actors[&source].faction && t.deployed)
                .map(|t| t.id.clone())
                .collect()
        } else {
            vec![a.target.clone()]
        };
        for target in targets {
            let direction = toward(
                tx.state.actors[&source].position,
                tx.state.actors[&target].position,
            );
            let facing = tx.state.actors[&source].facing;
            let dot = direction[0] * facing[0] + direction[1] * facing[1];
            let required = if a.style == "harbor" && a.verb == "normal" {
                500_000
            } else if a.style == "stone" && a.verb == "normal" {
                707_000
            } else {
                -1_000_000
            };
            if dot >= required
                && distance(
                    tx.state.actors[&source].position,
                    tx.state.actors[&target].position,
                ) <= a.range as f64
                && clear(&tx.state, &source, &target)
            {
                hit(tx, &source, &target, &a)?;
            } else {
                log(
                    &mut tx.state,
                    format!("{} missed: range or obstruction changed.", source),
                );
            }
        }
    }
    let mut flying = vec![];
    for mut p in std::mem::take(&mut tx.state.projectiles) {
        p.remaining = p.remaining.saturating_sub(
            if tx.state.focus && tx.state.actors[&p.owner].faction == "hostile" {
                1
            } else {
                2
            },
        );
        if p.remaining > 0 {
            flying.push(p);
            continue;
        }
        if alive(&tx.state, &tx.rpg, &p.target)
            && distance(tx.state.actors[&p.target].position, p.destination) <= 800.
            && clear(&tx.state, &p.owner, &p.target)
        {
            hit(
                tx,
                &p.owner,
                &p.target,
                &Action {
                    id: p.id,
                    style: "projectile".into(),
                    verb: "normal".into(),
                    target: p.target.clone(),
                    start: tick,
                    elapsed: 0,
                    startup: 0,
                    recovery: 0,
                    damage: p.damage,
                    power: false,
                    range: 12000,
                    projectile: true,
                    fired: true,
                },
            )?;
        } else {
            log(&mut tx.state, "Projectile missed.");
        }
    }
    tx.state.projectiles = flying;
    if let Some(target) = selected_target(&tx.state, &tx.rpg) {
        tx.state.target = target.to_owned();
    }
    if tx.state.healing && tick >= tx.state.heal_due {
        tx.state.heal_due += 4;
        let missing = tx.rpg.resources()[&rid("player", "health")].maximum
            - amount(&tx.rpg, "player", "health");
        if missing > 0 {
            if amount(&tx.rpg, "player", "chi") >= 2 {
                pay(&mut tx.rpg, "player", "chi", 2)?;
                change(&mut tx.rpg, "player", "health", missing.min(6))?;
            } else {
                tx.state.healing = false;
            }
        }
    }
    if !alive(&tx.state, &tx.rpg, "player") {
        tx.state.phase = "defeat".into();
        tx.state.focus = false;
        tx.state.healing = false;
        for a in tx.state.actors.values_mut() {
            a.active = None;
            a.direction = [0, 0];
        }
    } else if tick >= tx.state.encounter_start + 80
        && ["hound", "sentinel", "corsair_raider"]
            .iter()
            .all(|id| amount(&tx.rpg, id, "health") == 0)
    {
        reward(&mut tx.state, &mut tx.rpg)?;
    } else if tick >= tx.state.encounter_start + 80
        && !tx.state.surrender_declined
        && amount(&tx.rpg, "hound", "health") == 0
        && amount(&tx.rpg, "sentinel", "health") == 0
        && (1..=16).contains(&amount(&tx.rpg, "corsair_raider", "health"))
    {
        tx.state.phase = "surrender".into();
        tx.state
            .pauses
            .insert("surrender".into(), "Surrender offered".into());
        tx.state.actors.get_mut("player").unwrap().direction = [0, 0];
        tx.state.healing = false;
        log(
            &mut tx.state,
            "The raider lowers his weapon and offers to surrender.",
        );
    }
    Ok(())
}
