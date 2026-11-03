//! Typed, deterministic transaction kernel; game mechanics belong to registered profiles.
use crate::rpg::{EntityId, RpgState, ServiceError};
use serde::{de::DeserializeOwned, Deserialize, Serialize};
use serde_json::Value;
use std::collections::{hash_map::RandomState, BTreeMap, BTreeSet};
use std::hash::BuildHasher;
use std::sync::atomic::{AtomicU64, Ordering};

pub const RUNTIME_SCHEMA: u32 = 2;
pub type RuleResult<T = ()> = Result<T, RuleError>;

mod manifest;
pub use manifest::{Manifest, ProviderSpec};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "audiences", rename_all = "snake_case")]
pub enum Visibility {
    Public,
    Only(BTreeSet<String>),
}
impl Visibility {
    pub fn only(audience: impl Into<String>) -> Self {
        Self::Only(BTreeSet::from([audience.into()]))
    }
    pub fn permits(&self, audience: &str) -> bool {
        match self {
            Self::Public => true,
            Self::Only(ids) => ids.contains(audience),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Reason {
    pub code: String,
    pub message: String,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RuleError {
    pub reason: Reason,
    pub visibility: Visibility,
}
impl RuleError {
    pub fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            reason: Reason {
                code: code.into(),
                message: message.into(),
            },
            visibility: Visibility::Public,
        }
    }
    pub fn private(mut self, audience: impl Into<String>) -> Self {
        self.visibility = Visibility::only(audience);
        self
    }
    fn observed(&self, audience: &str) -> Reason {
        if self.visibility.permits(audience) {
            self.reason.clone()
        } else {
            Reason {
                code: "unavailable".into(),
                message: "Action unavailable".into(),
            }
        }
    }
}
impl std::fmt::Display for RuleError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.reason.code, self.reason.message)
    }
}
impl std::error::Error for RuleError {}
impl From<ServiceError> for RuleError {
    fn from(e: ServiceError) -> Self {
        Self::new("service", e.0)
    }
}
impl From<serde_json::Error> for RuleError {
    fn from(e: serde_json::Error) -> Self {
        Self::new("serialization", e.to_string())
    }
}

