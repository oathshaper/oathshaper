//! Authored, bounded narrative journeys through the production evaluator.
//! No direct flag assignment, combat-result injection or claim of physical traversal.
use crate::{continuity, Condition, NarrativeSession, Story, StoryState};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Journeys {
    pub schema: u32,
    pub story_id: String,
    pub journeys: Vec<Journey>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Journey {
    pub id: String,
    pub purpose: String,
    pub steps: Vec<Step>,
    pub expected: Vec<Condition>,
}

#[derive(Deserialize, Serialize, Debug)]
#[serde(tag = "action", rename_all = "snake_case", deny_unknown_fields)]
pub enum Step {
    Enter { node: String },
    Choose { choice: String },
    FinishResponse,
    Leave,
    SaveReload,
}

#[derive(Serialize)]
pub struct Trace {
    pub step: usize,
    pub action: String,
    pub state: StoryState,
    pub error: Option<String>,
    pub findings: Vec<continuity::Finding>,
}

#[derive(Serialize)]
pub struct ResultEntry {
    pub id: String,
    pub purpose: String,
    pub status: String,
    pub trace: Vec<Trace>,
    pub final_expectations_met: bool,
    pub expected: Vec<Condition>,
}

#[derive(Serialize)]
pub struct ReplayReport {
    pub schema: u32,
    pub story_id: String,
    pub scope: String,
    pub status: String,
    pub journeys: Vec<ResultEntry>,
}

pub fn replay(
    story: Story,
    contract: continuity::Contract,
    data: Journeys,
    max_steps: usize,
) -> Result<ReplayReport, String> {
    continuity::validate_contract(&story, &contract)?;
    if data.schema != 1 || data.story_id != story.id || data.journeys.is_empty() {
        return Err(
            "journeys need schema 1, the matching story id and at least one journey".into(),
        );
    }
    let mut ids = BTreeSet::new();
    for journey in &data.journeys {
        if journey.id.is_empty()
            || !ids.insert(&journey.id)
            || journey.purpose.is_empty()
            || journey.steps.is_empty()
            || journey.expected.is_empty()
        {
            return Err(
                "journey requires a unique id, purpose, steps and final expectations".into(),
            );
        }
        story.validate_conditions(&journey.expected)?;
    }
    let mut report = ReplayReport {
        schema: 1, story_id: story.id.clone(),
        scope: "Authored narrative journeys from initial state, with real choices, response returns and save/load. Enter calls are host assumptions; no physical travel, combat result or exhaustive graph coverage.".into(),
        status: "passed".into(), journeys: vec![],
    };
    for journey in data.journeys {
        let mut session = NarrativeSession::new(story.clone())?;
        let mut trace = vec![];
        let mut status = if journey.steps.len() > max_steps {
            "incomplete"
        } else {
            "passed"
        };
        for (index, step) in journey.steps.iter().take(max_steps).enumerate() {
            let result = match step {
                Step::Enter { node } => session.begin_at(node).map(|_| ()),
                Step::Choose { choice } => session.choose(choice).map(|_| ()),
                Step::FinishResponse => session.finish_response().map(|_| ()),
                Step::Leave => {
                    session.end();
                    Ok(())
                }
                Step::SaveReload => {
                    let before = session.state().clone();
                    let view = session.view();
                    let mut restored = NarrativeSession::new(story.clone())?;
                    restored.load_json(&session.save_json()?)?;
                    if restored.state() != &before || restored.view() != view {
                        Err("save/load changed narrative state or displayed menu".into())
                    } else {
                        session = restored;
                        Ok(())
                    }
                }
            };
            let findings: Vec<_> = contract
                .rules
                .iter()
                .flat_map(|rule| continuity::observe(&session, rule))
                .collect();
            let failed =
                result.is_err() || findings.iter().any(|f| f.certainty == "contract_violation");
            trace.push(Trace {
                step: index + 1,
                action: serde_json::to_string(step).unwrap(),
                state: session.state().clone(),
                error: result.err(),
                findings,
            });
            if failed {
                status = "failed";
                break;
            }
        }
        let met = session.matches(&journey.expected);
        if status == "passed" && !met {
            status = "failed";
        }
        if status == "failed" || (status == "incomplete" && report.status != "failed") {
            report.status = status.into();
        }
        report.journeys.push(ResultEntry {
            id: journey.id,
            purpose: journey.purpose,
            status: status.into(),
            trace,
            final_expectations_met: met,
            expected: journey.expected,
        });
    }
    Ok(report)
}

#[cfg(test)]
mod tests {
    use super::*;
    const STORY: &str = include_str!("../../../godot/content/lantern_quay.json");
    const RULES: &str = include_str!("../../../godot/content/lantern_quay.continuity.json");
    const ROUTES: &str = include_str!("../../../godot/content/lantern_quay.journeys.json");
    fn run(story: Story, routes: &str, budget: usize) -> ReplayReport {
        replay(
            story,
            serde_json::from_str(RULES).unwrap(),
            serde_json::from_str(routes).unwrap(),
            budget,
        )
        .unwrap()
    }
    #[test]
    fn three_oil_routes_reach_the_gate_without_injected_flags() {
        let report = run(crate::load_story_json(STORY).unwrap(), ROUTES, 200);
        assert_eq!(report.status, "passed");
        assert_eq!(report.journeys.len(), 3);
        let final_states: Vec<_> = report
            .journeys
            .iter()
            .map(|r| &r.trace.last().unwrap().state)
            .collect();
        assert_eq!(
            final_states.iter().map(|s| s.moral).collect::<Vec<_>>(),
            [2, -1, 0]
        );
        assert!(final_states
            .iter()
            .all(|s| s.flags["gate_open"] && !s.flags["pay_recovered"]));
    }
    #[test]
    fn stale_topic_has_an_action_prefix_and_consistent_oil_facts() {
        let mut story = crate::load_story_json(STORY).unwrap();
        story
            .nodes
            .iter_mut()
            .find(|n| n.id == "mara_greeting")
            .unwrap()
            .choices
            .iter_mut()
            .find(|c| c.id == "ask_lamp")
            .unwrap()
            .hide_when
            .clear();
        let report = run(story, ROUTES, 200);
        let failure = report.journeys[0].trace.last().unwrap();
        assert_eq!(report.status, "failed");
        assert!(failure.state.flags["oil_shared"] && failure.state.flags["oil_decided"]);
        assert!(failure
            .findings
            .iter()
            .any(|f| f.observed.contains("ask_lamp")));
        assert_eq!(failure.step, 3);
    }
    #[test]
    fn bad_action_fails_with_its_index_and_never_completes() {
        let broken = ROUTES.replacen("share_oil", "missing_choice", 1);
        let report = run(crate::load_story_json(STORY).unwrap(), &broken, 200);
        assert_eq!(report.status, "failed");
        assert_eq!(report.journeys[0].trace.last().unwrap().step, 2);
        assert!(report.journeys[0].trace.last().unwrap().error.is_some());
    }
    #[test]
    fn budget_exhaustion_is_incomplete() {
        assert_eq!(
            run(crate::load_story_json(STORY).unwrap(), ROUTES, 1).status,
            "incomplete"
        );
    }
}
