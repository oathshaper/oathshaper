use super::*;
use content::*;
use rules::*;
pub fn pool(s: &CommandState, r: &RpgState, actor: &str, unit: &str) -> Value {
    let id = resource_id(actor, unit);
    let p = &r.resources()[&id];
    let reserved = r.reserved(&id).unwrap_or(0);
    json!({"current":p.current,"reserved":reserved,"maximum":p.maximum,"free":p.current-reserved,"debt":s.debt.get(&id)})
}
fn costs(r: &RpgState, a: &Action) -> Vec<Value> {
    r.claims().values().filter(|c|c.action==a.id).filter_map(|c|match &c.target{ClaimTarget::Resource{resource,amount}=>Some(json!({"resource_id":resource,"label":r.resources()[resource].unit,"amount":amount,"unit":r.resources()[resource].unit})),ClaimTarget::Item{item,quantity}=>Some(json!({"resource_id":item,"label":"Field dressing","amount":quantity,"unit":"item"})),_=>None}).collect()
}
fn action(r: &RpgState, a: &Action) -> Value {
    json!({"id":a.id,"admission_sequence":a.sequence.to_string(),"ability_id":a.ability,"source_id":a.source,"actor_id":a.actor,"origin":if a.ai{"ai"}else{"player"},"target":a.target,"state":a.phase,"activation_at":a.activation,"impact_at":a.impact,"recovery_at":a.recovery,"approach_deadline_at":a.deadline,"timing_certain":a.phase!="approach"&&a.phase!="waiting","reserved_costs":costs(r,a),"paid_costs":if a.paid>0{vec![json!({"resource_id":resource_id(&a.actor,if a.ability=="disrupt_device"{"battery"}else{"focus"}),"label":"Paid","amount":a.paid,"unit":if a.ability=="disrupt_device"{"battery"}else{"focus"}})]}else{vec![]},"interruptible":a.phase=="windup"||a.phase=="approach","reasons":[]})
}
fn reasons(result: RuleResult) -> Vec<Value> {
    result.err().map(|e| json!(e.reason)).into_iter().collect()
}
fn offer(
    s: &CommandState,
    r: &RpgState,
    id: &str,
    label: &str,
    description: &str,
    command: CommandIntent,
) -> Value {
    let mut state = s.clone();
    let mut rpg = r.clone();
    let why = reasons(command_check(&mut state, &mut rpg, &command));
    json!({"id":id,"label":label,"name":label,"description":description,"action":command,"available":why.is_empty(),"reasons":why})
}
fn command_check(s: &mut CommandState, r: &mut RpgState, c: &CommandIntent) -> RuleResult {
    rules::command(s, r, c, false)
}
fn source_label(r: &RpgState, grant: &Grant) -> String {
    match &grant.source {
        Source::Item { item, .. } => r
            .items()
            .get(item)
            .and_then(|i| item_def(&i.definition).ok())
            .map(|d| format!("Equipped {}", d.name))
            .unwrap_or_else(|| "Lost equipment source".into()),
        Source::Investment { .. } => format!(
            "Learned {}",
            ability(&grant.ability).map(|a| a.name).unwrap_or("ability")
        ),
        Source::Innate { .. } => "Innate ability".into(),
        _ => "Granted ability".into(),
    }
}
pub fn project(ctx: &ReadContext<'_, CommandState>) -> Value {
    let s = ctx.state;
    let r = ctx.rpg;
    let inspected = &s.actors[&s.inspected];
    let recipient = &s.actors[&s.recipient];
    let actors:Vec<_>=s.actors.values().filter(|a|a.faction=="party"||((s.phase=="encounter"||s.phase=="victory"||s.phase=="defeat")&&super::combat::observable(s,&a.id))).map(|a|{let party=a.faction=="party";let binding=r.bindings().get(&a.id);let appearance=|slot:&str|binding.and_then(|b|b.get(slot)).and_then(|i|r.items().get(i)).and_then(|i|item_def(&i.definition).ok()).map(|d|d.appearance).unwrap_or(if slot=="main_hand"{"unarmed"}else{"none"});json!({"id":a.id,"name":a.name,"faction":a.faction,"body":a.body,"roster_status":if !party{"encounter"}else if a.guest&&a.deployed{"guest_deployed"}else if a.guest{"guest_reserve"}else if a.deployed{"deployed"}else{"reserve"},"conscious":health(r,&a.id)>0,"position":if a.deployed{Some([a.position[0]as f64/1000.,a.position[1]as f64/1000.])}else{None},"health":pool(s,r,&a.id,"health"),"focus":if party{Some(pool(s,r,&a.id,"focus"))}else{None},"battery":if party{Some(pool(s,r,&a.id,"battery"))}else{None},"stats":{"level":party.then_some(a.level),"defense":party.then(||defense(s,r,&a.id)),"attack":party.then(||attack(s,r,&a.id)),"power_dc":party.then(||10+i64::from(a.level/2)+a.attributes["spirit"]),"saves":{"fortitude":party.then_some(0),"reflex":party.then_some(a.attributes["agility"]),"will":party.then_some(a.attributes["spirit"]) }},"appearance":{"model":match a.id.as_str(){"sentinel"=>"iron_sentinel","hound"=>"lantern_sentinel","corsair_raider"=>"crimson_corsair",_=>a.id.as_str()},"main_hand":appearance("main_hand"),"offhand":appearance("offhand"),"armor":appearance("body")},"conditions":a.conditions.iter().map(|(k,v)|json!({"id":k,"kind":k,"label":if k=="ward"{format!("Ward {} / {}",a.ward_remaining,a.ward_strength)}else{k.clone()},"expires_at":v})).collect::<Vec<_>>(),"active_action":a.active.as_ref().map(|a|action(r,a)),"queue":if party{a.queue.iter().map(|a|action(r,a)).collect::<Vec<_>>()}else{vec![]},"ai":party.then(||json!({"policy":a.policy,"empty_policy":a.empty_policy,"hold_after_orders":a.hold,"last_reason":super::combat::ai_reason(s,r,&a.id)})),"knowledge":if party{"party"}else{"visible"}})}).collect();
    let mut actions = vec![];
    for grant in r.grants().values().filter(|g| g.recipient == recipient.id) {
        if let Ok(ab) = ability(&grant.ability) {
            let mut why = reasons(availability(s, r, &recipient.id, &grant.ability, &grant.id));
            let unit = if ab.id == "disrupt_device" {
                "battery"
            } else {
                "focus"
            };
            if r.available(&resource_id(&recipient.id, unit)).unwrap_or(0) < ab.cost {
                why.push(json!({"code":"resource","message":"Insufficient free resource"}));
            }
            if recipient.queue.len() >= 4 {
                why.push(
                    json!({"code":"queue_full","message":"Four future orders are already queued"}),
                );
            }
            actions.push(json!({"id":ab.id,"name":ab.name,"description":ab.description(),"category":ab.category,"rank":1,"source_id":grant.id,"source_label":source_label(r,grant),"target_kind":ab.target,"range_m":effective_range(r,&recipient.id,&ab,&grant.id)as f64/1000.,"radius_m":ab.radius as f64/1000.,"costs":if ab.cost>0{vec![json!({"resource_id":resource_id(&recipient.id,unit),"label":unit,"amount":ab.cost,"unit":unit})]}else{vec![]},"available":why.is_empty(),"reasons":why,"cooldown_remaining_ticks":recipient.ready.saturating_sub(s.tick),"known":true,"ghost":false}));
        }
    }
    for grant in s
        .lost_grants
        .values()
        .filter(|g| g.recipient == recipient.id && !r.grants().contains_key(&g.id))
    {
        if let Ok(ab) = ability(&grant.ability) {
            actions.push(json!({"id":ab.id,"name":ab.name,"description":ab.description(),"category":ab.category,"rank":1,"source_id":grant.id,"source_label":source_label(r,grant),"target_kind":ab.target,"range_m":ab.range as f64/1000.,"radius_m":ab.radius as f64/1000.,"costs":[],"available":false,"reasons":[{"code":"source_lost","message":"The bound source is no longer equipped; rebind explicitly"}],"cooldown_remaining_ticks":0,"known":true,"ghost":true}));
        }
    }
    let mut options = vec![];
    let mut items = vec![];
    for item in r.items().values() {
        let def = item_def(&item.definition).expect("validated item definition");
        let bound = r
            .bindings()
            .iter()
            .find(|(_, slots)| slots.values().any(|i| i == &item.id));
        let slots: Vec<_> = bound
            .map(|(_, b)| {
                b.iter()
                    .filter(|(_, i)| *i == &item.id)
                    .map(|(s, _)| s.clone())
                    .collect()
            })
            .unwrap_or_default();
        let reserved: u32 = r
            .claims()
            .values()
            .filter_map(|c| match &c.target {
                ClaimTarget::Item { item: id, quantity } if id == &item.id => Some(*quantity),
                _ => None,
            })
            .sum();
        let mut operations = vec![];
        if item.definition == "dressing" {
            // Self is a legal representative target for opening the ally picker.
            // The eventual picked target is validated again by the same command.
            let mut operation = offer(
                s,
                r,
                &format!("use:{}", item.id),
                "Use field dressing",
                "Choose a party member to treat",
                CommandIntent::Use {
                    actor_id: inspected.id.clone(),
                    item_id: item.id.clone(),
                    target: Target::actor(&inspected.id),
                },
            );
            operation["kind"] = json!("inventory.use");
            operation["target_kind"] = json!("ally");
            operations.push(operation);
        }
        items.push(json!({"id":item.id,"definition_id":item.definition,"name":def.name,"category":def.category,"description":format!("{}; {}",def.name,def.category),"compatible_slots":def.slots,"occupies_slots":def.slots,"grants":def.grants,"container_id":item.owner,"quantity":item.quantity,"reserved":reserved,"free":item.quantity-reserved,"bound_actor_id":bound.map(|(a,_)|a),"bound_slots":slots,"binding_version":bound.map(|(a,_)|s.actors[a].binding_version.to_string()).unwrap_or_else(||"0".into()),"host_item_id":item.parent,"favorite":false,"quest_protected":item.protected,"accessible":item.owner=="party_pack"||s.phase=="camp","reasons":[],"operations":operations}));
        if !def.slots.is_empty() {
            let mut changes: Vec<_> = def
                .slots
                .iter()
                .map(|slot| SlotChange {
                    slot_id: (*slot).into(),
                    item_id: Some(item.id.clone()),
                })
                .collect();
            if def.slots.contains(&"main_hand") {
                if let Some(old) = r
                    .bindings()
                    .get(&inspected.id)
                    .and_then(|b| b.get("main_hand"))
                {
                    if r.bindings()
                        .get(&inspected.id)
                        .and_then(|b| b.get("offhand"))
                        == Some(old)
                        && !def.slots.contains(&"offhand")
                    {
                        changes.push(SlotChange {
                            slot_id: "offhand".into(),
                            item_id: None,
                        });
                    }
                }
            }
            let mut o = offer(
                s,
                r,
                &format!("equip:{}", item.id),
                def.name,
                "Equip this owned instance",
                CommandIntent::Equip {
                    actor_id: inspected.id.clone(),
                    expected_binding_version: inspected.binding_version.to_string(),
                    changes,
                    cancel_action_ids: vec![],
                },
            );
            o["item_id"] = json!(item.id);
            o["slot_ids"] = json!(def.slots);
            options.push(o);
        }
    }
    if let Some(bindings) = r.bindings().get(&inspected.id) {
        for item in bindings.values().collect::<BTreeSet<_>>() {
            let slots: Vec<_> = bindings
                .iter()
                .filter(|(_, i)| *i == item)
                .map(|(s, _)| s.clone())
                .collect();
            let mut o = offer(
                s,
                r,
                &format!("unequip:{item}"),
                &format!(
                    "Unequip {}",
                    item_def(&r.items()[item].definition).unwrap().name
                ),
                "Return item to the party pack",
                CommandIntent::Equip {
                    actor_id: inspected.id.clone(),
                    expected_binding_version: inspected.binding_version.to_string(),
                    changes: slots
                        .iter()
                        .map(|s| SlotChange {
                            slot_id: s.clone(),
                            item_id: None,
                        })
                        .collect(),
                    cancel_action_ids: vec![],
                },
            );
            o["item_id"] = Value::Null;
            o["slot_ids"] = json!(slots);
            options.push(o);
        }
    }
    let mut presets = vec![];
    if inspected.id == "clerk" && inspected.level == 6 {
        presets.push(offer(
            s,
            r,
            "clerk_level_7",
            "Pathfinder level 7",
            "Devices +2, Lore +2, Medicine +2, Marksmanship II",
            CommandIntent::Level {
                actor_id: "clerk".into(),
                expected_build_version: inspected.build_version.to_string(),
                class_id: "scout".into(),
                skills: ["devices", "lore", "medicine"]
                    .into_iter()
                    .map(|id| RankChoice {
                        id: id.into(),
                        ranks: 2,
                    })
                    .collect(),
                feats: vec!["marksmanship_ii".into()],
                powers: vec![],
                attributes: vec![],
                unbind_item_ids: vec![],
            },
        ));
    }
    for (id, name, command) in super::progression::presets(s, r, &inspected.id) {
        presets.push(offer(
            s,
            r,
            &format!("respec:{id}"),
            &name,
            "Rebuild choices serially; preserve resource depletion and identity",
            command,
        ));
    }
    let capabilities = vec![
        offer(
            s,
            r,
            "start",
            "Begin garden encounter",
            "Enter the practice encounter",
            CommandIntent::Start {
                encounter_id: "garden_patrol".into(),
            },
        ),
        offer(
            s,
            r,
            "camp",
            "Return to camp",
            "Settle the completed encounter",
            CommandIntent::Camp {
                camp_id: "garden_camp".into(),
            },
        ),
        offer(
            s,
            r,
            "rest",
            "Rest at camp",
            "Restore Health, Focus and tools over five simulation seconds",
            CommandIntent::Rest {
                camp_id: "garden_camp".into(),
            },
        ),
        offer(
            s,
            r,
            "craft_arc_edge",
            "Craft arc edge",
            "Four scrap and 20 credits; four Devices ranks required",
            CommandIntent::Craft {
                actor_id: inspected.id.clone(),
                recipe_id: "arc_edge".into(),
            },
        ),
        offer(
            s,
            r,
            "buy_dressing",
            "Buy dressing",
            "One field dressing for eight credits",
            CommandIntent::Buy {
                stock_id: "dressing".into(),
                quantity: 1,
            },
        ),
        offer(
            s,
            r,
            "workbench_lock",
            "Open workbench lock",
            "Devices 16, uses this actor's complete check",
            CommandIntent::Skill {
                actor_id: inspected.id.clone(),
                interaction_id: "workbench_lock".into(),
            },
        ),
    ];
    json!({"schema":"command.view/v1","session":{"profile_id":"command","generation":"host","epoch":ctx.epoch.to_string(),"revision":ctx.revision.to_string(),"ledger_sequence":"host","content_hash":CONTENT_HASH,"tick":s.tick,"tick_ms":100,"phase":s.phase},"clock":{"paused":!s.pauses.is_empty(),"can_advance":s.pauses.is_empty(),"pause_reasons":s.pauses.iter().map(|(id,p)|json!({"token":id,"owner":p.owner,"label":if p.owner=="orders_empty"{format!("{} needs orders",s.actors[&p.context].name)}else{p.owner.clone()},"acknowledgeable":p.automatic&&p.owner!="defeat"})).collect::<Vec<_>>()},"party":{"roster_ids":PARTY,"deployed_ids":PARTY.iter().filter(|id|s.actors[**id].deployed).collect::<Vec<_>>(),"recipient_id":s.recipient,"possessed_id":s.possessed,"inspected_id":s.inspected,"camera_follow_id":s.camera,"selected_target_id":s.selected_target},"actors":actors,"actions":actions,"targets":s.actors.values().filter(|a|a.deployed&&(a.faction=="party"||(s.phase=="encounter"&&super::combat::observable(s,&a.id)))&&health(r,&a.id)>0).map(|a|json!({"id":a.id,"label":a.name,"relation":if a.faction==recipient.faction{"ally"}else{"enemy"},"position":[a.position[0]as f64/1000.,a.position[1]as f64/1000.],"knowledge":"visible","identified_defenses":{"defense":Value::Null,"fortitude":Value::Null,"reflex":Value::Null,"will":Value::Null}})).collect::<Vec<_>>(),"equipment":{"actor_id":inspected.id,"binding_version":inspected.binding_version.to_string(),"body":inspected.body,"slots":SLOTS.iter().map(|slot|json!({"id":slot,"item_id":r.bindings().get(&inspected.id).and_then(|b|b.get(*slot))})).collect::<Vec<_>>(),"active_set_id":Value::Null,"sets":[],"options":options},"inventory":{"currency":{"credits":r.resources()["party:credits"].current},"capacity":Value::Null,"used_stacks":r.items().len(),"containers":[{"id":"party_pack","name":"Party pack","accessible":true},{"id":"camp_storage","name":"Camp storage","accessible":s.phase=="camp"}],"items":items},"progression":{"actor_id":inspected.id,"build_version":inspected.build_version.to_string(),"xp":inspected.xp,"level":inspected.level,"pending_levels":u32::from(inspected.xp>=100*(inspected.level+1)*inspected.level/2),"classes":inspected.classes.iter().map(|(id,l)|json!({"id":id,"level":l})).collect::<Vec<_>>(),"attributes":inspected.attributes.iter().map(|(id,n)|json!({"id":id,"base":n,"gear":0,"total":n})).collect::<Vec<_>>(),"skills":inspected.skills.iter().map(|(id,n)|{let attr=match id.as_str(){"devices"|"lore"=>"intellect","medicine"|"insight"=>"spirit","diplomacy"=>"presence",_=>"agility"};let modifier=inspected.attributes[attr];let bonus=if id=="devices"&&inspected.classes.get("scout").copied().unwrap_or(0)>=3{2}else{0};json!({"id":id,"rank":n,"governing_modifier":modifier,"bonus":bonus,"total":i64::from(*n)+modifier+bonus,"max_rank":inspected.level+2})}).collect::<Vec<_>>(),"feats":inspected.feats.iter().map(|id|json!({"id":id,"rank":1})).collect::<Vec<_>>(),"powers":r.grants().values().filter(|g|g.recipient==inspected.id&&ability(&g.ability).is_ok_and(|a|a.magic)).map(|g|json!({"id":g.ability,"rank":1,"source_id":g.id})).collect::<Vec<_>>(),"unspent":{"skill_points":inspected.unspent,"feat_choices":inspected.unspent_feats,"power_choices":inspected.unspent_powers,"attribute_points":inspected.unspent_attributes},"next_choices":[],"presets":presets,"respec":{"cost":s.respec_cost,"currency":"credits","available":s.phase=="camp"&&health(r,&inspected.id)>0,"reasons":[]}},"world_actions":[],"capabilities":capabilities,"logs":s.logs.iter().map(|l|json!({"id":l.id,"tick":l.tick,"kind":l.kind,"actor_id":l.actor_id,"target_id":l.target_id,"text":l.text,"details":{"roll":l.roll,"modifier":l.modifier,"threshold":l.threshold,"damage":l.damage,"healing":l.healing,"resource_delta":Value::Null}})).collect::<Vec<_>>(),"log_cursor":s.logs.last().map(|l|&l.id),"encounter":{"id":(s.encounter>0).then_some("garden_patrol"),"objective":"Defeat the raider and his two guards. Recover the stolen payroll.","status":match s.phase.as_str(){"encounter"=>"active","victory"=>"won","defeat"=>"lost",_=>"none"},"can_retreat":s.phase=="encounter","outcome":s.outcome,"reward_receipt_id":s.reward,"checkpoint_id":s.checkpoint_id,"camp_id":"garden_camp","trial":true},"space":{"waiting":false,"reason":Value::Null}})
}
