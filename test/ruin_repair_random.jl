using Test
using Random
using KIRO2025

Random.seed!(2026)

@testset "Ruin & Repair random iterations" begin
    instance_file = joinpath("data-projet","instances","instance_02.csv")
    vehicle_file = joinpath("data-projet","instances","vehicles.csv")
    instance = KIRO2025.read_instance(instance_file, vehicle_file)

    for s in 1:5
        Random.seed!(1000 + s)
        sol = KIRO2025.solve_concentric(instance)
        nb_remove = max(2, round(Int, length(instance.orders) * 0.15))
        cand, removed, dest_diag = KIRO2025.destroy_solution(sol, instance, nb_remove)
        repaired, repair_diag = KIRO2025.repair_solution(cand, instance)
        repaired, uniq_diag = KIRO2025.ensure_solution_uniqueness(repaired, instance)

        @test KIRO2025.is_feasible(repaired, instance)
        missing, dup, counts = KIRO2025.feasibility_issues(repaired, instance)
        @test isempty(missing)
        @test isempty(dup)
    end
end
