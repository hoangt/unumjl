#unum-properties
#functions that assess properties of unum values.

#generally speaking, the "unum library form" of a test will have the form
#is_XXXXX, for some of these, they are equivalent to a julia form from floating
#point tests that are overloaded - e.g. isnan == is_nan.  A separate file
#unum-teoe-func.jl provides aliasing implementations for all of the function
#in appendix a of "The End of Error"

decode_exp{ESS,FSS}(x::Unum{ESS,FSS}) = decode_exp(x.esize, x.exponent)
export decode_exp

#some really dumb ones, but we'll put these in for legibility.
is_ulp{ESS,FSS}(x::Unum{ESS,FSS})      = ((x.flags & UNUM_UBIT_MASK) != 0)
is_exact{ESS,FSS}(x::Unum{ESS,FSS})    = ((x.flags & UNUM_UBIT_MASK) == 0)
is_negative{ESS,FSS}(x::Unum{ESS,FSS}) = ((x.flags & UNUM_SIGN_MASK) != 0)
is_positive{ESS,FSS}(x::Unum{ESS,FSS}) = ((x.flags & UNUM_SIGN_MASK) == 0)
is_neg_def{ESS,FSS}(x::Unum{ESS,FSS})  = (!is_zero(x)) && is_negative(x)
is_pos_def{ESS,FSS}(x::Unum{ESS,FSS})  = (!is_zero(x)) && is_positive(x)
export is_ulp, is_exact, is_negative, is_positive

#a couple of testing conditions
@gen_code function __is_nan_or_inf{ESS,FSS}(x::Unum{ESS,FSS})
  #calculate expected fsize and esize.
  xesize = max_esize(ESS)
  xfsize = max_fsize(FSS)
  xexponent = max_biased_exponent(ESS)
  @code quote
    (x.fsize == $xfsize) || return false
    (x.esize == $xesize) || return false
    (x.exponent == $xexponent) || return false
  end

  if FSS < 7
    xfraction = mask_top(xfsize)
    @code :(x.fraction == $xfraction)
  else
    @code :(is_all_ones(x.fraction))
  end
end

is_nan{ESS,FSS}(x::Unum{ESS,FSS}) = is_ulp(x) && __is_nan_or_inf(x)
Base.isnan{ESS,FSS}(x::Unum{ESS,FSS}) = is_ulp(x) && __is_nan_or_inf(x)
export is_nan

#isinf matches the julia definiton and triggers on either positive or negative
#infinity.  is_pos_inf and is_neg_inf both are Unum-specific functions that detect
#the expected values.
is_inf{ESS,FSS}(x::Unum{ESS,FSS}) = is_exact(x) && __is_nan_or_inf(x)
is_pos_inf{ESS, FSS}(x::Unum{ESS, FSS}) = is_positive(x) && is_exact(x) && __is_nan_or_inf(x)
is_neg_inf{ESS, FSS}(x::Unum{ESS, FSS}) = is_negative(x) && is_exact(x) && __is_nan_or_inf(x)
export is_inf, is_pos_inf, is_neg_inf

#aliasing
Base.isinf{ESS,FSS}(x::Unum{ESS,FSS}) = is_exact(x) && __is_nan_or_inf(x)

@gen_code function is_finite{ESS,FSS}(x::Unum{ESS,FSS})
  #record the maximum esize and fsize values.  Any value less than this and
  #it's finite.
  mesize = max_esize(ESS)
  mfsize = max_fsize(FSS)
  mexponent = max_biased_exponent(ESS)
  @code quote
    x.esize < $mesize && return true
    x.fsize < $mfsize && return true
    x.exponent < $mexponent && return true
  end
  if (FSS < 7)
    mfraction = mask_top(mfsize)
    @code :(x.fraction < $mfraction)
  else
    @code :(!is_all_ones(x.fraction))
  end
end
Base.isfinite{ESS,FSS}(x::Unum{ESS,FSS}) = is_finite(x)

