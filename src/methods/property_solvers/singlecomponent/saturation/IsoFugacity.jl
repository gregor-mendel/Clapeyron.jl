"""
    psat_init(model::EoSModel, T)

Initial point for saturation pressure, given the temperature and V,T critical coordinates.
On moderate pressures it will use a Zero Pressure initialization. On pressures near the critical point it will switch to spinodal finding.

It can be overloaded to provide more accurate estimates if necessary.
"""
function psat_init(model,T)
    Tc, Pc, Vc = crit_pure(model)
    if T > Tc
        return zero(T)/zero(T)
    end
    return psat_init(model, T, Tc, Vc)
end

function psat_init(model::EoSModel, T, Tc, Vc)
    # Function to get an initial guess for the saturation pressure at a given temperature
    z = SA[1.] #static vector
    _0 = zero(T+Tc+Vc)
    RT = R̄*T
    Tr = T/Tc
    # Zero pressure initiation
    if Tr < 0.8
        P0 = _0
        vol_liq0 = volume(model, P0, T, phase=:liquid)
        ares = a_res(model, vol_liq0, T, z)
        lnϕ_liq0 = ares - 1. + log(RT/vol_liq0)
        P0 = exp(lnϕ_liq0)
    # Pmin, Pmax initiation
    elseif Tr <= 1.0
        low_v = Vc
        up_v = 5 * Vc
        #note: P_max is the pressure at the maximum volume, not the maximum pressure
        fmax(V) = -pressure(model, V, T)
        sol_max = Solvers.optimize(fmax, (low_v, up_v))
        P_max = -Solvers.x_minimum(sol_max)
        low_v = lb_volume(model)
        up_v = Vc
        #note: P_min is the pressure at the minimum volume, not the minimum pressure
        fmin(V) = pressure(model, V, T)
        sol_min = Solvers.optimize(fmin, (low_v,up_v))
        P_min = Solvers.x_minimum(sol_min)
        P0 = (max(zero(P_min), P_min) + P_max) / 2
    else
        P0 = _0/_0 #NaN, but propagates the type
    end
    return  P0
end

"""
    IsoFugacitySaturation(;p0 = nothing, vl = nothing,vv = nothing, max_iters = 20, p_tol = sqrt(eps(Float64)))

Single component saturation via isofugacity criteria. Ideal for Cubics or other EoS where the volume calculations are cheap. 
If `p0` is not provided, it will be calculated via [`psat_init`](@ref).
"""
struct IsoFugacitySaturation{T} <: SaturationMethod
    p0::T
    vl::Union{Nothing,T}
    vv::Union{Nothing,T}
    max_iters::Int
    p_tol::Float64
end

function IsoFugacitySaturation(;p0 = nothing,vl = nothing,vv = nothing,max_iters = 20,p_tol = sqrt(eps(Float64)))
    p0 === nothing && (p0 = NaN)
    if vl !== nothing
        p0,vl = promote(p0,vl)
    elseif vv !== nothing
        p0,vv = promote(p0,vv)
    elseif (vv !== nothing) & (vl !== nothing)
        p0,vl,vv = promote(p0,vl,vv)
    else
    end
    return IsoFugacitySaturation(p0,vl,vv,max_iters,p_tol)
end

function saturation_pressure_impl(model::EoSModel,T,method::IsoFugacitySaturation)
    vol0 = (method.vl,method.vv,T)
    p0 = method.p0
    if isnan(p0)
        p0 = psat_init(model, T)
    end

    if isnan(p0) #over critical point, or something else.
        nan = p0/p0
        return (nan,nan,nan)
    end

    return psat_fugacity(model,T,p0,vol0,method.max_iters,method.p_tol)
end

function psat_fugacity(model::EoSModel, T, p0, vol0=(nothing, nothing),max_iters = 20,p_tol = sqrt(eps(Float64)))
    # Objetive function to solve saturation pressure using the pressure as iterable variable
    # T = Saturation Temperature
    # p0 = initial guess for the saturation pressure
    # vol0 = initial guesses for the phase volumes = [vol liquid, vol vapor]
    # out = Saturation Pressure, vol liquid, vol vapor
    z = SA[1.]
    RT = R̄*T
    P = 1. * p0
    vol_liq0, vol_vap0 = vol0
    #we use volume here, because cubics can opt in to their root solver.
    vol_liq0 === nothing && (vol_liq0 = volume(model,P,T,z,phase =:liquid))
    vol_vap0 === nothing && (vol_vap0 = volume(model,P,T,z,phase =:gas))
    
    vol_liq = vol_liq0 
    vol_vap = vol_vap0
    #@show vol_liq, vol_vap
    itmax = max_iters
    for i in 1:itmax
        # Computing chemical potential
        μ_liq = VT_chemical_potential_res(model, vol_liq, T)[1]
        μ_vap = VT_chemical_potential_res(model, vol_vap, T)[1]
        #@show vol_liq,vol_vap
        Z_liq = P*vol_liq/RT
        Z_vap = P*vol_vap/RT

        lnϕ_liq = μ_liq/RT - log(Z_liq)
        lnϕ_vap = μ_vap/RT - log(Z_vap)
        # Updating the saturation pressure
        FO = lnϕ_vap - lnϕ_liq
        dFO = (Z_vap - Z_liq) / P
        dP = FO / dFO
        P = P - dP
        if abs(dP) < p_tol; break; end
        # Updating the phase volumes
        vol_liq = _volume_compress(model, P, T, z,vol_liq)
        vol_vap = _volume_compress(model, P, T, z,vol_vap)
    end
    return P, vol_liq, vol_vap
end

export IsoFugacitySaturation
