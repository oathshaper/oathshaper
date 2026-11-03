use std::{env, fs};
fn main() {
    let path = env::args()
        .nth(1)
        .expect("usage: validate_dialogue <story.json>");
    match fs::read_to_string(&path)
        .map_err(|e| e.to_string())
        .and_then(|s| oathshaper_core::load_story_json(&s))
    {
        Ok(story) => println!(
            "OK: {} revision {} ({} nodes)",
            story.id,
            story.revision,
            story.nodes.len()
        ),
        Err(e) => {
            eprintln!("ERROR: {e}");
            std::process::exit(1)
        }
    }
}
