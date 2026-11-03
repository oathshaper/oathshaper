use super::*;
use rules::*;
pub const GARDEN_JSON: &str = include_str!("../../../../godot/content/command_garden.json");
pub fn requests(s: &CommandState, generation: u64, revision: u64) -> Vec<SpaceRequest> {
    let mut requests = BTreeMap::new();
    let mut add = |id: String,
                   kind: &str,
                   actor: &str,
                   target: Option<String>,
                   from: [i64; 2],
                   to: [i64; 2],
                   purpose: &str| {
        requests.insert(
            id.clone(),
            SpaceRequest {
                id,
                generation: generation.to_string(),
                geometry_revision: s.geometry_revision.clone(),
                tick: s.tick,
                state_revision: revision.to_string(),
                kind: kind.into(),
                actor_id: actor.into(),
                target_actor_id: target,
                from_mm: from,
                to_mm: to,
                radius_mm: if kind == "los" { 0 } else { 350 },
                maximum_distance_mm: 20000,
                required_for: purpose.into(),
            },
        );
    };
    for a in s.actors.values().filter(|a| a.deployed) {
        for b in s.actors.values().filter(|b| b.deployed && b.id != a.id) {
            add(
                format!("los:{}:{}", a.id, b.id),
                "los",
                &a.id,
                Some(b.id.clone()),
                a.position,
                b.position,
                "impact",
            );
        }
        for action in a.active.iter().chain(a.queue.first()) {
            if let Some(target) = target_position(s, action) {
                add(
                    format!("path:{}:{}", a.id, action.id),
                    "path",
                    &a.id,
                    action.target.actor_id.clone(),
                    a.position,
                    target,
                    "activation",
                );
                let staging = approach_destination(s, action, target);
                if staging != target {
                    add(
                        format!("staging:{}:{}", a.id, action.id),
                        "path",
                        &a.id,
                        action.target.actor_id.clone(),
                        a.position,
                        staging,
                        "activation",
                    );
                }
                if action.target.kind == "point" {
                    add(
                        format!("los:{}:{}", a.id, action.id),
                        "los",
                        &a.id,
                        None,
                        a.position,
                        target,
                        "impact",
                    );
                }
            }
        }
        let apart = separation_endpoint(s, &a.id);
        if apart != a.position {
            add(
                format!("separation:{}:{}:{}", a.id, a.position[0], a.position[1]),
                "swept_path",
                &a.id,
                None,
                a.position,
                apart,
                "movement",
            );
        }
        if let Some(action) = a
            .active
            .as_ref()
            .filter(|action| action.ability == "gust" && action.phase == "windup")
        {
            if let Some(target) = action
                .target
                .actor_id
                .as_ref()
                .and_then(|id| s.actors.get(id))
            {
                for n in 1..=8 {
                    add(
                        format!("push:{}:{n}", action.id),
                        "swept_path",
                        &target.id,
                        None,
                        target.position,
                        push_endpoint(a.position, target.position, n),
                        "impact",
                    );
                }
            }
        }
        if a.direction != [0., 0.] {
            let target = [
                a.position[0] + (a.direction[0] * 300.).round() as i64,
                a.position[1] + (a.direction[1] * 300.).round() as i64,
            ];
            add(
                format!("movement:{}", a.id),
                "swept_path",
                &a.id,
                None,
                a.position,
                target,
                "movement",
            );
        }
    }
    requests.into_values().collect()
}

/// Choose a free place within melee reach instead of routing every attacker
/// through the target's center. Geometry still decides whether the path exists.
fn approach_destination(s: &CommandState, action: &Action, target: [i64; 2]) -> [i64; 2] {
    if !["basic", "lunge", "shield_bash"].contains(&action.ability.as_str())
        || action
            .target
            .actor_id
            .as_ref()
            .is_none_or(|id| s.actors[id].faction == s.actors[&action.actor].faction)
    {
        return target;
    }
    let from = s.actors[&action.actor].position;
    let bearing = ((from[1] - target[1]) as f64).atan2((from[0] - target[0]) as f64);
    [
        0.,
        0.55,
        -0.55,
        1.1,
        -1.1,
        1.65,
        -1.65,
        std::f64::consts::PI,
    ]
    .into_iter()
    .map(|offset| {
        let angle = bearing + offset;
        let point = [
            target[0] + (angle.cos() * 1700.).round() as i64,
            target[1] + (angle.sin() * 1700.).round() as i64,
        ];
        let crowd: f64 = s
            .actors
            .values()
            .filter(|a| {
                a.deployed && a.id != action.actor && Some(&a.id) != action.target.actor_id.as_ref()
            })
            .map(|a| (1400. - distance(point, a.position)).max(0.) * 5.)
            .sum();
        (point, distance(from, point) + crowd)
    })
    .min_by(|a, b| a.1.total_cmp(&b.1))
    .unwrap()
    .0
}

