//! Thin GDExtension adapter. Narrative rules live entirely in oathshaper-core.
// godot_api generates callbacks returning Godot's large CallError by value.
#![allow(clippy::result_large_err)]
use godot::prelude::*;
use oathshaper_core::{load_story_json, NarrativeSession};
use serde_json::json;
mod command_bridge;
mod flow_bridge;
mod vanguard_bridge;

#[derive(GodotClass)]
#[class(base = RefCounted)]
struct NarrativeBridge {
    #[base]
    base: Base<RefCounted>,
    session: Option<NarrativeSession>,
}

#[godot_api]
impl IRefCounted for NarrativeBridge {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            base,
            session: None,
        }
    }
}

fn ok(data: serde_json::Value) -> GString {
    json!({"ok":true,"data":data}).to_string().into()
}
fn err(message: String) -> GString {
    json!({"ok":false,"error":message}).to_string().into()
}

#[godot_api]
impl NarrativeBridge {
    #[func]
    fn validate_story(&self, source: GString) -> GString {
        match load_story_json(&source.to_string()) {
            Ok(story) => {
                ok(json!({"id":story.id,"revision":story.revision,"nodes":story.nodes.len()}))
            }
            Err(e) => err(e),
        }
    }
    #[func]
    fn load_story(&mut self, source: GString) -> GString {
        match load_story_json(&source.to_string()).and_then(NarrativeSession::new) {
            Ok(session) => {
                self.session = Some(session);
                ok(json!({"loaded":true}))
            }
            Err(e) => err(e),
        }
    }
    #[func]
    fn begin(&mut self) -> GString {
        match self.session.as_mut() {
            Some(session) => {
                let view = session.begin();
                ok(serde_json::to_value(view).unwrap())
            }
            None => err("no story is loaded".into()),
        }
    }
    #[func]
    fn begin_at(&mut self, node_id: GString) -> GString {
        match self
            .session
            .as_mut()
            .ok_or_else(|| "no story is loaded".to_string())
            .and_then(|session| session.begin_at(&node_id.to_string()))
        {
            Ok(view) => ok(serde_json::to_value(view).unwrap()),
            Err(e) => err(e),
        }
    }
    #[func]
    fn set_world_flag(&mut self, id: GString, value: bool) -> GString {
        match self
            .session
            .as_mut()
            .ok_or_else(|| "no story is loaded".to_string())
            .and_then(|s| s.set_world_flag(&id.to_string(), value))
        {
            Ok(()) => ok(json!({"synchronized":true})),
            Err(e) => err(e),
        }
    }
    #[func]
    fn state_json(&self) -> GString {
        match self.session.as_ref() {
            Some(session) => ok(serde_json::to_value(session.state()).unwrap()),
            None => err("no story is loaded".into()),
        }
    }
    #[func]
    fn view(&self) -> GString {
        match self.session.as_ref() {
            Some(session) => ok(serde_json::to_value(session.view()).unwrap()),
            None => err("no story is loaded".into()),
        }
    }
    #[func]
    fn choose(&mut self, id: GString) -> GString {
        match self
            .session
            .as_mut()
            .ok_or_else(|| "no story is loaded".to_string())
            .and_then(|s| s.choose(&id.to_string()))
        {
            Ok(view) => ok(serde_json::to_value(view).unwrap()),
            Err(e) => err(e),
        }
    }
    #[func]
    fn choose_with_events(&mut self, id: GString) -> GString {
        match self
            .session
            .as_mut()
            .ok_or_else(|| "no story is loaded".to_string())
            .and_then(|s| s.choose_with_events(&id.to_string()))
        {
            Ok(outcome) => ok(serde_json::to_value(outcome).unwrap()),
            Err(e) => err(e),
        }
    }
    #[func]
    fn finish_response(&mut self) -> GString {
        match self
            .session
            .as_mut()
            .ok_or_else(|| "no story is loaded".to_string())
            .and_then(NarrativeSession::finish_response)
        {
            Ok(view) => ok(serde_json::to_value(view).unwrap()),
            Err(e) => err(e),
        }
    }
    #[func]
    fn end_dialogue(&mut self) -> GString {
        match self.session.as_mut() {
            Some(session) => {
                session.end();
                ok(json!({"ended":true}))
            }
            None => err("no story is loaded".into()),
        }
    }
    #[func]
    fn save_json(&self) -> GString {
        match self
            .session
            .as_ref()
            .ok_or_else(|| "no story is loaded".to_string())
            .and_then(|s| s.save_json())
        {
            Ok(save) => ok(json!({"save":save})),
            Err(e) => err(e),
        }
    }
    #[func]
    fn load_save(&mut self, source: GString) -> GString {
        match self
            .session
            .as_mut()
            .ok_or_else(|| "no story is loaded".to_string())
            .and_then(|s| s.load_json(&source.to_string()))
        {
            Ok(()) => ok(json!({"loaded":true})),
            Err(e) => err(e),
        }
    }
}
struct OathshaperExtension;
#[gdextension]
unsafe impl ExtensionLibrary for OathshaperExtension {}
