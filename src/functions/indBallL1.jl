# indicator of the L1 norm ball with given radius

export IndBallL1

"""
**Indicator of a ``L_1`` norm ball**

    IndBallL1(r=1.0)

Returns the indicator function of the set
```math
S = \\left\\{ x : \\sum_i |x_i| \\leq r \\right\\}.
```
Parameter `r` must be positive.
"""
struct IndBallL1{R <: Real} <: ProximableFunction
    r::R
    function IndBallL1{R}(r::R) where {R <: Real}
        if r <= 0
            error("parameter r must be positive")
        else
            new(r)
        end
    end
end

is_convex(f::IndBallL1) = true
is_set(f::IndBallL1) = true
is_prox_accurate(f::IndBallL1) = false

IndBallL1(r::R=1.0) where {R <: Real} = IndBallL1{R}(r)

function (f::IndBallL1)(x::AbstractArray{T}) where {R <: Real, T <: RealOrComplex{R}}
    if norm(x, 1) - f.r > f.r*eps(R)
        return R(Inf)
    end
    return R(0)
end

function prox!(y::AbstractArray{T}, f::IndBallL1, x::AbstractArray{T}, gamma::R=R(1)) where {R <: Real, T <: RealOrComplex{R}}
    # TODO: a faster algorithm
    if norm(x, 1) - f.r <= f.r*eps(R)
        y .= x
        return R(0)
    else # do a projection of abs(x) onto simplex then recover signs
        n = length(x)
        p = abs.(view(x,:))
        sort!(p, rev=true)
        s = R(0)
        @inbounds for i = 1:n-1
            s = s + p[i]
            tmax = (s - f.r)/i
            if tmax >= p[i+1]
                @inbounds for j in eachindex(x)
                    y[j] = sign(x[j])*max(abs(x[j])-tmax, R(0))
                end
                return R(0)
            end
        end
        tmax = (s + p[n] - f.r)/n
        @inbounds for j in eachindex(x)
            y[j] = sign(x[j])*max(abs(x[j])-tmax, R(0))
        end
        return R(0)
    end
end

fun_name(f::IndBallL1) = "indicator of an L1 norm ball"
fun_dom(f::IndBallL1) = "AbstractArray{Real}, AbstractArray{Complex}"
fun_expr(f::IndBallL1) = "x ↦ 0 if ‖x‖_1 ⩽ r, +∞ otherwise"
fun_params(f::IndBallL1) = "r = $(f.r)"

function prox_naive(f::IndBallL1, x::AbstractArray{T}, gamma::R=R(1)) where {R <: Real, T <: RealOrComplex{R}}
    # do a simple bisection (aka binary search) on λ
    L = R(0)
    U = maximum(abs, x)
    λ = L
    v = R(0)
    maxit = 120
    for iter in 1:maxit
        λ = 0.5*(L + U)
        v = sum(max.(abs.(x) .- λ, R(0)))
        # modify lower or upper bound
        (v < f.r) ? U = λ : L = λ
        # exit condition
        if abs(L - U) < (1 + abs(U))*eps(R)
            break
        end
    end
    return sign.(x) .* max.(R(0), abs.(x) .- λ), R(0)
end
