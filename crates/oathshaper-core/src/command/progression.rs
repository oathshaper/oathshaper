use super::*;
use crate::rpg::{Investment, Mutation};
use content::*;
const ATTRIBUTES: [&str; 6] = [
    "might",
    "agility",
    "body",
    "intellect",
    "spirit",
    "presence",
];
pub fn max_health(a: &ActorState) -> i64 {
    20 + a
        .classes
        .iter()
        .map(|(c, l)| class(c).map(|v| v.0 * i64::from(*l)).unwrap_or(0))
        .sum::<i64>()
        + i64::from(a.level) * a.attributes["body"]
}
pub fn native_focus(a: &ActorState) -> i64 {
    let path = a
        .classes
        .iter()
        .find(|(c, _)| ["blade_adept", "storm_mystic", "investigator"].contains(&c.as_str()));
    path.map(|(c, l)| 20 + 2 * a.attributes["spirit"] + class(c).unwrap().2 * i64::from(*l))
        .unwrap_or(0)
}
fn class(id: &str) -> RuleResult<(i64, u32, i64)> {
    match id {
        "arms" => Ok((8, 2, 0)),
        "scout" => Ok((6, 4, 0)),
        "infiltrator" => Ok((5, 6, 0)),
        "blade_adept" => Ok((7, 2, 6)),
        "storm_mystic" => Ok((4, 3, 10)),
        "investigator" => Ok((6, 5, 7)),
        _ => Err(err("class", "Unknown development discipline")),
    }
}
pub fn gear_legal(a: &ActorState, definition: &str) -> bool {
    match definition {
        "heavy_armor" => a.feats.iter().any(|f| f == "heavy_training"),
        "buckler" | "mace" => {
            a.classes.contains_key("arms") || a.feats.iter().any(|f| f == "shield_training")
        }
        "sabre" => {
            a.classes.contains_key("arms")
                || a.classes.contains_key("scout")
                || a.feats.iter().any(|f| f == "blade_training")
        }
        "crossbow" => {
            a.classes.contains_key("arms")
                || a.classes.contains_key("scout")
                || a.feats.iter().any(|f| f == "bow_training")
        }
        _ => true,
    }
}
fn feat_legal(a: &ActorState, feat: &str) -> bool {
    let has = |id: &str| a.feats.iter().any(|f| f == id);
    match feat {
        "single_blade_i" | "dual_training_i" | "guard_i" | "marksmanship_i" | "field_medic_i"
        | "medium_training" | "shield_training" | "blade_training" | "bow_training" => true,
        "heavy_training" => {
            a.level >= 4 && (has("medium_training") || a.classes.contains_key("arms"))
        }
        "single_blade_ii" => a.level >= 7 && has("single_blade_i"),
        "single_blade_iii" => a.level >= 13 && has("single_blade_ii"),
        "marksmanship_ii" => a.level >= 7 && has("marksmanship_i"),
        "guard_ii" => a.level >= 7 && has("guard_i"),
        "dual_training_ii" => a.level >= 7 && has("dual_training_i"),
        "field_medic_ii" => a.level >= 7 && has("field_medic_i"),
        "breaker_i" => a.level >= 4,
        "breaker_ii" => a.level >= 10 && has("breaker_i"),
        _ => false,
    }
}
#[allow(clippy::too_many_arguments)]
pub fn respec(
    s: &mut CommandState,
    r: &mut RpgState,
    actor: &str,
    version: &str,
    base: &[BaseAttribute],
    levels: &[LevelAllocation],
    unbind: &[String],
) -> RuleResult {
    rules::camp(s)?;
    let original = s
        .actors
        .get(actor)
        .ok_or_else(|| err("actor", "Unknown actor"))?
        .clone();
    if original.build_version.to_string() != version
        || !rules::living(s, r, actor)
        || levels.len() != original.level as usize
    {
        return Err(err("build", "Stale or incomplete respec"));
    }
    let attrs: BTreeMap<_, _> = base.iter().map(|a| (a.id.clone(), a.value)).collect();
    let mut values: Vec<_> = attrs.values().copied().collect();
    values.sort();
    if attrs.len() != 6
        || base.len() != 6
        || ATTRIBUTES.iter().any(|id| !attrs.contains_key(*id))
        || values != [0, 0, 1, 2, 2, 3]
    {
        return Err(err(
            "attributes",
            "Assign the six base modifiers 3,2,2,1,0,0 exactly once",
        ));
    }
    let mut built = original.clone();
    built.level = 0;
    built.classes.clear();
    built.skills.clear();
    built.feats.clear();
    built.attributes = attrs;
    built.unspent = 0;
    let mut feat_bank = 0;
    let mut power_bank = 0;
    let mut attribute_bank = 0;
    let mut purchases = vec![];
    let mut powers = BTreeSet::new();
    let mut starting = None;
    let mut path = None;
    for (index, allocation) in levels.iter().enumerate() {
        let total = index as u32 + 1;
        let (_, skills_per_level, _) = class(&allocation.class_id)?;
        let awakened =
            ["blade_adept", "storm_mystic", "investigator"].contains(&allocation.class_id.as_str());
        if total == 1 {
            if awakened {
                return Err(err("class", "First discipline must be mundane"));
            }
            starting = Some(allocation.class_id.clone());
        }
        if awakened {
            if total < 4 || path.as_ref().is_some_and(|id| id != &allocation.class_id) {
                return Err(err(
                    "class",
                    "Awaken at level four and choose at most one path",
                ));
            }
            path = Some(allocation.class_id.clone());
        } else if starting.as_ref() != Some(&allocation.class_id) {
            return Err(err("class", "Only one starting discipline is permitted"));
        }
        built.level = total;
        let class_level = built
            .classes
            .entry(allocation.class_id.clone())
            .or_default();
        *class_level += 1;
        let class_level = *class_level;
        built.unspent += skills_per_level + built.attributes["intellect"].max(0) as u32;
        if total % 3 == 1 {
            feat_bank += 1;
        }
        if allocation.class_id == "arms" && class_level % 2 == 1 {
            feat_bank += 1;
        }
        if path.is_none() && [8, 12, 16, 20].contains(&total) {
            feat_bank += 1;
        }
        if total.is_multiple_of(5) {
            attribute_bank += 1;
        }
        power_bank += match allocation.class_id.as_str() {
            "storm_mystic" => {
                if class_level == 1 {
                    2
                } else {
                    1 + u32::from(class_level % 3 == 0)
                }
            }
            "blade_adept" => u32::from(class_level % 2 == 1),
            "investigator" => 1,
            _ => 0,
        };
        let mut skill_ids = BTreeSet::new();
        for choice in &allocation.skills {
            if ![
                "devices",
                "medicine",
                "lore",
                "insight",
                "stealth",
                "survival",
                "athletics",
                "diplomacy",
            ]
            .contains(&choice.id.as_str())
                || choice.ranks == 0
                || choice.ranks > built.unspent
                || !skill_ids.insert(choice.id.clone())
            {
                return Err(err("skill", "Invalid serial skill purchase"));
            }
            let rank = built.skills.entry(choice.id.clone()).or_default();
            *rank += choice.ranks;
            if *rank > total + 2 {
                return Err(err("skill", "Skill rank exceeds acquisition-level cap"));
            }
            built.unspent -= choice.ranks;
            purchases.push((
                format!("skill:{}", choice.id),
                total,
                i64::from(choice.ranks),
            ));
        }
        for feat in &allocation.feats {
            if feat_bank == 0 || built.feats.contains(feat) || !feat_legal(&built, feat) {
                return Err(err(
                    "feat",
                    "Feat prerequisite or award unavailable at acquisition",
                ));
            }
            feat_bank -= 1;
            built.feats.push(feat.clone());
            purchases.push((format!("feat:{feat}"), total, 1));
        }
        for choice in &allocation.powers {
            if power_bank == 0
                || choice.rank != 1
                || !ability(&choice.id)?.magic
                || !match path.as_deref() {
                    Some("storm_mystic") => true,
                    Some("blade_adept") => ["mend", "gust"].contains(&choice.id.as_str()),
                    Some("investigator") => {
                        ["gust", "binding_current", "mend"].contains(&choice.id.as_str())
                    }
                    _ => false,
                }
                || !powers.insert(choice.id.clone())
            {
                return Err(err("power", "Power award, rank or uniqueness is invalid"));
            }
            power_bank -= 1;
            purchases.push((format!("power:{}", choice.id), total, 1));
        }
        for choice in &allocation.attributes {
            if attribute_bank == 0
                || choice.amount != 1
                || !ATTRIBUTES.contains(&choice.id.as_str())
            {
                return Err(err("attributes", "Attribute increase unavailable"));
            }
            attribute_bank -= 1;
            *built.attributes.get_mut(&choice.id).unwrap() += 1;
        }
    }
    let bound = r.bindings().get(actor).cloned().unwrap_or_default();
    let to_unbind: BTreeSet<_> = unbind.iter().cloned().collect();
    if to_unbind.len() != unbind.len()
        || to_unbind.iter().any(|id| !bound.values().any(|i| i == id))
    {
        return Err(err(
            "binding",
            "Unbind plan names an unbound or duplicate instance",
        ));
    }
    if bound
        .values()
        .any(|i| !to_unbind.contains(i) && !gear_legal(&built, &r.items()[i].definition))
    {
        return Err(err(
            "training",
            "Return incompatible gear to pack or buy its training",
        ));
    }
    let old: Vec<_> = r
        .investments()
        .values()
        .filter(|i| i.actor == actor)
        .cloned()
        .collect();
    let mut changes = vec![Mutation::AdjustResource {
        id: "party:credits".into(),
        delta: -s.respec_cost,
    }];
    for investment in old {
        changes.push(Mutation::RevokeSource(Source::Investment {
            investment: investment.id.clone(),
        }));
        changes.push(Mutation::RemoveInvestment { id: investment.id });
    }
    changes.push(Mutation::Unequip {
        actor: actor.into(),
        slots: bound
            .iter()
            .filter(|(_, i)| to_unbind.contains(*i))
            .map(|(slot, _)| slot.clone())
            .collect(),
    });
    for (index, (definition, level, amount)) in purchases.into_iter().enumerate() {
        let id = format!("build:{actor}:{}:{index}", built.build_version + 1);
        changes.push(Mutation::AddInvestment(Investment {
            id: id.clone(),
            actor: actor.into(),
            definition: definition.clone(),
            awarded_at: level,
            currency: "allocation".into(),
            amount,
            prerequisites: BTreeSet::new(),
        }));
        if let Some(power) = definition.strip_prefix("power:") {
            changes.push(Mutation::AddGrant(Grant {
                id: source_id(actor, power),
                recipient: actor.into(),
                ability: power.into(),
                source: Source::Investment { investment: id },
            }));
        }
    }
    if !r
        .grants()
        .get(&source_id(actor, "basic"))
        .is_some_and(|g| matches!(g.source, Source::Innate { .. }))
    {
        changes.push(Mutation::AddGrant(Grant {
            id: source_id(actor, "basic"),
            recipient: actor.into(),
            ability: "basic".into(),
            source: Source::Innate {
                id: format!("unarmed:{actor}"),
            },
        }));
    }
    let removed = r.apply(&changes)?;
    for grant in removed.revoked_grants {
        s.lost_grants.insert(grant.id.clone(), grant);
    }
    built.unspent_feats = feat_bank;
    built.unspent_powers = power_bank;
    built.unspent_attributes = attribute_bank;
    built.build_version += 1;
    built.binding_version += 1;
    s.actors.insert(actor.into(), built);
    recompute(s, r, actor)?;
    Ok(())
}
pub fn recompute(s: &mut CommandState, r: &mut RpgState, actor: &str) -> RuleResult {
    let a = &s.actors[actor];
    let health = max_health(a);
    let mut focus = native_focus(a);
    let mut battery = 0;
    if let Some(bindings) = r.bindings().get(actor) {
        let items: BTreeSet<_> = bindings.values().collect();
        for item in items {
            match r.items()[item].definition.as_str() {
                "storm_lens" => focus += 30,
                "survey_tool" => battery = 3,
                _ => {}
            }
        }
    }
    rules::capacity(s, r, &resource_id(actor, "health"), health)?;
    rules::capacity(s, r, &resource_id(actor, "focus"), focus)?;
    rules::capacity(s, r, &resource_id(actor, "battery"), battery)?;
    Ok(())
}

