#unum.jl - a julia implementation of the unum
# this file is the module definition file and also contains
# includes for all of the components which make it work

#for now, only compatible with 64-bit architectures.
@assert(sizeof(Int) == 8, "currently only compatible with 64-bit architectures")

module Unums

#create the abstract Utype type
abstract Utype <: Real
export Utype

#development safety option scheme
include("./options/devsafety.jl")

################################################################################
#TYPE DEFINITION FILES
#type definitions for int64 array.
include("./int64op/i64o-typedefs.jl")
#type definition of unum.
include("./unum/unum-typedefs.jl")
#type definition of ubound
#include("./ubound/ubound-typedefs.jl")

################################################################################
#IMPLEMENTATION FILES
#implementation of int64 and int64 array utility code.
include("./int64op/int64ops.jl")
#implementation of unums.
include("./unum/unum.jl")
#ubound-related code
#include("./ubound/ubound.jl")

#utility files
#include("unum-bitwalk.jl")
#include("unum-promote.jl")
#include("unum-expwalk.jl")
#include("unum_solver.jl")


end #module
