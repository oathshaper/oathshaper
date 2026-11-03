//! Vanguard transport. Geometry is a host observation channel; actions cannot submit effects.
use godot::prelude::*;
use oathshaper_core::vanguard::{Frame, Intent, VanguardGame};
use serde_json::{json, Value};
#[derive(GodotClass)]
#[class(base=RefCounted)]
struct VanguardBridge {
    base: Base<RefCounted>,
    game: Option<VanguardGame>,
}
#[godot_api]
impl IRefCounted for VanguardBridge {
    fn init(base: Base<RefCounted>) -> Self {
        Self { base, game: None }
    }
}
fn response(r: Result<Value, String>) -> GString {
    match r {
        Ok(data) => json!({"ok":true,"data":data}),
        Err(message) => json!({"ok":false,"error":message}),
    }
    .to_string()
    .into()
}
#[godot_api]
impl VanguardBridge {
    #[func]
    fn create(&mut self) -> GString {
        response(
            VanguardGame::new()
                .map(|game| {
                    let view = game.view();
                    self.game = Some(game);
                    view
                })
                .map_err(|e| e.to_string()),
        )
    }
    #[func]
    fn view(&self) -> GString {
        response(
            self.game
                .as_ref()
                .map(VanguardGame::view)
                .ok_or("Vanguard is not initialized".into()),
        )
    }
    #[func]
    fn submit(&mut self, source: GString) -> GString {
        response((|| {
            let c: Intent = serde_json::from_str(&source.to_string()).map_err(|e| e.to_string())?;
            self.game
                .as_mut()
                .ok_or("Vanguard is not initialized")?
                .submit(c)
                .map_err(|e| e.to_string())
        })())
    }
    #[func]
    fn advance(&mut self, source: GString) -> GString {
        response((|| {
            let f: Frame = serde_json::from_str(&source.to_string()).map_err(|e| e.to_string())?;
            self.game
                .as_mut()
                .ok_or("Vanguard is not initialized")?
                .advance(f)
                .map_err(|e| e.to_string())
        })())
    }
}
