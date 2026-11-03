//! Deterministic, engine-independent dialogue state for Oathshaper.
pub mod command;
pub mod continuity;
pub mod continuity_replay;
pub mod dialogue_script;
pub mod flow;
pub mod rpg;
pub mod runtime;
pub mod vanguard;

use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

pub const STORY_SCHEMA: u32 = 1;
pub const SAVE_SCHEMA: u32 = 1;
/// An authored terminal target. Choosing it commits effects, then ends dialogue.
pub const EXIT_TARGET: &str = "$exit";

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct Story {
    pub schema: u32,
    pub id: String,
    pub revision: u32,
    pub start: String,
    pub moral: Moral,
    pub flags: Vec<String>,
    pub companions: Vec<String>,
    pub nodes: Vec<Node>,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct Moral {
    pub id: String,
    pub label: String,
    pub min: i32,
    pub max: i32,
    pub initial: i32,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct Node {
    pub id: String,
    pub speaker: String,
    pub text: String,
    #[serde(default)]
    pub variants: Vec<Variant>,
    #[serde(default)]
    pub voice: Option<String>,
    #[serde(default)]
    pub choices: Vec<Choice>,
    /// A spoken response returns to this menu when presentation completes it.
    /// Timing and skip input belong to the host; this transition has no effects.
    #[serde(default)]
    pub return_to: Option<String>,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct Variant {
    pub when: Vec<Condition>,
    pub text: String,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct Choice {
    pub id: String,
    pub text: String,
    #[serde(default)]
    pub when: Vec<Condition>,
    /// Any matching group hides a spent or obsolete choice. All conditions
    /// within a group must match.
    #[serde(default)]
    pub hide_when: Vec<Vec<Condition>>,
    /// Matching rules disable a visible choice with an authored reason. The
    /// first match wins, before ordinary `when` requirements are checked.
    #[serde(default)]
    pub disable_when: Vec<DisabledChoice>,
    #[serde(default)]
    pub locked_reason: Option<String>,
    /// Spoken topics are completed after selection. Explicitly repeatable
    /// topics may be asked again; exits and menu navigation always remain usable.
    #[serde(default)]
    pub repeatable: bool,
    #[serde(default)]
    pub effects: Vec<Effect>,
    pub next: String,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct DisabledChoice {
    pub when: Vec<Condition>,
    pub reason: String,
    #[serde(default)]
    pub completed: bool,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum Condition {
    Flag { id: String, value: bool },
    MoralAtLeast { value: i32 },
    AffinityAtLeast { companion: String, value: i32 },
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum Effect {
    SetFlag { id: String, value: bool },
    AddMoral { amount: i32 },
    AddAffinity { companion: String, amount: i32 },
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct StoryState {
    pub flags: BTreeMap<String, bool>,
    pub moral: i32,
    pub affinity: BTreeMap<String, i32>,
    pub current: String,
    pub in_dialogue: bool,
    /// Choice IDs are scoped to their menu, since separate menus may reuse IDs.
    /// Older saves omit this field; authored completion flags still apply.
    #[serde(default)]
    pub chosen_choices: BTreeMap<String, BTreeSet<String>>,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct SaveDocument {
    pub schema: u32,
    pub story_id: String,
    pub revision: u32,
    pub state: StoryState,
}
#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct DialogueView {
    pub node_id: String,
    pub in_dialogue: bool,
    pub speaker: String,
    pub text: String,
    pub voice: Option<String>,
    pub return_to: Option<String>,
    pub choices: Vec<ChoiceView>,
}
#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct ChoiceView {
    pub id: String,
    pub text: String,
    pub enabled: bool,
    pub locked_reason: Option<String>,
    /// Presentation hint for a previously completed, now disabled choice.
    pub completed: bool,
}
/// A deterministic integration seam for systems that react to a committed choice.
#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum NarrativeEvent {
    ChoiceCommitted {
        story_id: String,
        node_id: String,
        choice_id: String,
    },
}
#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct ChoiceOutcome {
    pub view: DialogueView,
    pub events: Vec<NarrativeEvent>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NarrativeSession {
    story: Story,
    state: StoryState,
}

impl Story {
    pub fn validate(&self) -> Result<(), String> {
        if self.schema != STORY_SCHEMA {
            return Err(format!("story.schema: expected {STORY_SCHEMA}"));
        }
        if self.id.is_empty() || self.start.is_empty() {
            return Err("story id and start are required".into());
        }
        if self.moral.min > self.moral.max
            || !(self.moral.min..=self.moral.max).contains(&self.moral.initial)
        {
            return Err("moral range or initial value is invalid".into());
        }
        let flags: BTreeSet<_> = self.flags.iter().collect();
        if flags.len() != self.flags.len() {
            return Err("duplicate flag id".into());
        }
        let companions: BTreeSet<_> = self.companions.iter().collect();
        if companions.len() != self.companions.len() {
            return Err("duplicate companion id".into());
        }
        let ids: BTreeSet<_> = self.nodes.iter().map(|n| &n.id).collect();
        if ids.len() != self.nodes.len() {
            return Err("duplicate node id".into());
        }
        if !ids.contains(&self.start) {
            return Err(format!("start node '{}' does not exist", self.start));
        }
        for node in &self.nodes {
            if node.id.is_empty() || node.id == EXIT_TARGET {
                return Err("node id cannot be empty or use the reserved $exit target".into());
            }
            if let Some(target) = &node.return_to {
                let menu = self.nodes.iter().find(|n| &n.id == target).ok_or_else(|| {
                    format!(
                        "node '{}': return_to target '{}' does not exist",
                        node.id, target
                    )
                })?;
                if !node.choices.is_empty() {
                    return Err(format!(
                        "node '{}': a response cannot also have choices",
                        node.id
                    ));
                }
                if target == &node.id || menu.return_to.is_some() || menu.choices.is_empty() {
                    return Err(format!(
                        "node '{}': return_to must name a question menu",
                        node.id
                    ));
                }
            }
            let mut choice_ids = BTreeSet::new();
            for choice in &node.choices {
                if !choice_ids.insert(&choice.id) {
                    return Err(format!(
                        "node '{}': duplicate choice '{}'",
                        node.id, choice.id
                    ));
                }
                if choice.next != EXIT_TARGET && !ids.contains(&choice.next) {
                    return Err(format!(
                        "node '{}', choice '{}': target '{}' does not exist",
                        node.id, choice.id, choice.next
                    ));
                }
                self.validate_conditions(&choice.when)?;
                for hidden_case in &choice.hide_when {
                    if hidden_case.is_empty() {
                        return Err(format!(
                            "node '{}', choice '{}': hide_when group cannot be empty",
                            node.id, choice.id
                        ));
                    }
                    self.validate_conditions(hidden_case)?;
                }
                for disabled in &choice.disable_when {
                    if disabled.when.is_empty() || disabled.reason.trim().is_empty() {
                        return Err(format!(
                            "node '{}', choice '{}': disable_when needs conditions and a reason",
                            node.id, choice.id
                        ));
                    }
                    self.validate_conditions(&disabled.when)?;
                }
                self.validate_effects(&choice.effects)?;
            }
            for variant in &node.variants {
                self.validate_conditions(&variant.when)?;
            }
        }
        Ok(())
    }
    fn validate_conditions(&self, cs: &[Condition]) -> Result<(), String> {
        for c in cs {
            match c {
                Condition::Flag { id, .. } if !self.flags.contains(id) => {
                    return Err(format!("unknown flag '{id}'"))
                }
                Condition::AffinityAtLeast { companion, .. }
                    if !self.companions.contains(companion) =>
                {
                    return Err(format!("unknown companion '{companion}'"))
                }
                _ => {}
            }
        }
        Ok(())
    }
    fn validate_effects(&self, es: &[Effect]) -> Result<(), String> {
        for e in es {
            match e {
                Effect::SetFlag { id, .. } if !self.flags.contains(id) => {
                    return Err(format!("unknown flag '{id}'"))
                }
                Effect::AddAffinity { companion, .. } if !self.companions.contains(companion) => {
                    return Err(format!("unknown companion '{companion}'"))
                }
                _ => {}
            }
        }
        Ok(())
    }
    fn node(&self, id: &str) -> &Node {
        self.nodes
            .iter()
            .find(|n| n.id == id)
            .expect("validated node")
    }
}
impl NarrativeSession {
    pub fn new(story: Story) -> Result<Self, String> {
        story.validate()?;
        let flags = story.flags.iter().map(|x| (x.clone(), false)).collect();
        let affinity = story.companions.iter().map(|x| (x.clone(), 0)).collect();
        let state = StoryState {
            flags,
            moral: story.moral.initial,
            affinity,
            current: story.start.clone(),
            in_dialogue: false,
            chosen_choices: BTreeMap::new(),
        };
        Ok(Self { story, state })
    }
    pub fn state(&self) -> &StoryState {
        &self.state
    }
    /// The host owns world outcomes (for example a completed encounter).
    /// Synchronizing one declared fact neither chooses dialogue nor grants rewards.
    pub fn set_world_flag(&mut self, id: &str, value: bool) -> Result<(), String> {
        let flag = self
            .state
            .flags
            .get_mut(id)
            .ok_or_else(|| format!("unknown world flag '{id}'"))?;
        *flag = value;
        Ok(())
    }
    pub fn begin(&mut self) -> DialogueView {
        self.state.in_dialogue = true;
        self.view()
    }
    /// Start a conversation at an authored entry node. Unknown IDs leave the
    /// active session untouched, so a scene typo cannot corrupt a save.
    pub fn begin_at(&mut self, node_id: &str) -> Result<DialogueView, String> {
        if !self.story.nodes.iter().any(|node| node.id == node_id) {
            return Err(format!("unknown dialogue node '{node_id}'"));
        }
        self.state.current = node_id.to_owned();
        self.state.in_dialogue = true;
        Ok(self.view())
    }
    pub fn end(&mut self) {
        self.state.in_dialogue = false;
        self.state.current = self.story.start.clone();
    }
    pub fn view(&self) -> DialogueView {
        let n = self.story.node(&self.state.current);
        let text = n
            .variants
            .iter()
            .find(|v| self.matches(&v.when))
            .map(|v| v.text.clone())
            .unwrap_or_else(|| n.text.clone());
        DialogueView {
            node_id: n.id.clone(),
            in_dialogue: self.state.in_dialogue,
            speaker: n.speaker.clone(),
            text,
            voice: n.voice.clone(),
            return_to: n.return_to.clone(),
            choices: n
                .choices
                .iter()
                .filter(|c| !self.is_hidden(c))
                .map(|c| {
                    let disabled = self.disabled_rule(c);
                    let already_chosen = self.topic_completed(&n.id, c);
                    let enabled = !already_chosen && disabled.is_none() && self.matches(&c.when);
                    ChoiceView {
                        id: c.id.clone(),
                        text: c.text.clone(),
                        enabled,
                        locked_reason: (!enabled).then(|| {
                            disabled
                                .map(|rule| rule.reason.clone())
                                .or_else(|| already_chosen.then(|| "Already asked".into()))
                                .or_else(|| c.locked_reason.clone())
                                .unwrap_or_else(|| "Requirements not met".into())
                        }),
                        completed: already_chosen || disabled.is_some_and(|rule| rule.completed),
                    }
                })
                .collect(),
        }
    }
    pub fn choose(&mut self, id: &str) -> Result<DialogueView, String> {
        self.choose_with_events(id).map(|outcome| outcome.view)
    }
    /// Complete or skip a response. Never replay the choice that entered it.
    pub fn finish_response(&mut self) -> Result<DialogueView, String> {
        if !self.state.in_dialogue {
            return Err("dialogue is not active".into());
        }
        let target = self
            .story
            .node(&self.state.current)
            .return_to
            .as_ref()
            .ok_or("current node is not a response")?;
        self.state.current = target.clone();
        Ok(self.view())
    }
    pub fn choose_with_events(&mut self, id: &str) -> Result<ChoiceOutcome, String> {
        if !self.state.in_dialogue {
            return Err("dialogue is not active".into());
        }
        let node = self.story.node(&self.state.current);
        let choice = node
            .choices
            .iter()
            .find(|c| c.id == id)
            .ok_or_else(|| format!("unknown choice '{id}'"))?;
        if self.is_hidden(choice) {
            return Err(format!("choice '{id}' is no longer available"));
        }
        if self.topic_completed(&node.id, choice)
            || self.disabled_rule(choice).is_some()
            || !self.matches(&choice.when)
        {
            return Err(format!("choice '{id}' is locked"));
        }
        let mut next = self.state.clone();
        for effect in &choice.effects {
            match effect {
                Effect::SetFlag { id, value } => {
                    next.flags.insert(id.clone(), *value);
                }
                Effect::AddMoral { amount } => {
                    next.moral = next.moral.checked_add(*amount).ok_or("moral overflow")?;
                    if !(self.story.moral.min..=self.story.moral.max).contains(&next.moral) {
                        return Err("moral would exceed configured range".into());
                    }
                }
                Effect::AddAffinity { companion, amount } => {
                    let current = *next.affinity.get(companion).ok_or("unknown companion")?;
                    next.affinity.insert(
                        companion.clone(),
                        current.checked_add(*amount).ok_or("affinity overflow")?,
                    );
                }
            }
        }
        let event = NarrativeEvent::ChoiceCommitted {
            story_id: self.story.id.clone(),
            node_id: node.id.clone(),
            choice_id: choice.id.clone(),
        };
        next.chosen_choices
            .entry(node.id.clone())
            .or_default()
            .insert(choice.id.clone());
        if choice.next == EXIT_TARGET {
            next.current = self.story.start.clone();
            next.in_dialogue = false;
        } else {
            next.current = choice.next.clone();
        }
        self.state = next;
        Ok(ChoiceOutcome {
            view: self.view(),
            events: vec![event],
        })
    }
    fn matches(&self, cs: &[Condition]) -> bool {
        cs.iter().all(|c| match c {
            Condition::Flag { id, value } => self.state.flags.get(id) == Some(value),
            Condition::MoralAtLeast { value } => self.state.moral >= *value,
            Condition::AffinityAtLeast { companion, value } => self
                .state
                .affinity
                .get(companion)
                .is_some_and(|v| v >= value),
        })
    }
    fn is_hidden(&self, choice: &Choice) -> bool {
        choice.hide_when.iter().any(|case| self.matches(case))
    }
    fn topic_completed(&self, node_id: &str, choice: &Choice) -> bool {
        !choice.repeatable
            && choice.next != EXIT_TARGET
            && self.story.node(&choice.next).return_to.is_some()
            && self
                .state
                .chosen_choices
                .get(node_id)
                .is_some_and(|choices| choices.contains(&choice.id))
    }
    fn disabled_rule<'a>(&self, choice: &'a Choice) -> Option<&'a DisabledChoice> {
        choice
            .disable_when
            .iter()
            .find(|rule| self.matches(&rule.when))
    }
    pub fn save_json(&self) -> Result<String, String> {
        serde_json::to_string_pretty(&SaveDocument {
            schema: SAVE_SCHEMA,
            story_id: self.story.id.clone(),
            revision: self.story.revision,
            state: self.state.clone(),
        })
        .map_err(|e| e.to_string())
    }
    pub fn load_json(&mut self, json: &str) -> Result<(), String> {
        let save: SaveDocument =
            serde_json::from_str(json).map_err(|e| format!("invalid save: {e}"))?;
        if save.schema != SAVE_SCHEMA
            || save.story_id != self.story.id
            || save.revision != self.story.revision
        {
            return Err("save is incompatible with this story".into());
        }
        let flags: BTreeSet<_> = self.story.flags.iter().cloned().collect();
        let companions: BTreeSet<_> = self.story.companions.iter().cloned().collect();
        if !self.story.nodes.iter().any(|n| n.id == save.state.current)
            || save.state.flags.keys().cloned().collect::<BTreeSet<_>>() != flags
            || save.state.affinity.keys().cloned().collect::<BTreeSet<_>>() != companions
            || !(self.story.moral.min..=self.story.moral.max).contains(&save.state.moral)
        {
            return Err("save state is invalid".into());
        }
        for (node_id, chosen) in &save.state.chosen_choices {
            let Some(node) = self.story.nodes.iter().find(|node| &node.id == node_id) else {
                return Err("save choice history contains an unknown node".into());
            };
            if chosen
                .iter()
                .any(|id| !node.choices.iter().any(|choice| &choice.id == id))
            {
                return Err("save choice history contains an unknown choice".into());
            }
        }
        self.state = save.state;
        Ok(())
    }
}
pub fn load_story_json(json: &str) -> Result<Story, String> {
    let story: Story = serde_json::from_str(json).map_err(|e| format!("invalid story: {e}"))?;
    story.validate()?;
    Ok(story)
}
