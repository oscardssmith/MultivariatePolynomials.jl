using Test
import Test: @inferred

import MutableArithmetics as MA

@testset "Substitution" begin
    Mod.@polyvar x[1:3]

    @test subs(2, x[1] => 3) == 2
    @test iszero((x[1] - x[1])(x[1] => x[2]))
    @test subs(CustomPoly(x[1] + x[2]), x[2] => x[1]) == 2x[1]

    a = (x[1])(x[1] => x[2])
    b = x[2]
    @test (x[1])(x[1] => x[2]) == x[2]

    p = x[1] * x[2] * x[3]
    @test convert(Int, p(x => (1, 2, 3))) == 6

    p = x[1]^2 + x[1] * x[3] - 3
    @test convert(Int, p(x => (5, x[1] * x[2], 4))) == 42

    p = x[1]^2 + x[2]^2
    q = p(x[1:2] => [1 -1; 1 1] * vec(x[1:2]))
    @test q == 2p

    t = 2.0 * x[1] * x[2]^2
    @test t(x => [1, 2, 3]) == 8.0
    @test t((x[2], x[1]) => [1, 3]) == 6.0

    p = x[1] + x[2] + 2 * x[1]^2 + 3 * x[1] * x[2]^2
    #@inferred p((x[1], x[2]) => (1.0, 2.0))

    m = x[1] * x[2]
    @inferred subs(m, x[2] => 2.0)
    @inferred subs(p, x[2] => 2.0)
    @test subs(p, x[2] => 2.0) == 13x[1] + 2 + 2x[1]^2
    @inferred subs(p, x[2] => x[1])
    @inferred subs(p, x[2] => x[1]) == 2x[1] + 2x[1]^2 + 3x[1]^3

    p = x[1] - x[1]
    @test iszero(p)
    @inferred p(x[1] => 1)
    @test iszero(p(x[1] => 1))
    @inferred subs(p, x[1] => 1)
    @test iszero(subs(p, x[1] => 1))

    # https://github.com/JuliaAlgebra/DynamicPolynomials.jl/issues/141
    @test subs(x[1]^2 + x[2]^2, x[1] => x[3]^2) == x[2]^2 + x[3]^4

    q = (x[1] + 1) / (x[1] + 2)
    @test isapproxzero(q(x[1] => -1))
    @test !isapproxzero(q(x[1] => 1))
    @test q(x[1] => 1) ≈ 2 / 3

    q = (x[1] + x[3]) / (x[2] - 1)
    @test subs(q, x[1:2] => (x[2], x[1])) == (x[2] + x[3]) / (x[1] - 1)

    # Taken from perf/runbenchmark.jl
    p = x[1] + x[2] + 2x[1]^2 + x[2]^3

    varst = (x[1], x[2])
    varsv = [x[1], x[2]]
    valst = (1.0, 2.0)
    valsv = [1.0, 2.0]

    @test variable.(Tuple(varsv)) == varst
    @test variable.(Tuple(varsv)) isa
          Tuple{<:AbstractVariable,<:AbstractVariable}

    @test p(variables(p) => valst) == 13
    @test p(variables(p) => valsv) == 13
    @test p(varst => valst) == 13
    @test p(varsv => valsv) == 13

    @testset "Eval on constant monomial" begin
        m = constant_monomial(prod(x))
        mr = m(x => reverse(x))
        @test isconstant(mr)
        @test variables(mr) == x
    end

    Mod.@polyvar x y
    @test subs([x^2 + y, x + y], x => y) == [y^2 + y, 2y]

    @testset "Subs with no variables" begin
        Mod.@polyvar x
        t = convert(term_type(x, Int), 3)
        @test t == @inferred subs(t, x => x + 1)
        @test t == @inferred subs(t, x => x + 1.0)
        @test t == @inferred subs(t, x => 1x)
        @test t == @inferred subs(t, x => 1.0x)
        @test t == @inferred subs(t, x => 1.0)
    end

    for (p, s) in [(x^1, x => 2x)]
        @test MA.promote_operation(substitute, Subs, typeof(p), typeof(s)) ==
              typeof(subs(p, s))
    end

    @testset "Issue #302 $T" for T in [BigFloat, BigInt]
        t = T(1) * x[1]
        @test copy(t).coefficient !== t.coefficient
        @test mutable_copy(t).coefficient !== t.coefficient
        @test copy_if_mutable(t).coefficient !== t.coefficient
        F = T(5) * x[1] * x[2] * x[3] + T(1) * x[1] * x[2]^2
        @test subs(F, c => T(0)) == a * b^2
        @test subs(F, c => 0) == a * b^2
    end
end
