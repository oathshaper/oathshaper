use oathshaper_core::{continuity, load_story_json};
use std::{env, fs};

fn main() {
    let result = (|| -> Result<continuity::Report, String> {
        let args: Vec<_> = env::args().skip(1).collect();
        if args.len() != 2 {
            return Err("usage: check_continuity <story.json> <continuity.json>".into());
        }
        let story = load_story_json(&fs::read_to_string(&args[0]).map_err(|e| e.to_string())?)?;
        let contract =
            serde_json::from_str(&fs::read_to_string(&args[1]).map_err(|e| e.to_string())?)
                .map_err(|e| format!("invalid contract: {e}"))?;
        continuity::check(story, contract, 65_536)
    })();
    match result {
        Ok(report) => {
            println!("{}", serde_json::to_string_pretty(&report).unwrap());
            if !report.complete_within_scope {
                std::process::exit(2);
            }
            if report
                .findings
                .iter()
                .any(|f| f.certainty == "contract_violation")
            {
                std::process::exit(1);
            }
        }
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(2);
        }
    }
}
