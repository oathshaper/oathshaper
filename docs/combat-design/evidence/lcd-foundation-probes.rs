#![cfg(test)]

use oathshaper_core::{rpg::*,runtime::*};
use serde_json::{json,Value};
use std::collections::BTreeSet;
fn resource()->Resource { Resource{id:"mana".into(),owner:"A".into(),unit:"point".into(),minimum:0,maximum:20,current:10} }
fn item(id:&str)->Item { Item{id:id.into(),definition:"wand/v1".into(),owner:"A".into(),parent:None,quantity:1,stack_key:"".into(),protected:false} }
fn equip(actor:&str,item:&str,slots:&[&str])->Mutation { Mutation::Equip{actor:actor.into(),item:item.into(),slots:slots.iter().map(|x|x.to_string()).collect()} }
fn source()->Source { Source::Item{item:"wand".into(),equipped:true} }
fn grant()->Grant { Grant{id:"g".into(),recipient:"A".into(),ability:"fire".into(),source:source()} }
#[test] fn reproduces_negative_claim_credit() {
 let mut r=RpgState::default();
 r.apply(&[Mutation::PutResource(resource()),Mutation::Reserve(Claim{id:"c".into(),owner:"A".into(),action:"cast".into(),target:ClaimTarget::Resource{resource:"mana".into(),amount:-7}}),Mutation::ConsumeClaim{id:"c".into()}]).unwrap();
 assert_eq!(r.resources()["mana"].current,17); assert!(r.claims().is_empty());
}
#[test] fn reproduces_equipped_grant_wrong_recipient() {
 let mut r=RpgState::default();
 r.apply(&[Mutation::InsertItem(item("wand")),equip("A","wand",&["hand"]),Mutation::AddGrant(grant())]).unwrap();
 r.apply(&[Mutation::Unequip{actor:"A".into(),slots:vec!["hand".into()]},Mutation::TransferItem{item:"wand".into(),owner:"B".into(),parent:None},equip("B","wand",&["hand"])]).unwrap();
 assert!(r.has_ability("A","fire")); assert_eq!(r.items()["wand"].owner,"B");
}
#[test] fn reproduces_explicit_revoke_missing_delta() {
 let mut r=RpgState::default();r.apply(&[Mutation::InsertItem(item("wand")),equip("A","wand",&["hand"]),Mutation::AddGrant(grant())]).unwrap();
 let c=r.apply(&[Mutation::RevokeSource(source())]).unwrap(); assert!(!r.has_ability("A","fire")); assert!(c.revoked_grants.is_empty());
}
#[test] fn reproduces_old_binding_claim_bypass() {
 let mut r=RpgState::default();r.apply(&[Mutation::InsertItem(item("wand")),equip("A","wand",&["left","right"]),Mutation::Reserve(Claim{id:"c".into(),owner:"A".into(),action:"cast".into(),target:ClaimTarget::Binding{actor:"A".into(),slot:"right".into()}})]).unwrap();
 r.apply(&[equip("A","wand",&["left"])]).unwrap();assert!(!r.bindings()["A"].contains_key("right"));assert!(r.claims().contains_key("c"));
}
#[test] fn verifies_batch_failure_keeps_all_resources() {
 let mut r=RpgState::default();r.apply(&[Mutation::PutResource(resource())]).unwrap();let old=r.clone();
 assert!(r.apply(&[Mutation::AdjustResource{id:"mana".into(),delta:-4},Mutation::AdjustResource{id:"missing".into(),delta:-1}]).is_err());assert_eq!(r,old);
}
struct Probe{custom:bool}
impl Profile for Probe {
 type State=u64;type Command=Value;type Advance=Value;type View=u64;type Preview=();
 fn manifest(&self)->Manifest { let mut m=Manifest::new("probe",1,"h");if self.custom { m.required_capabilities.insert("probe.timer/v1".into()); }m }
 fn preview(&self,_:&ReadContext<'_,u64>,_:Option<&str>,_:&Value)->RuleResult<()> {Ok(())}
 fn prepare_command(&self,t:&mut Transaction<u64>,_:Option<&str>,c:&Value)->RuleResult {t.entropy.below(6)?;t.observe("pose",1)?;t.occurrence("action/hit")?;t.state+=1;t.emit("hidden",42,Visibility::only("secret"))?;if c["fail"]==true {Err(RuleError::new("fail","secret reason").private("secret"))}else{Ok(())}}
 fn prepare_advance(&self,t:&mut Transaction<u64>,a:&Value)->RuleResult { self.prepare_command(t,None,a) }
 fn project(&self,c:&ReadContext<'_,u64>)->u64 {*c.state}
 fn validate(&self,_:&u64,_:&RpgState)->RuleResult {Ok(())}
 fn quiescent(&self,_:&u64,_:&RpgState)->bool {true}
}
fn principal()->Principal {Principal{id:"p".into(),role:Role::Player}}
fn lease(s:&mut Session<Probe>,h:&mut HostAuthority,a:&str)->String {s.issue_lease(h,principal(),a,LeaseScope{actors:BTreeSet::from(["A".into()]),..Default::default()}).unwrap()}
fn env(s:&Session<Probe>,l:&str,id:&str,rev:u64,fail:bool)->Envelope<Value>{Envelope{generation:s.generation(),epoch:s.epoch(),id:id.into(),lease:l.into(),expected_revision:rev,actor:Some("A".into()),payload:json!({"fail":fail})}}
#[test] fn verifies_rejection_entropy_cursor_rollback_and_retry() {
 let mut h=HostAuthority::default();let mut s=Session::new(Probe{custom:false},0,RpgState::default(),7,"s",&mut h).unwrap();let l=lease(&mut s,&mut h,"public");let e=env(&s,&l,"reject",0,true);
 let receipt=s.submit(e.clone()).unwrap();assert_eq!(receipt.status,Status::Rejected);assert_eq!(receipt.reason.unwrap().code,"unavailable");assert_eq!((*s.state(),s.revision(),s.entropy_draws(),s.ledger_sequence()),(0,0,0,1));
 let save:Value=serde_json::from_str(&s.save_json().unwrap()).unwrap();assert_eq!(save["observation_positions"],json!({}));assert_eq!(save["occurrences"],json!([]));
 s.submit(e).unwrap();assert_eq!(s.ledger_sequence(),1);
 let good=env(&s,&l,"good",0,false);let r=s.submit(good.clone()).unwrap();assert!(r.events.is_empty());assert_eq!((*s.state(),s.entropy_draws()),(1,1));
 s.submit(good.clone()).unwrap();assert_eq!((*s.state(),s.entropy_draws(),s.ledger_sequence()),(1,1,2));
 let secret=lease(&mut s,&mut h,"secret");let mut retry=good;retry.lease=secret;assert_eq!(s.submit(retry).unwrap().events.len(),1);
}
#[test] fn verifies_restore_fence_and_pause() {
 let mut h=HostAuthority::default();let mut s=Session::new(Probe{custom:false},0,RpgState::default(),7,"s",&mut h).unwrap();let l=lease(&mut s,&mut h,"public");let old=env(&s,&l,"late",0,false);let save=s.save_json().unwrap();s.restore_json(&save,&mut h).unwrap();assert!(s.restored_paused());assert!(s.submit(old).is_err());assert_eq!((*s.state(),s.ledger_sequence()),(0,0));
}
#[test] fn reproduces_restore_accepts_empty_fingerprint() {
 let mut h=HostAuthority::default();let mut s=Session::new(Probe{custom:false},0,RpgState::default(),7,"s",&mut h).unwrap();let l=lease(&mut s,&mut h,"public");let e=env(&s,&l,"good",0,false);s.submit(e).unwrap();let mut save:Value=serde_json::from_str(&s.save_json().unwrap()).unwrap();save["receipts"]["good"]["fingerprint"]=json!({});assert!(s.restore_json(&save.to_string(),&mut h).is_ok());
}
#[test] fn reproduces_profile_capability_rejected_by_fixed_kernel_list() {
 let mut h=HostAuthority::default();assert!(Session::new(Probe{custom:true},0,RpgState::default(),7,"s",&mut h).is_err());
}
