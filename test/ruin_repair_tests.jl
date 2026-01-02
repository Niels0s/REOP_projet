using Test
using Random
using KIRO2025

Random.seed!(1234)

@testset "Ruin & Repair invariants" begin
    instance_file = joinpath("data-projet","instances","instance_02.csv")
    vehicle_file = joinpath("data-projet","instances","vehicles.csv")
    instance = KIRO2025.read_instance(instance_file, vehicle_file)

    # Build an initial solution with the existing constructor
    sol = KIRO2025.solve_concentric(instance)

    nb_remove = max(2, round(Int, length(instance.orders) * 0.15))

    cand, removed, dest_diag = KIRO2025.destroy_solution(sol, instance, nb_remove)

    # Ensure removed ids are not present in the candidate routes
    present_after = Int[]
    for r in cand.routes
        append!(present_after, r.order_ids)
    end
    @test isempty(intersect(Set(removed), Set(present_after)))

    # Repair and ensure feasibility (with uniqueness enforcement)
    repaired, repair_diag = KIRO2025.repair_solution(cand, instance)
    repaired, uniq_diag = KIRO2025.ensure_solution_uniqueness(repaired, instance)

    @test KIRO2025.is_feasible(repaired, instance)
    missing, dup, counts = KIRO2025.feasibility_issues(repaired, instance)
    @test isempty(missing)
    @test isempty(dup)
end
