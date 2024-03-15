struct StateConstraint
    constraint::Constraint
    isactive::StateInt
end

function StateConstraint(sm::StateManager, constraint::Constraint)
    return StateConstraint(constraint, make_state_int(sm, 1))
end
