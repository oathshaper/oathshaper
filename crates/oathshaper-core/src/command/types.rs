use crate::rpg::Grant;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Target {
    pub kind: String,
    pub actor_id: Option<String>,
    pub position: Option<[f64; 2]>,
}
impl Target {
    pub fn actor(id: &str) -> Self {
        Self {
            kind: "actor".into(),
            actor_id: Some(id.into()),
            position: None,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SlotChange {
    pub slot_id: String,
    pub item_id: Option<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RankChoice {
    pub id: String,
    pub ranks: u32,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PowerChoice {
    pub id: String,
    pub rank: u32,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AttributeChoice {
    pub id: String,
    pub amount: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BaseAttribute {
    pub id: String,
    pub value: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LevelAllocation {
    pub class_id: String,
    pub skills: Vec<RankChoice>,
    pub feats: Vec<String>,
    pub powers: Vec<PowerChoice>,
    pub attributes: Vec<AttributeChoice>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "kind", deny_unknown_fields)]
pub enum CommandIntent {
    #[serde(rename = "target.select")]
    TargetSelect { target_id: Option<String> },
    #[serde(rename = "host.revoke_item")]
    RevokeItem { item_id: String },
    #[serde(rename = "progression.respec")]
    Respec {
        actor_id: String,
        expected_build_version: String,
        initial_attributes: Vec<BaseAttribute>,
        levels: Vec<LevelAllocation>,
        unbind_item_ids: Vec<String>,
    },
    #[serde(rename = "dismantle")]
    Dismantle { actor_id: String, item_id: String },
    #[serde(rename = "upgrade.apply")]
    Upgrade {
        actor_id: String,
        host_item_id: String,
        upgrade_item_id: String,
    },

    #[serde(rename = "host.resume_restore")]
    ResumeRestore { token: String },
    #[serde(rename = "party.select")]
    Select { actor_id: String },
    #[serde(rename = "party.possess")]
    Possess { actor_id: String, select: bool },
    #[serde(rename = "party.inspect")]
    Inspect { actor_id: String },
    #[serde(rename = "party.deploy")]
    Deploy { actor_ids: Vec<String> },
    #[serde(rename = "party.camera")]
    Camera { actor_id: Option<String> },
    #[serde(rename = "pause.acquire")]
    Pause { owner: String, context_id: String },
    #[serde(rename = "pause.release")]
    Release { token: String },
    #[serde(rename = "pause.acknowledge")]
    Acknowledge { token: String },
    #[serde(rename = "encounter.start")]
    Start { encounter_id: String },
    #[serde(rename = "encounter.retry")]
    Retry { checkpoint_id: String },
    #[serde(rename = "encounter.retreat")]
    Retreat { encounter_id: String },
    #[serde(rename = "camp.enter")]
    Camp { camp_id: String },
    #[serde(rename = "camp.rest")]
    Rest { camp_id: String },
    #[serde(rename = "queue.enqueue")]
    Enqueue {
        actor_id: String,
        ability_id: String,
        source_id: String,
        target: Target,
    },
    #[serde(rename = "queue.remove")]
    Remove { actor_id: String, action_id: String },
    #[serde(rename = "queue.reorder")]
    Reorder {
        actor_id: String,
        action_ids: Vec<String>,
    },
    #[serde(rename = "queue.clear_future")]
    Clear { actor_id: String },
    #[serde(rename = "queue.stop_clear")]
    Stop {
        actor_id: String,
        confirm_paid_cost: bool,
    },
    #[serde(rename = "movement.intent")]
    Move {
        actor_id: String,
        direction: [f64; 2],
    },
    #[serde(rename = "ai.configure")]
    Ai {
        actor_id: String,
        policy: String,
        empty_policy: String,
        hold_after_orders: bool,
    },
    #[serde(rename = "equipment.apply")]
    Equip {
        actor_id: String,
        expected_binding_version: String,
        changes: Vec<SlotChange>,
        cancel_action_ids: Vec<String>,
    },
    #[serde(rename = "inventory.use")]
    Use {
        actor_id: String,
        item_id: String,
        target: Target,
    },
    #[serde(rename = "inventory.transfer")]
    Transfer {
        item_id: String,
        quantity: u32,
        from_container_id: String,
        to_container_id: String,
    },
    #[serde(rename = "progression.level")]
    Level {
        actor_id: String,
        expected_build_version: String,
        class_id: String,
        skills: Vec<RankChoice>,
        feats: Vec<String>,
        powers: Vec<PowerChoice>,
        attributes: Vec<AttributeChoice>,
        unbind_item_ids: Vec<String>,
    },
    #[serde(rename = "craft")]
    Craft { actor_id: String, recipe_id: String },
    #[serde(rename = "shop.buy")]
    Buy { stock_id: String, quantity: u32 },
    #[serde(rename = "shop.sell")]
    Sell { item_id: String, quantity: u32 },
    #[serde(rename = "skill.use")]
    Skill {
        actor_id: String,
        interaction_id: String,
    },
    #[serde(rename = "dialogue.assist")]
    Assist {
        actor_id: String,
        interaction_id: String,
        helper_id: Option<String>,
    },
    #[serde(rename = "profile.prepare_exit")]
    Exit,
}
impl CommandIntent {
    pub fn actor(&self) -> Option<&str> {
        match self {
            Self::Respec { actor_id, .. }
            | Self::Dismantle { actor_id, .. }
            | Self::Upgrade { actor_id, .. }
            | Self::Select { actor_id }
            | Self::Possess { actor_id, .. }
            | Self::Inspect { actor_id }
            | Self::Enqueue { actor_id, .. }
            | Self::Remove { actor_id, .. }
            | Self::Reorder { actor_id, .. }
            | Self::Clear { actor_id }
            | Self::Stop { actor_id, .. }
            | Self::Move { actor_id, .. }
            | Self::Ai { actor_id, .. }
            | Self::Equip { actor_id, .. }
            | Self::Use { actor_id, .. }
            | Self::Level { actor_id, .. }
            | Self::Craft { actor_id, .. }
            | Self::Skill { actor_id, .. }
            | Self::Assist { actor_id, .. } => Some(actor_id),
            _ => None,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Action {
    pub id: String,
    pub sequence: u64,
    pub ability: String,
    pub source: String,
    pub actor: String,
    pub target: Target,
    pub phase: String,
    pub activation: Option<u64>,
    pub impact: Option<u64>,
    pub recovery: Option<u64>,
    pub deadline: Option<u64>,
    pub paid: i64,
    pub paid_item: bool,
    pub ai: bool,
    pub path: Vec<[i64; 2]>,
    pub approach_travel_mm: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ActorState {
    pub id: String,
    pub name: String,
    pub faction: String,
    pub body: String,
    pub deployed: bool,
    pub guest: bool,
    pub position: [i64; 2],
    pub level: u32,
    pub classes: BTreeMap<String, u32>,
    pub attributes: BTreeMap<String, i64>,
    pub skills: BTreeMap<String, u32>,
    pub feats: Vec<String>,
    pub xp: u32,
    pub unspent: u32,
    pub unspent_feats: u32,
    pub unspent_powers: u32,
    pub unspent_attributes: u32,
    pub build_version: u64,
    pub binding_version: u64,
    pub conditions: BTreeMap<String, u64>,
    pub active: Option<Action>,
    pub queue: Vec<Action>,
    pub ready: u64,
    pub policy: String,
    pub empty_policy: String,
    pub hold: bool,
    pub direction: [f64; 2],
    pub last_reason: Option<String>,
    pub device_uses: u32,
    pub ward_remaining: i64,
    pub ward_strength: i64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Pause {
    pub owner: String,
    pub context: String,
    pub automatic: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Log {
    pub id: String,
    pub tick: u64,
    pub kind: String,
    pub actor_id: Option<String>,
    pub target_id: Option<String>,
    pub text: String,
    pub roll: Option<i64>,
    pub modifier: Option<i64>,
    pub threshold: Option<i64>,
    pub damage: Option<i64>,
    pub healing: Option<i64>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CommandState {
    pub tick: u64,
    pub phase: String,
    pub actors: BTreeMap<String, ActorState>,
    pub debt: BTreeMap<String, i64>,
    pub pauses: BTreeMap<String, Pause>,
    pub recipient: String,
    pub possessed: Option<String>,
    pub inspected: String,
    pub camera: Option<String>,
    pub serial: u64,
    pub logs: Vec<Log>,
    pub encounter: u64,
    pub outcome: Option<String>,
    pub reward: Option<String>,
    pub rest_until: Option<u64>,
    pub retreat_since: Option<u64>,
    pub retreat_requested: bool,
    pub selected_target: Option<String>,
    pub checkpoint_id: Option<String>,
    pub respec_cost: i64,
    pub upgrades: BTreeMap<String, String>,
    pub lost_grants: BTreeMap<String, Grant>,
    pub geometry_revision: String,
    pub observations: BTreeMap<String, SpaceResult>,
    pub observation_sequence: BTreeMap<String, u64>,
    pub completed: Vec<String>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SpaceRequest {
    pub id: String,
    pub generation: String,
    pub geometry_revision: String,
    pub tick: u64,
    pub state_revision: String,
    pub kind: String,
    pub actor_id: String,
    pub target_actor_id: Option<String>,
    pub from_mm: [i64; 2],
    pub to_mm: [i64; 2],
    pub radius_mm: i64,
    pub maximum_distance_mm: i64,
    pub required_for: String,
}
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct SpaceResult {
    pub request_id: String,
    pub valid: bool,
    pub reason_code: Option<String>,
    pub position_mm: Option<[i64; 2]>,
    pub visible: Option<bool>,
    pub clear: Option<bool>,
    pub path_mm: Vec<[i64; 2]>,
    pub ground_height_mm: Option<i64>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SpaceFrame {
    pub generation: String,
    pub geometry_revision: String,
    pub tick: u64,
    pub state_revision: String,
    pub producer_id: String,
    pub sequence: String,
    pub results: Vec<SpaceResult>,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CommandStep {
    pub frame: Option<SpaceFrame>,
    pub pump_only: bool,
    #[serde(default)]
    pub observation_only: bool,
}
