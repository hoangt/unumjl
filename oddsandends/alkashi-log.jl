#alkashi-log.jl

include("../unum.jl")
using Unums

#implements an alkashi-like logarithm algorithm for Float64 as a testground for
#doing it in unums.

#returns a Int16 "1" if it's negative, "0" if it's positive.
function signof(x::FloatingPoint)
  T = typeof(x)
  if (T == Float64)
    return ((reinterpret(Uint64, x) & 0x8000_0000_0000_0000) != 0) ? 1 : 0
  elseif (T == Float32)
    return ((reinterpret(Uint32, x) & 0x8000_0000) != 0) ? 1 : 0
  end
end

function exponentof(x::FloatingPoint)
  T = typeof(x)
  if (T == Float64)
    return int64((reinterpret(Int64, x) & 0x7FF0_0000_0000_0000) >> 52 - 1023)
  elseif (T == Float32)
    return int64((reinterpret(Int32, x) & 0x7F80_0000) >> 23 - 127)
  end
end

function castfrac(x::FloatingPoint)
  T = typeof(x)
  if (T == Float64)
    return (reinterpret(Uint64, x) & 0x000F_FFFF_FFFF_FFFF) << 12
  elseif (T == Float32)
    return uint64(reinterpret(Uint32, x) & 0x007F_FFFF) << 41
  end
end

function maskfor(T::Type)
  if (T == Float64)
    return 0xFFFF_FFFF_FFFF_FF00  #56 digits suffices for Float64 (52 digits)
  elseif (T == Float32)
    return 0xFFFF_FFE0_0000_0000  #27 digits of precision seems to suffice for a Float32 (23 digits)
  end
end

o16 = one(Uint16)
z16 = zero(Uint16)
__clz_array=[0x0004,0x0003,0x0002,0x0002, o16, o16, o16, o16, z16,z16,z16,z16,z16,z16,z16,z16]
function clz(n)
  (n == 0) && return 64
  res::Uint16 = 0
  #use the binary search method
  (n & 0xFFFF_FFFF_0000_0000 == 0) && (n <<= 32; res += 0x0020)
  (n & 0xFFFF_0000_0000_0000 == 0) && (n <<= 16; res += 0x0010)
  (n & 0xFF00_0000_0000_0000 == 0) && (n <<= 8;  res += 0x0008)
  (n & 0xF000_0000_0000_0000 == 0) && (n <<= 4;  res += 0x0004)
  res + __clz_array[(n >> 60) + 1]
end

#simple fused - multiply - add.  Assumes num1 has hidden bits "carry" and num2
#has no hidden bits.
rm = 0x0000_0000_FFFF_FFFF
function sfma(carry, num1, num2)
  (fracprod, _) = Unums.__chunk_mult(num1, num2)
  (_carry, fracprod) = Unums.__carried_add(carry, num1, fracprod)
  ((carry & 0x1) != 0) && ((_carry, fracprod) = Unums.__carried_add(_carry, num2, fracprod))
  ((carry & 0x2) != 0) && ((_carry, fracprod) = Unums.__carried_add(_carry, lsh(num2, 1), fracprod))
  (_carry, fracprod)
end

#performs a simple multiply, Assumes that number 1 has a hidden bit of exactly one
#and number 2 has a hidden bit of exactly zero
#(1 + a)(0 + b) = b + ab
function smult(a::Uint64, b::Uint64)

  (fraction, _) = Unums.__chunk_mult(a, b)
  carry = one(Uint64)

  #only perform the respective adds if the *opposing* thing is not subnormal.
  ((carry, fraction) = Unums.__carried_add(carry, fraction, b))

  #carry may be as high as three!  So we must shift as necessary.
  (fraction, shift, is_ubit) = Unums.__shift_after_add(carry, fraction, _)
  fraction << 1
end

function reassemble(sign::Uint64, ev::Uint64, fv::Uint64)
  number = (fv >> 12) | ((ev + 1023) << 52) | (sign << 63)

  println(bits(number))

  reinterpret(Float64, number)
end


include("logtable.jl")
#ultimately, we may need to have more digits on the end of this value for logarithm.
const log2e = 0x71547652b82fe_000

function exlg(x::FloatingPoint)
  #exact floating point with the goldschmidt algorithm.
  T = typeof(x)

  isnan(x) && return (nan(T), false)

  x <= 0 && return nan(T)

  #calculate the exponent.
  exp_f::Int64 = exponentof(x) + (issubnormal(x) ? 1 : 0)

  #figure the decimals.
  fraction::Uint64 = castfrac(x) << 1

  if (issubnormal(x))
    shift::Uint64 = clz(fraction) + 1
    fraction = fraction << shift
    exp_f -= shift
  end

  sign::Uint64 = 0
  if (exp_f < 0)
    exp_f = -exp_f - 1
    sign = 1
  end
  lz = clz(uint64(exp_f))
  resexp = 63 - lz
  #add the exponent part onto the result fraction.
  resfrac = uint64(exp_f << (lz + 1))

  #do the goldschmidt-type algorithm

  #resexp = 0
  #resfrac = 0
  #reassemble the value into the requisite floating point
  reassemble(sign, resexp, resfrac)
end

#one-time testing
#v = (rand(Int64) & 0xFFF0_0000_0000_0000) | (rand(Int64) & 0x0000_0000_0FFF_FFFF)
v = rand(Int64)
x = abs(reinterpret(Float64, v))
z = exlg(x)
a = log2(x)

println("input :    $x")
println("answer:    $(log2(x))")
println("calculate: $z")

println("xbits:     ", bits(x))
println("abits:     ", bits(a))
println("zbits:     ", bits(z))

println("diff:      ", reinterpret(Uint64, a) - reinterpret(Uint64, z))

#######################################################
## testing fun

i2f(i) = reinterpret(Float64, (i >> 12) | 0x3FF0_0000_0000_0000)