//! Spatial wire shared with the authored garden adapter; no Command combat rules are used.
use super::*;
use rules::*;
/// Endpoint identities prevent a result observed before movement being reused
/// after movement or a push. The host still owns the actual geometric answer.
pub(super) fn pose_query(kind: &str, a: &str, b: &str, from: [i64; 2], to: [i64; 2]) -> String {
    format!("{kind}:{a}:{b}:{}:{}:{}:{}", from[0], from[1], to[0], to[1])
}
fn candidates(s: &State, a: &Actor) -> BTreeSet<[i64; 2]> {
    BTreeSet::from([a.position, movement(s, a)])
}
pub(super) fn movement(s: &State, a: &Actor) -> [i64; 2] {
    let mut speed = if a.id == "player" {
        if a.dodge_until > s.tick && s.tick < a.dodge_started + 8 {
            250
        } else if a.guard {
            75
        } else {
            200
        }
    } else if a.faction == "hostile" {
        90
    } else {
        150
    };
    if a.faction == "hostile" && s.focus {
        speed /= 2;
    }
    if a.slow > s.tick {
        speed = speed * 3 / 4;
    }
    if a.stun > s.tick
        || (a.id == "player"
            && (s.healing || a.dodge_until > s.tick && s.tick >= a.dodge_started + 8))
    {
        speed = 0;
    }
    // An idle dodge borrows a backward vector without latching walking input.
    let direction = if a.id == "player" && a.dodge_until > s.tick && a.direction == [0, 0] {
        [-a.facing[0], -a.facing[1]]
    } else {
        a.direction
    };
    [
        a.position[0] + direction[0] * speed / 1000,
        a.position[1] + direction[1] * speed / 1000,
    ]
}
pub(super) fn requests(s: &State, g: u64, r: u64) -> Vec<SpaceRequest> {
    let mut list = vec![];
    let mut add = |id: String,
                   kind: &str,
                   actor: &str,
                   target: Option<String>,
                   from: [i64; 2],
                   to: [i64; 2]| {
        list.push(SpaceRequest {
            id,
            generation: g.to_string(),
            geometry_revision: "garden-1".into(),
            tick: s.tick,
            state_revision: r.to_string(),
            kind: kind.into(),
            actor_id: actor.into(),
            target_actor_id: target,
            from_mm: from,
            to_mm: to,
            radius_mm: if kind == "los" { 0 } else { 420 },
            maximum_distance_mm: 20000,
            required_for: "flow_tick".into(),
        })
    };
    for a in s.actors.values().filter(|a| a.deployed) {
        for b in s.actors.values().filter(|b| b.deployed && b.id != a.id) {
            // Either sweep may be blocked. Query each bounded endpoint pair,
            // then the resolver selects only the pair that actually committed.
            for from in candidates(s, a) {
                for to in candidates(s, b) {
                    add(
                        pose_query("los", &a.id, &b.id, from, to),
                        "los",
                        &a.id,
                        Some(b.id.clone()),
                        from,
                        to,
                    );
                }
            }
        }
        add(
            format!("move:{}", a.id),
            "swept_path",
            &a.id,
            None,
            a.position,
            movement(s, a),
        );
        let hero = &s.actors["player"];
        if a.faction == "hostile" {
            for source in candidates(s, hero) {
                for target in candidates(s, a) {
                    let d = toward(source, target);
                    add(
                        pose_query("push", &hero.id, &a.id, source, target),
                        "swept_path",
                        &a.id,
                        None,
                        target,
                        [target[0] + d[0], target[1] + d[1]],
                    );
                }
            }
        }
    }
    list
}
