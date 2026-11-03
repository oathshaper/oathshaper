use super::*;
pub(super) fn rid(actor: &str, unit: &str) -> String {
    format!("{actor}:{unit}")
}
pub(super) fn amount(r: &RpgState, actor: &str, unit: &str) -> i64 {
    r.resources()[&rid(actor, unit)].current
}
pub(super) fn change(r: &mut RpgState, actor: &str, unit: &str, delta: i64) -> RuleResult {
    let id = rid(actor, unit);
    let p = &r.resources()[&id];
    let next = (p.current + delta).clamp(0, p.maximum);
    r.apply(&[Mutation::AdjustResource {
        id,
        delta: next - p.current,
    }])?;
    Ok(())
}
pub(super) fn pay(r: &mut RpgState, actor: &str, unit: &str, cost: i64) -> RuleResult {
    if amount(r, actor, unit) < cost {
        return Err(err(
            "resource",
            "Insufficient resource; choose a cost-free martial action",
        ));
    }
    change(r, actor, unit, -cost)
}
pub(super) fn alive(s: &State, r: &RpgState, id: &str) -> bool {
    s.actors.get(id).is_some_and(|a| a.deployed) && amount(r, id, "health") > 0
}
pub(super) fn distance(a: [i64; 2], b: [i64; 2]) -> f64 {
    ((a[0] - b[0]) as f64).hypot((a[1] - b[1]) as f64)
}
pub(super) fn toward(from: [i64; 2], to: [i64; 2]) -> [i64; 2] {
    let d = distance(from, to);
    if d == 0. {
        [0, 0]
    } else {
        [
            ((to[0] - from[0]) as f64 / d * 1000.).round() as i64,
            ((to[1] - from[1]) as f64 / d * 1000.).round() as i64,
        ]
    }
}
pub(super) fn clear(s: &State, a: &str, b: &str) -> bool {
    a == b
        || s.observations
            .get(&space::pose_query(
                "los",
                a,
                b,
                s.actors[a].position,
                s.actors[b].position,
            ))
            .is_some_and(|v| v.valid && v.clear == Some(true))
}
// Keep a live manual selection. A fallen target hands off to a visible nearby
// opponent; stable actor ordering breaks distance ties. Projecting this fallback
// also repairs the display of older saves before their first resumed tick.
pub(super) fn selected_target<'a>(s: &'a State, r: &RpgState) -> Option<&'a str> {
    if s.rewarded {
        return None;
    }
    if s.actors
        .get(&s.target)
        .is_some_and(|a| a.faction == "hostile")
        && alive(s, r, &s.target)
    {
        return Some(&s.target);
    }
    let origin = s.actors["player"].position;
    s.actors
        .values()
        .filter(|a| a.faction == "hostile" && alive(s, r, &a.id))
        .min_by(|a, b| {
            (!clear(s, "player", &a.id))
                .cmp(&(!clear(s, "player", &b.id)))
                .then_with(|| distance(origin, a.position).total_cmp(&distance(origin, b.position)))
                .then_with(|| a.id.cmp(&b.id))
        })
        .map(|a| a.id.as_str())
}
pub(super) fn log(s: &mut State, text: impl Into<String>) {
    s.logs.push(text.into());
    if s.logs.len() > 80 {
        s.logs.remove(0);
    }
}
pub(super) fn rank(s: &State, style: &str, track: &str) -> i64 {
    s.ranks
        .get(&format!("{style}:{track}"))
        .copied()
        .unwrap_or(0)
}
pub(super) fn gem_legal(s: &State, gem: &str) -> bool {
    match gem {
        "stone_charm" => s.attributes[0] >= 8,
        "rain_charm" => s.attributes[1] >= 8,
        "hawk_charm" => s.attributes[2] >= 8,
        "speaker_pearl" => true,
        _ => false,
    }
}
pub(super) fn maxima(s: &State, r: &RpgState) -> [i64; 3] {
    let mut m = [
        40 + 10 * s.attributes[0],
        10 + 5 * s.attributes[1],
        10 + 5 * s.attributes[2],
    ];
    for item in r
        .bindings()
        .get("player")
        .into_iter()
        .flatten()
        .map(|(_, i)| i)
    {
        match r.items()[item].definition.as_str() {
            "stone_charm" => m[0] += 20,
            "rain_charm" => m[1] += 10,
            "hawk_charm" => m[2] += 10,
            _ => {}
        }
    }
    m
}
fn recalc(s: &State, r: &mut RpgState) -> RuleResult {
    let m = maxima(s, r);
    for (i, u) in ["health", "chi", "focus"].iter().enumerate() {
        let mut p = r.resources()[&rid("player", u)].clone();
        p.maximum = m[i];
        p.current = p.current.min(m[i]);
        r.apply(&[Mutation::PutResource(p)])?;
    }
    Ok(())
}
pub(super) fn initial() -> RuleResult<(State, RpgState)> {
    let mut actors = BTreeMap::new();
    let mut r = RpgState::default();
    for (id, name, faction, pos, h, c, f) in [
        ("player", "Tessa Ward", "party", [-3500, 0], 160, 40, 40),
        ("mara", "Mara", "party", [-5500, 800], 100, 40, 0),
        ("ivo", "Ivo", "party", [-2500, 1500], 140, 0, 0),
        ("hound", "Lantern Sentinel", "hostile", [2000, 0], 120, 0, 0),
        (
            "sentinel",
            "Iron Sentinel",
            "hostile",
            [6000, 2000],
            96,
            0,
            0,
        ),
        (
            "corsair_raider",
            "Crimson Corsair",
            "hostile",
            [4000, -2000],
            144,
            0,
            0,
        ),
    ] {
        actors.insert(
            id.into(),
            Actor {
                id: id.into(),
                name: name.into(),
                faction: faction.into(),
                position: pos,
                direction: [0, 0],
                facing: if faction == "party" {
                    [1000, 0]
                } else {
                    [-1000, 0]
                },
                active: None,
                guard: id == "hound",
                stun: 0,
                reaction_until: 0,
                resolve: 0,
                setup: 0,
                spent: 0,
                slow: 0,
                deployed: true,
                dodge_started: 0,
                dodge_until: 0,
                last_ai: u64::MAX,
            },
        );
        for (u, v) in [("health", h), ("chi", c), ("focus", f)] {
            r.apply(&[Mutation::PutResource(Resource {
                id: rid(id, u),
                owner: id.into(),
                unit: u.into(),
                minimum: 0,
                maximum: v,
                current: v,
            })])?;
        }
    }
    for style in STYLES {
        r.apply(&[Mutation::AddGrant(Grant {
            id: format!("learned:{style}"),
            recipient: "player".into(),
            ability: style.into(),
            source: Source::Innate {
                id: "introductory-training".into(),
            },
        })])?;
    }
    for (id, definition) in [
        ("stone-1", "stone_charm"),
        ("rain-1", "rain_charm"),
        ("hawk-1", "hawk_charm"),
        ("pearl-1", "speaker_pearl"),
    ] {
        r.apply(&[Mutation::InsertItem(Item {
            id: id.into(),
            definition: definition.into(),
            owner: "player".into(),
            parent: None,
            quantity: 1,
            stack_key: definition.into(),
            protected: false,
        })])?;
    }
    r.apply(&[Mutation::PutResource(Resource {
        id: rid("party", "copper"),
        owner: "party".into(),
        unit: "copper".into(),
        minimum: 0,
        maximum: 1_000_000,
        current: 180,
    })])?;
    let s = State {
        tick: 0,
        encounter_start: 0,
        serial: 0,
        phase: "camp".into(),
        actors,
        style: "stone".into(),
        diamond: STYLES.map(str::to_owned).to_vec(),
        target: "hound".into(),
        preset: "stone".into(),
        attributes: [12, 6, 6],
        ranks: [("stone:damage".into(), 2), ("still:control".into(), 2)].into(),
        skills: ["intimidation", "acrobatics", "medicine", "mechanisms"]
            .map(str::to_owned)
            .to_vec(),
        level: 1,
        xp: 0,
        style_points: 0,
        attribute_points: 0,
        focus: false,
        focus_due: 0,
        enhanced: false,
        healing: false,
        heal_due: 0,
        cooldowns: BTreeMap::new(),
        pauses: BTreeMap::new(),
        follower_mode: "support".into(),
        follower_version: 0,
        support_due: 40,
        support_left: 12,
        projectiles: vec![],
        observations: BTreeMap::new(),
        cursors: BTreeMap::new(),
        logs: vec![],
        rewarded: false,
        surrender_declined: false,
    };
    Ok((s, r))
}
#[derive(Clone)]
pub(super) struct Verb {
    pub damage: i64,
    pub cost: i64,
    pub unit: &'static str,
    pub startup: u64,
    pub recovery: u64,
    pub range: i64,
    pub power: bool,
    pub projectile: bool,
}
pub(super) fn verb(s: &State, style: &str, verb: &str) -> RuleResult<Verb> {
    let (d, c, u, t, e, range, power, projectile): (i64, i64, &str, u64, u64, i64, bool, bool) =
        match (style, verb) {
            ("stone", "normal") => (18, 0, "chi", 5, 7, 1600, false, false),
            ("stone", "power") => (30, 0, "chi", 12, 10, 1800, true, false),
            ("stone", "area") => (0, 0, "chi", 8, 9, 1500, false, false),
            ("still", "normal") => (0, 0, "chi", 6, 8, 2000, false, false),
            ("still", "power") => (0, 6, "chi", 10, 7, 2000, true, false),
            ("gale", "normal") => (26, 8, "chi", 7, 8, 12000, false, true),
            ("gale", "area") => (20, 12, "chi", 12, 10, 2500, false, false),
            ("harbor", "normal") => (24, 0, "focus", 7, 8, 2500, false, false),
            ("harbor", "power") => (38, 10, "focus", 13, 11, 2500, true, false),
            _ => return Err(err("verb", "This style has no such verb")),
        };
    let speed = rank(s, style, "speed") as u64;
    Ok(Verb {
        damage: if d > 0 {
            d + 2 * rank(s, style, "damage")
        } else {
            0
        },
        cost: if c > 0 {
            (c - rank(s, style, "efficiency")).max(1)
        } else {
            0
        },
        unit: u,
        startup: t.saturating_sub(speed).max(2),
        recovery: e.saturating_sub(speed).max(2),
        range,
        power,
        projectile,
    })
}
pub(super) fn attack_verb(s: &State, r: &RpgState, v: &str) -> RuleResult<Verb> {
    if s.phase != "encounter" || !s.pauses.is_empty() || !alive(s, r, "player") {
        return Err(err("state", "Combat action requires a running encounter"));
    }
    let a = s.actors["player"].clone();
    if a.active.is_some() || a.stun > s.tick || a.dodge_until > s.tick {
        return Err(err("busy", "Finish the current action first"));
    }
    let vdef = verb(s, &s.style, v)?;
    let cooldown_key = if s.style == "still" {
        "still".to_owned()
    } else {
        format!("{}:{v}", s.style)
    };
    if s.cooldowns.get(&cooldown_key).is_some_and(|t| *t > s.tick) {
        return Err(err("cooldown", "Ability is recovering"));
    }
    let target = selected_target(s, r).ok_or_else(|| err("target", "No standing enemies"))?;
    if distance(a.position, s.actors[target].position) > vdef.range as f64 {
        return Err(err("range", "Move closer to your target"));
    }
    if !clear(s, "player", target) {
        return Err(err("obstruction", "Your target is behind an obstruction"));
    }

    if amount(r, "player", vdef.unit) < vdef.cost {
        return Err(err("resource", "Not enough energy for this attack"));
    }
    Ok(vdef)
}
fn interruptible(s: &State) -> RuleResult {
    let a = &s.actors["player"];
    if a.stun > s.tick || a.dodge_until > s.tick {
        return Err(err("disabled", "Recover before acting"));
    }
    if let Some(active) = &a.active {
        if active.fired && active.elapsed + 4 < active.startup + active.recovery {
            return Err(err(
                "recovery",
                "Guard or dodge is unavailable until the last 100 ms of recovery",
            ));
        }
    }
    Ok(())
}
fn camp(s: &State) -> RuleResult {
    if s.phase != "camp" {
        return Err(err(
            "camp",
            "Return to camp before training or changing gems",
        ));
    }
    Ok(())
}
pub(super) fn command(s: &mut State, r: &mut RpgState, c: &FlowIntent, system: bool) -> RuleResult {
    match c {
        FlowIntent::Start => {
            camp(s)?;
            if s.rewarded {
                return Err(err("encounter", "This chapter is already settled"));
            }
            s.phase = "encounter".into();
            s.encounter_start = s.tick;
            s.support_due = s.tick + 40;
            log(s, "The raider sends his two guards forward. Ivo holds the front; Mara stays behind you.");
        }
        FlowIntent::Camp => {
            if !["victory", "camp"].contains(&s.phase.as_str()) {
                return Err(err("camp", "Settle the encounter first"));
            }
            s.phase = "camp".into();
            s.pauses.clear();
        }
        FlowIntent::Retry => {
            if !["defeat", "encounter", "surrender"].contains(&s.phase.as_str()) {
                return Err(err("retry", "No unresolved encounter to retry"));
            }
        }
        FlowIntent::Pause { token } => {
            if token.is_empty() || token.len() > 80 || token == "surrender" {
                return Err(err("pause", "Invalid pause owner"));
            }
            s.pauses.insert(token.clone(), token.clone());
            s.actors.get_mut("player").unwrap().direction = [0, 0];
            s.healing = false;
        }
        FlowIntent::Unpause { token } => {
            if token == "surrender" || s.pauses.remove(token).is_none() {
                return Err(err("pause", "Unknown or owned encounter pause"));
            }
        }
        FlowIntent::Resume { .. } => {
            if !system {
                return Err(err("authority", "Host restore lease required"));
            }
            s.pauses.retain(|k, _| k == "surrender");
            s.actors.get_mut("player").unwrap().direction = [0, 0];
            s.healing = false;
        }
        FlowIntent::Target { actor_id } => {
            if !alive(s, r, actor_id) || s.actors[actor_id].faction != "hostile" {
                return Err(err("target", "Choose a conscious visible opponent"));
            }
            s.target = actor_id.clone();
        }
        FlowIntent::Style { style } => {
            if !STYLES.contains(&style.as_str()) {
                return Err(err("style", "Style is not learned"));
            }
            if s.actors["player"].stun > s.tick {
                return Err(err("stun", "Cannot switch while staggered"));
            }
            s.style = style.clone();
            s.healing = false;
            if s.actors["player"].active.as_ref().is_some_and(|a| !a.fired) {
                s.actors.get_mut("player").unwrap().active = None;
            }
        }
        FlowIntent::Assign { slot, style } => {
            if *slot >= 4 || !STYLES.contains(&style.as_str()) {
                return Err(err("slot", "Invalid learned style assignment"));
            }
            s.diamond[*slot] = style.clone();
        }
        FlowIntent::Move { direction } => {
            if direction.iter().any(|n| !n.is_finite() || n.abs() > 1.) {
                return Err(err("movement", "Invalid movement intent"));
            }
            let d = direction[0].hypot(direction[1]).max(1.);
            s.actors.get_mut("player").unwrap().direction = [
                (direction[0] / d * 1000.) as i64,
                (direction[1] / d * 1000.) as i64,
            ];
        }
        FlowIntent::Attack { verb: v } => {
            let vdef = attack_verb(s, r, v)?;
            s.target = selected_target(s, r).unwrap().to_owned();
            let a = s.actors["player"].clone();
            pay(r, "player", vdef.unit, vdef.cost)?;
            if vdef.unit == "focus" && vdef.cost > 0 {
                s.cooldowns.insert("focus:recovery".into(), s.tick + 40);
            }
            let mut damage = vdef.damage;
            if s.style == "stone" && damage > 0 && s.enhanced {
                let cost = (3 - rank(s, "stone", "efficiency")).max(1);
                if amount(r, "player", "chi") >= cost {
                    pay(r, "player", "chi", cost)?;
                    damage += 8;
                } else {
                    s.enhanced = false;
                    log(s, "Chi enhancement ended: ordinary strike admitted.");
                }
            }
            s.serial += 1;
            s.healing = false;
            let facing = toward(a.position, s.actors[&s.target].position);
            let actor = s.actors.get_mut("player").unwrap();
            actor.guard = false;
            actor.facing = facing;
            actor.active = Some(Action {
                id: format!("action-{}", s.serial),
                style: s.style.clone(),
                verb: v.clone(),
                target: s.target.clone(),
                start: s.tick,
                elapsed: 0,
                startup: vdef.startup * 2,
                recovery: vdef.recovery * 2,
                damage,
                power: vdef.power,
                range: vdef.range,
                projectile: vdef.projectile,
                fired: false,
            });
            if s.style == "still" {
                s.cooldowns.insert("still".into(), s.tick + 120);
            } else if s.style == "stone" && v == "area" {
                s.cooldowns.insert("stone:area".into(), s.tick + 40);
            }
        }
        FlowIntent::Guard { enabled } => {
            if *enabled {
                interruptible(s)?;
                s.actors.get_mut("player").unwrap().active = None;
                s.healing = false;
            }
            s.actors.get_mut("player").unwrap().guard = *enabled;
        }
        FlowIntent::Dodge => {
            interruptible(s)?;
            let a = s.actors.get_mut("player").unwrap();
            a.active = None;
            a.guard = false;
            a.dodge_started = s.tick;
            a.dodge_until = s.tick + 12;
            s.healing = false;
        }
        FlowIntent::Heal { enabled } => {
            if *enabled {
                if s.actors["player"].active.is_some()
                    || s.actors["player"].stun > s.tick
                    || !alive(s, r, "player")
                {
                    return Err(err("busy", "Cannot heal during an action or stagger"));
                }
                if amount(r, "player", "chi") < 2 {
                    return Err(err("resource", "Healing requires 2 Chi per pulse"));
                }
                s.heal_due = s.tick + 4;
            }
            s.healing = *enabled;
        }
        FlowIntent::Focus { enabled } => {
            if *enabled && (s.phase != "encounter" || !s.pauses.is_empty()) {
                return Err(err("encounter", "Focus mode requires an encounter"));
            }
            if *enabled && !s.focus {
                pay(r, "player", "focus", 2)?;
                s.focus_due = s.tick + 5;
                s.cooldowns.insert("focus:recovery".into(), s.tick + 40);
            }
            s.focus = *enabled;
        }
        FlowIntent::Enhance { enabled } => s.enhanced = *enabled,
        FlowIntent::Follower { mode } => {
            if !["attack", "support"].contains(&mode.as_str()) || !alive(s, r, "mara") {
                return Err(err(
                    "follower",
                    "Choose Attack or Support for a conscious follower",
                ));
            }
            if *mode != s.follower_mode {
                s.follower_mode = mode.clone();
                s.follower_version += 1;
                s.support_due = s.tick + 40;
                let a = s.actors.get_mut("mara").unwrap();
                if a.active.as_ref().is_some_and(|a| !a.fired) {
                    a.active = None;
                }
            }
        }
        FlowIntent::Equip { item_id, socket } => {
            camp(s)?;
            if *socket > 1 {
                return Err(err("slot", "Two amulet sockets are available"));
            }
            let item = r
                .items()
                .get(item_id)
                .ok_or_else(|| err("item", "Unknown owned gem"))?;
            if !gem_legal(s, &item.definition) {
                return Err(err(
                    "requirement",
                    "Permanent attributes do not meet this gem's requirement",
                ));
            }
            if r.bindings()
                .get("player")
                .into_iter()
                .flatten()
                .any(|(slot, id)| {
                    slot != &format!("socket{socket}")
                        && (id == item_id || r.items()[id].definition == item.definition)
                })
            {
                return Err(err("family", "That gem family is already bound"));
            }
            r.apply(&[
                Mutation::Unequip {
                    actor: "player".into(),
                    slots: vec![format!("socket{socket}")],
                },
                Mutation::Equip {
                    actor: "player".into(),
                    item: item_id.clone(),
                    slots: vec![format!("socket{socket}")],
                },
            ])?;
            recalc(s, r)?;
        }
        FlowIntent::Unequip { socket } => {
            camp(s)?;
            if *socket > 1 {
                return Err(err("slot", "Unknown socket"));
            }
            r.apply(&[Mutation::Unequip {
                actor: "player".into(),
                slots: vec![format!("socket{socket}")],
            }])?;
            recalc(s, r)?;
        }
        FlowIntent::Train { style, track } => {
            camp(s)?;
            if !STYLES.contains(&style.as_str())
                || !if style == "still" {
                    ["control", "speed", "efficiency"].contains(&track.as_str())
                } else {
                    ["damage", "speed", "efficiency"].contains(&track.as_str())
                }
            {
                return Err(err("training", "Unknown style track"));
            }
            let n = rank(s, style, track);
            if n >= 3 || s.style_points < n + 1 {
                return Err(err("training", "Not enough style points for the next rank"));
            }
            s.style_points -= n + 1;
            s.ranks.insert(format!("{style}:{track}"), n + 1);
        }
        FlowIntent::Attribute { attribute } => {
            camp(s)?;
            if *attribute >= 3 || s.attribute_points == 0 {
                return Err(err("training", "No attribute award available"));
            }
            s.attributes[*attribute] += 1;
            s.attribute_points -= 1;
            recalc(s, r)?;
        }
        FlowIntent::Preset { preset } => {
            camp(s)?;
            let (attrs, ranks, skills) = match preset.as_str() {
                "stone" => (
                    [12, 6, 6],
                    vec![("stone:damage", 2), ("still:control", 2)],
                    vec!["intimidation", "acrobatics", "medicine", "mechanisms"],
                ),
                "gale" => (
                    [6, 12, 6],
                    vec![("gale:damage", 2), ("gale:efficiency", 2)],
                    vec!["intuition", "charm", "medicine", "mechanisms"],
                ),
                "harbor" => (
                    [7, 6, 11],
                    vec![("harbor:damage", 2), ("harbor:efficiency", 2)],
                    vec!["charm", "acrobatics", "intimidation", "mechanisms"],
                ),
                "storm" => (
                    [8, 8, 8],
                    vec![
                        ("stone:damage", 1),
                        ("gale:damage", 1),
                        ("harbor:efficiency", 1),
                        ("still:control", 1),
                        ("stone:speed", 1),
                        ("gale:efficiency", 1),
                    ],
                    vec!["intuition", "charm", "acrobatics", "medicine"],
                ),
                _ => return Err(err("preset", "Unknown investment preset")),
            };
            pay(r, "party", "copper", 30)?;
            s.attributes = attrs;
            s.ranks = ranks.into_iter().map(|(k, v)| (k.into(), v)).collect();
            s.skills = skills.into_iter().map(str::to_owned).collect();
            s.attribute_points = 2 * i64::from(s.level - 1);
            s.style_points = 3 * i64::from(s.level - 1);
            for item in r
                .bindings()
                .get("player")
                .into_iter()
                .flatten()
                .map(|(_, i)| i)
            {
                if !gem_legal(s, &r.items()[item].definition) {
                    return Err(err(
                        "requirement",
                        "Unbind incompatible gems before this preset change",
                    ));
                }
            }
            s.preset = preset.clone();
            recalc(s, r)?;
        }
        FlowIntent::Rest => {
            camp(s)?;
            for id in ["player", "mara", "ivo"] {
                for unit in ["health", "chi", "focus"] {
                    let max = r.resources()[&rid(id, unit)].maximum;
                    change(r, id, unit, max)?;
                }
            }
        }
        FlowIntent::Surrender { accept } => {
            if s.phase != "surrender" {
                return Err(err("surrender", "No surrender offer"));
            }
            s.pauses.remove("surrender");
            if *accept {
                combat::reward(s, r)?;
            } else {
                s.phase = "encounter".into();
                s.surrender_declined = true;
            }
        }
        FlowIntent::Ai {
            actor_id,
            target,
            attack,
            retreat,
        } => {
            if actor_id == "player" || !alive(s, r, actor_id) || !alive(s, r, target) {
                return Err(err("ai", "Invalid AI actor or target"));
            }
            let target_position = s.actors[target].position;
            let actor = s.actors.get_mut(actor_id).unwrap();
            actor.last_ai = s.tick;
            actor.direction = [0, 0];
            if *attack {
                let (damage, range, projectile, startup, power) =
                    if actor_id == "mara" && amount(r, "mara", "chi") >= 8 {
                        pay(r, "mara", "chi", 8)?;
                        (20, 12000, true, 7, false)
                    } else if actor_id == "mara" {
                        (12, 1600, false, 10, false)
                    } else if actor_id == "ivo" {
                        (10, 1800, false, 14, false)
                    } else {
                        (
                            if actor_id == "hound" { 12 } else { 8 },
                            1800,
                            false,
                            if actor_id == "hound" { 24 } else { 18 },
                            actor_id == "hound",
                        )
                    };
                s.serial += 1;
                actor.guard = false;
                actor.facing = toward(actor.position, target_position);
                actor.active = Some(Action {
                    id: format!("action-{}", s.serial),
                    style: "npc".into(),
                    verb: "normal".into(),
                    target: target.clone(),
                    start: s.tick,
                    elapsed: 0,
                    startup: startup * 2,
                    recovery: 40,
                    damage,
                    power,
                    range,
                    projectile,
                    fired: false,
                });
                // A readable beat after each attack; no back-to-back AI spam.
                s.cooldowns
                    .insert(format!("ai:{actor_id}"), s.tick + startup + 40);
            } else {
                let stand_off = if actor_id == "mara" { 3500. } else { 1500. };
                actor.direction = if *retreat {
                    toward(target_position, actor.position)
                } else if distance(actor.position, target_position) <= stand_off {
                    [0, 0]
                } else {
                    toward(actor.position, target_position)
                };
            }
        }
    }
    Ok(())
}