/// Versioned SplitMix64 stream. No wall clock, process RNG or Godot values enter rule rolls.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Entropy {
    algorithm: String,
    state: u64,
    draws: u64,
}
impl Entropy {
    pub fn seeded(seed: u64) -> Self {
        Self {
            algorithm: "splitmix64/v1".into(),
            state: seed,
            draws: 0,
        }
    }
    pub fn draws(&self) -> u64 {
        self.draws
    }
    pub fn next_u64(&mut self) -> RuleResult<u64> {
        self.draws = self
            .draws
            .checked_add(1)
            .ok_or_else(|| RuleError::new("entropy", "Entropy cursor exhausted"))?;
        self.state = self.state.wrapping_add(0x9e3779b97f4a7c15);
        let mut z = self.state;
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
        Ok(z ^ (z >> 31))
    }
    pub fn below(&mut self, upper: u64) -> RuleResult<u64> {
        if upper == 0 {
            return Err(RuleError::new("entropy", "Empty random range"));
        }
        let threshold = upper.wrapping_neg() % upper;
        loop {
            let value = self.next_u64()?;
            if value >= threshold {
                return Ok(value % upper);
            }
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Role {
    Player,
    Ai,
    System,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Principal {
    pub id: String,
    pub role: Role,
}
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct LeaseScope {
    pub actors: BTreeSet<EntityId>,
    pub system_commands: bool,
    pub advance: bool,
}
#[derive(Clone, Debug)]
struct Lease {
    principal: Principal,
    audience: String,
    scope: LeaseScope,
}

/// Host-only authority issuer. Never deserialize this object or expose lease issuance as a game command.
pub struct HostAuthority {
    salt: RandomState,
    serial: u64,
}
impl Default for HostAuthority {
    fn default() -> Self {
        Self {
            salt: RandomState::new(),
            serial: 0,
        }
    }
}
impl HostAuthority {
    fn generation(&mut self) -> RuleResult<u64> {
        static GENERATION: AtomicU64 = AtomicU64::new(1);
        GENERATION
            .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |n| n.checked_add(1))
            .map_err(|_| RuleError::new("generation", "Host generation exhausted"))
    }
    fn token(&mut self, generation: u64) -> RuleResult<String> {
        self.serial = self
            .serial
            .checked_add(1)
            .ok_or_else(|| RuleError::new("lease", "Host lease counter exhausted"))?;
        Ok(format!(
            "{:016x}{:016x}",
            self.salt.hash_one((generation, self.serial, 0_u8)),
            self.salt.hash_one((generation, self.serial, 1_u8))
        ))
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Envelope<T> {
    pub generation: u64,
    pub epoch: u64,
    pub id: String,
    pub lease: String,
    pub expected_revision: u64,
    pub actor: Option<EntityId>,
    pub payload: T,
}

#[derive(Clone, Debug)]
pub struct ParticipantAuthority {
    actors: BTreeSet<EntityId>,
}
impl ParticipantAuthority {
    pub fn can_command(&self, actor: &str) -> bool {
        self.actors.contains(actor)
    }
    pub fn require<'a>(&self, actors: impl IntoIterator<Item = &'a str>) -> RuleResult {
        if actors.into_iter().any(|a| !self.actors.contains(a)) {
            return Err(RuleError::new(
                "authority",
                "Required participant outside control lease",
            ));
        }
        Ok(())
    }
}

pub struct ReadContext<'a, S> {
    pub state: &'a S,
    pub rpg: &'a RpgState,
    pub revision: u64,
    pub epoch: u64,
    pub observer: &'a str,
    pub principal: &'a Principal,
    pub authority: ParticipantAuthority,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Event {
    pub kind: String,
    pub payload: Value,
    pub visibility: Visibility,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ObservedEvent {
    pub kind: String,
    pub payload: Value,
}

/// A private candidate for one step. Dropping it discards every mutation, roll and observation.
pub struct Transaction<S> {
    pub state: S,
    pub rpg: RpgState,
    pub entropy: Entropy,
    pub principal: Principal,
    pub observer: String,
    pub revision: u64,
    pub epoch: u64,
    authority: ParticipantAuthority,
    events: Vec<Event>,
    occurrences: BTreeSet<String>,
    observation_positions: BTreeMap<String, u64>,
}
impl<S> Transaction<S> {
    pub fn authority(&self) -> &ParticipantAuthority {
        &self.authority
    }

    pub fn emit(
        &mut self,
        kind: impl Into<String>,
        payload: impl Serialize,
        visibility: Visibility,
    ) -> RuleResult {
        let kind = kind.into();
        if kind.is_empty() {
            return Err(RuleError::new("event", "Empty event kind"));
        }
        self.events.push(Event {
            kind,
            payload: serde_json::to_value(payload)?,
            visibility,
        });
        Ok(())
    }
    /// Use a profile-defined action/stage/target/component key before an effect; duplicate returns false.
    pub fn occurrence(&mut self, key: impl Into<String>) -> RuleResult<bool> {
        let key = key.into();
        if key.is_empty() {
            return Err(RuleError::new("occurrence", "Empty occurrence key"));
        }
        Ok(self.occurrences.insert(key))
    }
    /// Ordered canonical observation consumption. Gaps reject; repeated deliveries return false.
    pub fn observe(&mut self, producer: &str, position: u64) -> RuleResult<bool> {
        if producer.is_empty() || position == 0 {
            return Err(RuleError::new(
                "observation",
                "Invalid observation position",
            ));
        }
        let old = self
            .observation_positions
            .get(producer)
            .copied()
            .unwrap_or(0);
        if position <= old {
            return Ok(false);
        }
        if old.checked_add(1) != Some(position) {
            return Err(RuleError::new("observation", "Observation sequence gap"));
        }
        self.observation_positions.insert(producer.into(), position);
        Ok(true)
    }
}

pub struct RestoreContext<'a, S> {
    pub state: &'a S,
    pub rpg: &'a RpgState,
    pub epoch: u64,
    pub revision: u64,
    pub ledger_sequence: u64,
    pub entropy_draws: u64,
    pub occurrences: &'a BTreeSet<String>,
    pub observation_positions: &'a BTreeMap<String, u64>,
}

pub trait Profile {
    type State: Clone + Serialize + DeserializeOwned;
    type Command: Clone + Serialize + DeserializeOwned;
    type Advance: Clone + Serialize + DeserializeOwned;
    type View: Serialize;
    type Preview: Serialize;
    fn manifest(&self) -> Manifest;
    /// Controlled participants only; effect targets must not be included merely because they are targets.
    fn participants(&self, actor: Option<&str>, _command: &Self::Command) -> BTreeSet<EntityId> {
        actor.map(str::to_owned).into_iter().collect()
    }
    /// Additional cross-ledger checks; `validate` always runs before this hook.
    fn validate_restore(&self, _candidate: &RestoreContext<'_, Self::State>) -> RuleResult {
        Ok(())
    }
    fn preview(
        &self,
        ctx: &ReadContext<'_, Self::State>,
        actor: Option<&str>,
        command: &Self::Command,
    ) -> RuleResult<Self::Preview>;
    fn prepare_command(
        &self,
        tx: &mut Transaction<Self::State>,
        actor: Option<&str>,
        command: &Self::Command,
    ) -> RuleResult;
    fn prepare_advance(
        &self,
        tx: &mut Transaction<Self::State>,
        advance: &Self::Advance,
    ) -> RuleResult;
    fn project(&self, ctx: &ReadContext<'_, Self::State>) -> Self::View;
    fn validate(&self, state: &Self::State, rpg: &RpgState) -> RuleResult;
    fn decide_ai(&self, _ctx: &ReadContext<'_, Self::State>, _actor: &str) -> Vec<Self::Command> {
        Vec::new()
    }
    /// Required before receipt/occurrence epoch compaction. Default is deliberately conservative.
    fn quiescent(&self, _state: &Self::State, _rpg: &RpgState) -> bool {
        false
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Status {
    Accepted,
    Rejected,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub id: String,
    pub epoch: u64,
    pub ledger_sequence: u64,
    pub revision: u64,
    pub status: Status,
    pub reason: Option<Reason>,
    pub events: Vec<ObservedEvent>,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
enum Operation {
    Command,
    Advance,
}
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Fingerprint {
    operation: Operation,
    actor: Option<EntityId>,
    participants: BTreeSet<EntityId>,
    principal: Principal,
    expected_revision: u64,
    payload: Value,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct StoredReceipt {
    fingerprint: Fingerprint,
    principal: Principal,
    id: String,
    epoch: u64,
    ledger_sequence: u64,
    revision: u64,
    status: Status,
    reason: Option<RuleError>,
    events: Vec<Event>,
}
impl StoredReceipt {
    fn observed(&self, audience: &str) -> Receipt {
        Receipt {
            id: self.id.clone(),
            epoch: self.epoch,
            ledger_sequence: self.ledger_sequence,
            revision: self.revision,
            status: self.status.clone(),
            reason: self.reason.as_ref().map(|r| r.observed(audience)),
            events: self
                .events
                .iter()
                .filter(|e| e.visibility.permits(audience))
                .map(|e| ObservedEvent {
                    kind: e.kind.clone(),
                    payload: e.payload.clone(),
                })
                .collect(),
        }
    }
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct SaveDocument<S> {
    schema: u32,
    manifest: Manifest,
    session_id: String,
    epoch: u64,
    revision: u64,
    ledger_sequence: u64,
    epoch_base_ledger: u64,
    epoch_base_revision: u64,
    state: S,
    rpg: RpgState,
    entropy: Entropy,
    receipts: BTreeMap<String, StoredReceipt>,
    occurrences: BTreeSet<String>,
    observation_positions: BTreeMap<String, u64>,
}

/// Host attachment for a registered, typed profile. Authority remains outside the save.
///
/// ```no_run
/// use oathshaper_core::{rpg::RpgState, runtime::*};
/// use std::collections::BTreeSet;
/// fn attach<P: Profile>(profile: P, state: P::State, rpg: RpgState,
///                       command: P::Command) -> RuleResult<String> {
///     let mut host = HostAuthority::default();
///     let mut session = Session::new(profile, state, rpg, 42, "practice-01", &mut host)?;
///     let lease = session.issue_lease(&mut host,
///         Principal { id: "local-player".into(), role: Role::Player }, "player",
///         LeaseScope { actors: BTreeSet::from(["student".into()]),
///                      system_commands: false, advance: false })?;
///     let receipt = session.submit(Envelope {
///         generation: session.generation(), epoch: session.epoch(),
///         id: "intent-1".into(), lease, expected_revision: session.revision(),
///         actor: Some("student".into()), payload: command,
///     })?;
///     // Inspect receipt.status: admitted rule rejections return a durable receipt too.
///     assert!(matches!(receipt.status, Status::Accepted | Status::Rejected));
///     session.save_json()
/// }
/// ```
pub struct Session<P: Profile> {
    profile: P,
    manifest: Manifest,
    session_id: String,
    state: P::State,
    rpg: RpgState,
    entropy: Entropy,
    generation: u64,
    epoch: u64,
    revision: u64,
    ledger_sequence: u64,
    epoch_base_ledger: u64,
    epoch_base_revision: u64,
    leases: BTreeMap<String, Lease>,
    receipts: BTreeMap<String, StoredReceipt>,
    occurrences: BTreeSet<String>,
    observation_positions: BTreeMap<String, u64>,
    restored_paused: bool,
}

impl<P: Profile> Session<P> {
    pub fn new(
        profile: P,
        state: P::State,
        rpg: RpgState,
        seed: u64,
        session_id: impl Into<String>,
        host: &mut HostAuthority,
    ) -> RuleResult<Self> {
        let manifest = profile.manifest();
        manifest.validate()?;
        rpg.validate()?;
        manifest.validate_rpg(&rpg)?;
        profile.validate(&state, &rpg)?;
        let session_id = session_id.into();
        if session_id.is_empty() {
            return Err(RuleError::new("session", "Empty session identity"));
        }
        Ok(Self {
            profile,
            manifest,
            session_id,
            state,
            rpg,
            entropy: Entropy::seeded(seed),
            generation: host.generation()?,
            epoch: 1,
            revision: 0,
            ledger_sequence: 0,
            epoch_base_ledger: 0,
            epoch_base_revision: 0,
            leases: BTreeMap::new(),
            receipts: BTreeMap::new(),
            occurrences: BTreeSet::new(),
            observation_positions: BTreeMap::new(),
            restored_paused: false,
        })
    }
    pub fn generation(&self) -> u64 {
        self.generation
    }
    pub fn epoch(&self) -> u64 {
        self.epoch
    }
    pub fn revision(&self) -> u64 {
        self.revision
    }
    pub fn ledger_sequence(&self) -> u64 {
        self.ledger_sequence
    }
    pub fn entropy_draws(&self) -> u64 {
        self.entropy.draws()
    }
    pub fn restored_paused(&self) -> bool {
        self.restored_paused
    }
    /// Trusted Rust access; never serialize this directly to an observer-facing bridge.
    pub fn state(&self) -> &P::State {
        &self.state
    }
    pub fn rpg(&self) -> &RpgState {
        &self.rpg
    }
    pub fn manifest(&self) -> &Manifest {
        &self.manifest
    }
    /// Host-only methods. Lease tokens are local capabilities, not a network authentication protocol.
    pub fn issue_lease(
        &mut self,
        host: &mut HostAuthority,
        principal: Principal,
        audience: impl Into<String>,
        scope: LeaseScope,
    ) -> RuleResult<String> {
        let audience = audience.into();
        if principal.id.is_empty()
            || audience.is_empty()
            || scope.actors.iter().any(String::is_empty)
        {
            return Err(RuleError::new("lease", "Invalid lease scope"));
        }
        let token = host.token(self.generation)?;
        self.leases.insert(
            token.clone(),
            Lease {
                principal,
                audience,
                scope,
            },
        );
        Ok(token)
    }
    pub fn revoke_lease(&mut self, token: &str) {
        self.leases.remove(token);
    }
    pub fn resume_after_restore(&mut self) {
        self.restored_paused = false;
    }
    /// Host-only restore acknowledgement with ordinary command admission.
    /// The host must choose an acknowledgement validated by its profile; this
    /// method does not authorize arbitrary user commands to bypass restore.
    /// A rejection, admission error or historical cached receipt cannot release
    /// the restore barrier. The profile state and the barrier commit together.
    pub fn resume_and_submit(&mut self, envelope: Envelope<P::Command>) -> RuleResult<Receipt> {
        let was_paused = self.restored_paused;
        let revision = self.revision;
        self.restored_paused = false;
        let result = self.submit(envelope);
        let committed = matches!(&result, Ok(receipt) if receipt.status == Status::Accepted)
            && self.revision > revision;
        if was_paused && !committed {
            self.restored_paused = true;
        }
        result
    }
    fn lease(&self, token: &str) -> RuleResult<&Lease> {
        self.leases
            .get(token)
            .ok_or_else(|| RuleError::new("authority", "Unknown or revoked control lease"))
    }
    fn context<'a>(&'a self, lease: &'a Lease) -> ReadContext<'a, P::State> {
        ReadContext {
            state: &self.state,
            rpg: &self.rpg,
            revision: self.revision,
            epoch: self.epoch,
            observer: &lease.audience,
            principal: &lease.principal,
            authority: ParticipantAuthority {
                actors: lease.scope.actors.clone(),
            },
        }
    }
    pub fn view(&self, token: &str) -> RuleResult<P::View> {
        Ok(self.profile.project(&self.context(self.lease(token)?)))
    }
    fn actor_allowed(lease: &Lease, actor: Option<&str>) -> bool {
        actor.map_or(lease.scope.system_commands, |actor| {
            lease.scope.actors.contains(actor)
        })
    }
    pub fn preview(
        &self,
        token: &str,
        actor: Option<&str>,
        command: &P::Command,
    ) -> Result<P::Preview, Reason> {
        let lease = self.lease(token).map_err(|e| e.reason)?;
        if !Self::actor_allowed(lease, actor) {
            return Err(RuleError::new("authority", "Actor outside control lease").reason);
        }
        ParticipantAuthority {
            actors: lease.scope.actors.clone(),
        }
        .require(
            self.profile
                .participants(actor, command)
                .iter()
                .map(String::as_str),
        )
        .map_err(|e| e.reason)?;
        self.profile
            .preview(&self.context(lease), actor, command)
            .map_err(|e| e.observed(&lease.audience))
    }
    pub fn ai_commands(&self, token: &str, actor: &str) -> RuleResult<Vec<P::Command>> {
        let lease = self.lease(token)?;
        if lease.principal.role != Role::Ai || !lease.scope.actors.contains(actor) {
            return Err(RuleError::new(
                "authority",
                "AI actor outside control lease",
            ));
        }
        if self.restored_paused {
            return Ok(Vec::new());
        }
        Ok(self.profile.decide_ai(&self.context(lease), actor))
    }
    pub fn submit(&mut self, envelope: Envelope<P::Command>) -> RuleResult<Receipt> {
        let mut participants = self
            .profile
            .participants(envelope.actor.as_deref(), &envelope.payload);
        participants.extend(envelope.actor.iter().cloned());
        self.execute(envelope, false, participants, |p, tx, actor, command| {
            p.prepare_command(tx, actor, command)
        })
    }
    pub fn advance(&mut self, envelope: Envelope<P::Advance>) -> RuleResult<Receipt> {
        self.execute(envelope, true, BTreeSet::new(), |p, tx, _, advance| {
            p.prepare_advance(tx, advance)
        })
    }
    fn execute<T: Serialize>(
        &mut self,
        envelope: Envelope<T>,
        advance: bool,
        participants: BTreeSet<EntityId>,
        prepare: impl FnOnce(&P, &mut Transaction<P::State>, Option<&str>, &T) -> RuleResult,
    ) -> RuleResult<Receipt> {
        if envelope.generation != self.generation || envelope.epoch != self.epoch {
            return Err(RuleError::new(
                "generation",
                "Stale generation or closed epoch",
            ));
        }
        let lease = self.lease(&envelope.lease)?.clone();
        if (advance && (!lease.scope.advance || envelope.actor.is_some()))
            || (!advance && !Self::actor_allowed(&lease, envelope.actor.as_deref()))
        {
            return Err(RuleError::new(
                "authority",
                "Operation outside control lease",
            ));
        }
        ParticipantAuthority {
            actors: lease.scope.actors.clone(),
        }
        .require(participants.iter().map(String::as_str))?;
        if envelope.id.is_empty() {
            return Err(RuleError::new("command_id", "Empty command identity"));
        }
        let fingerprint = Fingerprint {
            operation: if advance {
                Operation::Advance
            } else {
                Operation::Command
            },
            actor: envelope.actor.clone(),
            participants,
            principal: lease.principal.clone(),
            expected_revision: envelope.expected_revision,
            payload: serde_json::to_value(&envelope.payload)?,
        };
        if let Some(old) = self.receipts.get(&envelope.id) {
            if old.fingerprint != fingerprint {
                return Err(RuleError::new(
                    "fingerprint",
                    "Command identity reused with changed semantics",
                ));
            }
            return Ok(old.observed(&lease.audience));
        }
        // After admission, even stale-revision/resource/paused rejections have one durable receipt.
        let next_ledger = self
            .ledger_sequence
            .checked_add(1)
            .ok_or_else(|| RuleError::new("ledger", "Receipt ledger exhausted"))?;
        let mut tx = Transaction {
            state: self.state.clone(),
            rpg: self.rpg.clone(),
            entropy: self.entropy.clone(),
            principal: lease.principal.clone(),
            observer: lease.audience.clone(),
            revision: self.revision,
            epoch: self.epoch,
            authority: ParticipantAuthority {
                actors: lease.scope.actors.clone(),
            },
            events: Vec::new(),
            occurrences: self.occurrences.clone(),
            observation_positions: self.observation_positions.clone(),
        };
        let result = if envelope.expected_revision != self.revision {
            Err(RuleError::new("revision", "Stale gameplay revision"))
        } else if self.restored_paused {
            Err(RuleError::new(
                "paused",
                "Resume the restored session before committing",
            ))
        } else {
            prepare(
                &self.profile,
                &mut tx,
                envelope.actor.as_deref(),
                &envelope.payload,
            )
            .and_then(|()| tx.rpg.validate().map_err(RuleError::from))
            .and_then(|()| self.manifest.validate_rpg(&tx.rpg))
            .and_then(|()| self.profile.validate(&tx.state, &tx.rpg))
            .and_then(|()| {
                self.revision
                    .checked_add(1)
                    .map(|_| ())
                    .ok_or_else(|| RuleError::new("revision", "Gameplay revision exhausted"))
            })
        };
        let (status, reason, events) = match result {
            Ok(()) => {
                self.state = tx.state;
                self.rpg = tx.rpg;
                self.entropy = tx.entropy;
                self.occurrences = tx.occurrences;
                self.observation_positions = tx.observation_positions;
                self.revision += 1;
                (Status::Accepted, None, tx.events)
            }
            Err(error) => (Status::Rejected, Some(error), Vec::new()),
        };
        self.ledger_sequence = next_ledger;
        let stored = StoredReceipt {
            fingerprint,
            principal: lease.principal,
            id: envelope.id.clone(),
            epoch: self.epoch,
            ledger_sequence: next_ledger,
            revision: self.revision,
            status,
            reason,
            events,
        };
        let observed = stored.observed(&lease.audience);
        self.receipts.insert(envelope.id, stored);
        Ok(observed)
    }
    /// Read-only lifecycle barrier. The GameSession owns the later destination activation/swap.
    pub fn prepare_transition<T>(
        &self,
        prepare: impl FnOnce(&P::State, &RpgState) -> RuleResult<T>,
    ) -> RuleResult<T> {
        self.ensure_quiescent()?;
        prepare(&self.state, &self.rpg)
    }
    pub fn ensure_quiescent(&self) -> RuleResult {
        if !self.profile.quiescent(&self.state, &self.rpg) || !self.rpg.claims().is_empty() {
            return Err(RuleError::new(
                "pending",
                "Cannot compact an epoch with pending operations",
            ));
        }
        Ok(())
    }
    pub fn close_epoch(&mut self) -> RuleResult {
        self.ensure_quiescent()?;
        let next = self
            .epoch
            .checked_add(1)
            .ok_or_else(|| RuleError::new("epoch", "Epoch exhausted"))?;
        self.epoch = next;
        self.epoch_base_ledger = self.ledger_sequence;
        self.epoch_base_revision = self.revision;
        self.receipts.clear();
        self.occurrences.clear();
        // Observation producer positions and gameplay/narrative state are not reset by compaction.
        Ok(())
    }
    pub fn save_json(&self) -> RuleResult<String> {
        Ok(serde_json::to_string(&SaveDocument {
            schema: RUNTIME_SCHEMA,
            manifest: self.manifest.clone(),
            session_id: self.session_id.clone(),
            epoch: self.epoch,
            revision: self.revision,
            ledger_sequence: self.ledger_sequence,
            epoch_base_ledger: self.epoch_base_ledger,
            epoch_base_revision: self.epoch_base_revision,
            state: &self.state,
            rpg: self.rpg.clone(),
            entropy: self.entropy.clone(),
            receipts: self.receipts.clone(),
            occurrences: self.occurrences.clone(),
            observation_positions: self.observation_positions.clone(),
        })?)
    }
    pub fn restore_json(&mut self, source: &str, host: &mut HostAuthority) -> RuleResult {
        let save: SaveDocument<P::State> = serde_json::from_str(source)?;
        if save.schema != RUNTIME_SCHEMA
            || save.manifest != self.manifest
            || save.session_id != self.session_id
            || save.epoch == 0
            || save.entropy.algorithm != "splitmix64/v1"
        {
            return Err(RuleError::new(
                "save",
                "Unsupported or incompatible runtime save",
            ));
        }
        save.rpg.validate()?;
        self.manifest.validate_rpg(&save.rpg)?;
        self.profile.validate(&save.state, &save.rpg)?;
        self.profile.validate_restore(&RestoreContext {
            state: &save.state,
            rpg: &save.rpg,
            epoch: save.epoch,
            revision: save.revision,
            ledger_sequence: save.ledger_sequence,
            entropy_draws: save.entropy.draws(),
            occurrences: &save.occurrences,
            observation_positions: &save.observation_positions,
        })?;
        if save.revision > save.ledger_sequence
            || save.epoch_base_revision > save.epoch_base_ledger
            || (save.epoch == 1 && (save.epoch_base_ledger != 0 || save.epoch_base_revision != 0))
            || save.epoch_base_ledger > save.ledger_sequence
            || save.epoch_base_revision > save.revision
        {
            return Err(RuleError::new("save", "Invalid epoch ledger baseline"));
        }
        let mut receipts: Vec<_> = save.receipts.iter().collect();
        receipts.sort_by_key(|(_, receipt)| receipt.ledger_sequence);
        let mut sequence = save.epoch_base_ledger;
        let mut revision = save.epoch_base_revision;
        for (id, receipt) in receipts {
            sequence = sequence
                .checked_add(1)
                .ok_or_else(|| RuleError::new("save", "Ledger overflow"))?;
            let fp = &receipt.fingerprint;
            if id.is_empty()
                || id != &receipt.id
                || receipt.epoch != save.epoch
                || receipt.ledger_sequence != sequence
                || receipt.principal.id.is_empty()
                || fp.principal != receipt.principal
                || fp.actor.as_ref().is_some_and(String::is_empty)
                || fp.participants.iter().any(String::is_empty)
            {
                return Err(RuleError::new(
                    "save",
                    "Invalid receipt identity or fingerprint",
                ));
            }
            match fp.operation {
                Operation::Command => {
                    let command: P::Command = serde_json::from_value(fp.payload.clone())?;
                    let mut participants = self.profile.participants(fp.actor.as_deref(), &command);
                    participants.extend(fp.actor.iter().cloned());
                    if participants != fp.participants
                        || serde_json::to_value(command)? != fp.payload
                    {
                        return Err(RuleError::new("save", "Noncanonical command fingerprint"));
                    }
                }
                Operation::Advance => {
                    let advance: P::Advance = serde_json::from_value(fp.payload.clone())?;
                    if fp.actor.is_some()
                        || !fp.participants.is_empty()
                        || serde_json::to_value(advance)? != fp.payload
                    {
                        return Err(RuleError::new("save", "Invalid advance fingerprint"));
                    }
                }
            }
            match receipt.status {
                Status::Accepted => {
                    if fp.expected_revision != revision || receipt.reason.is_some() {
                        return Err(RuleError::new("save", "Invalid accepted receipt"));
                    }
                    revision = revision
                        .checked_add(1)
                        .ok_or_else(|| RuleError::new("save", "Revision overflow"))?;
                }
                Status::Rejected => {
                    if receipt.reason.is_none() || !receipt.events.is_empty() {
                        return Err(RuleError::new("save", "Invalid rejected receipt"));
                    }
                }
            }
            if receipt.revision != revision
                || receipt.events.iter().any(|event| event.kind.is_empty())
                || receipt
                    .reason
                    .as_ref()
                    .is_some_and(|r| r.reason.code.is_empty())
            {
                return Err(RuleError::new("save", "Invalid receipt revision or event"));
            }
        }
        if sequence != save.ledger_sequence || revision != save.revision {
            return Err(RuleError::new("save", "Receipt ledger is incomplete"));
        }
        if save.occurrences.iter().any(String::is_empty)
            || save
                .observation_positions
                .iter()
                .any(|(p, n)| p.is_empty() || *n == 0)
        {
            return Err(RuleError::new(
                "save",
                "Invalid occurrence or observation ledger",
            ));
        }
        let generation = host.generation()?;
        self.state = save.state;
        self.rpg = save.rpg;
        self.entropy = save.entropy;
        self.epoch = save.epoch;
        self.revision = save.revision;
        self.ledger_sequence = save.ledger_sequence;
        self.epoch_base_ledger = save.epoch_base_ledger;
        self.epoch_base_revision = save.epoch_base_revision;
        self.receipts = save.receipts;
        self.occurrences = save.occurrences;
        self.observation_positions = save.observation_positions;
        self.generation = generation;
        self.leases.clear();
        self.restored_paused = true;
        Ok(())
    }
}
