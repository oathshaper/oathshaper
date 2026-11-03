use super::*;
use rules::*;
fn pool(r: &RpgState, id: &str, u: &str) -> Value {
    let p = &r.resources()[&rid(id, u)];
    json!({"current":p.current,"maximum":p.maximum,"reserved":0,"free":p.current})
}
pub(super) fn project(s: &State, r: &RpgState, revision: u64) -> Value {
    let target_id = selected_target(s, r).unwrap_or("");
    let actors: Vec<_> = s.actors.values().filter(|a| a.deployed).map(|a| {
        let model = match a.id.as_str() {
            "hound" => "lantern_sentinel", "sentinel" => "iron_sentinel",
            "corsair_raider" => "crimson_corsair", _ => "",
        };
        let main_hand = match a.id.as_str() {
            "mara" => "staff", "ivo" => "mace", "corsair_raider" => "sabre",
            "player" if s.style == "harbor" => "sabre", _ => "unarmed",
        };
        json!({"id":a.id,"name":a.name,"faction":a.faction,
            "position":[a.position[0] as f64/1000.,a.position[1] as f64/1000.],
            "conscious":alive(s,r,&a.id),"health":pool(r,&a.id,"health"),"chi":pool(r,&a.id,"chi"),"focus":pool(r,&a.id,"focus"),
            "appearance":{"model":model,"main_hand":main_hand,"offhand":if a.id=="ivo"{"buckler"}else{"none"},"armor":"none"},
            "active_action":a.active.as_ref().map(|v|json!({"id":v.id,"state":if v.fired{"recovery"}else{"windup"},"target":{"actor_id":v.target},"ability_id":format!("{}_{}",v.style,v.verb),"power":v.power,"remaining_ticks":(v.startup+v.recovery-v.elapsed)/2})),
            "guard":a.guard,"setup_until":a.setup,
            "conditions":[if a.setup>s.tick{json!({"label":format!("Resonance {:.1}s",(a.setup-s.tick)as f64*0.05)})}else if a.guard{json!({"label":"Guarding"})}else if a.stun>s.tick{json!({"label":"Staggered"})}else{json!({"label":""})}]})
    }).collect();
    let verbs: Vec<_> = ["normal","power","area"].iter().map(|id| match verb(s,&s.style,id) {
        Ok(v) => { let ready = attack_verb(s,r,id);
            json!({"id":id,"supported":true,"available":ready.is_ok(),"damage":v.damage,"cost":v.cost,"resource":v.unit,"range":v.range as f64/1000.,"startup_ticks":v.startup,"recovery_ticks":v.recovery,"reason":ready.err().map(|e|e.reason.message)}) },
        Err(e) => json!({"id":id,"supported":false,"available":false,"reason":e.reason.message}),
    }).collect();
    let items:Vec<_>=r.items().values().map(|i|json!({"id":i.id,"name":i.definition.replace('_'," "),"definition":i.definition,"quantity":i.quantity,"protected":i.protected,"eligible":gem_legal(s,&i.definition),"bound":r.bindings().get("player").into_iter().flatten().find(|(_,id)|**id==i.id).map(|(slot,_)|slot),"requirement":match i.definition.as_str(){"stone_charm"=>"Body 8 · +20 maximum Health","rain_charm"=>"Spirit 8 · +10 maximum Chi","hawk_charm"=>"Mind 8 · +10 maximum Focus","speaker_pearl"=>"+2 Charm and Intuition",_=>"Quest material"}})).collect();
    let mut result = json!({"schema":"flow.view/v1","session":{"profile_id":"flow","generation":"host","revision":revision.to_string(),"ledger_sequence":"host","tick":s.tick,"tick_ms":50,"phase":s.phase},"clock":{"paused":!s.pauses.is_empty(),"pause_reasons":s.pauses,"restore_token":Value::Null},"party":{"recipient_id":"player","possessed_id":"player","camera_follow_id":"player","follower_id":"mara","selected_target_id":target_id,"members":["player","mara","ivo"]},"actors":actors,"hero":{"style":s.style,"diamond":s.diamond,"target_id":target_id,"focus_mode":s.focus,"chi_enhancement":s.enhanced,"healing":s.healing,"preset":s.preset,"attributes":{"body":s.attributes[0],"spirit":s.attributes[1],"mind":s.attributes[2]},"ranks":s.ranks,"skills":s.skills},"verbs":verbs,"follower":{"id":"mara","mode":s.follower_mode,"mode_version":s.follower_version.to_string(),"support_remaining":s.support_left,"next_pulse":s.support_due,"reason":if !alive(s,r,"mara"){"Downed"}else if s.follower_mode=="support"{"Heals injured allies using her Chi; restores your Chi nearby"}else{"Attacks visible opponents; uses own Chi"}},"inventory":{"items":items,"copper":amount(r,"party","copper"),"capacity":Value::Null},"progression":{"level":s.level,"xp":s.xp,"style_points":s.style_points,"attribute_points":s.attribute_points},"encounter":{"objective":"Defeat the raider and his two guards. Recover the stolen payroll.","status":s.phase,"won":s.rewarded,"surrender":s.phase=="surrender"},"logs":s.logs,"projectiles":s.projectiles.len()});
    let mut scores = serde_json::Map::new();
    let pearl = r
        .bindings()
        .get("player")
        .into_iter()
        .flatten()
        .any(|(_, id)| r.items()[id].definition == "speaker_pearl");
    for (skill, a, b) in [
        ("charm", 0, 2),
        ("intuition", 1, 2),
        ("intimidation", 0, 1),
        ("acrobatics", 0, 2),
        ("medicine", 1, 2),
        ("mechanisms", 0, 2),
    ] {
        let trained = i64::from(s.skills.iter().any(|v| v == skill)) * 3;
        scores.insert(
            skill.into(),
            json!(
                (s.attributes[a] + s.attributes[b]) / 2
                    + trained
                    + if pearl && ["charm", "intuition"].contains(&skill) {
                        2
                    } else {
                        0
                    }
            ),
        );
    }
    result["targeting"] = if target_id.is_empty() {
        json!({"distance":Value::Null,"line_of_sight":false})
    } else {
        json!({"distance":distance(s.actors["player"].position,s.actors[target_id].position)/1000.,"line_of_sight":clear(s,"player",target_id)})
    };
    result["hero"]["skill_scores"] = Value::Object(scores);
    result
}
