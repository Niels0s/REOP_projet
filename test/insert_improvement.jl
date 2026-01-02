using Test
using Random
using KIRO2025

Random.seed!(4321)

@testset "Insertion improvement: displacement reduces forced singletons" begin
    instance_file = joinpath("data-projet","instances","instance_05.csv")
    vehicle_file = joinpath("data-projet","instances","vehicles.csv")
    instance = KIRO2025.read_instance(instance_file, vehicle_file)

    # Build an initial solution
    sol = KIRO2025.solve_concentric(instance)

    # Remove a larger fraction to stress insertion
    nb_remove = max(3, round(Int, length(instance.orders) * 0.25))

    cand, removed, dest_diag = KIRO2025.destroy_solution(sol, instance, nb_remove)

    repaired, repair_diag = KIRO2025.repair_solution(cand, instance)
    repaired, uniq_diag = KIRO2025.ensure_solution_uniqueness(repaired, instance)

    @test KIRO2025.is_feasible(repaired, instance)

    missing, dup, counts = KIRO2025.feasibility_issues(repaired, instance)
    @test isempty(missing)
    @test isempty(dup)

    # Ensure repair didn't simply force every removed customer into singletons.
    # repair_diag keys may be Int or collections depending on implementation details; handle both.
    forced_raw = get(repair_diag, :forced_singletons, 0)
    forced = isa(forced_raw, Integer) ? forced_raw : length(forced_raw)
    @test forced < length(removed)

    # Also ensure the number of inserted customers + forced_singletons covers the removed set
    inserted_raw = get(repair_diag, :inserted, [])
    inserted = isa(inserted_raw, Integer) ? inserted_raw : length(inserted_raw)
    total_covered = inserted + forced
    @test total_covered >= length(removed)
end
