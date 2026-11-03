//! Repetition review over the spoken graph, using the production dialogue evaluator.
//! Conditional starting contexts are logical candidates, not physically reached worlds.
use crate::{Condition, DialogueView, NarrativeSession, Story, StoryState};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet, VecDeque};

#[derive(Deserialize)]
pub struct VoiceScript {
    pub lines: Vec<VoiceLine>,
}
#[derive(Deserialize)]
pub struct VoiceLine {
    pub speaker: String,
    pub lookup_text: String,
    pub spoken_text: String,
    pub sources: Vec<String>,
}
#[derive(Clone, Debug, Serialize)]
pub struct Speech {
    pub source: String,
    pub speaker: String,
    pub text: String,
}
#[derive(Serialize)]
pub struct Finding {
    pub certainty: String,
    pub kind: String,
    pub earlier: Speech,
    pub later: Speech,
    pub repeated_phrase: String,
    pub intervening_lines: usize,
    pub witness_flags: BTreeMap<String, bool>,
    pub path: Vec<String>,
}
#[derive(Serialize)]
pub struct Report {
    pub schema: u32,
    pub story_id: String,
    pub complete_within_scope: bool,
    pub scope: String,
    pub explored_states: usize,
    pub conditional_entries: usize,
    pub transitions: usize,
    pub sequence_groups: usize,
    pub frontier_remaining: usize,
    pub budget_omissions: usize,
    pub findings: Vec<Finding>,
    pub limitations: Vec<String>,
}
struct Work {
    state: StoryState,
    heard: Vec<(Speech, usize)>,
    spoken_count: usize,
    path: Vec<String>,
    witness: BTreeMap<String, bool>,
}

fn words(text: &str) -> Vec<String> {
    text.to_lowercase()
        .split(|c: char| !c.is_alphanumeric() && c != '\'' && c != '’')
        .filter(|w| !w.is_empty())
        .map(|w| w.replace('’', "'"))
        .collect()
}
fn substantive(word: &str) -> bool {
    ![
        "a", "an", "the", "of", "to", "and", "or", "but", "i", "i'll", "you", "your", "we", "he",
        "she", "it", "its", "it's", "that", "that's", "this", "is", "was", "are", "be", "been",
        "have", "has", "had", "in", "on", "at", "for", "with", "me", "my", "our",
    ]
    .contains(&word)
}

/// Longest shared phrase. Routine short acknowledgements are not findings.
fn repetition(a: &str, b: &str) -> Option<(String, String)> {
    let a = words(a);
    let b = words(b);
    let mut best = vec![];
    for i in 0..a.len() {
        for j in 0..b.len() {
            let size = a[i..]
                .iter()
                .zip(&b[j..])
                .take_while(|(x, y)| x == y)
                .count();
            if size > best.len() {
                best = a[i..i + size].to_vec();
            }
        }
    }
    if best.len() >= 3 && best.iter().filter(|w| substantive(w)).count() >= 2 {
        Some((
            if a == b {
                "repeated_line"
            } else {
                "phrase_echo"
            }
            .into(),
            best.join(" "),
        ))
    } else {
        None
    }
}

fn observe(report: &mut Report, seen: &mut BTreeSet<String>, work: &mut Work, next: Speech) {
    for (earlier, spoken_at) in &work.heard {
        // Re-selecting an explicitly repeatable topic is an intentional replay.
        if earlier.source == next.source && earlier.text == next.text {
            continue;
        }
        if let Some((kind, phrase)) = repetition(&earlier.text, &next.text) {
            let identity = format!(
                "{}\n{}\n{}\n{}\n{}",
                earlier.source, earlier.text, next.source, next.text, phrase
            );
            if seen.insert(identity) {
                report.findings.push(Finding {
                    certainty: "heuristic_suspicion".into(),
                    kind,
                    earlier: earlier.clone(),
                    later: next.clone(),
                    repeated_phrase: phrase,
                    intervening_lines: work.spoken_count - spoken_at - 1,
                    witness_flags: work.witness.clone(),
                    path: work.path.clone(),
                });
            }
        }
    }
    if !work
        .heard
        .iter()
        .any(|(s, _)| s.source == next.source && s.text == next.text)
    {
        work.heard.push((next, work.spoken_count));
    }
    work.spoken_count += 1;
}

