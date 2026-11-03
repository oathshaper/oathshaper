use super::*;
use crate::rpg::{Grant, Investment, Item, Mutation, Resource, Source};

pub const PARTY: [&str; 4] = ["player", "mara", "clerk", "ivo"];
pub const ENEMIES: [&str; 3] = ["sentinel", "hound", "corsair_raider"];
pub const CONTENT_HASH: &str = "command-garden/v5";
pub const INITIATIVE: [&str; 7] = [
    "mara",
    "player",
    "clerk",
    "sentinel",
    "hound",
    "corsair_raider",
    "ivo",
];
pub const SLOTS: [&str; 8] = [
    "head",
    "body",
    "hands",
    "belt",
    "accessory",
    "focus_tool",
    "main_hand",
    "offhand",
];
#[derive(Clone)]
pub struct Ability {
    pub id: &'static str,
    pub name: &'static str,
    pub category: &'static str,
    pub target: &'static str,
    pub range: i64,
    pub radius: i64,
    pub cost: i64,
    pub magic: bool,
}
impl Ability {
    pub fn timing(&self) -> (u64, u64) {
        if self.id == "shield_bash" {
            (6, 36)
        } else {
            (10, 30)
        }
    }
    pub fn description(&self) -> &'static str {
        match self.id {
            "shield_bash" => "Strike with the buckler: 1d4 + Might damage on a hit, interrupt and stun for 1.5 seconds unless immune. Impact after 0.6 seconds; ready again after 3.6 seconds. Requires an equipped buckler.",
            _ => "",
        }
    }
}
pub fn ability(id: &str) -> RuleResult<Ability> {
    let (name, category, target, range, radius, cost, magic) = match id {
        "basic" => ("Basic attack", "weapon", "enemy", 2000, 0, 0, false),
        "lunge" => ("Lunge", "weapon", "enemy", 4000, 0, 0, false),
        "shield_bash" => ("Shield bash", "weapon", "enemy", 2000, 0, 0, false),
        "binding_current" => ("Binding current", "powers", "point", 10000, 2000, 18, true),
        "gale_arc" => ("Gale arc", "powers", "enemy", 10000, 0, 10, true),
        "mend" => ("Mend", "powers", "ally", 8000, 0, 16, true),
        "veil" => ("Veil", "powers", "self", 0, 5000, 20, true),
        "gust" => ("Gust", "powers", "enemy", 8000, 0, 12, true),
        "disrupt_device" => ("Disrupt device", "tech", "enemy", 10000, 0, 1, false),
        "pinning_bolt" => ("Pinning bolt", "weapon", "enemy", 15000, 0, 0, false),
        "dressing" => ("Field dressing", "items", "ally", 2000, 0, 0, false),
        "brace" => ("Brace", "weapon", "self", 0, 0, 0, false),
        _ => return Err(err("ability", "Unknown ability")),
    };
    Ok(Ability {
        id: match id {
            "basic" => "basic",
            "lunge" => "lunge",
            "shield_bash" => "shield_bash",
            "binding_current" => "binding_current",
            "gale_arc" => "gale_arc",
            "mend" => "mend",
            "veil" => "veil",
            "gust" => "gust",
            "disrupt_device" => "disrupt_device",
            "pinning_bolt" => "pinning_bolt",
            "dressing" => "dressing",
            _ => "brace",
        },
        name,
        category,
        target,
        range,
        radius,
        cost,
        magic,
    })
}
pub struct ItemDef {
    pub name: &'static str,
    pub category: &'static str,
    pub slots: &'static [&'static str],
    pub appearance: &'static str,
    pub grants: &'static [&'static str],
    pub price: i64,
}
pub fn item_def(id: &str) -> RuleResult<ItemDef> {
    let (name, category, slots, appearance, grants, price): (_, _, &[&str], _, &[&str], _) =
        match id {
            "sabre" => (
                "Corsair sabre",
                "weapon",
                &["main_hand"],
                "sabre",
                &["basic", "lunge"],
                45,
            ),
            "buckler" => (
                "Buckler",
                "shield",
                &["offhand"],
                "buckler",
                &["brace", "shield_bash"],
                25,
            ),
            "staff" => (
                "Ash staff",
                "weapon",
                &["main_hand", "offhand"],
                "staff",
                &["basic"],
                20,
            ),
            "crossbow" => (
                "Survey crossbow",
                "weapon",
                &["main_hand", "offhand"],
                "crossbow",
                &["basic", "pinning_bolt"],
                40,
            ),
            "mace" => (
                "Guard mace",
                "weapon",
                &["main_hand"],
                "mace",
                &["basic"],
                35,
            ),
            "light_coat" => ("Light coat", "armor", &["body"], "light", &[], 30),
            "robe" => ("Travel robe", "armor", &["body"], "robe", &[], 10),
            "heavy_armor" => ("Heavy armor", "armor", &["body"], "heavy", &[], 60),
            "storm_lens" => (
                "Storm lens",
                "focus",
                &["focus_tool"],
                "lens",
                &["gust"],
                60,
            ),
            "survey_tool" => (
                "Survey tool",
                "tool",
                &["focus_tool"],
                "tool",
                &["disrupt_device"],
                40,
            ),
            "dressing" => ("Field dressing", "consumable", &[], "", &[], 8),
            "scrap" => ("Machine scrap", "material", &[], "", &[], 2),
            "arc_edge" => ("Arc edge", "upgrade", &[], "", &[], 30),
            _ => return Err(err("item", "Unknown item definition")),
        };
    Ok(ItemDef {
        name,
        category,
        slots,
        appearance,
        grants,
        price,
    })
}
pub fn resource_id(actor: &str, unit: &str) -> String {
    format!("{actor}:{unit}")
}
pub fn source_id(actor: &str, ability: &str) -> String {
    format!("learned:{actor}:{ability}:1")
}
pub fn initial() -> RuleResult<(CommandState, RpgState)> {
    let mut state = CommandState {
        tick: 0,
        phase: "camp".into(),
        actors: BTreeMap::new(),
        debt: BTreeMap::new(),
        pauses: BTreeMap::new(),
        recipient: "player".into(),
        possessed: Some("player".into()),
        inspected: "player".into(),
        camera: Some("player".into()),
        serial: 0,
        logs: vec![],
        encounter: 0,
        outcome: None,
        reward: None,
        rest_until: None,
        retreat_since: None,
        retreat_requested: false,
        selected_target: None,
        checkpoint_id: None,
        respec_cost: 0,
        upgrades: BTreeMap::new(),
        lost_grants: BTreeMap::new(),
        geometry_revision: "garden-1".into(),
        observations: BTreeMap::new(),
        observation_sequence: BTreeMap::new(),
        completed: vec![],
    };
    let mut rpg = RpgState::default();
    for (id, name, classes, attrs, pos, body, health, focus) in [
        (
            "player",
            "Tessa Ward",
            vec![("arms", 6)],
            [3, 2, 2, 1, 1, 0],
            [0, 0],
            "humanoid",
            80,
            0,
        ),
        (
            "mara",
            "Mara",
            vec![("scout", 3), ("storm_mystic", 3)],
            [0, 2, 0, 2, 3, 2],
            [-2000, 0],
            "humanoid",
            50,
            56,
        ),
        (
            "clerk",
            "Civic clerk",
            vec![("scout", 6)],
            [0, 3, 1, 2, 1, 2],
            [-2000, 2000],
            "humanoid",
            62,
            0,
        ),
        (
            "ivo",
            "Ivo",
            vec![("arms", 6)],
            [3, 0, 3, 0, 1, 2],
            [-3500, 1000],
            "humanoid",
            86,
            0,
        ),
        (
            "hound",
            "Lantern Sentinel",
            vec![],
            [0, 2, 0, 1, 2, 0],
            [2000, 0],
            "construct",
            30,
            20,
        ),
        (
            "sentinel",
            "Iron Sentinel",
            vec![],
            [0, 0, 0, 0, 0, 0],
            [6000, 2000],
            "construct",
            48,
            0,
        ),
        (
            "corsair_raider",
            "Crimson Corsair",
            vec![],
            [2, 3, 1, 0, 0, 0],
            [4000, -2000],
            "humanoid",
            36,
            0,
        ),
    ] {
        let party = PARTY.contains(&id);
        let mut actor = ActorState {
            id: id.into(),
            name: name.into(),
            faction: if party { "party" } else { "hostile" }.into(),
            body: body.into(),
            deployed: id != "ivo",
            guest: id == "clerk",
            position: pos,
            level: if party { 6 } else { 1 },
            classes: classes.into_iter().map(|(s, n)| (s.into(), n)).collect(),
            attributes: [
                "might",
                "agility",
                "body",
                "intellect",
                "spirit",
                "presence",
            ]
            .into_iter()
            .zip(attrs)
            .map(|(s, n)| (s.into(), n))
            .collect(),
            skills: BTreeMap::new(),
            feats: vec![],
            xp: if party { 1500 } else { 0 },
            unspent: 0,
            unspent_feats: 0,
            unspent_powers: 0,
            unspent_attributes: 0,
            build_version: 1,
            binding_version: 1,
            conditions: BTreeMap::new(),
            active: None,
            queue: vec![],
            ready: 0,
            policy: if id == "mara" {
                "balanced"
            } else {
                "conservative"
            }
            .into(),
            empty_policy: "role".into(),
            hold: false,
            direction: [0., 0.],
            last_reason: None,
            device_uses: 0,
            ward_remaining: 0,
            ward_strength: 0,
        };
        if id == "player" || id == "corsair_raider" {
            actor.feats.push("single_blade_i".into());
        }
        if id == "ivo" {
            actor
                .feats
                .extend(["heavy_training".into(), "guard_i".into()]);
        }
        if id == "clerk" {
            actor.skills.extend([
                ("devices".into(), 4),
                ("lore".into(), 3),
                ("medicine".into(), 1),
            ]);
            actor.feats.push("marksmanship_i".into());
        }
        if id == "mara" {
            actor.skills.insert("medicine".into(), 3);
            actor.skills.insert("diplomacy".into(), 6);
        }
        state.actors.insert(id.into(), actor);
        for (unit, max) in [
            ("health", health),
            ("focus", focus),
            ("battery", if id == "clerk" { 3 } else { 0 }),
        ] {
            let rid = resource_id(id, unit);
            state.debt.insert(rid.clone(), 0);
            rpg.apply(&[Mutation::PutResource(Resource {
                id: rid,
                owner: id.into(),
                unit: unit.into(),
                minimum: 0,
                maximum: max,
                current: max,
            })])?;
        }
        for power in match id {
            "mara" => vec!["binding_current", "gale_arc", "mend", "veil"],
            "sentinel" => vec!["basic", "brace"],
            "hound" => vec!["basic", "gale_arc"],
            "corsair_raider" => vec!["basic", "lunge"],
            _ => vec!["basic"],
        } {
            let sid = source_id(id, power);
            rpg.apply(&[
                Mutation::AddInvestment(Investment {
                    id: sid.clone(),
                    actor: id.into(),
                    definition: power.into(),
                    awarded_at: 1,
                    currency: "choices".into(),
                    amount: 1,
                    prerequisites: BTreeSet::new(),
                }),
                Mutation::AddGrant(Grant {
                    id: sid.clone(),
                    recipient: id.into(),
                    ability: power.into(),
                    source: Source::Investment { investment: sid },
                }),
            ])?;
        }
    }
    for (id, def, actor) in [
        ("sabre-4", "sabre", "player"),
        ("buckler-2", "buckler", "player"),
        ("coat-1", "light_coat", "player"),
        ("staff-mara", "staff", "mara"),
        ("robe-mara", "robe", "mara"),
        ("crossbow-clerk", "crossbow", "clerk"),
        ("coat-clerk", "light_coat", "clerk"),
        ("tool-clerk", "survey_tool", "clerk"),
        ("mace-ivo", "mace", "ivo"),
        ("shield-ivo", "buckler", "ivo"),
        ("armor-ivo", "heavy_armor", "ivo"),
        ("staff-9", "staff", ""),
        ("lens-17", "storm_lens", ""),
    ] {
        rpg.apply(&[Mutation::InsertItem(Item {
            id: id.into(),
            definition: def.into(),
            owner: "party_pack".into(),
            parent: None,
            quantity: 1,
            stack_key: def.into(),
            protected: false,
        })])?;
        if !actor.is_empty() {
            rpg.apply(&[Mutation::Equip {
                actor: actor.into(),
                item: id.into(),
                slots: item_def(def)?.slots.iter().map(|s| (*s).into()).collect(),
            }])?;
            grant_item(&mut rpg, actor, id)?;
        }
    }
    for (id, def, n) in [
        ("dressing-stack-1", "dressing", 2),
        ("scrap-stack-1", "scrap", 6),
    ] {
        rpg.apply(&[Mutation::InsertItem(Item {
            id: id.into(),
            definition: def.into(),
            owner: "party_pack".into(),
            parent: None,
            quantity: n,
            stack_key: def.into(),
            protected: false,
        })])?;
    }
    rpg.apply(&[Mutation::PutResource(Resource {
        id: "party:credits".into(),
        owner: "party".into(),
        unit: "credits".into(),
        minimum: 0,
        maximum: 1_000_000,
        current: 100,
    })])?;
    Ok((state, rpg))
}
pub fn grant_item(rpg: &mut RpgState, actor: &str, item: &str) -> RuleResult {
    let def = item_def(&rpg.items()[item].definition)?;
    for ability in def.grants {
        let id = format!("item:{item}:{ability}");
        if !rpg.grants().contains_key(&id) {
            rpg.apply(&[Mutation::AddGrant(Grant {
                id,
                recipient: actor.into(),
                ability: (*ability).into(),
                source: Source::Item {
                    item: item.into(),
                    equipped: true,
                },
            })])?;
        }
    }
    Ok(())
}
pub fn weapon<'a>(rpg: &'a RpgState, actor: &str) -> Option<&'a Item> {
    rpg.bindings()
        .get(actor)
        .and_then(|s| s.get("main_hand"))
        .and_then(|i| rpg.items().get(i))
}
pub fn defense(state: &CommandState, rpg: &RpgState, id: &str) -> i64 {
    match id {
        "hound" => 13,
        "sentinel" => 16,
        "corsair_raider" => 14,
        _ => {
            let a = &state.actors[id];
            let armor = rpg
                .bindings()
                .get(id)
                .and_then(|s| s.get("body"))
                .and_then(|i| rpg.items().get(i))
                .map(|i| i.definition.as_str())
                .unwrap_or("robe");
            let (bonus, cap) = match armor {
                "light_coat" => (2, 4),
                "heavy_armor" => (6, 1),
                _ => (0, 99),
            };
            let shield = rpg
                .bindings()
                .get(id)
                .and_then(|s| s.get("offhand"))
                .and_then(|i| rpg.items().get(i))
                .is_some_and(|i| i.definition == "buckler");
            10 + bonus + a.attributes["agility"].min(cap) + i64::from(shield)
        }
    }
}
pub fn attack(state: &CommandState, rpg: &RpgState, id: &str) -> i64 {
    if id == "hound" {
        return 4;
    }
    if id == "sentinel" {
        return 5;
    }
    if id == "corsair_raider" {
        return 6;
    }
    let a = &state.actors[id];
    let ranged = weapon(rpg, id).is_some_and(|i| i.definition == "crossbow");
    let bab: i64 = a
        .classes
        .iter()
        .map(|(c, l)| match c.as_str() {
            "arms" | "blade_adept" => i64::from(*l),
            "storm_mystic" => i64::from(*l / 2),
            _ => i64::from(*l * 3 / 4),
        })
        .sum();
    let single = weapon(rpg, id).is_some_and(|i| i.definition == "sabre")
        && a.feats.iter().any(|f| f == "single_blade_i");
    bab + a.attributes[if ranged { "agility" } else { "might" }] + i64::from(single)
}