/// Soft personal space with a bounded step. A stable ID direction resolves
/// exact overlap; no render-only displacement or random jitter is involved.
pub(super) fn separation_endpoint(s: &CommandState, id: &str) -> [i64; 2] {
    let from = s.actors[id].position;
    let mut offset = [0., 0.];
    for other in s.actors.values().filter(|a| a.deployed && a.id != id) {
        let d = distance(from, other.position);
        let personal_space = if s.actors[id].faction == other.faction {
            2000.
        } else {
            1450.
        };
        if d >= personal_space {
            continue;
        }
        let away = if d < 1. {
            [if id < other.id.as_str() { -1. } else { 1. }, 0.]
        } else {
            [
                (from[0] - other.position[0]) as f64 / d,
                (from[1] - other.position[1]) as f64 / d,
            ]
        };
        let amount = (personal_space - d) * 0.25;
        offset[0] += away[0] * amount;
        offset[1] += away[1] * amount;
    }
    let length = offset[0].hypot(offset[1]);
    let scale = if length > 90. { 90. / length } else { 1. };
    [
        from[0] + (offset[0] * scale).round() as i64,
        from[1] + (offset[1] * scale).round() as i64,
    ]
}

/// Prevent a step from creating a new overlap, but allow actors already close
/// together to leave. Sample the whole step so a lunge cannot tunnel through.
pub(super) fn uncrowded_step(s: &CommandState, id: &str, to: [i64; 2]) -> [i64; 2] {
    let from = s.actors[id].position;
    let mut accepted = from;
    let samples = (distance(from, to) / 50.).ceil().max(1.) as i64;
    for n in 1..=samples {
        let point = [
            from[0] + (to[0] - from[0]) * n / samples,
            from[1] + (to[1] - from[1]) * n / samples,
        ];
        if s.actors
            .values()
            .filter(|a| a.deployed && a.id != id)
            .any(|a| {
                distance(point, a.position) + 1.
                    < distance(from, a.position).min(if a.faction == s.actors[id].faction {
                        1400.
                    } else {
                        1000.
                    })
            })
        {
            break;
        }
        accepted = point;
    }
    accepted
}
pub(super) fn push_endpoint(from: [i64; 2], origin: [i64; 2], steps: i64) -> [i64; 2] {
    let length = distance(from, origin);
    if length == 0. {
        return origin;
    }
    let displacement = (steps * 250) as f64;
    [
        origin[0] + (((origin[0] - from[0]) as f64 / length) * displacement).round() as i64,
        origin[1] + (((origin[1] - from[1]) as f64 / length) * displacement).round() as i64,
    ]
}
/// Deterministic fixture adapter over the same authored data as Godot's adapter.
/// It supplies geometry only; it cannot submit damage, entropy or outcomes.
pub fn fixture_frame(requests: &[SpaceRequest], sequence: u64) -> RuleResult<SpaceFrame> {
    let first = requests
        .first()
        .ok_or_else(|| err("geometry", "Empty geometry request"))?;
    let geometry: Value = serde_json::from_str(GARDEN_JSON)?;
    let mut results = vec![];
    for q in requests {
        let from = [q.from_mm[0] as f64 / 1000., q.from_mm[1] as f64 / 1000.];
        let to = [q.to_mm[0] as f64 / 1000., q.to_mm[1] as f64 / 1000.];
        let radius = q.radius_mm as f64 / 1000.;
        let mut answer = SpaceResult {
            request_id: q.id.clone(),
            valid: true,
            reason_code: None,
            position_mm: None,
            visible: None,
            clear: None,
            path_mm: vec![],
            ground_height_mm: None,
        };
        match q.kind.as_str() {
            "los" | "visibility" => {
                let clear = line_clear(&geometry, from, to, 0., false);
                answer.clear = Some(clear);
                answer.visible =
                    Some(clear && distance(q.from_mm, q.to_mm) <= q.maximum_distance_mm as f64);
            }
            "swept_path" => answer.clear = Some(line_clear(&geometry, from, to, radius, true)),
            "path" => {
                answer.path_mm = route(&geometry, from, to, radius)
                    .into_iter()
                    .map(|p| [(p[0] * 1000.).round() as i64, (p[1] * 1000.).round() as i64])
                    .collect();
                answer.clear = Some(!answer.path_mm.is_empty());
            }
            "pose" => {
                if walkable(&geometry, to, radius) {
                    answer.position_mm = Some(q.to_mm)
                }
            }
            "ground" => {
                if walkable(&geometry, to, radius) {
                    answer.ground_height_mm = Some(if to[0] < -4.59 {
                        (-578. * (1. - ((to[0] + 8.33) / 3.74).clamp(0., 1.))).round() as i64
                    } else {
                        0
                    });
                }
            }
            _ => return Err(err("geometry", "Unknown query variant")),
        }
        results.push(answer);
    }
    Ok(SpaceFrame {
        generation: first.generation.clone(),
        geometry_revision: first.geometry_revision.clone(),
        tick: first.tick,
        state_revision: first.state_revision.clone(),
        producer_id: "headless-garden".into(),
        sequence: sequence.to_string(),
        results,
    })
}
fn point(value: &Value) -> [f64; 2] {
    [value[0].as_f64().unwrap(), value[1].as_f64().unwrap()]
}
fn rect(obstacle: &Value, radius: f64) -> ([f64; 2], [f64; 2]) {
    let c = point(&obstacle["center"]);
    let size = point(&obstacle["size"]);
    (
        [c[0] - size[0] / 2. - radius, c[1] - size[1] / 2. - radius],
        [c[0] + size[0] / 2. + radius, c[1] + size[1] / 2. + radius],
    )
}
fn walkable(g: &Value, p: [f64; 2], radius: f64) -> bool {
    for offset in [
        [0., 0.],
        [radius, radius],
        [-radius, radius],
        [radius, -radius],
        [-radius, -radius],
    ] {
        let p = [p[0] + offset[0], p[1] + offset[1]];
        if !g["walkable"].as_array().unwrap().iter().any(|f| {
            let min = point(&f["min"]);
            let max = point(&f["max"]);
            p[0] >= min[0] && p[0] <= max[0] && p[1] >= min[1] && p[1] <= max[1]
        }) {
            return false;
        }
    }
    !g["obstacles"].as_array().unwrap().iter().any(|o| {
        let (min, max) = rect(o, radius);
        p[0] >= min[0] && p[0] < max[0] && p[1] >= min[1] && p[1] < max[1]
    })
}
fn crosses(from: [f64; 2], to: [f64; 2], min: [f64; 2], max: [f64; 2]) -> bool {
    let mut near = 0.0_f64;
    let mut far = 1.0_f64;
    for axis in 0..2 {
        let d = to[axis] - from[axis];
        if d.abs() < 0.00001 {
            if from[axis] < min[axis] || from[axis] > max[axis] {
                return false;
            }
        } else {
            let a = (min[axis] - from[axis]) / d;
            let b = (max[axis] - from[axis]) / d;
            near = near.max(a.min(b));
            far = far.min(a.max(b));
            if near > far {
                return false;
            }
        }
    }
    true
}
fn line_clear(g: &Value, from: [f64; 2], to: [f64; 2], radius: f64, floor: bool) -> bool {
    if g["obstacles"].as_array().unwrap().iter().any(|o| {
        let (min, max) = rect(o, radius);
        crosses(from, to, min, max)
    }) {
        return false;
    }
    if floor {
        let samples = ((to[0] - from[0]).hypot(to[1] - from[1]) / 0.2)
            .ceil()
            .max(1.) as u32;
        for i in 0..=samples {
            let f = f64::from(i) / f64::from(samples);
            if !walkable(
                g,
                [
                    from[0] + (to[0] - from[0]) * f,
                    from[1] + (to[1] - from[1]) * f,
                ],
                radius,
            ) {
                return false;
            }
        }
    }
    true
}
fn route(g: &Value, from: [f64; 2], to: [f64; 2], radius: f64) -> Vec<[f64; 2]> {
    if !walkable(g, from, radius) || !walkable(g, to, radius) {
        return vec![];
    }
    if line_clear(g, from, to, radius, true) {
        return vec![from, to];
    }
    let mut points = vec![from, to];
    for o in g["obstacles"].as_array().unwrap() {
        let (min, max) = rect(o, radius + 0.015);
        for p in [min, [max[0], min[1]], max, [min[0], max[1]]] {
            if walkable(g, p, radius) {
                points.push(p)
            }
        }
    }
    for portal in g["portals"].as_array().unwrap() {
        let p = point(portal);
        if walkable(g, p, radius) {
            points.push(p)
        }
    }
    let mut distances = vec![f64::INFINITY; points.len()];
    let mut previous = vec![None; points.len()];
    let mut visited = BTreeSet::new();
    distances[0] = 0.;
    while let Some(current) = (0..points.len())
        .filter(|i| !visited.contains(i))
        .min_by(|a, b| distances[*a].total_cmp(&distances[*b]))
    {
        if !distances[current].is_finite() {
            break;
        }
        if current == 1 {
            let mut path = vec![to];
            let mut cursor = 1;
            while let Some(p) = previous[cursor] {
                path.push(points[p]);
                cursor = p;
            }
            path.reverse();
            return path;
        }
        visited.insert(current);
        for target in 0..points.len() {
            if !visited.contains(&target)
                && line_clear(g, points[current], points[target], radius, true)
            {
                let d = distances[current]
                    + (points[current][0] - points[target][0])
                        .hypot(points[current][1] - points[target][1]);
                if d < distances[target] {
                    distances[target] = d;
                    previous[target] = Some(current)
                }
            }
        }
    }
    vec![]
}