fn spoken(view: &DialogueView, voices: &VoiceScript) -> Speech {
    let line = voices
        .lines
        .iter()
        .find(|l| l.speaker == view.speaker && l.lookup_text == view.text);
    Speech {
        source: format!("node:{}", view.node_id),
        speaker: view.speaker.clone(),
        text: line.map_or_else(|| view.text.clone(), |l| l.spoken_text.clone()),
    }
}

/// Find every flag read by this connected conversation, including return menus.
fn dependencies(story: &Story, entry: &str) -> (Vec<String>, bool) {
    let mut nodes = vec![entry.to_string()];
    let mut seen = BTreeSet::new();
    let mut flags = BTreeSet::new();
    let mut numeric = false;
    while let Some(id) = nodes.pop() {
        if !seen.insert(id.clone()) {
            continue;
        }
        let n = story.node(&id);
        let mut conditions: Vec<&Condition> = n.variants.iter().flat_map(|v| &v.when).collect();
        if let Some(target) = &n.return_to {
            nodes.push(target.clone());
        }
        for c in &n.choices {
            if c.next != crate::EXIT_TARGET {
                nodes.push(c.next.clone());
            }
            conditions.extend(&c.when);
            conditions.extend(c.hide_when.iter().flatten());
            conditions.extend(c.disable_when.iter().flat_map(|d| &d.when));
        }
        for c in conditions {
            match c {
                Condition::Flag { id, .. } => {
                    flags.insert(id.clone());
                }
                _ => numeric = true,
            }
        }
    }
    (flags.into_iter().collect(), numeric)
}

fn enqueue(
    queue: &mut VecDeque<Work>,
    visited: &mut BTreeSet<String>,
    work: Work,
    budget: usize,
) -> bool {
    // History matters: two paths reaching one node can expose different choices.
    // A set of every heard utterance preserves distant echoes without enumerating
    // every equivalent ordering. Counts and order only describe the retained witness.
    let key = serde_json::to_string(&(
        &work.state,
        work.heard
            .iter()
            .map(|(s, _)| (&s.source, &s.speaker, &s.text))
            .collect::<BTreeSet<_>>(),
    ))
    .unwrap();
    if visited.contains(&key) {
        return true;
    }
    if visited.len() >= budget {
        return false;
    }
    visited.insert(key);
    queue.push_back(work);
    true
}

