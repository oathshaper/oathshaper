//! Bounded Vanguard garden slice. The shared LCD Session owns every mutation;
//! the host supplies geometry observations, never health, heat or effects.
use crate::rpg::RpgState;
use crate::runtime::*;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet};
const U: i32 = 60;
fn error(message: &str) -> RuleError {
    RuleError::new("vanguard", message)
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Weapon {
    pub kind: String,
    pub module: String,
    pub heat: i32,
    pub latched: bool,
    pub last: u64,
    pub next: u64,
}
impl Weapon {
    fn new(kind: &str) -> Self {
        Self {
            kind: kind.into(),
            module: "standard".into(),
            heat: 0,
            latched: false,
            last: 0,
            next: 0,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Pending {
    pub power: String,
    pub target: String,
    pub activation: Option<u64>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Actor {
    pub id: String,
    pub name: String,
    pub class: String,
    pub party: bool,
    pub position: [i32; 2],
    pub hp: i32,
    pub hp_max: i32,
    pub shields: i32,
    pub shield_max: i32,
    pub armor: i32,
    pub barrier: i32,
    pub barrier_until: u64,
    pub barrier_source: String,
    pub damaged: u64,
    pub weapons: Vec<Weapon>,
    pub active: usize,
    pub busy: u64,
    pub cooldowns: BTreeMap<String, u64>,
    pub powers: Vec<String>,
    pub pending: Option<Pending>,
    pub stance: String,
    pub attack_target: String,
    pub knockback: [i32; 2],
    pub knockback_until: u64,
    pub stunned: u64,
    pub immunity: u64,
    pub sabotage: u64,
    pub fortify: u64,
    pub cover: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct State {
    pub tick: u64,
    pub sequence: u64,
    pub actors: BTreeMap<String, Actor>,
    pub pauses: BTreeSet<String>,
    pub status: String,
    pub fire: bool,
    pub aimed: bool,
    pub draw: bool,
    pub aim: Option<String>,
    pub visible: BTreeSet<String>,
    pub log: Vec<String>,
    pub shots: u64,
    pub last_shooter: String,
    pub last_target: Option<String>,
    pub reward: bool,
    pub surrender_declined: bool,
}
/// One host-produced geometry sample for exactly the next simulation interval.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Frame {
    pub tick: u64,
    pub sequence: u64,
    pub positions: BTreeMap<String, [i32; 2]>,
    pub sight: BTreeSet<String>,
    pub aim: Option<String>,
    pub cover: BTreeSet<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum Intent {
    Begin,
    Surrender {
        accept: bool,
    },
    Equip {
        actor: String,
        module: String,
    },
    Pause {
        owner: String,
        paused: bool,
    },
    Trigger {
        pressed: bool,
    },
    Aim {
        pressed: bool,
    },
    Cover,
    Holster,
    Swap,
    Power {
        actor: String,
        power: String,
        target: String,
    },
    Cancel {
        actor: String,
    },
    Order {
        actor: String,
        stance: String,
        target: String,
    },
}
fn actor(
    id: &str,
    display: [&str; 2],
    pools: [i32; 2],
    position: [i32; 2],
    weapons: &[&str],
    powers: &[&str],
    party: bool,
) -> Actor {
    Actor {
        id: id.into(),
        name: display[0].into(),
        class: display[1].into(),
        party,
        position,
        hp: pools[0] * U,
        hp_max: pools[0] * U,
        shields: pools[1] * U,
        shield_max: pools[1] * U,
        armor: if id == "player" { 2 } else { 0 },
        barrier: 0,
        barrier_until: 0,
        barrier_source: String::new(),
        damaged: 0,
        weapons: weapons.iter().map(|k| Weapon::new(k)).collect(),
        active: 0,
        busy: 0,
        cooldowns: BTreeMap::new(),
        powers: powers.iter().map(|s| s.to_string()).collect(),
        pending: None,
        stance: "follow".into(),
        attack_target: String::new(),
        knockback: [0, 0],
        knockback_until: 0,
        stunned: 0,
        immunity: 0,
        sabotage: 0,
        fortify: 0,
        cover: false,
    }
}
impl Default for State {
    fn default() -> Self {
        let actors = [
            actor(
                "player",
                ["Tessa Ward", "Breacher"],
                [160, 150],
                [-1000, 0],
                &["carbine", "shotgun"],
                &["concussive_shot", "fortify"],
                true,
            ),
            actor(
                "mara",
                ["Mara", "Field engineer"],
                [95, 110],
                [-2400, -1500],
                &["pistol"],
                &["arc_overload", "sabotage", "shield_repair"],
                true,
            ),
            actor(
                "ivo",
                ["Ivo", "Storm sentinel"],
                [110, 130],
                [-2400, 1500],
                &["pistol"],
                &["disrupt", "barrier_pulse", "kinetic_throw"],
                true,
            ),
            actor(
                "corsair_raider",
                ["Crimson Raider", "Raider"],
                [100, 40],
                [9000, 0],
                &["pistol"],
                &[],
                false,
            ),
            actor(
                "hound",
                ["Lantern Sentinel", "Synthetic"],
                [120, 60],
                [6500, -1600],
                &["pistol"],
                &[],
                false,
            ),
            actor(
                "sentinel",
                ["Iron sentinel", "Anchored"],
                [180, 80],
                [11000, 1600],
                &["carbine"],
                &[],
                false,
            ),
        ]
        .into_iter()
        .map(|a| (a.id.clone(), a))
        .collect();
        Self {
            tick: 0,
            sequence: 0,
            actors,
            pauses: BTreeSet::from(["briefing".into()]),
            status: "briefing".into(),
            fire: false,
            aimed: false,
            draw: true,
            aim: None,
            visible: BTreeSet::new(),
            log: vec!["Defeat the raider and his two guards. Recover the stolen payroll.".into()],
            shots: 0,
            last_shooter: String::new(),
            last_target: None,
            reward: false,
            surrender_declined: false,
        }
    }
}
fn gun(kind: &str) -> (i32, i32, u64, i32) {
    match kind {
        "shotgun" => (50, 35, 60, 8000),
        "carbine" => (15, 15, 15, 25000),
        _ => (20, 20, 30, 20000),
    }
}
fn distance(a: [i32; 2], b: [i32; 2]) -> f64 {
    (f64::from(a[0]) - f64::from(b[0])).hypot(f64::from(a[1]) - f64::from(b[1]))
}
fn player_emission_ready(s: &State) -> bool {
    s.draw && (!s.actors["player"].cover || s.aimed)
}
fn log(s: &mut State, message: String) {
    s.log.push(message);
    if s.log.len() > 8 {
        s.log.remove(0);
    }
}
fn pair(a: &str, b: &str) -> String {
    format!("{a}:{b}")
}
fn cooldown(power: &str) -> u64 {
    match power {
        "concussive_shot" | "arc_overload" => 480,
        "fortify" => 960,
        "sabotage" | "disrupt" => 600,
        "kinetic_throw" => 720,
        _ => 840,
    }
}
fn friendly_power(p: &str) -> bool {
    matches!(p, "shield_repair" | "barrier_pulse" | "fortify")
}
fn legal_power(
    s: &State,
    actor_id: &str,
    p: &str,
    target: &str,
    sight: &BTreeSet<String>,
) -> RuleResult {
    let a = s
        .actors
        .get(actor_id)
        .ok_or_else(|| error("Unknown squad member"))?;
    let b = s
        .actors
        .get(target)
        .ok_or_else(|| error("Choose an observed target"))?;
    if !a.party || a.hp <= 0 || !a.powers.iter().any(|x| x == p) || b.hp <= 0 {
        return Err(error("Power or conscious target unavailable"));
    }
    if friendly_power(p) != b.party {
        return Err(error("Invalid power target"));
    }
    let range = if p == "fortify" {
        0
    } else if matches!(p, "shield_repair" | "barrier_pulse" | "kinetic_throw") {
        10000
    } else {
        15000
    };
    if (p == "fortify" && actor_id != target)
        || distance(a.position, b.position) > range as f64
        || (actor_id != target && !sight.contains(&pair(actor_id, target)))
    {
        return Err(error("Target out of range or sight"));
    }
    if matches!(p, "arc_overload" | "disrupt") && b.shields <= 0 {
        return Err(error("Target shields already stripped"));
    }
    if p == "shield_repair" && b.shields >= b.shield_max {
        return Err(error("Shields are full"));
    }
    if p == "barrier_pulse" && b.barrier_until > s.tick && b.barrier >= 40 * U {
        return Err(error("Existing barrier is not improved"));
    }
    if p == "kinetic_throw" && (b.shields > 0 || target == "sentinel" || b.immunity > s.tick) {
        return Err(error("Throw needs an unshielded movable target"));
    }
    if p == "concussive_shot" && (a.weapons[a.active].latched || a.weapons[a.active].next > s.tick)
    {
        return Err(error("Weapon cooling or cadence prevents powered emission"));
    }
    if p == "concussive_shot" && actor_id == "player" && !player_emission_ready(s) {
        return Err(error("Draw the weapon and aim out of cover before firing"));
    }
    Ok(())
}
fn damage(s: &mut State, target: &str, raw: i32, tech: bool) {
    let now = s.tick;
    let b = s.actors.get_mut(target).unwrap();
    if b.hp <= 0 {
        return;
    }
    b.damaged = now;
    let mut amount = raw * U;
    if !tech {
        let absorbed = amount.min(b.barrier);
        b.barrier -= absorbed;
        amount -= absorbed;
    }
    let absorbed = amount.min(b.shields);
    b.shields -= absorbed;
    amount -= absorbed;
    if !tech {
        amount = (amount - b.armor * U).max(0);
        if b.fortify > now {
            amount = (amount / U * 3 / 5) * U;
        }
        b.hp = (b.hp - amount).max(0);
    }
    if b.hp == 0 {
        b.pending = None;
        b.barrier = 0;
        b.cover = false;
    }
}
fn emit(
    s: &mut State,
    id: &str,
    target: Option<&str>,
    powered: bool,
    sight: &BTreeSet<String>,
) -> bool {
    if id == "player" && !player_emission_ready(s) {
        return false;
    }
    let a = &s.actors[id];
    let w = &a.weapons[a.active];
    let (mut base, mut heat, cadence, range) = gun(&w.kind);
    if w.module == "cooling" {
        base -= 5;
    }
    if w.module == "damage" {
        base += 5;
        heat += 5;
    }
    if a.hp <= 0 || a.stunned > s.tick || a.sabotage > s.tick || w.latched || w.next > s.tick {
        return false;
    }
    let contact = target.filter(|t| {
        s.actors
            .get(*t)
            .is_some_and(|b| b.hp > 0 && b.party != a.party)
            && sight.contains(&pair(id, t))
    });
    if powered && contact.is_none() {
        return false;
    }
    if let Some(t) = contact {
        if distance(a.position, s.actors[t].position) > range as f64 * 2.0 {
            return false;
        }
    }
    let a = s.actors.get_mut(id).unwrap();
    let w = &mut a.weapons[a.active];
    w.heat = (w.heat + if powered { 10 * U } else { heat * U }).min(100 * U);
    w.latched = w.heat >= 100 * U;
    w.last = s.tick;
    w.next = s.tick + cadence;
    if !powered {
        a.busy = s.tick + 6;
    }
    s.shots += 1;
    s.last_shooter = id.into();
    s.last_target = contact.map(str::to_string);
    if let Some(t) = contact {
        let mut raw = if powered { 30 } else { base };
        if !powered && distance(a.position, s.actors[t].position) > range as f64 {
            raw /= 2;
        }
        damage(s, t, raw, false);
        if powered && s.actors[t].shields == 0 && s.actors[t].immunity <= s.tick {
            let b = s.actors.get_mut(t).unwrap();
            b.stunned = s.tick + 60;
        }
        log(
            s,
            format!("{} hit {} · {}", s.actors[id].name, s.actors[t].name, raw),
        );
    }
    true
}
fn command(s: &mut State, c: &Intent) -> RuleResult {
    match c {
        Intent::Surrender { accept } => {
            if s.status != "surrender" {
                return Err(error("No surrender offer"));
            }
            s.pauses.remove("surrender");
            if *accept {
                victory(s);
            } else {
                s.surrender_declined = true;
                s.status = "engaged".into();
                log(s, "The raider takes up his weapon again.".into());
            }
        }
        Intent::Equip { actor, module } => {
            if s.status != "briefing"
                || !["standard", "cooling", "damage"].contains(&module.as_str())
            {
                return Err(error("Module changes require the staging area"));
            }
            let a = s
                .actors
                .get_mut(actor)
                .filter(|a| a.party)
                .ok_or_else(|| error("Unknown squad member"))?;
            a.weapons[a.active].module = module.clone();
        }
        Intent::Pause { owner, paused } => {
            if !["wheel", "menu", "manual"].contains(&owner.as_str()) {
                return Err(error("Unknown pause owner"));
            }
            if *paused {
                s.pauses.insert(owner.clone());
                s.fire = false;
            } else {
                s.pauses.remove(owner);
            }
        }
        Intent::Begin => {
            if s.status != "briefing" {
                return Err(error("Chapter already started"));
            }
            s.status = "engaged".into();
            s.pauses.remove("briefing");
        }
        Intent::Trigger { pressed } | Intent::Aim { pressed } => {
            if *pressed && !s.draw {
                let a = s.actors.get_mut("player").unwrap();
                if a.busy > s.tick || a.pending.is_some() {
                    return Err(error("Action channel occupied"));
                }
                s.draw = true;
                a.busy = s.tick + 18;
            }
            if matches!(c, Intent::Trigger { .. }) {
                s.fire = *pressed;
            } else {
                s.aimed = *pressed;
            }
        }
        Intent::Cover => {
            if !s.pauses.is_empty() {
                return Err(error("Close the menu first"));
            }
            let a = s.actors.get_mut("player").unwrap();
            if !a.cover && !s.visible.contains("cover:player") {
                return Err(error("Move beside a marked planter to take cover"));
            }
            a.cover = !a.cover;
        }
        Intent::Holster => {
            let a = s.actors.get_mut("player").unwrap();
            if a.busy > s.tick || a.pending.is_some() {
                return Err(error("Action channel occupied"));
            }
            s.draw = !s.draw;
            s.fire = false;
            a.busy = s.tick + 18;
        }
        Intent::Swap => {
            let a = s.actors.get_mut("player").unwrap();
            if a.busy > s.tick || a.pending.is_some() {
                return Err(error("Action channel occupied"));
            }
            a.active = (a.active + 1) % a.weapons.len();
            a.busy = s.tick + 24;
            s.fire = false;
        }
        Intent::Power {
            actor,
            power,
            target,
        } => {
            if s.status != "engaged" {
                return Err(error("No active encounter"));
            }
            legal_power(s, actor, power, target, &s.visible)?;
            let a = s.actors.get_mut(actor).unwrap();
            if a.pending.is_some()
                || a.busy > s.tick
                || a.cooldowns.get(power).is_some_and(|t| *t > s.tick)
            {
                return Err(error("Power cooling or action already pending"));
            }
            a.pending = Some(Pending {
                power: power.clone(),
                target: target.clone(),
                activation: None,
            });
        }
        Intent::Cancel { actor } => {
            let a = s
                .actors
                .get_mut(actor)
                .filter(|a| a.party)
                .ok_or_else(|| error("Unknown squad member"))?;
            a.pending = None;
        }
        Intent::Order {
            actor,
            stance,
            target,
        } => {
            if actor == "player" || !matches!(stance.as_str(), "follow" | "hold" | "attack") {
                return Err(error("Invalid companion order"));
            }
            if stance == "attack"
                && !s.actors.get(target).is_some_and(|a| {
                    !a.party && a.hp > 0 && s.visible.contains(&pair(actor, target))
                })
            {
                return Err(error("Choose an observed hostile"));
            }
            let a = s
                .actors
                .get_mut(actor)
                .filter(|a| a.party && a.hp > 0)
                .ok_or_else(|| error("Companion unavailable"))?;
            a.stance = stance.clone();
            a.attack_target = target.clone();
        }
    }
    Ok(())
}
fn step(s: &mut State, f: &Frame) -> RuleResult {
    if !s.pauses.is_empty() || s.status != "engaged" {
        return Ok(());
    }
    if f.tick != s.tick || f.sequence != s.sequence + 1 || f.positions.len() != s.actors.len() {
        return Err(error("Stale or incomplete geometry frame"));
    }
    for (id, pos) in &f.positions {
        let a = s
            .actors
            .get_mut(id)
            .ok_or_else(|| error("Unknown observed actor"))?;
        if distance(*pos, a.position)
            > if a.knockback_until > s.tick {
                302.0
            } else {
                68.0
            }
        {
            return Err(error("Observed movement exceeds speed"));
        }
        if a.hp > 0 && (a.stunned <= s.tick || a.knockback_until > s.tick) && !a.cover {
            a.position = *pos;
        }
    }
    s.visible = f.sight.clone();
    for id in &f.cover {
        s.visible.insert(format!("cover:{id}"));
    }
    s.aim = f.aim.clone().filter(|t| {
        s.actors.get(t).is_some_and(|a| !a.party && a.hp > 0)
            && f.sight.contains(&pair("player", t))
    });
    s.sequence = f.sequence;
    s.tick += 1;
    let now = s.tick;
    let ids: Vec<_> = s.actors.keys().cloned().collect();
    for id in &ids {
        let a = s.actors.get_mut(id).unwrap();
        for w in &mut a.weapons {
            if now > w.last + 30 {
                w.heat = (w.heat - if w.module == "cooling" { 30 } else { 20 }).max(0);
                if w.heat <= 30 * U {
                    w.latched = false;
                }
            }
        }
        if a.hp <= 0 {
            continue;
        }
        if now >= a.barrier_until {
            a.barrier = 0;
        }
        if now >= a.damaged + 180 {
            a.shields = (a.shields + 20).min(a.shield_max);
        }
        if a.stunned == now {
            a.immunity = now + 60;
        }
    }
    for id in &ids {
        let pending = s.actors[id].pending.clone();
        if let Some(mut p) = pending {
            if s.actors[id].hp <= 0 || s.actors[id].stunned > now {
                s.actors.get_mut(id).unwrap().pending = None;
                continue;
            }
            if p.activation.is_none() {
                if legal_power(s, id, &p.power, &p.target, &f.sight).is_err() {
                    s.actors.get_mut(id).unwrap().pending = None;
                    log(s, format!("{}: order no longer valid", s.actors[id].name));
                    continue;
                }
                p.activation = Some(now);
                let a = s.actors.get_mut(id).unwrap();
                a.cooldowns
                    .insert(p.power.clone(), now + cooldown(&p.power));
                a.busy = now + 18;
                a.pending = Some(p.clone());
            }
            if now >= p.activation.unwrap() + 12 {
                if legal_power(s, id, &p.power, &p.target, &f.sight).is_ok() {
                    match p.power.as_str() {
                        "arc_overload" => damage(s, &p.target, 60, true),
                        "disrupt" => damage(s, &p.target, 40, true),
                        "concussive_shot" => {
                            emit(s, id, Some(&p.target), true, &f.sight);
                        }
                        "fortify" => s.actors.get_mut(id).unwrap().fortify = now + 240,
                        "sabotage" => s.actors.get_mut(&p.target).unwrap().sabotage = now + 120,
                        "shield_repair" => {
                            let b = s.actors.get_mut(&p.target).unwrap();
                            b.shields = (b.shields + 40 * U).min(b.shield_max);
                        }
                        "barrier_pulse" => {
                            let b = s.actors.get_mut(&p.target).unwrap();
                            b.barrier = 40 * U;
                            b.barrier_until = now + 240;
                            b.barrier_source = id.clone();
                        }
                        "kinetic_throw" => {
                            damage(s, &p.target, 20, false);
                            let source = s.actors[id].position;
                            let dest = s.actors[&p.target].position;
                            let length = distance(source, dest).max(1.0);
                            let b = s.actors.get_mut(&p.target).unwrap();
                            b.stunned = now + 60;
                            b.knockback = [
                                ((f64::from(dest[0]) - f64::from(source[0])) / length * 300.0)
                                    as i32,
                                ((f64::from(dest[1]) - f64::from(source[1])) / length * 300.0)
                                    as i32,
                            ];
                            b.knockback_until = now + 10;
                        }
                        _ => {}
                    }
                    log(
                        s,
                        format!("{} · {}", s.actors[id].name, p.power.replace('_', " ")),
                    );
                } else {
                    log(
                        s,
                        format!("{} missed · cooldown retained", s.actors[id].name),
                    );
                }
                s.actors.get_mut(id).unwrap().pending = None;
            }
        }
    }
    if s.fire
        && player_emission_ready(s)
        && s.actors["player"].pending.is_none()
        && s.actors["player"].busy <= now
    {
        let target = s.aim.clone();
        emit(s, "player", target.as_deref(), false, &f.sight);
    }
    if now.is_multiple_of(12) {
        for id in &ids {
            if id == "player" {
                continue;
            }
            let a = &s.actors[id];
            if a.hp <= 0 || a.busy > now || a.pending.is_some() {
                continue;
            }
            if a.party && a.shields * 10 < a.shield_max * 3 {
                let power = if id == "mara" {
                    "shield_repair"
                } else {
                    "barrier_pulse"
                };
                if a.cooldowns.get(power).is_none_or(|t| *t <= now)
                    && legal_power(s, id, power, id, &f.sight).is_ok()
                {
                    s.actors.get_mut(id).unwrap().pending = Some(Pending {
                        power: power.into(),
                        target: id.clone(),
                        activation: None,
                    });
                    continue;
                }
            }
            let a = &s.actors[id];
            let target = if !a.party {
                Some("player".to_string())
            } else if a.stance == "attack" {
                Some(a.attack_target.clone())
            } else {
                ids.iter()
                    .filter(|t| {
                        !s.actors[*t].party && s.actors[*t].hp > 0 && f.sight.contains(&pair(id, t))
                    })
                    // Default squad AI removes the guards first. Explicit
                    // player orders can still target the raider at any time.
                    .min_by_key(|t| (t.as_str() == "corsair_raider", t.as_str()))
                    .cloned()
            };
            if let Some(t) = target {
                if !s.actors.contains_key(&t) || s.actors[&t].hp <= 0 {
                    let a = s.actors.get_mut(id).unwrap();
                    a.stance = "hold".into();
                    continue;
                }
                if a.party || now % 90 < 12 {
                    emit(s, id, Some(&t), false, &f.sight);
                }
            }
        }
    }
    if s.actors["player"].hp <= 0 {
        s.status = "lost".into();
        s.pauses.insert("outcome".into());
        s.fire = false;
    } else if s.actors.values().filter(|a| !a.party).all(|a| a.hp <= 0) {
        victory(s);
    } else if !s.surrender_declined
        && s.actors["corsair_raider"].hp > 0
        && ["hound", "sentinel"].iter().all(|id| s.actors[*id].hp <= 0)
    {
        s.status = "surrender".into();
        s.pauses.insert("surrender".into());
        s.fire = false;
        s.aimed = false;
        log(
            s,
            "The raider lowers his weapon and offers to surrender.".into(),
        );
    }
    Ok(())
}
fn victory(s: &mut State) {
    s.status = "won".into();
    s.reward = true;
    s.pauses.insert("outcome".into());
    s.fire = false;
    s.aimed = false;
    for a in s.actors.values_mut().filter(|a| a.party) {
        if a.hp == 0 {
            a.hp = U;
        }
    }
}
pub struct VanguardProfile;
impl Profile for VanguardProfile {
    type State = State;
    type Command = Intent;
    type Advance = Frame;
    type View = Value;
    type Preview = Value;
    fn manifest(&self) -> Manifest {
        Manifest::minimal("vanguard", 1, "vanguard-garden-slice/v3")
    }
    fn participants(&self, _: Option<&str>, c: &Intent) -> BTreeSet<String> {
        match c {
            Intent::Equip { actor, .. }
            | Intent::Power { actor, .. }
            | Intent::Cancel { actor }
            | Intent::Order { actor, .. } => BTreeSet::from([actor.clone()]),
            _ => BTreeSet::new(),
        }
    }
    fn preview(&self, ctx: &ReadContext<State>, _: Option<&str>, c: &Intent) -> RuleResult<Value> {
        let mut s = ctx.state.clone();
        command(&mut s, c)?;
        Ok(json!({"available":true}))
    }
    fn prepare_command(
        &self,
        tx: &mut Transaction<State>,
        _: Option<&str>,
        c: &Intent,
    ) -> RuleResult {
        command(&mut tx.state, c)
    }
    fn prepare_advance(&self, tx: &mut Transaction<State>, f: &Frame) -> RuleResult {
        if !tx.state.pauses.is_empty() || tx.state.status != "engaged" {
            return Ok(());
        }
        if !tx.observe("vanguard-garden", f.sequence)? {
            return Err(error("Repeated geometry frame"));
        }
        step(&mut tx.state, f)
    }
    fn project(&self, ctx: &ReadContext<State>) -> Value {
        let s = ctx.state;
        let mut v = serde_json::to_value(s).unwrap();
        v["schema"] = json!("vanguard.view/v1");
        v["revision"] = json!(ctx.revision);
        v["epoch"] = json!(ctx.epoch);
        v["paused"] = json!(!s.pauses.is_empty());
        v
    }
    fn validate(&self, s: &State, _: &RpgState) -> RuleResult {
        if s.actors.len() != 6 || !s.actors.contains_key("player") || s.tick > 1_000_000_000 {
            return Err(error("Invalid roster or clock"));
        }
        for a in s.actors.values() {
            if a.hp < 0
                || a.hp > a.hp_max
                || a.shields < 0
                || a.shields > a.shield_max
                || a.barrier < 0
                || a.active >= a.weapons.len()
                || a.weapons.iter().any(|w| w.heat < 0 || w.heat > 100 * U)
            {
                return Err(error("Invalid actor resources"));
            }
        }
        Ok(())
    }
}
/// Owns non-serializable control capabilities. No caller may forge a lease.
pub struct VanguardGame {
    session: Session<VanguardProfile>,
    player: String,
    host: String,
    serial: u64,
}
impl VanguardGame {
    pub fn new() -> RuleResult<Self> {
        let mut authority = HostAuthority::default();
        let mut session = Session::new(
            VanguardProfile,
            State::default(),
            RpgState::default(),
            20261022,
            "vanguard-trial",
            &mut authority,
        )?;
        let player = session.issue_lease(
            &mut authority,
            Principal {
                id: "player".into(),
                role: Role::Player,
            },
            "player",
            LeaseScope {
                actors: BTreeSet::from(["player".into(), "mara".into(), "ivo".into()]),
                system_commands: true,
                advance: false,
            },
        )?;
        let host = session.issue_lease(
            &mut authority,
            Principal {
                id: "godot".into(),
                role: Role::System,
            },
            "player",
            LeaseScope {
                advance: true,
                ..Default::default()
            },
        )?;
        Ok(Self {
            session,
            player,
            host,
            serial: 0,
        })
    }
    pub fn view(&self) -> Value {
        let mut v = self.session.view(&self.player).unwrap();
        v["generation"] = json!(self.session.generation());
        v
    }
    pub fn submit(&mut self, c: Intent) -> RuleResult<Value> {
        self.serial += 1;
        let receipt = self.session.submit(Envelope {
            generation: self.session.generation(),
            epoch: self.session.epoch(),
            id: format!("input-{}", self.serial),
            lease: self.player.clone(),
            expected_revision: self.session.revision(),
            actor: None,
            payload: c,
        })?;
        Ok(json!({"receipt":receipt,"view":self.view()}))
    }
    pub fn advance(&mut self, f: Frame) -> RuleResult<Value> {
        self.serial += 1;
        let receipt = self.session.advance(Envelope {
            generation: self.session.generation(),
            epoch: self.session.epoch(),
            id: format!("frame-{}", self.serial),
            lease: self.host.clone(),
            expected_revision: self.session.revision(),
            actor: None,
            payload: f,
        })?;
        Ok(json!({"receipt":receipt,"view":self.view()}))
    }
}

#[cfg(test)]
mod surrender_tests {
    use super::*;
    #[test]
    fn surrender_pauses_until_explicit_choice_and_rewards_once() {
        for accept in [true, false] {
            let mut s = State::default();
            command(&mut s, &Intent::Begin).unwrap();
            for id in ["hound", "sentinel"] {
                s.actors.get_mut(id).unwrap().hp = 0;
            }
            let frame = Frame {
                tick: 0,
                sequence: 1,
                positions: s
                    .actors
                    .iter()
                    .map(|(id, a)| (id.clone(), a.position))
                    .collect(),
                sight: BTreeSet::new(),
                aim: None,
                cover: BTreeSet::new(),
            };
            step(&mut s, &frame).unwrap();
            assert_eq!(s.status, "surrender");
            assert!(s.pauses.contains("surrender"));
            let tick = s.tick;
            step(&mut s, &frame).unwrap();
            assert_eq!(s.tick, tick);
            assert!(!s.reward);
            command(&mut s, &Intent::Surrender { accept }).unwrap();
            assert_eq!(s.status, if accept { "won" } else { "engaged" });
            assert_eq!(s.reward, accept);
            assert_eq!(s.surrender_declined, !accept);
            assert!(command(&mut s, &Intent::Surrender { accept }).is_err());
            if !accept {
                let mut next = frame;
                next.tick = s.tick;
                next.sequence += 1;
                step(&mut s, &next).unwrap();
                assert_eq!(
                    s.status, "engaged",
                    "Declining does not immediately offer again"
                );
            }
        }
    }
}
