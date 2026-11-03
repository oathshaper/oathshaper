//! Offline continuity checks over the same views the game displays.
//! Boolean witnesses are candidates, not claims of physical reachability.
use crate::{Condition, NarrativeSession, Story};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Contract {
    pub schema: u32,
    pub story_id: String,
    pub rules: Vec<Rule>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Rule {
    pub id: String,
    pub node: String,
    pub reason: String,
    /// OR of AND groups. Only known Boolean flags are supported in v1.
    pub when_any: Vec<Vec<Condition>>,
    #[serde(default)]
    pub absent_choices: Vec<String>,
    #[serde(default)]
    pub enabled_choices: Vec<String>,
    /// Case-insensitive phrase heuristic, evaluated on the actual displayed line.
    #[serde(default)]
    pub forbidden_text: Vec<String>,
}

#[derive(Serialize, Debug)]
pub struct Finding {
    pub rule_id: String,
    pub node: String,
    pub reason: String,
    pub certainty: String,
    pub observed: String,
    pub witness_flags: BTreeMap<String, bool>,
}

#[derive(Serialize, Debug)]
pub struct Report {
    pub schema: u32,
    pub story_id: String,
    pub scope: String,
    pub complete_within_scope: bool,
    pub evaluated_states: usize,
    pub matched_rule_states: usize,
    pub findings: Vec<Finding>,
}

/// Enumerate every Boolean valuation, leaving numeric scores at their defaults.
/// Production rendering/choice logic is reused; there is no second interpreter.
pub fn check(story: Story, contract: Contract, max_states: usize) -> Result<Report, String> {
    validate_contract(&story, &contract)?;
    let total = 1usize
        .checked_shl(story.flags.len() as u32)
        .ok_or("too many flags for Boolean enumeration")?;
    let mut session = NarrativeSession::new(story)?;
    let mut report = Report {
        schema: 1,
        story_id: session.story.id.clone(),
        scope: "Boolean menu-state matrix; initial numeric scores; fresh choice history; no world reachability or render proof".into(),
        complete_within_scope: total <= max_states,
        evaluated_states: total.min(max_states),
        matched_rule_states: 0,
        findings: vec![],
    };
    let mut reported = BTreeSet::new();
    let mut matched = BTreeSet::new();
    for mask in 0..total.min(max_states) {
        for (bit, id) in session.story.flags.iter().enumerate() {
            session
                .state
                .flags
                .insert(id.clone(), mask & (1 << bit) != 0);
        }
        for rule in &contract.rules {
            if !rule.when_any.iter().any(|group| session.matches(group)) {
                continue;
            }
            matched.insert(&rule.id);
            report.matched_rule_states += 1;
            session.begin_at(&rule.node)?;
            for finding in observe(&session, rule) {
                if reported.insert((finding.rule_id.clone(), finding.observed.clone())) {
                    report.findings.push(finding);
                }
            }
        }
    }
    if report.complete_within_scope && matched.len() != contract.rules.len() {
        return Err("one or more continuity rules never matched a state".into());
    }
    Ok(report)
}

pub(crate) fn validate_contract(story: &Story, contract: &Contract) -> Result<(), String> {
    story.validate()?;
    if contract.schema != 1 || contract.story_id != story.id || contract.rules.is_empty() {
        return Err("continuity contract schema, story id or rules are invalid".into());
    }
    let mut ids = BTreeSet::new();
    for rule in &contract.rules {
        if rule.id.is_empty() || !ids.insert(&rule.id) || rule.reason.is_empty() {
            return Err("continuity rule needs a unique id and reason".into());
        }
        let node = story
            .nodes
            .iter()
            .find(|n| n.id == rule.node)
            .ok_or_else(|| format!("{}: unknown node {}", rule.id, rule.node))?;
        if rule.when_any.is_empty() || rule.when_any.iter().any(Vec::is_empty) {
            return Err(format!(
                "{}: explicit, nonempty applicability required",
                rule.id
            ));
        }
        for group in &rule.when_any {
            story.validate_conditions(group)?;
            if group.iter().any(|c| !matches!(c, Condition::Flag { .. })) {
                return Err("v1 contracts support Boolean applicability only".into());
            }
            let mut values = BTreeMap::new();
            for c in group {
                if let Condition::Flag { id, value } = c {
                    if values.insert(id, value).is_some_and(|old| old != value) {
                        return Err(format!("{}: contradictory applicability", rule.id));
                    }
                }
            }
        }
        if rule.absent_choices.is_empty()
            && rule.enabled_choices.is_empty()
            && rule.forbidden_text.is_empty()
        {
            return Err(format!("{}: no observations specified", rule.id));
        }
        for choice in rule.absent_choices.iter().chain(&rule.enabled_choices) {
            if !node.choices.iter().any(|c| &c.id == choice) {
                return Err(format!("{}: unknown choice {}", rule.id, choice));
            }
        }
        if rule.forbidden_text.iter().any(|t| t.trim().is_empty()) {
            return Err(format!("{}: empty text heuristic", rule.id));
        }
    }
    Ok(())
}

/// Inspect an actual displayed menu, preserving the session's history and scores.
pub(crate) fn observe(session: &NarrativeSession, rule: &Rule) -> Vec<Finding> {
    if !session.state.in_dialogue
        || session.state.current != rule.node
        || !rule.when_any.iter().any(|group| session.matches(group))
    {
        return vec![];
    }
    let view = session.view();
    let mut observations = vec![];
    for id in &rule.absent_choices {
        if view.choices.iter().any(|c| &c.id == id) {
            observations.push((
                "contract_violation",
                format!("obsolete choice still visible: {id}"),
            ));
        }
    }
    for id in &rule.enabled_choices {
        if !view.choices.iter().any(|c| &c.id == id && c.enabled) {
            observations.push((
                "contract_violation",
                format!("required reply unavailable: {id}"),
            ));
        }
    }
    for phrase in &rule.forbidden_text {
        if view.text.to_lowercase().contains(&phrase.to_lowercase()) {
            observations.push((
                "heuristic_suspicion",
                format!("possibly stale line: {}", view.text),
            ));
        }
    }
    observations
        .into_iter()
        .map(|(certainty, observed)| Finding {
            rule_id: rule.id.clone(),
            node: rule.node.clone(),
            reason: rule.reason.clone(),
            certainty: certainty.into(),
            observed,
            witness_flags: session.state.flags.clone(),
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    const STORY: &str = include_str!("../../../godot/content/lantern_quay.json");
    const CONTRACT: &str = include_str!("../../../godot/content/lantern_quay.continuity.json");
    fn run(story: Story, limit: usize) -> Report {
        check(story, serde_json::from_str(CONTRACT).unwrap(), limit).unwrap()
    }
    #[test]
    fn current_chapter_meets_authored_applicability() {
        let report = run(crate::load_story_json(STORY).unwrap(), 4096);
        assert!(report.complete_within_scope);
        assert!(report.findings.is_empty(), "{:?}", report.findings);
    }
    #[test]
    fn detects_playtest_dark_tower_regression_and_reports_witness() {
        let mut story = crate::load_story_json(STORY).unwrap();
        let node = story
            .nodes
            .iter_mut()
            .find(|n| n.id == "mara_greeting")
            .unwrap();
        node.choices
            .iter_mut()
            .find(|c| c.id == "ask_lamp")
            .unwrap()
            .hide_when
            .clear();
        node.variants.retain(|v| {
            !v.when.contains(&Condition::Flag {
                id: "oil_shared".into(),
                value: true,
            })
        });
        let report = run(story, 4096);
        assert!(report
            .findings
            .iter()
            .any(|f| f.observed.contains("ask_lamp")));
        assert!(report
            .findings
            .iter()
            .any(|f| f.certainty == "heuristic_suspicion" && f.witness_flags["oil_shared"]));
    }
    #[test]
    fn budget_exhaustion_is_not_a_pass() {
        assert!(!run(crate::load_story_json(STORY).unwrap(), 1).complete_within_scope);
    }
    #[test]
    fn typo_in_contract_fails_instead_of_silently_skipping() {
        let mut contract: Contract = serde_json::from_str(CONTRACT).unwrap();
        contract.rules[0].node = "missing".into();
        assert!(check(crate::load_story_json(STORY).unwrap(), contract, 4096).is_err());
    }
}