/// Mandatory removal is one profile transaction: release incompatible whole
/// orders, recompute capacity with persistent debt, then re-admit surviving
/// resource claims in original admission order (not the player's queue order).
pub fn revoke_item(s: &mut CommandState, r: &mut RpgState, item: &str) -> RuleResult {
    let owned = r
        .items()
        .get(item)
        .ok_or_else(|| err("item", "Source instance is absent"))?
        .clone();
    let actors: Vec<_> = r
        .bindings()
        .iter()
        .filter(|(_, b)| b.values().any(|id| id == item))
        .map(|(id, _)| id.clone())
        .collect();
    let source_ids: BTreeSet<_> = r
        .grants()
        .values()
        .filter(|g| matches!(&g.source,Source::Item{item:id,..}if id==item))
        .map(|g| g.id.clone())
        .collect();
    let mut canceled = vec![];
    for a in s.actors.values_mut() {
        let lost: Vec<_> = a
            .queue
            .iter()
            .filter(|q| source_ids.contains(&q.source))
            .map(|q| q.id.clone())
            .collect();
        a.queue.retain(|q| !source_ids.contains(&q.source));
        canceled.extend(lost);
        if a.active
            .as_ref()
            .is_some_and(|q| source_ids.contains(&q.source))
        {
            canceled.push(a.active.take().unwrap().id);
        }
    }
    for id in &canceled {
        rules::release(r, id)?;
    }
    let mut held = vec![];
    for actor in &actors {
        let claims:Vec<_>=r.claims().values().filter(|c|matches!(&c.target,ClaimTarget::Resource{resource,..}if resource==&resource_id(actor,"focus")||resource==&resource_id(actor,"battery"))).cloned().collect();
        for claim in claims {
            r.apply(&[Mutation::ReleaseClaim {
                id: claim.id.clone(),
            }])?;
            held.push(claim);
        }
    }
    let mut changes = vec![];
    for actor in &actors {
        let slots = r.bindings()[actor]
            .iter()
            .filter(|(_, id)| *id == item)
            .map(|(slot, _)| slot.clone())
            .collect();
        changes.push(Mutation::Unequip {
            actor: actor.clone(),
            slots,
        });
    }
    changes.push(Mutation::ConsumeItem {
        item: item.into(),
        quantity: owned.quantity,
    });
    let removed = r.apply(&changes)?;
    for grant in removed.revoked_grants {
        s.lost_grants.insert(grant.id.clone(), grant);
    }
    s.upgrades.remove(item);
    for actor in &actors {
        s.actors.get_mut(actor).unwrap().binding_version += 1;
        recompute(s, r, actor)?;
    }
    held.sort_by_key(|claim| {
        s.actors
            .values()
            .flat_map(|a| a.queue.iter().chain(a.active.iter()))
            .find(|a| a.id == claim.action)
            .map(|a| a.sequence)
            .unwrap_or(u64::MAX)
    });
    for claim in held {
        if canceled.contains(&claim.action) {
            continue;
        }
        if r.apply(&[Mutation::Reserve(claim.clone())]).is_err() {
            let id = claim.action.clone();
            rules::release(r, &id)?;
            for a in s.actors.values_mut() {
                a.queue.retain(|a| a.id != id);
                if a.active.as_ref().is_some_and(|a| a.id == id) {
                    a.active = None;
                }
            }
            canceled.push(id);
        }
    }
    if !canceled.is_empty() {
        rules::pause(s, "action_failed", "source-loss", true);
        rules::log(
            s,
            "source_loss",
            None,
            None,
            format!(
                "Source removed; canceled {} whole orders, retained paid debt and recovery",
                canceled.len()
            ),
        );
    }
    Ok(())
}