#NB:  The difference between "is_exp_zero" and "issubnormal" - is_exp_zero admits
#zero as a solution; issubnormal is in compliance with the standard julia
#issubnormal function and does not admit zero as a true result.
is_subnormal{ESS,FSS}(x::Unum{ESS,FSS}) = (x.exponent == z64) && is_not_zero(x.fraction)
is_exp_zero{ESS,FSS}(x::Unum{ESS,FSS}) = x.exponent == z64
@gen_code function is_strange_subnormal{ESS,FSS}(x::Unum{ESS,FSS})
  mesize = max_esize(ESS)
  @code :((x.exponent == z64) && (x.esize < $mesize))
end

Base.issubnormal{ESS,FSS}(x::Unum{ESS,FSS}) = is_subnormal(x)                    #alias the unum-form to the julia-compliant form.
#use ESS because this will be checked by the compiler, instead of at runtime.
is_frac_zero{ESS,FSS}(x::Unum{ESS,FSS}) = is_all_zero(x.fraction)
is_zero{ESS,FSS}(x::Unum{ESS,FSS}) = (x.exponent == z64) && is_exact(x) && is_frac_zero(x)

function is_unit{ESS,FSS}(x::Unum{ESS,FSS})
  #asymmetric exponents make this slightly more laborious than might be expected
  #one is not an ulp, it is exact.
  is_ulp(x) && return false
  #case one:  An exponent of zero and nothing in the fraction.
  #note that when x.esize == 0, then decode_exp 0 is subnormal.
  (x.esize != 0) && (decode_exp(x) == 0) && is_all_zero(x.fraction) && return true
  is_subnormal(x) && (x.esize == 0) && (is_top(x.fraction)) && return true
  return false
end

is_one{ESS,FSS}(x::Unum{ESS,FSS}) = is_positive(x) && is_unit(x)
is_neg_one{ESS,FSS}(x::Unum{ESS,FSS}) = is_negative(x) && is_unit(x)
#checks if the value is sss ("smaller than small subnormal")
is_sss{ESS,FSS}(x::Unum{ESS,FSS}) = (x.exponent == z64) && is_ulp(x) && is_all_zero(x.fraction)
is_pos_sss{ESS,FSS}(x::Unum{ESS,FSS}) = is_positive(x) && is_sss(x)
is_neg_sss{ESS,FSS}(x::Unum{ESS,FSS}) = is_negative(x) && is_sss(x)
#checks if the value is more than maxreal
@gen_code function is_mmr{ESS,FSS}(x::Unum{ESS,FSS})
  xesize = max_esize(ESS)
  xfsize = max_fsize(FSS)
  xfsm1::UInt16 = ESS == 0 ? 0 : xfsize - 1
  xexponent = max_exponent(ESS)
  @code quote
    is_ulp(x) || return false
    x.esize == $xesize || return false
    x.fsize == $xfsize || return false
    x.exponent == $xexponent || return false
  end
  if FSS < 7
    xfraction::UInt64 = ESS == 0 ? 0 : mask_top(xfsm1)
    @code :(x.fraction == $xfraction)
  else
    @code :(is_mmr_frac(x.fraction))
  end
end

is_pos_mmr{ESS,FSS}(x::Unum{ESS,FSS}) = is_positive(x) && is_mmr(x)
is_neg_mmr{ESS,FSS}(x::Unum{ESS,FSS}) = is_negative(x) && is_mmr(x)

export is_subnormal, is_exp_zero
export is_frac_zero, is_zero, is_sss, is_pos_sss, is_neg_sss
export is_mmr, is_pos_mmr, is_neg_mmr
#=
function width{ESS,FSS}(x::Unum{ESS,FSS})
  is_exact(x) && return zero(Unum{ESS,FSS})
  #return the difference, but made exact, and with ulp and sign bits bashed away.
  return unum_unsafe(__outward_exact(x) - __inward_exact(x), z16)
end
export width
=#
