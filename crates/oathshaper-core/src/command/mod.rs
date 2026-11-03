//! Command's typed profile and host facade. All gameplay commits pass through Session.
use crate::rpg::{ClaimTarget, Grant, Item, RpgState, Source};
use crate::runtime::*;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet};
mod combat;
mod content;
mod progression;
mod rules;
pub mod space;
mod types;
mod view;
use types::*;
pub use types::{SpaceFrame, SpaceRequest, SpaceResult};
pub type CommandError = RuleError;
fn err(code: &str, message: &str) -> RuleError {
    RuleError::new(code, message)
}
pub struct CommandProfile;
impl Profile for CommandProfile {
    type State = CommandState;
    type Command = CommandIntent;
    type Advance = CommandStep;
    type View = Value;
    type Preview = Value;
    fn manifest(&self) -> Manifest {
        Manifest::new("command", 4, content::CONTENT_HASH)
    }
    fn participants(&self, _: Option<&str>, command: &CommandIntent) -> BTreeSet<String> {
        let mut actors: BTreeSet<_> = command.actor().map(str::to_owned).into_iter().collect();
        if matches!(command, CommandIntent::Deploy { .. }) {
            // Deployment changes both the incoming and outgoing companions.
            actors.extend(content::PARTY.into_iter().map(str::to_owned));
        }
        if let CommandIntent::Assist {
            helper_id: Some(id),
            ..
        } = command
        {
            actors.insert(id.clone());
        }
        actors
    }
    fn preview(
        &self,
        ctx: &ReadContext<'_, CommandState>,
        _: Option<&str>,
        command: &CommandIntent,
    ) -> RuleResult<Value> {
        let mut state = ctx.state.clone();
        let mut rpg = ctx.rpg.clone();
        let result = rules::command(&mut state, &mut rpg, command, false)
            .and_then(|()| self.validate(&state, &rpg));
        let reasons: Vec<_> = result.err().map(|e| e.reason).into_iter().collect();
        let projected = view::project(&ReadContext {
            state: if reasons.is_empty() {
                &state
            } else {
                ctx.state
            },
            rpg: if reasons.is_empty() { &rpg } else { ctx.rpg },
            revision: ctx.revision,
            epoch: ctx.epoch,
            observer: ctx.observer,
            principal: ctx.principal,
            authority: ctx.authority.clone(),
        });
        Ok(json!({"available":reasons.is_empty(),"reasons":reasons,"view":projected}))
    }
    fn prepare_command(
        &self,
        tx: &mut Transaction<CommandState>,
        _: Option<&str>,
        command: &CommandIntent,
    ) -> RuleResult {
        if matches!(
            command,
            CommandIntent::ResumeRestore { .. } | CommandIntent::RevokeItem { .. }
        ) && tx.principal.role != Role::System
        {
            return Err(err(
                "authority",
                "Restore lifecycle requires the host lease",
            ));
        }
        let before = tx.state.serial;
        rules::command(
            &mut tx.state,
            &mut tx.rpg,
            command,
            tx.principal.role == Role::Ai,
        )?;
        let action_id = tx
            .state
            .actors
            .values()
            .flat_map(|a| a.queue.iter())
            .find(|a| a.sequence > before)
            .map(|a| a.id.clone());
        let pause_token = tx
            .state
            .pauses
            .keys()
            .find(|id| {
                id.strip_prefix("pause-")
                    .and_then(|n| n.parse::<u64>().ok())
                    .is_some_and(|n| n > before)
            })
            .cloned();
        tx.emit(
            "command",
            json!({"action_id":action_id,"pause_token":pause_token}),
            Visibility::Public,
        )
    }
    fn prepare_advance(
        &self,
        tx: &mut Transaction<CommandState>,
        step: &CommandStep,
    ) -> RuleResult {
        combat::step(tx, step)
    }
    fn project(&self, ctx: &ReadContext<'_, CommandState>) -> Value {
        view::project(ctx)
    }
    fn validate(&self, s: &CommandState, r: &RpgState) -> RuleResult {
        if s.geometry_revision != "garden-1"
            || !s.actors.contains_key(&s.recipient)
            || !s.actors.contains_key(&s.inspected)
            || s.possessed
                .as_ref()
                .is_some_and(|id| !s.actors.contains_key(id))
        {
            return Err(err("state", "Invalid Command identity or geometry"));
        }
        if s.tick > 1_000_000_000_000
            || s.serial > 1_000_000_000_000
            || s.actors.keys().map(String::as_str).collect::<BTreeSet<_>>()
                != content::INITIATIVE.into_iter().collect()
        {
            return Err(err("state", "Invalid clock or roster"));
        }
        if s.debt.len() != content::INITIATIVE.len() * 3
            || r.resources().len() != content::INITIATIVE.len() * 3 + 1
        {
            return Err(err("resource", "Command resource set is incomplete"));
        }
        if !s.actors["player"].deployed
            || content::PARTY
                .iter()
                .filter(|id| s.actors[**id].deployed)
                .count()
                != 3
        {
            return Err(err(
                "party",
                "Deployment requires the player and two companions",
            ));
        }
        for id in content::PARTY {
            let actor = &s.actors[id];
            if actor.attributes.len() != 6
                || [
                    "might",
                    "agility",
                    "body",
                    "intellect",
                    "spirit",
                    "presence",
                ]
                .iter()
                .any(|k| !actor.attributes.contains_key(*k))
                || actor.attributes.values().any(|n| !(-5..=20).contains(n))
                || actor
                    .classes
                    .values()
                    .try_fold(0_u32, |sum, n| sum.checked_add(*n))
                    != Some(actor.level)
                || actor.skills.values().any(|n| *n > actor.level + 2)
            {
                return Err(err("build", "Invalid actor build"));
            }
            let health = progression::max_health(actor);
            let mut focus = progression::native_focus(actor);
            let mut battery = 0;
            if let Some(bindings) = r.bindings().get(id) {
                for item in bindings.values().collect::<BTreeSet<_>>() {
                    let item = r
                        .items()
                        .get(item)
                        .ok_or_else(|| err("binding", "Unknown bound instance"))?;
                    let def = content::item_def(&item.definition)?;
                    if !progression::gear_legal(actor, &item.definition)
                        || def
                            .slots
                            .iter()
                            .any(|slot| bindings.get(*slot) != Some(&item.id))
                    {
                        return Err(err("binding", "Invalid body occupancy or training"));
                    }
                    if item.definition == "storm_lens" {
                        focus += 30
                    }
                    if item.definition == "survey_tool" {
                        battery = 3
                    }
                }
            }
            for (unit, maximum) in [("health", health), ("focus", focus), ("battery", battery)] {
                if r.resources()
                    .get(&content::resource_id(id, unit))
                    .is_none_or(|p| p.maximum != maximum)
                {
                    return Err(err(
                        "capacity",
                        "Saved capacity disagrees with build and equipment",
                    ));
                }
            }
        }
        for (id, debt) in &s.debt {
            let p = r
                .resources()
                .get(id)
                .ok_or_else(|| err("debt", "Debt resource is absent"))?;
            if !(0..=1_000_000).contains(debt)
                || p.maximum > 1_000_000
                || p.maximum < 0
                || p.current != (p.maximum - debt).max(0)
            {
                return Err(err("debt", "Resource and persistent depletion disagree"));
            }
        }
        let mut actions = BTreeSet::new();
        for (id, a) in &s.actors {
            if id != &a.id
                || a.queue.len() > 4
                || a.level == 0
                || a.level > 20
                || !(0..=28).contains(&a.ward_strength)
                || !(0..=a.ward_strength).contains(&a.ward_remaining)
                || (a.ward_strength > 0) != a.conditions.contains_key("ward")
                || a.position.iter().any(|p| !(-100000..=100000).contains(p))
            {
                return Err(err("state", "Invalid actor"));
            }
            for action in a.active.iter().chain(a.queue.iter()) {
                if action.actor != *id
                    || !actions.insert(action.id.clone())
                    || content::ability(&action.ability).is_err()
                {
                    return Err(err("action", "Invalid action identity"));
                }
                let ability = content::ability(&action.ability)?;
                let paid = action.activation.is_some();
                let claims: Vec<_> = r
                    .claims()
                    .values()
                    .filter(|c| c.action == action.id)
                    .collect();
                if claims.iter().any(|c| c.owner != *id) {
                    return Err(err("claim", "Action claim belongs to another actor"));
                }
                let resource_claims: Vec<_> = claims
                    .iter()
                    .filter(|c| matches!(c.target, ClaimTarget::Resource { .. }))
                    .collect();
                if paid {
                    if !resource_claims.is_empty()
                        || action.paid != ability.cost
                        || action.activation.is_none_or(|t| t > s.tick)
                        || action.impact != action.activation.map(|t| t + ability.timing().0)
                        || action.recovery != action.activation.map(|t| t + ability.timing().1)
                    {
                        return Err(err("payment", "Invalid paid action snapshot"));
                    }
                } else if ability.cost > 0 {
                    let resource = content::resource_id(
                        id,
                        if action.ability == "disrupt_device" {
                            "battery"
                        } else {
                            "focus"
                        },
                    );
                    if resource_claims.len() != 1
                        || !matches!(&resource_claims[0].target,ClaimTarget::Resource{resource:r,amount}if r==&resource&&*amount==ability.cost)
                    {
                        return Err(err(
                            "claims",
                            "Pending action lacks its complete reservation",
                        ));
                    }
                } else if !resource_claims.is_empty() {
                    return Err(err(
                        "claims",
                        "Zero-cost action owns a resource reservation",
                    ));
                }
                let mut expected_claims = usize::from(!paid && ability.cost > 0);
                if action.ability == "dressing" {
                    if action.paid_item != paid {
                        return Err(err(
                            "payment",
                            "Dressing payment marker disagrees with activation",
                        ));
                    }
                    if !paid {
                        expected_claims += 1;
                        if r.items().get(&action.source).is_none_or(|i|i.definition!="dressing"||i.owner!="party_pack")||claims.iter().filter(|c|matches!(&c.target,ClaimTarget::Item{item,quantity}if item==&action.source&&*quantity==1)).count()!=1{return Err(err("claims","Unpaid dressing requires its accessible item and complete claim"))}
                    }
                } else if action.paid_item {
                    return Err(err("payment", "Non-item action has an item payment"));
                }
                if let Some(Grant {
                    source: Source::Item { item, .. },
                    ..
                }) = r.grants().get(&action.source)
                {
                    expected_claims += 1;
                    if claims
                        .iter()
                        .filter(|c| matches!(&c.target,ClaimTarget::ItemRead{item:id}if id==item))
                        .count()
                        != 1
                    {
                        return Err(err("claims", "Equipped action lost its shared item read"));
                    }
                    for (slot, bound) in r.bindings().get(id).into_iter().flatten() {
                        if bound == item {
                            expected_claims += 1;
                            if claims.iter().filter(|c|matches!(&c.target,ClaimTarget::BindingRead{actor,slot:s,item:i}if actor==id&&s==slot&&i==item)).count()!=1{return Err(err("claims","Equipped action lost its binding read"))}
                        }
                    }
                }
                if claims.len() != expected_claims {
                    return Err(err(
                        "claims",
                        "Action claim set contains missing or unrelated claims",
                    ));
                }
                if action
                    .target
                    .position
                    .is_some_and(|p| p.iter().any(|n| !n.is_finite() || n.abs() > 100.))
                    || action
                        .target
                        .actor_id
                        .as_ref()
                        .is_some_and(|id| !s.actors.contains_key(id))
                    || action
                        .path
                        .iter()
                        .flatten()
                        .any(|n| !(-100000..=100000).contains(n))
                    || !(0..=18060).contains(&action.approach_travel_mm)
                    || action.sequence > s.serial
                    || action.id.is_empty()
                {
                    return Err(err("action", "Invalid target, path or sequence"));
                }
                match ability.target {
                    "point"
                        if action.target.kind != "point"
                            || action.target.position.is_none()
                            || action.target.actor_id.is_some() =>
                    {
                        return Err(err("target", "Malformed ground target"))
                    }
                    "self"
                        if action.target.kind != "self"
                            || action.target.actor_id.is_some()
                            || action.target.position.is_some() =>
                    {
                        return Err(err("target", "Malformed self target"))
                    }
                    "enemy" | "ally"
                        if action.target.kind != "actor"
                            || action.target.actor_id.is_none()
                            || action.target.position.is_some() =>
                    {
                        return Err(err("target", "Malformed actor target"))
                    }
                    _ => {}
                }
                if (action.phase == "waiting" || action.phase == "approach") && paid
                    || action.phase == "waiting"
                        && (action.deadline.is_some()
                            || action.impact.is_some()
                            || action.recovery.is_some())
                    || action.phase == "approach"
                        && action
                            .deadline
                            .is_none_or(|deadline| deadline <= s.tick || deadline > s.tick + 60)
                {
                    return Err(err("timing", "Malformed pending action timing"));
                }
                if action.ability != "dressing"
                    && r.grants()
                        .get(&action.source)
                        .is_none_or(|g| g.recipient != *id || g.ability != action.ability)
                {
                    return Err(err(
                        "source",
                        "Pending action has no matching ability grant",
                    ));
                }
                if action.phase == "windup" && action.impact.is_some_and(|t| t <= s.tick)
                    || action.phase == "recovery" && action.impact.is_some_and(|t| t > s.tick)
                    || !["waiting", "approach", "windup", "recovery"]
                        .contains(&action.phase.as_str())
                {
                    return Err(err("timing", "Invalid action timing state"));
                }
                if action.phase == "windup"
                    && (action.activation.is_none()
                        || action.impact.is_none()
                        || action.recovery.is_none())
                {
                    return Err(err("action", "Incomplete paid timing"));
                }
            }
        }
        if r.claims().values().any(|c| !actions.contains(&c.action)) {
            return Err(err("claims", "Claim has no pending action"));
        }
        for i in r.items().values() {
            content::item_def(&i.definition)?;
            if i.parent.is_some() || i.quantity > 99 {
                return Err(err(
                    "inventory",
                    "Invalid Command stack or nested container",
                ));
            }
        }
        Ok(())
    }
    fn validate_restore(&self, candidate: &RestoreContext<'_, CommandState>) -> RuleResult {
        for actor in candidate.state.actors.values() {
            for action in actor.active.iter() {
                let occurred = candidate
                    .occurrences
                    .contains(&format!("{}:impact", action.id));
                if (action.phase == "recovery") != occurred {
                    return Err(err(
                        "occurrence",
                        "Active stage disagrees with committed impact ledger",
                    ));
                }
            }
        }
        if &candidate.state.observation_sequence != candidate.observation_positions {
            return Err(err(
                "observation",
                "Profile geometry cursor disagrees with kernel cursor",
            ));
        }
        Ok(())
    }
    fn decide_ai(&self, ctx: &ReadContext<'_, CommandState>, actor: &str) -> Vec<CommandIntent> {
        combat::ai(ctx.state, ctx.rpg, actor)
    }
    fn quiescent(&self, s: &CommandState, _: &RpgState) -> bool {
        s.phase == "camp"
            && s.rest_until.is_none()
            && s.actors
                .values()
                .all(|a| a.active.is_none() && a.queue.is_empty())
    }
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Input {
    schema: String,
    command_id: String,
    generation: String,
    expected_revision: String,
    action: CommandIntent,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct PreviewInput {
    schema: String,
    generation: String,
    expected_revision: String,
    action: CommandIntent,
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Save {
    schema: String,
    session: String,
    checkpoint: Option<String>,
}
pub struct CommandGame {
    session: Session<CommandProfile>,
    host: HostAuthority,
    player: String,
    ai: String,
    system: String,
    staged: Option<SpaceFrame>,
    checkpoint: Option<String>,
    restore_token: Option<String>,
}
impl CommandGame {
    pub fn new(seed: u64) -> RuleResult<Self> {
        let (mut state, rpg) = content::initial()?;
        let requests = space::requests(&state, 0, 0);
        let frame = space::fixture_frame(&requests, 1)?;
        state.observations = frame
            .results
            .into_iter()
            .map(|r| (r.request_id.clone(), r))
            .collect();
        let mut host = HostAuthority::default();
        let session = Session::new(CommandProfile, state, rpg, seed, "command-trial", &mut host)?;
        let mut game = Self {
            session,
            host,
            player: String::new(),
            ai: String::new(),
            system: String::new(),
            staged: None,
            checkpoint: None,
            restore_token: None,
        };
        game.leases()?;
        Ok(game)
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
                actors: content::PARTY.into_iter().map(str::to_owned).collect(),
                system_commands: true,
                advance: false,
            },
        )?;
        self.ai = self.session.issue_lease(
            &mut self.host,
            Principal {
                id: "command-ai".into(),
                role: Role::Ai,
            },
            "player",
            LeaseScope {
                actors: content::INITIATIVE.into_iter().map(str::to_owned).collect(),
                system_commands: false,
                advance: false,
            },
        )?;
        self.system = self.session.issue_lease(
            &mut self.host,
            Principal {
                id: "command-host".into(),
                role: Role::System,
            },
            "player",
            LeaseScope {
                actors: content::INITIATIVE.into_iter().map(str::to_owned).collect(),
                system_commands: true,
                advance: true,
            },
        )?;
        Ok(())
    }
    fn fill(&self, mut view: Value) -> Value {
        view["session"]["generation"] = json!(self.session.generation().to_string());
        view["session"]["ledger_sequence"] = json!(self.session.ledger_sequence().to_string());
        if let Some(token) = self
            .restore_token
            .as_ref()
            .filter(|_| self.session.restored_paused())
        {
            view["session"]["phase"] = json!("restore_prompt");
            view["clock"]["paused"] = json!(true);
            view["clock"]["can_advance"] = json!(false);
            view["clock"]["pause_reasons"].as_array_mut().unwrap().push(json!({"token":token,"owner":"restore","label":"Resume from save","acknowledgeable":true}));
        }
        view
    }
    pub fn view(&self) -> Value {
        self.fill(
            self.session
                .view(&self.player)
                .expect("private valid player lease"),
        )
    }
    pub fn preview(&self, input: Value) -> RuleResult<Value> {
        let input: PreviewInput = serde_json::from_value(input)?;
        if input.schema != "command.preview/v1"
            || input.generation != self.session.generation().to_string()
            || input.expected_revision != self.session.revision().to_string()
        {
            return Err(err("revision", "Stale preview"));
        }
        let mut result = self
            .session
            .preview(&self.player, input.action.actor(), &input.action)
            .map_err(|r| RuleError::new(r.code, r.message))?;
        result["view"] = self.fill(result["view"].clone());
        Ok(result)
    }
    pub fn submit(&mut self, input: Value) -> RuleResult<Value> {
        let input: Input = serde_json::from_value(input)?;
        if input.schema != "command.action/v1"
            || matches!(
                input.action,
                CommandIntent::ResumeRestore { .. } | CommandIntent::RevokeItem { .. }
            )
        {
            return Err(err("schema", "Unsupported public Command action"));
        }
        let generation = input
            .generation
            .parse()
            .map_err(|_| err("generation", "Invalid generation"))?;
        if generation != self.session.generation() {
            return Err(err("generation", "Stale generation"));
        }
        let revision = input
            .expected_revision
            .parse()
            .map_err(|_| err("revision", "Invalid revision"))?;
        let resume = matches!(&input.action,CommandIntent::Acknowledge{token}if self.restore_token.as_ref()==Some(token));
        let retry = matches!(input.action, CommandIntent::Retry { .. });
        let before_revision = self.session.revision();
        let checkpoint = matches!(input.action, CommandIntent::Start { .. })
            .then(|| self.session.save_json())
            .transpose()?;
        let command = if resume {
            CommandIntent::ResumeRestore {
                token: self.restore_token.clone().unwrap(),
            }
        } else {
            input.action
        };
        let envelope = Envelope {
            generation,
            epoch: self.session.epoch(),
            id: input.command_id,
            lease: if resume {
                self.system.clone()
            } else {
                self.player.clone()
            },
            expected_revision: revision,
            actor: command.actor().map(str::to_owned),
            payload: command,
        };
        let receipt = if resume {
            self.session.resume_and_submit(envelope)?
        } else {
            self.session.submit(envelope)?
        };
        if receipt.status == Status::Accepted && self.session.revision() > before_revision {
            if let Some(checkpoint) = checkpoint {
                self.checkpoint = Some(checkpoint)
            }
            self.staged = None;
            if retry {
                let checkpoint = self
                    .checkpoint
                    .clone()
                    .ok_or_else(|| err("retry", "Missing checkpoint"))?;
                self.session.restore_json(&checkpoint, &mut self.host)?;
                self.leases()?;
                self.restore_token = Some(format!("restore:{}", self.session.generation()));
            }
        }
        let event = receipt
            .events
            .iter()
            .find(|e| e.kind == "command")
            .map(|e| e.payload.clone())
            .unwrap_or(Value::Null);
        Ok(
            json!({"receipt":{"command_id":receipt.id,"status":receipt.status,"revision":receipt.revision.to_string(),"ledger_sequence":receipt.ledger_sequence.to_string(),"action_id":event["action_id"],"pause_token":event["pause_token"],"reasons":receipt.reason.into_iter().collect::<Vec<_>>(),"events":receipt.events},"view":self.view()}),
        )
    }

    /// Next committed cursor for this trusted geometry producer. Staging a frame
    /// does not consume it; callers must query again after commands or restore.
    /// Trusted source loss; public submit rejects this operation.
    pub fn revoke_item_source(&mut self, item_id: &str) -> RuleResult<Value> {
        let receipt = self.session.submit(Envelope {
            generation: self.session.generation(),
            epoch: self.session.epoch(),
            id: format!("host-revoke:{}", self.session.ledger_sequence() + 1),
            lease: self.system.clone(),
            expected_revision: self.session.revision(),
            actor: None,
            payload: CommandIntent::RevokeItem {
                item_id: item_id.into(),
            },
        })?;
        self.staged = None;
        Ok(json!({"receipt":receipt,"view":self.view()}))
    }
    pub fn next_observation_sequence(&self, producer: &str) -> u64 {
        self.session
            .state()
            .observation_sequence
            .get(producer)
            .copied()
            .unwrap_or(0)
            + 1
    }

    pub fn space_requests(&self) -> Vec<SpaceRequest> {
        space::requests(
            self.session.state(),
            self.session.generation(),
            self.session.revision(),
        )
    }
    pub fn observe_space(&mut self, frame: SpaceFrame) -> RuleResult {
        if frame.generation != self.session.generation().to_string()
            || frame.state_revision != self.session.revision().to_string()
            || frame.tick != self.session.state().tick
            || frame.geometry_revision != self.session.state().geometry_revision
        {
            return Err(err("observation", "Stale geometry frame"));
        }
        let requests = self.space_requests();
        let expected: BTreeSet<_> = requests.iter().map(|r| r.id.as_str()).collect();
        let actual: BTreeSet<_> = frame
            .results
            .iter()
            .map(|r| r.request_id.as_str())
            .collect();
        if expected != actual
            || actual.len() != frame.results.len()
            || frame.results.iter().any(|r| !r.valid)
            || frame.producer_id.is_empty()
            || frame.sequence.parse::<u64>().ok()
                != Some(
                    self.session
                        .state()
                        .observation_sequence
                        .get(&frame.producer_id)
                        .copied()
                        .unwrap_or(0)
                        + 1,
                )
        {
            return Err(err(
                "observation",
                "Incomplete, duplicate or invalid geometry frame",
            ));
        }
        for request in &requests {
            let answer = frame
                .results
                .iter()
                .find(|r| r.request_id == request.id)
                .unwrap();
            if answer.path_mm.len() > 512
                || answer
                    .path_mm
                    .iter()
                    .flatten()
                    .any(|n| !(-100000..=100000).contains(n))
                || answer
                    .position_mm
                    .is_some_and(|p| p.iter().any(|n| !(-100000..=100000).contains(n)))
            {
                return Err(err("observation", "Invalid geometry result coordinates"));
            }
            match request.kind.as_str() {
                "los" | "visibility" if answer.clear.is_none() || answer.visible.is_none() => {
                    return Err(err("observation", "Incomplete visibility observation"))
                }
                "swept_path" if answer.clear.is_none() => {
                    return Err(err("observation", "Incomplete sweep observation"))
                }
                "path"
                    if answer.clear.is_none()
                        || answer.clear == Some(true)
                            && (answer.path_mm.first() != Some(&request.from_mm)
                                || answer.path_mm.last() != Some(&request.to_mm))
                        || answer.clear == Some(false) && !answer.path_mm.is_empty() =>
                {
                    return Err(err("observation", "Incomplete path observation"))
                }
                _ => {}
            }
        }
        if self
            .staged
            .as_ref()
            .is_some_and(|old| serde_json::to_value(old).ok() != serde_json::to_value(&frame).ok())
        {
            return Err(err(
                "observation",
                "Staged sequence reused with different results",
            ));
        }
        self.staged = Some(frame);
        Ok(())
    }
    fn ai_orders(&mut self) -> RuleResult {
        for actor in content::INITIATIVE {
            let commands = self.session.ai_commands(&self.ai, actor)?;
            for command in commands {
                let receipt = self.session.submit(Envelope {
                    generation: self.session.generation(),
                    epoch: self.session.epoch(),
                    id: format!("ai:{}:{actor}", self.session.ledger_sequence() + 1),
                    lease: self.ai.clone(),
                    expected_revision: self.session.revision(),
                    actor: Some(actor.into()),
                    payload: command,
                })?;
                if receipt.status == Status::Accepted {
                    self.staged = None;
                }
            }
        }
        Ok(())
    }
    pub fn advance(&mut self, ticks: u32) -> RuleResult<Value> {
        if ticks > 100 {
            return Err(err("ticks", "At most 100 ticks per call"));
        }
        let mut consumed = 0;
        let mut reason = "complete";
        if ticks == 0 && !self.session.restored_paused() {
            // Planning still needs fresh visibility after a deployment. A zero-
            // time refresh commits geometry only, including during contact pause.
            if let Some(frame) = self.staged.take() {
                let receipt = self.session.advance(Envelope {
                    generation: self.session.generation(),
                    epoch: self.session.epoch(),
                    id: format!("geometry:{}", self.session.ledger_sequence() + 1),
                    lease: self.system.clone(),
                    expected_revision: self.session.revision(),
                    actor: None,
                    payload: CommandStep {
                        frame: Some(frame),
                        pump_only: false,
                        observation_only: true,
                    },
                })?;
                if receipt.status != Status::Accepted {
                    reason = "rejected";
                }
            } else {
                reason = "waiting_for_space";
            }
        } else if self.session.restored_paused() || !self.session.state().pauses.is_empty() {
            reason = "paused";
        } else {
            self.ai_orders()?;
            let pump = self.session.state().actors.values().any(|a| {
                a.active.is_none() && !a.queue.is_empty() && a.ready <= self.session.state().tick
            });
            if let Some(frame) = self.staged.take() {
                let step = CommandStep {
                    frame: Some(frame),
                    pump_only: pump,
                    observation_only: false,
                };
                let receipt = self.session.advance(Envelope {
                    generation: self.session.generation(),
                    epoch: self.session.epoch(),
                    id: format!("tick:{}", self.session.ledger_sequence() + 1),
                    lease: self.system.clone(),
                    expected_revision: self.session.revision(),
                    actor: None,
                    payload: step,
                })?;
                if receipt.status == Status::Accepted {
                    consumed = if pump { 0 } else { 1 };
                } else {
                    reason = "rejected";
                }
            } else {
                reason = "waiting_for_space";
            }
        }
        let mut view = self.view();
        view["space"] = json!({"waiting":reason=="waiting_for_space","reason":if reason=="waiting_for_space"{Some(json!({"code":reason,"message":"Waiting for authoritative garden geometry"}))}else{None}});
        Ok(
            json!({"consumed_ticks":consumed,"remaining_ticks":ticks.saturating_sub(consumed),"stop_reason":reason,"view":view}),
        )
    }
    pub fn save_json(&self) -> RuleResult<String> {
        Ok(serde_json::to_string(&Save {
            schema: "command.save/v1".into(),
            session: self.session.save_json()?,
            checkpoint: self.checkpoint.clone(),
        })?)
    }
    pub fn restore_json(&mut self, source: &str) -> RuleResult<Value> {
        let save: Save = serde_json::from_str(source)?;
        if save.schema != "command.save/v1" {
            return Err(err("save", "Unsupported Command save"));
        }
        if let Some(checkpoint) = &save.checkpoint {
            let mut candidate = Self::new(0)?;
            candidate
                .session
                .restore_json(checkpoint, &mut candidate.host)?;
        }
        self.session.restore_json(&save.session, &mut self.host)?;
        self.checkpoint = save.checkpoint;
        self.staged = None;
        self.leases()?;
        self.restore_token = Some(format!("restore:{}", self.session.generation()));
        Ok(self.view())
    }
    /// Exact authored geometry helper for headless integration tests and deterministic previews.
    pub fn observe_fixture(&mut self) -> RuleResult {
        let sequence = self
            .session
            .state()
            .observation_sequence
            .get("headless-garden")
            .copied()
            .unwrap_or(0)
            + 1;
        let frame = space::fixture_frame(&self.space_requests(), sequence)?;
        self.observe_space(frame)
    }
}

#[cfg(test)]
mod tests;