/// Visible, complete serial plans. The HUD forwards these plans unchanged and
/// can show every acquisition before confirmation; no renderer-side allocation.
pub fn presets(
    s: &CommandState,
    r: &RpgState,
    actor: &str,
) -> Vec<(String, String, CommandIntent)> {
    let a = &s.actors[actor];
    let mut result = vec![];
    for (id, name, start, path, base, raise) in [
        (
            "arms",
            "Arms specialist",
            "arms",
            None,
            [3, 2, 2, 0, 1, 0],
            "intellect",
        ),
        (
            "scout",
            "Adaptable Scout",
            "scout",
            None,
            [0, 3, 1, 2, 0, 2],
            "spirit",
        ),
        (
            "infiltrator",
            "Skill-heavy Infiltrator",
            "infiltrator",
            None,
            [0, 3, 1, 2, 0, 2],
            "spirit",
        ),
        (
            "blade_adept",
            "Blade adept",
            "arms",
            Some("blade_adept"),
            [3, 2, 2, 0, 1, 0],
            "intellect",
        ),
        (
            "storm_mystic",
            "Storm mystic",
            "scout",
            Some("storm_mystic"),
            [0, 2, 0, 2, 3, 1],
            "presence",
        ),
        (
            "investigator",
            "Investigator",
            "infiltrator",
            Some("investigator"),
            [0, 2, 1, 3, 2, 0],
            "presence",
        ),
    ] {
        let mut levels = vec![];
        let mut powers = 0;
        let mut ranks = 0;
        for level in 1..=a.level {
            let class = if level >= 4 {
                path.unwrap_or(start)
            } else {
                start
            };
            let path_level = level.saturating_sub(3);
            let power_awards = match class {
                "storm_mystic" => {
                    if path_level == 1 {
                        2
                    } else {
                        1 + u32::from(path_level % 3 == 0)
                    }
                }
                "blade_adept" => u32::from(path_level % 2 == 1),
                "investigator" => 1,
                _ => 0,
            };
            let selected: &[&str] = match path {
                Some("blade_adept") => &["gust", "mend"],
                Some("investigator") => &["binding_current", "gust", "mend"],
                _ => &["binding_current", "gale_arc", "mend", "veil", "gust"],
            };
            let mut learned = vec![];
            for _ in 0..power_awards {
                if powers < selected.len() {
                    learned.push(PowerChoice {
                        id: selected[powers].into(),
                        rank: 1,
                    });
                    powers += 1;
                }
            }
            let skill = if path == Some("storm_mystic") {
                "medicine"
            } else {
                "devices"
            };
            let add = (level + 2 - ranks).min(2);
            ranks += add;
            levels.push(LevelAllocation {
                class_id: class.into(),
                skills: vec![RankChoice {
                    id: skill.into(),
                    ranks: add,
                }],
                feats: if level == 1 {
                    vec![if start == "arms" {
                        "single_blade_i"
                    } else {
                        "marksmanship_i"
                    }
                    .into()]
                } else {
                    vec![]
                },
                powers: learned,
                attributes: if level % 5 == 0 {
                    vec![AttributeChoice {
                        id: raise.into(),
                        amount: 1,
                    }]
                } else {
                    vec![]
                },
            });
        }
        let mut preview = a.clone();
        preview.classes.clear();
        for l in &levels {
            *preview.classes.entry(l.class_id.clone()).or_default() += 1;
        }
        preview.feats = levels.iter().flat_map(|l| l.feats.clone()).collect();
        let unbind = r
            .bindings()
            .get(actor)
            .into_iter()
            .flat_map(|b| b.values())
            .filter(|id| !gear_legal(&preview, &r.items()[*id].definition))
            .cloned()
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect();
        result.push((
            id.into(),
            name.into(),
            CommandIntent::Respec {
                actor_id: actor.into(),
                expected_build_version: a.build_version.to_string(),
                initial_attributes: ATTRIBUTES
                    .into_iter()
                    .zip(base)
                    .map(|(id, value)| BaseAttribute {
                        id: id.into(),
                        value,
                    })
                    .collect(),
                levels,
                unbind_item_ids: unbind,
            },
        ));
    }
    result
}
