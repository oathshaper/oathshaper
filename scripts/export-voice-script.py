#!/usr/bin/env python3
"""Export exact dialogue/variant/choice lines for recorded or generated speech.
No provider calls. A changed displayed line gets a new asset key, so old audio
cannot silently accompany a rewritten subtitle.
"""
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
PLAYER_LINES = {
    "accept_help": "She's safe. He stole the payroll. Will you come with me?",
    "return_pay": "Here is the stolen payroll.",
    "check_office": "I'll check on the clerk.",
    "ask_robbery": "Who was he? What did he take?",
    "ask_theft": "What happened?",
    "ask_pay": "Do you work here?",
    "share_oil": "Here. This should get the tower burning again.",
    "keep_oil": "I need to keep the oil for the road.",
    "ask_for_favor": "Where is Ivo?",
    "open_gate": "Mara's ready. Let's get the payroll back.",
    "ask_about_gate": "Why haven't you gone in?",
    "ask_sentries": "What are those machines?",
    "open_shortcut": "Could I use the market side passage?",
    "ask_about_records": "May I look through the harbor archive?",
    "ask_town": "Do robberies happen often here?",
    "take_records": "A history of the harbor. I'll take a look.",
    "ask_directions": "Can you point me through town?",
    "ask_about_tower": "What can you tell me about the lantern tower?",
    "ask_lamp": "Why is the tower dark?",
    "leave": "Until next time.",
}

CAST = {
    "Corsair": "Adult woman; warm, grounded, direct. The player character.",
    "Mara": "Adult woman; practical dockworker, warm with a rough edge.",
    "Crimson Raider": "Adult raider; curt, defensive, no theatrical villain voice.",
    "Ivo": "Adult watchkeeper; calm, low register, deliberate without theatrical gravity.",
    "Clerk": "Older woman; precise, dry, confident, conversational pace.",
    "Vendor": "Adult merchant; bright and lightly amused, never a caricature.",
    "Filing Cabinet": "Neutral narrator; quiet observation, no character impersonation.",
    "Narrator": "Neutral narrator; shares the filing cabinet voice.",
}
entries = {}
def add(speaker, displayed, spoken, source):
    # Display-name change only: retain the recorded casting identity and hashes.
    if speaker == "Tessa Ward":
        speaker = "Corsair"
    key = hashlib.sha256((speaker + "\n" + displayed).encode()).hexdigest()
    asset_key = hashlib.sha256((speaker + "\n" + displayed + "\n" + spoken).encode()).hexdigest()
    if key in entries:
        entries[key]["sources"].append(source)
        return
    entries[key] = {"key": key, "speaker": speaker, "lookup_text": displayed,
        "spoken_text": spoken, "sources": [source],
        "path": f"res://assets/audio/generated/{asset_key}.wav"}
story = json.loads((ROOT / 'godot/content/lantern_quay.json').read_text())
for node in story['nodes']:
    add(node['speaker'], node['text'], node['text'], f"node:{node['id']}")
    for i, variant in enumerate(node.get('variants', [])):
        add(node['speaker'], variant['text'], variant['text'], f"node:{node['id']}/variant:{i}")
    for choice in node.get('choices', []):
        spoken = PLAYER_LINES.get(choice['id'])
        if node['speaker'] in {'Filing Cabinet', 'Narrator'} and choice['id'] != 'take_records':
            continue  # Closing a drawer is an action, not a spoken farewell.
        if spoken:
            add('Corsair', choice['text'], spoken, f"choice:{node['id']}/{choice['id']}")
chapter = json.loads((ROOT / 'godot/content/garden_chapter.json').read_text())
for section in ['briefing', 'resolution', 'surrender']:
    for i, line in enumerate(chapter[section].split('\n\n')):
        if ': "' in line:
            speaker, text = line.split(': "', 1)
            text = text.removesuffix('"')
            add(speaker, text, text, f"chapter:{chapter['id']}/{section}:{i}")
for section in ['opening', 'ending', 'ending_early']:
    for i, line in enumerate(chapter.get(section, [])):
        add(line['speaker'], line['text'], line['text'], f"chapter:{section}:{i}")
payload = {"schema":1, "status":"script_only", "cast":CAST, "lines":list(entries.values())}
path = ROOT / 'godot/content/voice_script.json'
path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + '\n')
print(f"{len(entries)} lines; {sum(len(x['spoken_text']) for x in entries.values())} characters; {len(CAST)} speaker roles; no generation performed")
