//! Flow's transport boundary. The UI cannot submit an effect, a die roll,
//! an authority lease or replacement state. Rules live in oathshaper-core.
use godot::prelude::*;
use oathshaper_core::flow::{FlowGame, SpaceFrame};
use serde_json::{json, Value};

#[derive(GodotClass)]
#[class(base = RefCounted)]
struct FlowBridge {
    base: Base<RefCounted>,
    game: Option<FlowGame>,
}

#[godot_api]
impl IRefCounted for FlowBridge {
    fn init(base: Base<RefCounted>) -> Self {
        Self { base, game: None }
    }
}

fn response(result: Result<Value, String>) -> GString {
    match result {
        Ok(data) => json!({"ok":true,"data":data}),
        Err(message) => json!({"ok":false,"error":{"code":"flow_error","message":message}}),
    }
    .to_string()
    .into()
}

impl FlowBridge {
    fn game(&self) -> Result<&FlowGame, String> {
        self.game
            .as_ref()
            .ok_or_else(|| "Flow trial is not initialized".into())
    }

    fn game_mut(&mut self) -> Result<&mut FlowGame, String> {
        self.game
            .as_mut()
            .ok_or_else(|| "Flow trial is not initialized".into())
    }
}

#[godot_api]
impl FlowBridge {
    #[func]
    fn create(&mut self, seed_decimal: GString) -> GString {
        let result = (|| {
            let seed = seed_decimal
                .to_string()
                .parse::<u64>()
                .map_err(|_| "Seed must be an unsigned decimal integer".to_owned())?;
            let candidate = FlowGame::new(seed).map_err(|error| error.to_string())?;
            let view = candidate.view();
            self.game = Some(candidate);
            Ok(view)
        })();
        response(result)
    }

    #[func]
    fn view(&self) -> GString {
        response(self.game().map(FlowGame::view))
    }

    #[func]
    fn submit(&mut self, input: GString) -> GString {
        let result = (|| {
            let value =
                serde_json::from_str(&input.to_string()).map_err(|error| error.to_string())?;
            self.game_mut()?
                .submit(value)
                .map_err(|error| error.to_string())
        })();
        response(result)
    }

    #[func]
    fn preview(&self, input: GString) -> GString {
        let result = (|| {
            let value =
                serde_json::from_str(&input.to_string()).map_err(|error| error.to_string())?;
            self.game()?
                .preview(value)
                .map_err(|error| error.to_string())
        })();
        response(result)
    }

    #[func]
    fn advance(&mut self, ticks: i64) -> GString {
        let result = (|| {
            if !(0..=100).contains(&ticks) {
                return Err("Advance must be between zero and 100 ticks".into());
            }
            self.game_mut()?
                .advance(ticks as u32)
                .map_err(|error| error.to_string())
        })();
        response(result)
    }

    #[func]
    fn save_json(&self) -> GString {
        response(self.game().and_then(|game| {
            game.save_json()
                .map(|save| json!({"save":save}))
                .map_err(|error| error.to_string())
        }))
    }

    #[func]
    fn restore_json(&mut self, source: GString) -> GString {
        response(self.game_mut().and_then(|game| {
            game.restore_json(&source.to_string())
                .map_err(|error| error.to_string())
        }))
    }

    /// Host geometry channel; never dispatched from a player's action object.
    #[func]
    fn space_requests(&self) -> GString {
        response(self.game().and_then(|game| {
            serde_json::to_value(game.space_requests()).map_err(|error| error.to_string())
        }))
    }

    #[func]
    fn space_sequence(&self) -> GString {
        response(
            self.game()
                .map(|game| json!(game.next_observation_sequence("godot-garden").to_string())),
        )
    }

    /// Only the owned garden geometry adapter calls this method.
    #[func]
    fn observe_space(&mut self, input: GString) -> GString {
        let result = (|| {
            let frame: SpaceFrame =
                serde_json::from_str(&input.to_string()).map_err(|error| error.to_string())?;
            self.game_mut()?
                .observe_space(frame)
                .map_err(|error| error.to_string())?;
            Ok(json!({"observed":true}))
        })();
        response(result)
    }
}
