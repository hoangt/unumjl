#ubound-comparison.jl

#runs comparisons on the ubound type

import Base: ==, <, >

#==============================================================================#
#equality comparison
@universal function ==(a::Ubound, b::Ubound)
  #first, check to make sure that the left and right sides of the unum have the
  #same exact vs. inexact character.  This is a quick first-pass check to make
  low_exact = is_exact(a.lower)
  high_exact = is_exact(a.upper)
  (low_exact != is_exact(b.lower)) && return false
  (high_exact != is_exact(b.upper)) && return false

  #in the case they're exact then checking the end bounds is straightforward equality.
  if low_exact
    (a.lower != b.lower) && return false
  else
    cmp_lower_bound(a.lower, b.lower) || return false
  end

  if high_exact
    (a.upper != b.upper) && return false
  else
    cmp_upper_bound(a.upper, b.upper) || return false
  end

  return true
end

function =={ESS,FSS}(a::Ubound{ESS,FSS}, b::Unum{ESS,FSS})
  #resolve the ubound then check against the unum value.  For now, this returns
  #false.  A correct implementation will do a more detailed check.
  return false
  #=
  resd = ubound_resolve(a)
  isa(resd, Unum) || return false
  return resd == b
  =#
end

#just flip the previous function to make things easier.
=={ESS,FSS}(a::Unum{ESS,FSS}, b::Ubound{ESS,FSS}) = (b == a)

#repeat the process, except for isequal.
function Base.isequal{ESS,FSS}(a::Ubound{ESS,FSS}, b::Unum{ESS,FSS})
  return false
end

Base.isequal{ESS,FSS}(a::Unum{ESS,FSS}, b::Ubound{ESS,FSS}) = isequal(b, a)

#==============================================================================#

<{ESS,FSS}(a::Ubound{ESS,FSS}, b::Ubound{ESS,FSS}) = a.upper < b.lower
<{ESS,FSS}(a::Unum{ESS,FSS}, b::Ubound{ESS,FSS}) = a < b.lower
<{ESS,FSS}(a::Ubound{ESS,FSS}, b::Unum{ESS,FSS}) = a.upper < b

>{ESS,FSS}(a::Ubound{ESS,FSS}, b::Ubound{ESS,FSS}) = a.lower > b.upper
>{ESS,FSS}(a::Unum{ESS,FSS}, b::Ubound{ESS,FSS}) = a > b.upper
>{ESS,FSS}(a::Ubound{ESS,FSS}, b::Unum{ESS,FSS}) = a.lower > b
