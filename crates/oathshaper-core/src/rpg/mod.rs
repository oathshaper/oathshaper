//! Optional ownership services. Profiles supply capacity, body, recipe and build rules.
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

pub type EntityId = String;
pub type ItemId = String;
pub type ServiceResult<T> = Result<T, ServiceError>;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ServiceError(pub String);
impl std::fmt::Display for ServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.0.fmt(f)
    }
}
impl std::error::Error for ServiceError {}
fn fail<T>(s: &str) -> ServiceResult<T> {
    Err(ServiceError(s.into()))
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Item {
    pub id: ItemId,
    pub definition: String,
    /// A profile-defined actor, shared pack, stash or world-container identity.
    pub owner: EntityId,
    pub parent: Option<ItemId>,
    pub quantity: u32,
    /// Equal keys alone do not merge instances: merge is an explicit operation.
    pub stack_key: String,
    pub protected: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum Source {
    Item {
        item: ItemId,
        equipped: bool,
    },
    /// Explicit aura source; the emitter must equip it, independently of the recipient.
    EquippedBy {
        item: ItemId,
        actor: EntityId,
    },
    Investment {
        investment: String,
    },
    Innate {
        id: String,
    },
    Temporary {
        id: String,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Grant {
    pub id: String,
    pub recipient: EntityId,
    pub ability: String,
    pub source: Source,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Investment {
    pub id: String,
    pub actor: EntityId,
    pub definition: String,
    pub awarded_at: u32,
    pub currency: String,
    pub amount: i64,
    pub prerequisites: BTreeSet<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Resource {
    pub id: String,
    pub owner: EntityId,
    pub unit: String,
    pub minimum: i64,
    pub maximum: i64,
    pub current: i64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case", deny_unknown_fields)]
pub enum ClaimTarget {
    Resource {
        resource: String,
        amount: i64,
    },
    Item {
        item: ItemId,
        quantity: u32,
    },
    Binding {
        actor: EntityId,
        slot: String,
    },
    Actor {
        actor: EntityId,
    },
    /// Shared source reads reserve no physical quantity.
    ItemRead {
        item: ItemId,
    },
    BindingRead {
        actor: EntityId,
        slot: String,
        item: ItemId,
    },
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Claim {
    pub id: String,
    pub owner: EntityId,
    pub action: String,
    pub target: ClaimTarget,
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RpgState {
    items: BTreeMap<ItemId, Item>,
    /// actor -> slot -> instance. One instance may occupy several slots of one actor.
    bindings: BTreeMap<EntityId, BTreeMap<String, ItemId>>,
    grants: BTreeMap<String, Grant>,
    investments: BTreeMap<String, Investment>,
    resources: BTreeMap<String, Resource>,
    claims: BTreeMap<String, Claim>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Mutation {
    InsertItem(Item),
    TransferItem {
        item: ItemId,
        owner: EntityId,
        parent: Option<ItemId>,
    },
    ConsumeItem {
        item: ItemId,
        quantity: u32,
    },
    SplitItem {
        item: ItemId,
        quantity: u32,
        new_id: ItemId,
    },
    MergeItems {
        from: ItemId,
        into: ItemId,
    },
    Equip {
        actor: EntityId,
        item: ItemId,
        slots: Vec<String>,
    },
    Unequip {
        actor: EntityId,
        slots: Vec<String>,
    },
    AddGrant(Grant),
    RevokeSource(Source),
    AddInvestment(Investment),
    RemoveInvestment {
        id: String,
    },
    PutResource(Resource),
    AdjustResource {
        id: String,
        delta: i64,
    },
    Reserve(Claim),
    ReleaseClaim {
        id: String,
    },
    ConsumeClaim {
        id: String,
    },
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ServiceChanges {
    pub revoked_grants: Vec<Grant>,
}

/// A profile can implement slots, Bulk, weight, physical packing, or no capacity limit.
pub trait InventoryPolicy {
    fn validate(&self, state: &RpgState) -> ServiceResult<()>;
}
impl<F: Fn(&RpgState) -> ServiceResult<()>> InventoryPolicy for F {
    fn validate(&self, state: &RpgState) -> ServiceResult<()> {
        self(state)
    }
}

/// Recipes prepare explicit inputs, currency and output instances; the service owns no recipes.
pub trait RecipePolicy {
    fn prepare(&self, state: &RpgState, actor: &str, recipe: &str) -> ServiceResult<Vec<Mutation>>;
}

impl RpgState {
    pub(crate) fn occupied_namespaces(&self) -> Vec<&'static str> {
        let mut result = Vec::new();
        for (present, namespace) in [
            (!self.items.is_empty(), "rpg.inventory"),
            (!self.bindings.is_empty(), "rpg.equipment"),
            (!self.grants.is_empty(), "rpg.grants"),
            (!self.investments.is_empty(), "rpg.progression"),
            (!self.resources.is_empty(), "rpg.resources"),
            (!self.claims.is_empty(), "rpg.claims"),
        ] {
            if present {
                result.push(namespace);
            }
        }
        result
    }
    pub fn items(&self) -> &BTreeMap<ItemId, Item> {
        &self.items
    }
    pub fn bindings(&self) -> &BTreeMap<EntityId, BTreeMap<String, ItemId>> {
        &self.bindings
    }
    pub fn grants(&self) -> &BTreeMap<String, Grant> {
        &self.grants
    }
    pub fn investments(&self) -> &BTreeMap<String, Investment> {
        &self.investments
    }
    pub fn resources(&self) -> &BTreeMap<String, Resource> {
        &self.resources
    }
    pub fn claims(&self) -> &BTreeMap<String, Claim> {
        &self.claims
    }
    pub fn has_ability(&self, actor: &str, ability: &str) -> bool {
        self.grants
            .values()
            .any(|g| g.recipient == actor && g.ability == ability)
    }
    pub fn reserved(&self, id: &str) -> ServiceResult<i64> {
        self.claims
            .values()
            .try_fold(0_i64, |sum, c| match &c.target {
                ClaimTarget::Resource { resource, amount } if resource == id => sum
                    .checked_add(*amount)
                    .ok_or_else(|| ServiceError("claim overflow".into())),
                _ => Ok(sum),
            })
    }
    pub fn available(&self, id: &str) -> ServiceResult<i64> {
        let r = self
            .resources
            .get(id)
            .ok_or_else(|| ServiceError("unknown resource".into()))?;
        r.current
            .checked_sub(r.minimum)
            .and_then(|n| n.checked_sub(self.reserved(id).ok()?))
            .ok_or_else(|| ServiceError("resource arithmetic overflow".into()))
    }
    pub fn apply(&mut self, mutations: &[Mutation]) -> ServiceResult<ServiceChanges> {
        self.apply_with_policy(mutations, &|_: &RpgState| Ok(()))
    }
    /// The entire batch, grant reconciliation and profile policy either publish together or not at all.
    pub fn apply_with_policy(
        &mut self,
        mutations: &[Mutation],
        policy: &impl InventoryPolicy,
    ) -> ServiceResult<ServiceChanges> {
        self.validate()?;
        let mut next = self.clone();
        for mutation in mutations {
            next.apply_one(mutation)?;
        }
        let invalid: Vec<_> = next
            .grants
            .iter()
            .filter(|(_, g)| !next.grant_source_exists(g))
            .map(|(id, _)| id.clone())
            .collect();
        for id in invalid {
            next.grants.remove(&id);
        }
        let changes = ServiceChanges {
            revoked_grants: self
                .grants
                .iter()
                .filter(|(id, old)| next.grants.get(*id) != Some(*old))
                .map(|(_, old)| old.clone())
                .collect(),
        };
        next.validate()?;
        policy.validate(&next)?;
        *self = next;
        Ok(changes)
    }
    pub fn craft(
        &mut self,
        actor: &str,
        recipe: &str,
        recipes: &impl RecipePolicy,
        capacity: &impl InventoryPolicy,
    ) -> ServiceResult<ServiceChanges> {
        let plan = recipes.prepare(self, actor, recipe)?;
        self.apply_with_policy(&plan, capacity)
    }
    fn grant_source_exists(&self, grant: &Grant) -> bool {
        let equipped_by = |item: &str, actor: &str| {
            self.bindings
                .get(actor)
                .is_some_and(|slots| slots.values().any(|id| id == item))
        };
        match &grant.source {
            Source::Item { item, equipped } => {
                self.items.contains_key(item) && (!equipped || equipped_by(item, &grant.recipient))
            }
            Source::EquippedBy { item, actor } => {
                self.items.contains_key(item) && equipped_by(item, actor)
            }
            Source::Investment { investment } => self
                .investments
                .get(investment)
                .is_some_and(|i| i.actor == grant.recipient),
            Source::Innate { id } | Source::Temporary { id } => !id.is_empty(),
        }
    }
    fn item_claimed(&self, item: &str) -> bool {
        self.claims
            .values()
            .any(|c| matches!(&c.target, ClaimTarget::Item { item: id, .. } | ClaimTarget::ItemRead { item: id } | ClaimTarget::BindingRead { item: id, .. } if id == item))
    }
    fn binding_claimed(&self, actor: &str, slot: &str) -> bool {
        self.claims.values().any(|c| matches!(&c.target, ClaimTarget::Binding { actor: a, slot: s } | ClaimTarget::BindingRead { actor: a, slot: s, .. } if a == actor && s == slot))
    }
    fn apply_one(&mut self, mutation: &Mutation) -> ServiceResult<()> {
        match mutation {
            Mutation::InsertItem(item) => {
                if self.items.contains_key(&item.id) {
                    return fail("duplicate item instance");
                }
                if item.id.is_empty()
                    || item.definition.is_empty()
                    || item.owner.is_empty()
                    || item.quantity == 0
                {
                    return fail("invalid item record");
                }
                self.items.insert(item.id.clone(), item.clone());
            }
            Mutation::TransferItem {
                item,
                owner,
                parent,
            } => {
                if !self.items.contains_key(item) {
                    return fail("unknown item");
                }
                let mut subtree = BTreeSet::from([item.clone()]);
                loop {
                    let before = subtree.len();
                    for i in self.items.values() {
                        if i.parent.as_ref().is_some_and(|p| subtree.contains(p)) {
                            subtree.insert(i.id.clone());
                        }
                    }
                    if subtree.len() == before {
                        break;
                    }
                }
                if subtree.iter().any(|i| {
                    self.item_claimed(i)
                        || self.bindings.values().any(|s| s.values().any(|v| v == i))
                }) {
                    return fail("claimed or equipped item cannot transfer");
                }
                for id in subtree {
                    self.items.get_mut(&id).expect("known subtree").owner = owner.clone();
                }
                self.items.get_mut(item).expect("known item").parent = parent.clone();
            }
            Mutation::ConsumeItem { item, quantity } => {
                if *quantity == 0 || self.item_claimed(item) {
                    return fail("invalid quantity or claimed item");
                }
                let old = self
                    .items
                    .get(item)
                    .ok_or_else(|| ServiceError("unknown item".into()))?;
                if old.protected
                    || *quantity > old.quantity
                    || self.items.values().any(|i| i.parent.as_ref() == Some(item))
                    || self
                        .bindings
                        .values()
                        .any(|s| s.values().any(|v| v == item))
                {
                    return fail("item cannot be consumed");
                }
                if *quantity == old.quantity {
                    self.items.remove(item);
                } else {
                    self.items.get_mut(item).expect("known item").quantity -= quantity;
                }
            }
            Mutation::SplitItem {
                item,
                quantity,
                new_id,
            } => {
                if self.items.contains_key(new_id) || new_id.is_empty() || self.item_claimed(item) {
                    return fail("invalid split");
                }
                let mut split = self
                    .items
                    .get(item)
                    .cloned()
                    .ok_or_else(|| ServiceError("unknown item".into()))?;
                if *quantity == 0
                    || *quantity >= split.quantity
                    || split.protected
                    || self.items.values().any(|i| i.parent.as_ref() == Some(item))
                    || self
                        .bindings
                        .values()
                        .any(|s| s.values().any(|i| i == item))
                {
                    return fail("invalid split quantity or source");
                }
                split.id = new_id.clone();
                split.quantity = *quantity;
                self.items.get_mut(item).expect("known item").quantity -= quantity;
                self.items.insert(new_id.clone(), split);
            }
            Mutation::MergeItems { from, into } => {
                if from == into || self.item_claimed(from) || self.item_claimed(into) {
                    return fail("invalid merge");
                }
                let a = self
                    .items
                    .get(from)
                    .ok_or_else(|| ServiceError("unknown item".into()))?;
                let b = self
                    .items
                    .get(into)
                    .ok_or_else(|| ServiceError("unknown item".into()))?;
                if a.definition != b.definition || a.stack_key != b.stack_key || a.owner != b.owner || a.parent != b.parent || a.protected || b.protected || self.items.values().any(|i| i.parent.as_ref() == Some(from) || i.parent.as_ref() == Some(into)) || self.bindings.values().any(|s| s.values().any(|i| i == from || i == into)) || self.grants.values().any(|g| matches!(&g.source, Source::Item{item,..} if item == from || item == into)) { return fail("incompatible merge"); }
                let quantity = a
                    .quantity
                    .checked_add(b.quantity)
                    .ok_or_else(|| ServiceError("quantity overflow".into()))?;
                self.items.get_mut(into).expect("known item").quantity = quantity;
                self.items.remove(from);
            }
            Mutation::Equip { actor, item, slots } => {
                if actor.is_empty()
                    || slots.is_empty()
                    || slots
                        .iter()
                        .any(|s| s.is_empty() || self.binding_claimed(actor, s))
                    || slots.iter().collect::<BTreeSet<_>>().len() != slots.len()
                    || !self.items.contains_key(item)
                    || self.item_claimed(item)
                {
                    return fail("invalid or claimed equipment binding");
                }
                if self
                    .bindings
                    .iter()
                    .any(|(a, s)| a != actor && s.values().any(|i| i == item))
                {
                    return fail("instance already equipped by another actor");
                }
                if self.bindings.get(actor).is_some_and(|old| {
                    old.iter().any(|(slot, old_item)| {
                        (old_item == item || slots.contains(slot))
                            && (self.binding_claimed(actor, slot) || self.item_claimed(old_item))
                    })
                }) {
                    return fail("affected old equipment is claimed");
                }
                let bindings = self.bindings.entry(actor.clone()).or_default();
                // The profile names all occupied slots; it must validate anatomical requirements.
                bindings.retain(|_, i| i != item);
                for slot in slots {
                    bindings.insert(slot.clone(), item.clone());
                }
            }
            Mutation::Unequip { actor, slots } => {
                if slots.iter().any(|s| {
                    self.binding_claimed(actor, s)
                        || self
                            .bindings
                            .get(actor)
                            .and_then(|bindings| bindings.get(s))
                            .is_some_and(|item| self.item_claimed(item))
                }) {
                    return fail("binding or equipped item is claimed");
                }
                if let Some(bindings) = self.bindings.get_mut(actor) {
                    for slot in slots {
                        bindings.remove(slot);
                    }
                }
            }
            Mutation::AddGrant(g) => {
                if self.grants.contains_key(&g.id) || !self.grant_source_exists(g) {
                    return fail("duplicate grant or missing source");
                }
                self.grants.insert(g.id.clone(), g.clone());
            }
            Mutation::RevokeSource(source) => {
                self.grants.retain(|_, g| &g.source != source);
            }
            Mutation::AddInvestment(i) => {
                if self.investments.contains_key(&i.id) {
                    return fail("duplicate investment");
                }
                self.investments.insert(i.id.clone(), i.clone());
            }
            Mutation::RemoveInvestment { id } => {
                if self.investments.remove(id).is_none() {
                    return fail("unknown investment");
                }
            }
            Mutation::PutResource(r) => {
                Self::validate_resource(r)?;
                self.resources.insert(r.id.clone(), r.clone());
                self.validate_claims()?;
            }
            Mutation::AdjustResource { id, delta } => {
                let r = self
                    .resources
                    .get_mut(id)
                    .ok_or_else(|| ServiceError("unknown resource".into()))?;
                r.current = r
                    .current
                    .checked_add(*delta)
                    .ok_or_else(|| ServiceError("resource overflow".into()))?;
                Self::validate_resource(r)?;
                self.validate_claims()?;
            }
            Mutation::Reserve(c) => {
                if self.claims.contains_key(&c.id) {
                    return fail("duplicate claim");
                }
                if c.id.is_empty() || c.owner.is_empty() || c.action.is_empty() {
                    return fail("invalid claim identity");
                }
                self.claims.insert(c.id.clone(), c.clone());
                self.validate_claims()?;
            }
            Mutation::ReleaseClaim { id } => {
                if self.claims.remove(id).is_none() {
                    return fail("unknown claim");
                }
            }
            Mutation::ConsumeClaim { id } => {
                self.validate_claims()?;
                let c = self
                    .claims
                    .remove(id)
                    .ok_or_else(|| ServiceError("unknown claim".into()))?;
                match c.target {
                    ClaimTarget::Resource { resource, amount } => {
                        self.apply_one(&Mutation::AdjustResource {
                            id: resource,
                            delta: amount
                                .checked_neg()
                                .ok_or_else(|| ServiceError("claim negation overflow".into()))?,
                        })?
                    }
                    ClaimTarget::Item { item, quantity } => {
                        // Other claims remain valid, but must not block consuming this own reserved share.
                        let other: Vec<_> = self.claims.values().filter(|c| matches!(&c.target, ClaimTarget::Item { item: i, .. } if i == &item)).cloned().collect();
                        for claim in &other {
                            self.claims.remove(&claim.id);
                        }
                        self.apply_one(&Mutation::ConsumeItem { item, quantity })?;
                        for claim in other {
                            self.claims.insert(claim.id.clone(), claim);
                        }
                    }
                    ClaimTarget::Binding { .. }
                    | ClaimTarget::Actor { .. }
                    | ClaimTarget::ItemRead { .. }
                    | ClaimTarget::BindingRead { .. } => {}
                }
            }
        }
        Ok(())
    }
    pub fn validate(&self) -> ServiceResult<()> {
        for (id, item) in &self.items {
            if id.is_empty()
                || id != &item.id
                || item.definition.is_empty()
                || item.owner.is_empty()
                || item.quantity == 0
            {
                return fail("invalid item record");
            }
            let mut visited = BTreeSet::from([id.clone()]);
            let mut parent = item.parent.as_ref();
            while let Some(p) = parent {
                if !visited.insert(p.clone()) {
                    return fail("container cycle");
                }
                let container = self
                    .items
                    .get(p)
                    .ok_or_else(|| ServiceError("missing container".into()))?;
                if container.owner != item.owner {
                    return fail("container owner mismatch");
                }
                parent = container.parent.as_ref();
            }
        }
        let mut equipped = BTreeMap::new();
        for (actor, slots) in &self.bindings {
            if actor.is_empty() {
                return fail("empty binding actor");
            }
            for (slot, item) in slots {
                if slot.is_empty() || !self.items.contains_key(item) {
                    return fail("invalid binding");
                }
                if equipped.insert(item, actor).is_some_and(|old| old != actor) {
                    return fail("item bound to two actors");
                }
            }
        }
        for (id, g) in &self.grants {
            if id.is_empty()
                || id != &g.id
                || g.recipient.is_empty()
                || g.ability.is_empty()
                || !self.grant_source_exists(g)
            {
                return fail("invalid grant source");
            }
        }
        for (id, i) in &self.investments {
            if id.is_empty()
                || id != &i.id
                || i.actor.is_empty()
                || i.definition.is_empty()
                || i.currency.is_empty()
                || i.amount < 0
            {
                return fail("invalid investment");
            }
        }
        self.validate_dependencies()?;
        for (id, r) in &self.resources {
            if id != &r.id {
                return fail("resource identity mismatch");
            }
            Self::validate_resource(r)?;
        }
        self.validate_claims()
    }
    fn validate_resource(r: &Resource) -> ServiceResult<()> {
        if r.id.is_empty()
            || r.owner.is_empty()
            || r.unit.is_empty()
            || r.minimum > r.maximum
            || r.current < r.minimum
            || r.current > r.maximum
            || r.current.checked_sub(r.minimum).is_none()
        {
            return fail("invalid resource bounds");
        }
        Ok(())
    }
    fn validate_claims(&self) -> ServiceResult<()> {
        let mut unique = BTreeSet::new();
        let mut item_totals = BTreeMap::<&str, u32>::new();
        for (id, c) in &self.claims {
            if id.is_empty() || id != &c.id || c.owner.is_empty() || c.action.is_empty() {
                return fail("invalid claim");
            }
            match &c.target {
                ClaimTarget::Resource { resource, amount } => {
                    if *amount <= 0 || !self.resources.contains_key(resource) {
                        return fail("invalid resource claim");
                    }
                }
                ClaimTarget::Item { item, quantity } => {
                    if *quantity == 0 || !self.items.contains_key(item) {
                        return fail("invalid item claim");
                    }
                    let total = item_totals.entry(item).or_default();
                    *total = total
                        .checked_add(*quantity)
                        .ok_or_else(|| ServiceError("claim overflow".into()))?;
                    if *total > self.items[item].quantity {
                        return fail("item overclaimed");
                    }
                }
                ClaimTarget::Binding { actor, slot } => {
                    let held = self.bindings.get(actor).and_then(|slots| slots.get(slot));
                    if held.is_some_and(|item| self.claims.values().any(|other| matches!(&other.target, ClaimTarget::ItemRead { item: read } | ClaimTarget::BindingRead { item: read, .. } if read == item))) {
                        return fail("exclusive binding conflicts with source readers");
                    }
                    if actor.is_empty()
                        || slot.is_empty()
                        || !unique.insert(("binding", actor.as_str(), slot.as_str()))
                    {
                        return fail("binding overclaimed");
                    }
                }
                ClaimTarget::ItemRead { item } | ClaimTarget::BindingRead { item, .. } => {
                    if !self.items.contains_key(item) || self.claims.values().any(|other| matches!(&other.target, ClaimTarget::Item { item: i, .. } if i == item)) {
                        return fail("missing source or conflicting quantity claim");
                    }
                    if let ClaimTarget::BindingRead { actor, slot, item } = &c.target {
                        if self.bindings.get(actor).and_then(|s| s.get(slot)) != Some(item)
                            || self.claims.values().any(|other| matches!(&other.target, ClaimTarget::Binding { actor: a, slot: s } if a == actor && s == slot)) {
                            return fail("missing source binding or conflicting exclusive claim");
                        }
                    }
                }
                ClaimTarget::Actor { actor } => {
                    if actor.is_empty() || !unique.insert(("actor", actor.as_str(), "")) {
                        return fail("actor overclaimed");
                    }
                }
            }
        }
        for id in self.resources.keys() {
            if self.available(id)? < 0 {
                return fail("resource overclaimed");
            }
        }
        Ok(())
    }
    // Iterative topological validation avoids recursive stack growth and repeated DAG traversal.
    fn validate_dependencies(&self) -> ServiceResult<()> {
        let mut degrees: BTreeMap<&str, usize> = BTreeMap::new();
        let mut children: BTreeMap<&str, Vec<&str>> = BTreeMap::new();
        for (id, investment) in &self.investments {
            degrees.insert(id, investment.prerequisites.len());
            for prerequisite in &investment.prerequisites {
                let parent = self
                    .investments
                    .get(prerequisite)
                    .ok_or_else(|| ServiceError("missing investment prerequisite".into()))?;
                if parent.actor != investment.actor {
                    return fail("investment prerequisite actor mismatch");
                }
                children.entry(prerequisite).or_default().push(id);
            }
        }
        let mut ready: Vec<_> = degrees
            .iter()
            .filter(|(_, n)| **n == 0)
            .map(|(id, _)| *id)
            .collect();
        let mut visited = 0;
        while let Some(id) = ready.pop() {
            visited += 1;
            if let Some(dependents) = children.get(id) {
                for child in dependents {
                    let degree = degrees.get_mut(child).expect("known dependent");
                    *degree -= 1;
                    if *degree == 0 {
                        ready.push(*child);
                    }
                }
            }
        }
        if visited != self.investments.len() {
            return fail("investment dependency cycle");
        }
        Ok(())
    }
}
