use super::{RuleError, RuleResult};
use crate::rpg::RpgState;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

/// Declaration for code statically registered by the composing Rust Profile, not a plugin loader.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProviderSpec {
    pub id: String,
    pub version: u32,
    pub owns: BTreeSet<String>,
    pub provides: BTreeSet<String>,
    pub requires: BTreeSet<String>,
}
impl ProviderSpec {
    pub fn new(
        id: impl Into<String>,
        namespace: impl Into<String>,
        capability: impl Into<String>,
    ) -> Self {
        Self {
            id: id.into(),
            version: 1,
            owns: BTreeSet::from([namespace.into()]),
            provides: BTreeSet::from([capability.into()]),
            requires: BTreeSet::new(),
        }
    }
    fn kernel() -> Self {
        Self::new("runtime.kernel", "runtime", "runtime.core/v1")
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub id: String,
    pub version: u32,
    pub content_hash: String,
    pub required_capabilities: BTreeSet<String>,
    pub providers: Vec<ProviderSpec>,
}
impl Manifest {
    /// Convenience constructor with the optional built-in service providers registered.
    pub fn new(id: impl Into<String>, version: u32, content_hash: impl Into<String>) -> Self {
        let mut result = Self::minimal(id, version, content_hash);
        for name in [
            "inventory",
            "equipment",
            "grants",
            "resources",
            "progression",
            "claims",
        ] {
            result.providers.push(ProviderSpec::new(
                format!("rpg.{name}"),
                format!("rpg.{name}"),
                format!("rpg.{name}/v1"),
            ));
        }
        result
    }
    /// No inventory, resource, clock, party or Health provider is required.
    pub fn minimal(id: impl Into<String>, version: u32, content_hash: impl Into<String>) -> Self {
        let id = id.into();
        Self {
            providers: vec![
                ProviderSpec::kernel(),
                ProviderSpec::new(
                    format!("profile.{id}"),
                    format!("profile.{id}"),
                    format!("profile.{id}/v1"),
                ),
            ],
            id,
            version,
            content_hash: content_hash.into(),
            required_capabilities: BTreeSet::new(),
        }
    }
    pub fn validate(&self) -> RuleResult {
        if self.id.is_empty() || self.version == 0 || self.content_hash.is_empty() {
            return Err(RuleError::new("manifest", "Invalid profile manifest"));
        }
        let mut ids = BTreeSet::new();
        let mut namespaces = BTreeMap::<&str, &str>::new();
        let mut capabilities = BTreeSet::new();
        for provider in &self.providers {
            if provider.id.is_empty()
                || provider.version == 0
                || provider.owns.is_empty()
                || !ids.insert(provider.id.as_str())
            {
                return Err(RuleError::new("provider", "Invalid or duplicate provider"));
            }
            for namespace in &provider.owns {
                if namespace.is_empty()
                    || namespace.split('.').any(str::is_empty)
                    || namespaces.keys().any(|old| {
                        **old == *namespace
                            || old.starts_with(&format!("{namespace}."))
                            || namespace.starts_with(&format!("{old}."))
                    })
                {
                    return Err(RuleError::new(
                        "ownership",
                        "Conflicting or invalid namespace ownership",
                    ));
                }
                namespaces.insert(namespace, &provider.id);
            }
            for capability in &provider.provides {
                if capability.is_empty() || !capabilities.insert(capability.as_str()) {
                    return Err(RuleError::new(
                        "capability",
                        "Duplicate or invalid capability provider",
                    ));
                }
            }
        }
        if !namespaces.contains_key(format!("profile.{}", self.id).as_str())
            || !capabilities.contains(format!("profile.{}/v1", self.id).as_str())
        {
            return Err(RuleError::new(
                "ownership",
                "Profile state must have an explicit owner",
            ));
        }
        if !self.providers.contains(&ProviderSpec::kernel()) {
            return Err(RuleError::new(
                "kernel",
                "The kernel provider cannot be replaced",
            ));
        }
        for requirement in self
            .required_capabilities
            .iter()
            .chain(self.providers.iter().flat_map(|p| &p.requires))
        {
            if !capabilities.contains(requirement.as_str()) {
                return Err(RuleError::new(
                    "capability",
                    format!("Missing required capability: {requirement}"),
                ));
            }
        }
        Ok(())
    }
    pub(crate) fn validate_rpg(&self, rpg: &RpgState) -> RuleResult {
        for namespace in rpg.occupied_namespaces() {
            let found = self.providers.iter().any(|p| {
                p.id == namespace
                    && p.owns.contains(namespace)
                    && p.provides.contains(&format!("{namespace}/v1"))
            });
            if !found {
                return Err(RuleError::new(
                    "provider",
                    format!("Built-in data requires its registered provider: {namespace}"),
                ));
            }
        }
        Ok(())
    }
}
