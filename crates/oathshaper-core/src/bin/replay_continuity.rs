use oathshaper_core::{continuity_replay, load_story_json};
use std::{env, fs};
fn main() {
    let result = (|| -> Result<_, String> {
        let args: Vec<_> = env::args().skip(1).collect();
        if args.len() != 3 {
            return Err(
                "usage: replay_continuity <story.json> <continuity.json> <journeys.json>".into(),
            );
        }
        let read = |path: &str| fs::read_to_string(path).map_err(|e| e.to_string());
        continuity_replay::replay(
            load_story_json(&read(&args[0])?)?,
            serde_json::from_str(&read(&args[1])?).map_err(|e| e.to_string())?,
            serde_json::from_str(&read(&args[2])?).map_err(|e| e.to_string())?,
            200,
        )
    })();
    match result {
        Ok(report) => {
            println!("{}", serde_json::to_string_pretty(&report).unwrap());
            std::process::exit(match report.status.as_str() {
                "passed" => 0,
                "failed" => 1,
                _ => 2,
            });
        }
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(2);
        }
    }
}