pub fn check(story: Story, voices: VoiceScript, max_states: usize) -> Result<Report, String> {
    story.validate()?;
    let mut session = NarrativeSession::new(story.clone())?;
    let initial = session.state.clone();
    let mut report = Report { schema: 1, story_id: story.id.clone(), complete_within_scope: true,
        scope: "All enabled dialogue branches in Boolean entry contexts; production effects, variants and choice history; repetition against every earlier spoken line on a path. Equivalent state/history/heard-utterance sets merge; silent response-menu returns add no speech.".into(),
        explored_states: 0, conditional_entries: 0, transitions: 0, sequence_groups: 0,
        frontier_remaining: 0, budget_omissions: 0, findings: vec![], limitations: vec![
            "Entry contexts are logical candidates, including impossible world states; witness flags are assumptions, not physical reachability proof.".into(),
            "Numeric scores start at authored defaults. Numeric-gated conversations mark the report incomplete.".into(),
            "Phrase matches are review warnings, not semantic equivalence or automatic rewrite decisions. Short acknowledgements and intentional replays of the same authored line are excluded.".into(),
            "Coverage is within conversations and authored cutscene sequences, not arbitrary ordering of separate world interactions. All earlier lines within each conversation or sequence are compared.".into(),
        ] };
    let mut queue = VecDeque::new();
    let mut visited = BTreeSet::new();
    let mut found = BTreeSet::new();
    for node in story
        .nodes
        .iter()
        .filter(|n| !n.choices.is_empty() || n.id == story.start)
    {
        let (flags, numeric) = dependencies(&story, &node.id);
        if numeric {
            report.complete_within_scope = false;
        }
        let contexts = 1usize.checked_shl(flags.len() as u32).unwrap_or(usize::MAX);
        if contexts > max_states.saturating_sub(report.conditional_entries) {
            report.complete_within_scope = false;
            report
                .limitations
                .push(format!("Entry budget exceeded at {}", node.id));
            break;
        }
        for mask in 0..contexts {
            session.state = initial.clone();
            for (bit, flag) in flags.iter().enumerate() {
                session
                    .state
                    .flags
                    .insert(flag.clone(), mask & (1 << bit) != 0);
            }
            let view = session.begin_at(&node.id)?;
            report.conditional_entries += 1;
            let mut work = Work {
                state: session.state.clone(),
                heard: vec![],
                spoken_count: 0,
                path: vec![format!("enter:{}", node.id)],
                witness: session.state.flags.clone(),
            };
            observe(&mut report, &mut found, &mut work, spoken(&view, &voices));
            if !enqueue(&mut queue, &mut visited, work, max_states) {
                report.budget_omissions += 1;
            }
        }
    }
    while report.explored_states < max_states {
        let Some(work) = queue.pop_front() else {
            break;
        };
        report.explored_states += 1;
        session.state = work.state.clone();
        let view = session.view();
        if !view.in_dialogue {
            continue;
        }
        if view.return_to.is_some() {
            session.finish_response()?;
            let mut path = work.path;
            path.push("finish_response:silent".into());
            if !enqueue(
                &mut queue,
                &mut visited,
                Work {
                    state: session.state.clone(),
                    path,
                    ..work
                },
                max_states,
            ) {
                report.budget_omissions += 1;
            }
            continue;
        }
        for choice in view.choices.iter().filter(|c| c.enabled) {
            session.state = work.state.clone();
            let next_view = match session.choose(&choice.id) {
                Ok(view) => view,
                Err(error) => {
                    report.complete_within_scope = false;
                    let note = format!(
                        "Enabled transition {}/{} could not be evaluated: {error}",
                        view.node_id, choice.id
                    );
                    if !report.limitations.contains(&note) {
                        report.limitations.push(note);
                    }
                    continue;
                }
            };
            report.transitions += 1;
            let source = format!("choice:{}/{}", view.node_id, choice.id);
            let mut next = Work {
                state: session.state.clone(),
                heard: work.heard.clone(),
                spoken_count: work.spoken_count,
                path: work.path.clone(),
                witness: work.witness.clone(),
            };
            next.path.push(source.clone());
            if let Some(line) = voices.lines.iter().find(|l| l.sources.contains(&source)) {
                observe(
                    &mut report,
                    &mut found,
                    &mut next,
                    Speech {
                        source,
                        speaker: line.speaker.clone(),
                        text: line.spoken_text.clone(),
                    },
                );
            }
            if next_view.in_dialogue {
                observe(
                    &mut report,
                    &mut found,
                    &mut next,
                    spoken(&next_view, &voices),
                );
                if !enqueue(&mut queue, &mut visited, next, max_states) {
                    report.budget_omissions += 1;
                }
            }
        }
    }
    report.frontier_remaining = queue.len();
    if !queue.is_empty() || report.budget_omissions > 0 {
        report.complete_within_scope = false;
    }
    let mut sequences: BTreeMap<String, BTreeMap<usize, Speech>> = BTreeMap::new();
    for line in &voices.lines {
        for source in &line.sources {
            if source.starts_with("chapter:") {
                if let Some((group, index)) = source.rsplit_once(':') {
                    if let Ok(index) = index.parse() {
                        sequences.entry(group.into()).or_default().insert(
                            index,
                            Speech {
                                source: source.clone(),
                                speaker: line.speaker.clone(),
                                text: line.spoken_text.clone(),
                            },
                        );
                    }
                }
            }
        }
    }
    report.sequence_groups = sequences.len();
    for (group, lines) in sequences {
        let mut work = Work {
            state: initial.clone(),
            heard: vec![],
            spoken_count: 0,
            path: vec![group],
            witness: BTreeMap::new(),
        };
        for (index, speech) in lines {
            work.path.push(format!("line:{index}"));
            observe(&mut report, &mut found, &mut work, speech);
        }
    }
    Ok(report)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    fn branch_story(flip: bool) -> Story {
        serde_json::from_value(json!({
            "schema":1,"id":"script-fixture","revision":1,"start":"menu",
            "moral":{"id":"mercy","label":"Mercy","min":-5,"max":5,"initial":0},
            "flags":["changed"],"companions":[],"nodes":[
              {"id":"menu","speaker":"Mara","text":"What would you like to know?","choices":[
                {"id":"a","text":"First topic","next":"a","when":[{"kind":"flag","id":"changed","value":false}],"effects":if flip {json!([{"kind":"set_flag","id":"changed","value":true}])}else{json!([])}},
                {"id":"b","text":"Second topic","next":"b","when":[{"kind":"flag","id":"changed","value":true}]}
              ]},
              {"id":"a","speaker":"Mara","text":"He nearly took my head off.","return_to":"menu"},
              {"id":"b","speaker":"Ivo","text":"That guard nearly took my head off.","return_to":"menu"}
            ]
        })).unwrap()
    }
    #[test]
    fn incompatible_branches_are_not_compared_as_one_conversation() {
        let report = check(branch_story(false), VoiceScript { lines: vec![] }, 1000).unwrap();
        assert!(report.complete_within_scope);
        assert!(report.findings.is_empty());
    }
    #[test]
    fn effects_return_menus_and_history_produce_a_reproducible_echo() {
        let report = check(branch_story(true), VoiceScript { lines: vec![] }, 1000).unwrap();
        assert!(report.complete_within_scope);
        let echo = report
            .findings
            .iter()
            .find(|f| f.earlier.source == "node:a" && f.later.source == "node:b")
            .unwrap();
        assert_eq!(
            echo.path,
            [
                "enter:menu",
                "choice:menu/a",
                "finish_response:silent",
                "choice:menu/b"
            ]
        );
        assert!(!echo.witness_flags["changed"]);
    }
    #[test]
    fn actual_player_speech_is_compared_instead_of_menu_label() {
        let mut story = branch_story(false);
        story.nodes[1].text = "Ah, the knurled beets, of course!".into();
        let voices = VoiceScript {
            lines: vec![VoiceLine {
                speaker: "Tessa Ward".into(),
                lookup_text: "First topic".into(),
                spoken_text: "I'll deliver the knurled beets.".into(),
                sources: vec!["choice:menu/a".into()],
            }],
        };
        let report = check(story, voices, 1000).unwrap();
        assert!(report.findings.iter().any(
            |f| f.earlier.source == "choice:menu/a" && f.repeated_phrase == "the knurled beets"
        ));
    }
    #[test]
    fn repeats_are_found_across_a_long_conversation_path() {
        let mut story = branch_story(true);
        story.nodes[1].return_to = None;
        story.nodes[1].choices = story.nodes[0].choices.clone();
        story.nodes[1].choices.retain(|c| c.id == "b");
        story.nodes[1].choices[0].next = "filler0".into();
        for i in 0..5 {
            let mut filler = story.nodes[1].clone();
            filler.id = format!("filler{i}");
            filler.text = format!("Detail {i}.");
            filler.choices[0].next = if i == 4 {
                "b".into()
            } else {
                format!("filler{}", i + 1)
            };
            story.nodes.push(filler);
        }
        let report = check(story, VoiceScript { lines: vec![] }, 10_000).unwrap();
        assert!(report.complete_within_scope);
        assert!(report.findings.iter().any(|f| f.earlier.source == "node:a"
            && f.later.source == "node:b"
            && f.intervening_lines >= 5));
    }
    #[test]
    fn repeatable_loops_merge_and_numeric_gates_do_not_claim_coverage() {
        let mut story = branch_story(false);
        story.nodes[0].choices[0].repeatable = true;
        let report = check(story.clone(), VoiceScript { lines: vec![] }, 1000).unwrap();
        assert!(report.complete_within_scope && report.explored_states < 1000);
        story.nodes[0].choices[0]
            .when
            .push(Condition::MoralAtLeast { value: 2 });
        assert!(
            !check(story, VoiceScript { lines: vec![] }, 1000)
                .unwrap()
                .complete_within_scope
        );
    }
    #[test]
    fn echo_heuristic_ignores_short_acknowledgement_and_catches_example() {
        assert!(repetition(
            "I'll deliver the knurled beets.",
            "Ah, the knurled beets, of course!"
        )
        .is_some());
        assert!(repetition("Thank you.", "Thank you.").is_none());
        assert!(repetition(
            "Here. This should get the tower burning again.",
            "That's enough to get the tower burning again."
        )
        .is_some());
    }
    #[test]
    fn budget_exhaustion_is_never_complete() {
        let story =
            crate::load_story_json(include_str!("../../../godot/content/lantern_quay.json"))
                .unwrap();
        let report = check(story, VoiceScript { lines: vec![] }, 1).unwrap();
        assert!(!report.complete_within_scope);
    }
}
