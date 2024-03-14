struct StateConstraint
    constraint::Constraint
    isactive::StateInt
end

function StateConstraint(sm::StateManager, constraint::Constraint)
    StateConstraint(constraint, make_state_int(sm, 1))
end


function propagate!(solver::Solver, sc::StateConstraint)
    if sc.isactive
        #sc.isactive = false # by default, constraints are disabled after propagation
        propagate!(solver, sc.constraint)
    end
end
