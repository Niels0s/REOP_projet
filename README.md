# REOP 2025-2026 -- Projet-- Califrais Delivery Optimization Challenge

Vehicle Routing Problem with Time Windows (VRPTW) solver for the KIRO 2025 competition, in collaboration with **Califrais**, the official digital and logistics operator of the Rungis International Market.

## Competition Overview

### Industrial Context

[Califrais](https://www.califrais.fr/) operates the digital marketplace [RungisMarket](https://rungismarket.com/) for the Rungis International Market, one of the world's largest wholesale food markets located in the Paris suburbs. The platform enables Paris restaurants and businesses to order fresh products (fruits, vegetables, meat, fish, etc.) from a unified marketplace, with Califrais handling:

- **Order consolidation** from multiple suppliers
- **Warehouse storage** at Rungis Market
- **Last-mile delivery** to Paris customers with a truck fleet

### Challenge Objective

**Optimize delivery truck routes** to minimize operational costs while satisfying all constraints. This is a real-world problem solved daily by Califrais using operations research methods.

**Key Constraints:**
- Customers order until midnight for next-day delivery
- Warehouse loading starts immediately
- First trucks depart early morning (5-6 AM)
- **Algorithm runtime**: ≤ 10 minutes for largest instances

**Evaluation:** Teams submit solutions for all problem instances to the KIRO platform. The team with the lowest total cost across all instances wins.

## Problem Description

### Vehicle Fleet
- **Unlimited rental fleet** with multiple vehicle families (F types)
- Each family has distinct characteristics:
  - Maximum capacity (kg)
  - Daily rental cost (€)
  - Fuel cost per meter (€/m)
  - Radius penalty cost (€/m²) - encourages clustered deliveries
  - Speed (m/s) and parking time (s)
  - Time-dependent travel coefficients (Fourier series)

### Customers & Orders
- **Depot (i=0)**: Califrais warehouse at Rungis Market
- **Customers (i ∈ I)**: Delivery locations in Paris region
  - GPS coordinates (latitude, longitude in degrees)
  - Order weight (kg)
  - Delivery time window [t_min, t_max] (seconds from midnight)
  - Service duration (seconds)

### Time-Dependent Travel Times
Travel times vary by vehicle type and time of day (rush hour modeling):

```
τ_f(i,j|t) = τ_f(i,j) · γ_f(t)
```

- **Reference time**: Based on Manhattan distance and vehicle speed
- **Time factor**: Fourier series (period = 24h) capturing traffic patterns
- **FIFO property**: Departing later means arriving later (guaranteed)

### Cost Components

**Total cost = Σ (Rental + Fuel + Radius penalty)**

1. **Rental cost**: Daily vehicle hire (fixed per route)
2. **Fuel cost**: Based on Manhattan distance traveled
3. **Radius penalty**: Squared Euclidean radius of delivery cluster
   - Encourages geographically compact routes
   - Reduces driving time in congested Paris streets

### Constraints

1. **Coverage**: Each customer served exactly once
2. **Capacity**: Total weight ≤ vehicle capacity
3. **Time windows**: Arrivals within [t_min, t_max] (waiting allowed)
4. **Sequencing**: Proper arrival/departure timing with travel times

## Features

- **Time-dependent travel times** using Fourier series
- **Multiple vehicle types** with different capacities and costs
- **Time window constraints** for deliveries
- **FIFO property** enforcement
- **Real map visualization** with OpenStreetMap tiles of Paris

### Route Maps with Real Paris Streets
Interactive HTML maps showing routes overlaid on **real OpenStreetMap tiles**:
- Actual Paris street names and geography
- Zoom from city-wide to street-level detail
- Click markers for delivery details
- Color-coded routes by vehicle

### Per-Vehicle Analysis Charts
- **Time windows**: Separate Gantt chart per vehicle showing:
  - Waiting times (orange dashed)
  - Service times (dark blue)
  - Time window constraints (gray bars)
- **Truck loads**: Individual capacity tracking per vehicle
  - Current load progression
  - Peak utilization percentage

## Usage

### Run full optimization (all 10 instances) 
```bash
julia --project=. scripts/main.jl
```
Runs a bad heuristic on all instances. **You should build a better heuristic**

### Compute performance summary
```bash
julia --project=. scripts/compute_summary.jl
```
Shows feasibility status and cost improvements for all solutions. **This is the script that will be used to evaluate your solutions**. Please test that it works with your solutions.

### Create visualizations
```bash
julia --project=. scripts/visualization.jl
```
This requires to install some python packages (not needed, but can help you figure out what happens with your algorithms)

## Quick start & debugging

Run the full batch (default quiet mode):

```bash
julia --project=. scripts/main.jl
```

Enable verbose debug logging to see the detailed ruin/repair traces and diagnostics (useful for debugging a single instance):

```bash
julia --project=. scripts/main.jl --verbose
# or
julia --project=. scripts/main.jl -v
```

Notes:
- The heuristic entry point is `KIRO2025.vnd_heuristic(instance; verbose=true)` and supports a `verbose` keyword to enable per-iteration diagnostics.
- High-volume internal diagnostics (destroy/repair trace and skip summaries) are emitted at the debug log level and will appear when `--verbose` is used.

Running tests:

```bash
julia --project=. test/ruin_repair_tests.jl
julia --project=. test/ruin_repair_random.jl
```

If you want CI integration, I can add a minimal GitHub Actions workflow that runs these tests on push.

## Recent improvements (since first prototype)

This project has received several robustness, diagnostics and usability improvements to make the ruin-&-recreate (ILS) pipeline safe, debuggable, and easier to tune. Summary of changes:

- Defensive repair logic
  - `repair_solution` now computes the set of missing orders internally from the candidate solution instead of relying on the caller to pass a list. This removes a class of mismatches that previously caused infeasible solutions or assertion failures.
  - When a customer cannot be feasibly inserted, the algorithm forces a singleton "rescue" route and records the event in diagnostics (`:forced_singletons`). These events are reported at debug level.

- Better diagnostics and non-aborting behavior
  - The driver script `scripts/main.jl` no longer aborts on a single infeasible instance. Instead it emits diagnostic information (missing and duplicated orders) and continues processing all instances.
  - Added `feasibility_issues(solution, instance)` helper to list missing and duplicated order ids.

- Uniqueness enforcement
  - A helper `ensure_solution_uniqueness` removes duplicate visits (keeps first occurrence) and reinserts missing orders as singleton routes. This is called immediately after repair to avoid duplicate propagation across iterations.
  - Final finalization `finalize_solution_unique` performs a last pass to drop duplicates and add missing orders before returning the solution.

- Logging & verbosity
  - A `--verbose` / `-v` flag enables debug logging. High-volume diagnostics are logged at the Debug level and gated by this flag.
  - Destroy/repair now return concise diagnostic maps (e.g., `:removed_by_route`, `:sampled_targets`, `:inserted`, `:skip_counts`) so you can inspect what happened in each iteration.
  - The per-iteration debug traces were aggregated to concise counts to reduce log spam while preserving useful information.

- Tunable CLI parameters
  - You can now tune key ILS parameters from the command line:
    - `--ils-iter=<N>` : number of ILS iterations (default 50)
    - `--ruin-fraction=<f>` : fraction of orders to remove during ruin (default 0.15)

  Example:

  ```bash
  julia --project=. scripts/main.jl --verbose --ils-iter=100 --ruin-fraction=0.12
  ```

- Improved insertion heuristic
  - The repair phase (`repair_solution`) now attempts to insert a removed customer into existing routes by considering alternative vehicle families for that route when necessary. That means, before forcing a singleton rescue route, the algorithm will try to change the route's vehicle family (if a larger vehicle is available and feasible) to accommodate the extra load and time-window constraints. This reduces the number of forced singletons and improves feasibility and cost in many instances.

- Stronger local search and route merging (quality improvements)
  - The local relocate operator now evaluates candidate moves using optimized vehicle selection for both source and destination routes instead of assuming the current vehicles. That enables moves that change vehicle families when beneficial, yielding more accurate cost estimates and allowing better relocations.
  - The Variable Neighborhood Descent (VND) loop was given more budget (inner VND iterations increased) to let local operators fully explore improvements (safer default: 20 internal iterations rather than 10).
  - A new greedy route-merge post-processing step runs after VND: it tries to merge pairs of compatible routes (in all concatenation orientations) and reselects vehicle families for the merged route. Merging reduces rental and fuel costs when two short routes can be combined safely.

These three small changes together improved solution quality in our tests (example batch run below reduced the total heuristic cost from ~36.8k to ~29.7k):

```bash
julia --project=. scripts/main.jl --ils-iter=50 --ruin-fraction=0.12
# => Total Solution Heuristic Cost: ~29663.6 (example run on my machine)
```

- Tests
  - Added unit tests for ruin & repair invariants (`test/ruin_repair_tests.jl`, `test/ruin_repair_random.jl`). Run them locally:

  ```bash
  julia --project=. test/ruin_repair_tests.jl
  julia --project=. test/ruin_repair_random.jl
  ```

- Continuous Integration
  - A minimal GitHub Actions workflow (`.github/workflows/ci.yml`) was added to run the tests and a short smoke-run of `scripts/main.jl` on push/PR.

Notes and next steps
- The repair algorithm still sometimes produces forced singletons; improving insertion heuristics (e.g., smarter vehicle selection, local reordering, and lookahead) will reduce these events and improve solution cost.
- A lightweight profiler and more targeted unit tests for corner cases (time windows, capacity edge cases) are recommended next.

If you'd like, I can now:
- Wire `--ils-iter` and `--ruin-fraction` to a configuration file instead of CLI flags
- Improve the insertion heuristic to reduce forced singletons (medium effort)
- Add CI status badges to this README
