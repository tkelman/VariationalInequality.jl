
type JuVIData
    F::Array{JuMP.NonlinearExpression,1}
    var::Array{JuMP.Variable,1}
end

function JuVIModel(solver=Ipopt.IpoptSolver(print_level=0))
    m = Model(solver=solver)
    m.ext[:VIP] = JuVIData(Array(JuMP.NonlinearExpression,0), Array(JuMP.Variable,0))
    return m
end

function getJuVIData(m::Model)
    if haskey(m.ext, :VIP)
        return m.ext[:VIP]::JuVIData
    else
        error("The 'getJuVIData' function is only for VIP models as in JuVI.jl")
    end
end

function setVIP(m::Model, expressions::Array{JuMP.NonlinearExpression,1}, variables::Array{JuMP.Variable,1})
    @assert length(expressions) == length(variables)

    data = getJuVIData(m)
    data.F = expressions
    data.var = variables

    return m
end


function solveVIP(m::Model    ; step_size=0.01,
                                algorithm=:fixed_point,
                                tolerance=1e-10,
                                max_iter=1000            )

    F = getJuVIData(m).F
    var = getJuVIData(m).var
    @assert length(F) == length(var)
    dim = length(F)

    x0 = zeros(dim)

    return solveVIP(m, x0, step_size=step_size, algorithm=algorithm, tolerance=tolerance, max_iter=max_iter)

end

function initial_projection(m, x0)
    var = getJuVIData(m).var
    dim = length(var)
    @setNLObjective(m, Min, sum{ ( var[i] - x0[i] )^2, i=1:dim} )
    status = solve(m)
    return getValue(var)
end

function gap_function(m, y)
    F = getJuVIData(m).F
    var = getJuVIData(m).var
    dim = length(F)

    setValue(var, y)
    Fy = getValue(F)

    @setNLObjective(m, Max, sum{ Fy[i]*(y[i]-var[i]), i=1:dim} )
    solve(m)
    gap = getObjectiveValue(m)
    return gap
end

function solveVIP(m::Model, x0; step_size=0.01,
                                algorithm=:fixed_point,
                                tolerance=1e-10,
                                max_iter=1000            )
    # :fixed_point basic fixed-point iteration, Section 12.1.1
    # :extra_gradient extragradient, Section 12.1.2

    # var = getJuVIData(m).var
    # F = getJuVIData(m).F
    # setValue(var, x0)
    # F0 = getValue(F)
    # println("F0=", F0)
    #
    # error("..........")

    x0 = initial_projection(m, x0)

    sol = []
    if algorithm==:fixed_point
        sol, F = _solve_fp(m, x0, step_size, tolerance, max_iter)
    elseif algorithm==:extra_gradient
        sol, F = _solve_eg(m, x0, step_size, tolerance, max_iter)
    elseif algorithm==:hyperplane
        sol, F = _solve_hp(m, x0, step_size, tolerance, max_iter)
    end

    gap = gap_function(m, sol)

    return sol, F, gap

end
