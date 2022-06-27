abstract type TwuAlphaModel <: AlphaModel end

struct TwuAlphaParam <: EoSParam
    M::SingleParam{Float64}
    N::SingleParam{Float64}
    L::SingleParam{Float64}
end

@newmodelsimple TwuAlpha TwuAlphaModel TwuAlphaParam

"""
    TwuAlpha <: TwuAlphaModel
    
    TwuAlpha(components::Vector{String};
    userlocations::Vector{String}=String[],
    verbose::Bool=false)

## Input Parameters

- `M`: Single Parameter
- `N`: Single Parameter
- `L`: Single Parameter

## Model Parameters

- `M`: Single Parameter
- `N`: Single Parameter
- `L`: Single Parameter

## Description

Cubic alpha `(α(T))` model. Default for [`VTPR`](@ref) EoS.
```

αᵢ = Trᵢ^(N*(M-1))*exp(L*(1-Trᵢ^(N*M))
Trᵢ = T/Tcᵢ
```

## References

1. Twu, C. H., Lee, L. L., & Starling, K. E. (1980). Improved analytical representation of argon thermodynamic behavior. Fluid Phase Equilibria, 4(1–2), 35–44. [doi:10.1016/0378-3812(80)80003-3](https://doi.org/10.1016/0378-3812(80)80003-3)

"""
TwuAlpha

export TwuAlpha
function TwuAlpha(components::Vector{String}; userlocations::Vector{String}=String[], verbose::Bool=false)
    params = getparams(components, ["properties/critical.csv","alpha/Twu/Twu_like.csv"]; userlocations=userlocations, verbose=verbose)
    M = params["M"]
    N = params["N"]
    L = params["L"]
    packagedparams = TwuAlphaParam(M,N,L)
    model = TwuAlpha(packagedparams, verbose=verbose)
    return model
end

function α_function(model::CubicModel,V,T,z,alpha_model::TwuAlphaModel)
    Tc = model.params.Tc.values
    _M  = alpha_model.params.M.values
    _N  = alpha_model.params.N.values
    _L  = alpha_model.params.L.values
    α = zeros(typeof(T),length(Tc))
    for i in @comps
        M = _M[i]
        N = _N[i]
        L = _L[i]
        Tr = T/Tc[i]
        α[i] = Tr^(N*(M-1))*exp(L*(1-Tr^(N*M)))
    end
    return α
end

