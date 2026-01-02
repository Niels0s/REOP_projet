using KIRO2025

data_dir = joinpath(@__DIR__, "..", "data-projet")
instance_dir = joinpath(data_dir, "instances")
solution_dir = joinpath(data_dir, "solutions")

vehicle_file = joinpath(instance_dir, "vehicles.csv")
cost_file = joinpath(solution_dir, "costs.txt")

println("="^60)
println("Starting optimization for 10 instances")
println("="^60)

open(cost_file, "w") do io
    for i in 1:10
        println("\n" * "="^60)
        println("INSTANCE $i / 10")
        println("="^60)

        print("  [1/2] Loading instance... ")
        instance_file = joinpath(instance_dir, "instance_$(lpad(i, 2, '0')).csv")
        instance = read_instance(instance_file, vehicle_file)
        println("✓ ($(length(instance.orders)) orders)")

        print("  [2/2] Computing new heuristic... ")
            # Run heuristic in quiet mode for batch runs. Set verbose=true to enable detailed per-iteration logs.
            solution = KIRO2025.vnd_heuristic(instance; verbose=false)
        solution_feasibility = is_feasible(solution, instance)
        if !solution_feasibility
            # Provide diagnostic info instead of immediately aborting so we can debug
            missing, duplicates, counts = KIRO2025.feasibility_issues(solution, instance)
            println("    WARNING: solution infeasible for instance $i")
            println("      Missing orders (not visited): ", missing)
            println("      Duplicate orders (visited >1 times): ", duplicates)
        end
        solution_cost = cost(solution, instance)
        solution_rental_cost = rental_cost(solution, instance)
        solution_fuel_cost = fuel_cost(solution, instance)
        solution_radius_cost = radius_cost(solution, instance)
        solution_file = joinpath(solution_dir, "solution_$(lpad(i, 2, '0')).csv")
        write_solution(solution, solution_file)
        println("✓ (cost: $(round(solution_cost, digits=2)))")

        println(io, "Instance $(i):")
        println(io, "    Heuristic Cost: $(solution_cost)")
        println(io, "    Feasible: $(solution_feasibility)")
        println(io, "    Rental Cost: $(solution_rental_cost)")
        println(io, "    Fuel Cost: $(solution_fuel_cost)")
        println(io, "    Radius Cost: $(solution_radius_cost)")
    end
end

# Print summary comparison
println("\n" * "="^60)
println("COMPUTING FINAL SUMMARY")
println("="^60)

let total_cost = 0.0

    print("Reading all solutions and computing totals... ")
    flush(stdout)
    for i in 1:10
        instance_file = joinpath(instance_dir, "instance_$(lpad(i, 2, '0')).csv")
        instance = read_instance(instance_file, vehicle_file)

        solution = read_solution(
            joinpath(solution_dir, "solution_$(lpad(i, 2, '0')).csv")
        )

        total_cost += cost(solution, instance)
    end
    println("✓\n")

    println("Total Solution Heuristic Cost:         $(round(total_cost, digits=2))")
    println()
end
