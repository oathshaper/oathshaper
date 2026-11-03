use oathshaper_core::{dialogue_script, load_story_json};
fn main() {
    let result = (|| -> Result<_, String> {
        let args: Vec<_> = std::env::args().skip(1).collect();
        if !(2..=3).contains(&args.len()) {
            return Err("usage: check_dialogue_script STORY.json VOICES.json [MAX_STATES]".into());
        }
        let read = |p: &str| std::fs::read_to_string(p).map_err(|e| e.to_string());
        let story = load_story_json(&read(&args[0])?)?;
        let voices = serde_json::from_str(&read(&args[1])?).map_err(|e| e.to_string())?;
        let budget = args
            .get(2)
            .map(|s| s.parse())
            .transpose()
            .map_err(|_| "invalid state budget")?
            .unwrap_or(250_000);
        dialogue_script::check(story, voices, budget)
    })();
    match result {
        Ok(report) => {
            println!("{}", serde_json::to_string_pretty(&report).unwrap());
            std::process::exit(if report.complete_within_scope { 0 } else { 2 });
        }
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(2);
        }
    }
}
