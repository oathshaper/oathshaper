//! Flow's real-time style profile. Session owns admission, entropy, observations and saves.
pub use crate::command::{SpaceFrame, SpaceRequest, SpaceResult};
use crate::rpg::{Grant, Item, Mutation, Resource, RpgState, Source};
use crate::runtime::*;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet};
mod combat;
mod rules;
pub mod space;
mod view;
use rules::*;
fn err(code: &str, message: &str) -> RuleError {
    RuleError::new(code, message)
}
pub const STYLES: [&str; 4] = ["stone", "gale", "harbor", "still"];
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Actor {
    id: String,
    name: String,
    faction: String,
    position: [i64; 2],
    direction: [i64; 2],
    facing: [i64; 2],
    active: Option<Action>,
    guard: bool,
    stun: u64,
    reaction_until: u64,
    resolve: u64,
    setup: u64,
    spent: u64,
    slow: u64,
    deployed: bool,
    dodge_until: u64,
    dodge_started: u64,
    last_ai: u64,
}
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Action {
    id: String,
    style: String,
    verb: String,
    target: String,
    start: u64,
    elapsed: u64,
    startup: u64,
    recovery: u64,
    damage: i64,
    power: bool,
    range: i64,
    projectile: bool,
    fired: bool,
}
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Projectile {
    id: String,
    owner: String,
    target: String,
    destination: [i64; 2],
    remaining: u64,
    damage: i64,
}
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct State {
    tick: u64,
    encounter_start: u64,
    serial: u64,
    phase: String,
    actors: BTreeMap<String, Actor>,
    style: String,
    diamond: Vec<String>,
    target: String,
    preset: String,
    attributes: [i64; 3],
    ranks: BTreeMap<String, i64>,
    skills: Vec<String>,
    level: u32,
    xp: u32,
    style_points: i64,
    attribute_points: i64,
    focus: bool,
    focus_due: u64,
    enhanced: bool,
    healing: bool,
    heal_due: u64,
    cooldowns: BTreeMap<String, u64>,
    pauses: BTreeMap<String, String>,
    follower_mode: String,
    follower_version: u64,
    support_due: u64,
    support_left: i64,
    projectiles: Vec<Projectile>,
    observations: BTreeMap<String, SpaceResult>,
    cursors: BTreeMap<String, u64>,
    logs: Vec<String>,
    rewarded: bool,
    surrender_declined: bool,
}
#[derive(Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum FlowIntent {
    Start,
    Camp,
    Retry,
    Resume {
        token: String,
    },
    Pause {
        token: String,
    },
    Unpause {
        token: String,
    },
    Style {
        style: String,
    },
    Assign {
        slot: usize,
        style: String,
    },
    Target {
        actor_id: String,
    },
    Move {
        direction: [f64; 2],
    },
    Attack {
        verb: String,
    },
    Guard {
        enabled: bool,
    },
    Dodge,
    Heal {
        enabled: bool,
    },
    Focus {
        enabled: bool,
    },
    Enhance {
        enabled: bool,
    },
    Follower {
        mode: String,
    },
    Preset {
        preset: String,
    },
    Train {
        style: String,
        track: String,
    },
    Attribute {
        attribute: usize,
    },
    Equip {
        item_id: String,
        socket: usize,
    },
    Unequip {
        socket: usize,
    },
    Rest,
    Surrender {
        accept: bool,
    },
    Ai {
        actor_id: String,
        target: String,
        attack: bool,
        retreat: bool,
    },
}
#[derive(Clone, Serialize, Deserialize)]
struct Step {
    frame: SpaceFrame,
}
struct FlowProfile;
impl Profile for FlowProfile {
    type State = State;
    type Command = FlowIntent;
    type Advance = Step;
    type View = Value;
    type Preview = Value;
    fn manifest(&self) -> Manifest {
        Manifest::new("flow", 2, "flow-garden/v2")
    }
    fn preview(
        &self,
        ctx: &ReadContext<'_, State>,
        _: Option<&str>,
        c: &FlowIntent,
    ) -> RuleResult<Value> {
        let mut s = ctx.state.clone();
        let mut r = ctx.rpg.clone();
        let result = command(&mut s, &mut r, c, false).and_then(|()| self.validate(&s, &r));
        Ok(
            json!({"available":result.is_ok(),"reason":result.err().map(|e|e.reason),"view":view::project(&s,&r,ctx.revision)}),
        )
    }
    fn prepare_command(
        &self,
        tx: &mut Transaction<State>,
        _: Option<&str>,
        c: &FlowIntent,
    ) -> RuleResult {
        if matches!(c, FlowIntent::Ai { .. }) && tx.principal.role != Role::Ai {
            return Err(err(
                "authority",
                "Only the AI lease controls non-player actors",
            ));
        }
        command(
            &mut tx.state,
            &mut tx.rpg,
            c,
            tx.principal.role == Role::System,
        )?;
        tx.emit("intent", json!({"kind":c}), Visibility::Public)
    }
    fn prepare_advance(&self, tx: &mut Transaction<State>, step: &Step) -> RuleResult {
        combat::step(tx, &step.frame)
    }
    fn project(&self, ctx: &ReadContext<'_, State>) -> Value {
        view::project(ctx.state, ctx.rpg, ctx.revision)
    }
    fn validate(&self, s: &State, r: &RpgState) -> RuleResult {
        if !["camp", "encounter", "victory", "defeat", "surrender"].contains(&s.phase.as_str())
            || s.tick > 1_000_000_000
            || s.serial > 1_000_000_000
            || s.actors.len() != 6
            || s.diamond.len() != 4
            || s.attributes.iter().any(|n| !(6..=40).contains(n))
            || !STYLES.contains(&s.style.as_str())
            || s.diamond.iter().any(|v| !STYLES.contains(&v.as_str()))
            || !(0..=12).contains(&s.support_left)
            || !s.actors.contains_key(&s.target)
        {
            return Err(err("save", "Invalid Flow state"));
        }
        for id in [
            "player",
            "mara",
            "ivo",
            "hound",
            "sentinel",
            "corsair_raider",
        ] {
            let a = s
                .actors
                .get(id)
                .ok_or_else(|| err("save", "Missing actor"))?;
            if a.id != id
                || a.position.iter().any(|p| !(-100000..=100000).contains(p))
                || a.direction.iter().any(|p| !(-1000..=1000).contains(p))
            {
                return Err(err("save", "Invalid actor pose"));
            }
            for unit in ["health", "chi", "focus"] {
                if !r.resources().contains_key(&rid(id, unit)) {
                    return Err(err("save", "Missing actor resource"));
                }
            }
            if let Some(action) = &a.active {
                if !s.actors.contains_key(&action.target)
                    || action.elapsed > action.startup + action.recovery
                    || action.damage < 0
                    || action.damage > 200
                    || action.startup > 100
                    || action.recovery > 100
                {
                    return Err(err("save", "Invalid action snapshot"));
                }
            }
        }
        let mut projectile_ids = BTreeSet::new();
        for p in &s.projectiles {
            let serial =
                p.id.strip_prefix("action-")
                    .and_then(|id| id.parse::<u64>().ok());
            let source = s.actors.get(&p.owner);
            let target = s.actors.get(&p.target);
            if !projectile_ids.insert(&p.id)
                || serial.is_none_or(|id| id == 0 || id > s.serial)
                || source.is_none()
                || target.is_none()
                || source
                    .zip(target)
                    .is_some_and(|(a, b)| a.faction == b.faction)
                || p.destination
                    .iter()
                    .any(|n| !(-100000..=100000).contains(n))
                || !(1..=1000).contains(&p.remaining)
                || !(0..=200).contains(&p.damage)
            {
                return Err(err("save", "Invalid projectile snapshot"));
            }
        }
        if s.ranks.values().any(|v| !(0..=3).contains(v))
            || s.style_points < 0
            || s.attribute_points < 0
        {
            return Err(err("save", "Invalid training"));
        }
        if s.level == 0
            || s.level > 10
            || s.attributes.iter().sum::<i64>() + s.attribute_points
                != 24 + 2 * i64::from(s.level - 1)
            || s.ranks
                .values()
                .map(|rank| rank * (rank + 1) / 2)
                .sum::<i64>()
                + s.style_points
                != 6 + 3 * i64::from(s.level - 1)
        {
            return Err(err(
                "save",
                "Earned progression budget disagrees with investment",
            ));
        }
        for style in STYLES {
            if r.grants()
                .get(&format!("learned:{style}"))
                .is_none_or(|g| g.recipient != "player" || g.ability != style)
            {
                return Err(err("save", "Missing learned style source"));
            }
        }
        for (id, maxima) in [
            ("mara", [100, 40, 0]),
            ("ivo", [140, 0, 0]),
            ("hound", [120, 0, 0]),
            ("sentinel", [96, 0, 0]),
            ("corsair_raider", [144, 0, 0]),
        ] {
            for (i, unit) in ["health", "chi", "focus"].iter().enumerate() {
                if r.resources()[&rid(id, unit)].maximum != maxima[i] {
                    return Err(err("save", "Invalid authored actor capacity"));
                }
            }
        }
        let max = maxima(s, r);
        for (i, u) in ["health", "chi", "focus"].iter().enumerate() {
            if r.resources()[&rid("player", u)].maximum != max[i] {
                return Err(err("save", "Equipment and capacity disagree"));
            }
        }
        for (slot, item) in r.bindings().get("player").into_iter().flatten() {
            if !["socket0", "socket1"].contains(&slot.as_str())
                || !gem_legal(s, &r.items()[item].definition)
            {
                return Err(err("save", "Invalid amulet binding"));
            }
        }
        Ok(())
    }
    fn validate_restore(&self, c: &RestoreContext<'_, State>) -> RuleResult {
        if &c.state.cursors != c.observation_positions {
            return Err(err("save", "Observation cursor mismatch"));
        }
        Ok(())
    }
    fn decide_ai(&self, ctx: &ReadContext<'_, State>, actor: &str) -> Vec<FlowIntent> {
        combat::ai(ctx.state, ctx.rpg, actor)
    }
    fn quiescent(&self, s: &State, _: &RpgState) -> bool {
        s.phase == "camp" && s.actors.values().all(|a| a.active.is_none())
    }
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Input {
    schema: String,
    command_id: String,
    generation: String,
    expected_revision: String,
    action: FlowIntent,
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Save {
    schema: String,
    session: String,
    checkpoint: Option<String>,
}
pub struct FlowGame {
    session: Session<FlowProfile>,
    host: HostAuthority,
    player: String,
    ai: String,
    system: String,
    staged: Option<SpaceFrame>,
    checkpoint: Option<String>,
    restore: Option<String>,
}
impl FlowGame {
    pub fn new(seed: u64) -> RuleResult<Self> {
        let (mut s, r) = initial()?;
        let frame = crate::command::space::fixture_frame(&space::requests(&s, 0, 0), 1)?;
        s.observations = frame
            .results
            .into_iter()
            .map(|r| (r.request_id.clone(), r))
            .collect();
        let mut host = HostAuthority::default();
        let session = Session::new(FlowProfile, s, r, seed, "flow-chapter", &mut host)?;
        let mut g = Self {
            session,
            host,
            player: String::new(),
            ai: String::new(),
            system: String::new(),
            staged: None,
            checkpoint: None,
            restore: None,
        };
        g.leases()?;
        Ok(g)
    }
    fn leases(&mut self) -> RuleResult {
        self.player = self.session.issue_lease(
            &mut self.host,
            Principal {
                id: "local-player".into(),
                role: Role::Player,
            },
            "player",
            LeaseScope {
                actors: ["player".into()].into(),
                system_commands: true,
                advance: false,
            },
        )?;
        self.ai = self.session.issue_lease(
            &mut self.host,
            Principal {
                id: "flow-ai".into(),
                role: Role::Ai,
            },
            "player",
            LeaseScope {
                actors: ["mara", "ivo", "hound", "sentinel", "corsair_raider"]
                    .map(str::to_owned)
                    .into(),
                system_commands: false,
                advance: false,
            },
        )?;
        self.system = self.session.issue_lease(
            &mut self.host,
            Principal {
                id: "flow-host".into(),
                role: Role::System,
            },
            "player",
            LeaseScope {
                actors: BTreeSet::new(),
                system_commands: true,
                advance: true,
            },
        )?;
        Ok(())
    }
    pub fn view(&self) -> Value {
        let mut v = self.session.view(&self.player).expect("owned player lease");
        v["session"]["generation"] = json!(self.session.generation().to_string());
        v["session"]["ledger_sequence"] = json!(self.session.ledger_sequence().to_string());
        if self.session.restored_paused() {
            v["clock"]["paused"] = json!(true);
            v["clock"]["restore_token"] = json!(self.restore);
        }
        v
    }
    pub fn submit(&mut self, input: Value) -> RuleResult<Value> {
        let i: Input = serde_json::from_value(input)?;
        if i.schema != "flow.action/v1" || matches!(i.action, FlowIntent::Ai { .. }) {
            return Err(err("schema", "Unsupported public Flow action"));
        }
        let generation = i
            .generation
            .parse()
            .map_err(|_| err("generation", "Invalid generation"))?;
        if generation != self.session.generation() {
            return Err(err("generation", "Stale generation"));
        }
        let revision = i
            .expected_revision
            .parse()
            .map_err(|_| err("revision", "Invalid revision"))?;
        let resume =
            matches!(&i.action,FlowIntent::Resume{token}if self.restore.as_ref()==Some(token));
        if matches!(&i.action, FlowIntent::Resume { .. }) && !resume {
            return Err(err("restore", "Unknown restore prompt"));
        }
        let retry = matches!(i.action, FlowIntent::Retry);
        let checkpoint = if matches!(i.action, FlowIntent::Start) {
            Some(self.session.save_json()?)
        } else {
            None
        };
        let before = self.session.revision();
        let e = Envelope {
            generation,
            epoch: self.session.epoch(),
            id: i.command_id,
            lease: if resume {
                self.system.clone()
            } else {
                self.player.clone()
            },
            expected_revision: revision,
            actor: None,
            payload: i.action,
        };
        let receipt = if resume {
            self.session.resume_and_submit(e)?
        } else {
            self.session.submit(e)?
        };
        if receipt.status == Status::Accepted && self.session.revision() > before {
            self.staged = None;
            if let Some(c) = checkpoint {
                self.checkpoint = Some(c)
            }
            if retry {
                let c = self
                    .checkpoint
                    .clone()
                    .ok_or_else(|| err("retry", "No encounter checkpoint"))?;
                self.session.restore_json(&c, &mut self.host)?;
                self.leases()?;
                self.restore = Some(format!("restore:{}", self.session.generation()));
            }
        }
        Ok(json!({"receipt":receipt,"view":self.view()}))
    }
    pub fn preview(&self, input: Value) -> RuleResult<Value> {
        let i: Input = serde_json::from_value(input)?;
        if i.generation != self.session.generation().to_string()
            || i.expected_revision != self.session.revision().to_string()
            || matches!(i.action, FlowIntent::Ai { .. } | FlowIntent::Resume { .. })
        {
            return Err(err("preview", "Stale or privileged preview"));
        }
        self.session
            .preview(&self.player, None, &i.action)
            .map_err(|r| RuleError::new(r.code, r.message))
    }
    pub fn space_requests(&self) -> Vec<SpaceRequest> {
        space::requests(
            self.session.state(),
            self.session.generation(),
            self.session.revision(),
        )
    }
    pub fn next_observation_sequence(&self, p: &str) -> u64 {
        self.session.state().cursors.get(p).copied().unwrap_or(0) + 1
    }
    pub fn observe_space(&mut self, f: SpaceFrame) -> RuleResult {
        let requests = self.space_requests();
        if f.generation != self.session.generation().to_string()
            || f.state_revision != self.session.revision().to_string()
            || f.tick != self.session.state().tick
            || f.geometry_revision != "garden-1"
            || f.producer_id.is_empty()
            || f.sequence.parse::<u64>().ok()
                != Some(self.next_observation_sequence(&f.producer_id))
            || f.results.len() != requests.len()
        {
            return Err(err("geometry", "Stale or incomplete geometry"));
        }
        let ids: BTreeSet<_> = f.results.iter().map(|r| r.request_id.as_str()).collect();
        if ids.len() != requests.len()
            || requests.iter().any(|q| !ids.contains(q.id.as_str()))
            || f.results.iter().any(|r| {
                !r.valid
                    || r.clear.is_none()
                    || r.path_mm
                        .iter()
                        .flatten()
                        .any(|n| !(-100000..=100000).contains(n))
            })
        {
            return Err(err("geometry", "Invalid observation result"));
        }
        self.staged = Some(f);
        Ok(())
    }
    pub fn observe_fixture(&mut self) -> RuleResult {
        self.observe_space(crate::command::space::fixture_frame(
            &self.space_requests(),
            self.next_observation_sequence("headless-garden"),
        )?)
    }
    pub fn advance(&mut self, ticks: u32) -> RuleResult<Value> {
        if ticks > 100 {
            return Err(err("ticks", "At most 100 ticks"));
        }
        if self.session.restored_paused() || !self.session.state().pauses.is_empty() {
            return Ok(json!({"consumed_ticks":0,"stop_reason":"paused","view":self.view()}));
        }
        if ticks == 0 {
            return Ok(json!({"consumed_ticks":0,"stop_reason":"complete","view":self.view()}));
        }
        if self.session.state().tick.is_multiple_of(5) {
            for actor in ["mara", "ivo", "hound", "sentinel", "corsair_raider"] {
                for c in self.session.ai_commands(&self.ai, actor)? {
                    let receipt = self.session.submit(Envelope {
                        generation: self.session.generation(),
                        epoch: self.session.epoch(),
                        id: format!("ai:{}", self.session.ledger_sequence() + 1),
                        lease: self.ai.clone(),
                        expected_revision: self.session.revision(),
                        actor: Some(actor.into()),
                        payload: c,
                    })?;
                    if receipt.status == Status::Accepted {
                        self.staged = None;
                    }
                }
            }
        }
        let Some(frame) = self.staged.take() else {
            return Ok(
                json!({"consumed_ticks":0,"stop_reason":"waiting_for_space","view":self.view()}),
            );
        };
        let result = self.session.advance(Envelope {
            generation: self.session.generation(),
            epoch: self.session.epoch(),
            id: format!("step:{}", self.session.ledger_sequence() + 1),
            lease: self.system.clone(),
            expected_revision: self.session.revision(),
            actor: None,
            payload: Step { frame },
        })?;
        Ok(
            json!({"consumed_ticks":if result.status==Status::Accepted{1}else{0},"stop_reason":if result.status==Status::Accepted{"complete"}else{"rejected"},"receipt":result,"view":self.view()}),
        )
    }
    pub fn save_json(&self) -> RuleResult<String> {
        Ok(serde_json::to_string(&Save {
            schema: "flow.save/v2".into(),
            session: self.session.save_json()?,
            checkpoint: self.checkpoint.clone(),
        })?)
    }
    pub fn restore_json(&mut self, text: &str) -> RuleResult<Value> {
        let s: Save = serde_json::from_str(text)?;
        if s.schema != "flow.save/v2" {
            return Err(err("save", "Unsupported Flow save"));
        }
        if let Some(c) = &s.checkpoint {
            let mut g = Self::new(0)?;
            g.session.restore_json(c, &mut g.host)?;
        }
        self.session.restore_json(&s.session, &mut self.host)?;
        self.leases()?;
        self.checkpoint = s.checkpoint;
        self.staged = None;
        self.restore = Some(format!("restore:{}", self.session.generation()));
        Ok(self.view())
    }
}
