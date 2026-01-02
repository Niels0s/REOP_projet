# # (**) Quelques fonctions utilitaires (**)

# # Calcule le coût radial d'une route donnée
# function route_radius_cost(route::Route, instance::Instance)
#     n = length(route.order_ids)
#     if n <= 1
#         return 0.0
#     end
    
#     route_diameter = 0.0
#     # On ne parcourt que le triangle supérieur de la matrice (i < j)
#     for i in 1:(n-1)
#         id1 = route.order_ids[i]
#         for j in (i+1):n
#             id2 = route.order_ids[j]
#             dist = instance.euclidean_distances[id1 + 1, id2 + 1]
#             if dist > route_diameter
#                 route_diameter = dist
#             end
#         end
#     end
    
#     vehicle = instance.vehicles[route.family]
#     return vehicle.radius_cost * route_diameter / 2
# end

# # Calcule le coût total d'une route donnée
# function route_cost(route::Route, instance::Instance)
#     vehicle_idx = route.family
#     vehicle = instance.vehicles[vehicle_idx]
#     # Coût de location
#     cost = vehicle.rental_cost
#     # Coût radial
#     radius = route_radius_cost(route, instance)
#     cost += vehicle.radius_cost * radius
#     # Coût de fuel
#     n = length(route.order_ids)
#     for i in 1:(n-1)
#         cost += instance.manhattan_distances[route.order_ids[i] + 1, route.order_ids[i+1] + 1] * vehicle.fuel_cost
#     end
#     cost += (instance.manhattan_distances[1, route.order_ids[1] + 1] + instance.manhattan_distances[route.order_ids[end] + 1, 1]) * vehicle.fuel_cost
#     # Coût total
#     return cost
# end

# # Calcule le poids total d'une route donnée
# function route_weight(route::Route, instance::Instance)
#     return sum(instance.orders[order_id].weight for order_id in route.order_ids)
# end

# # Vérifie si une route respecte toutes les contraintes de time windows et capacité
# function is_route_feasible(route::Route, instance::Instance)
#     vehicle = instance.vehicles[route.family]

#     # Vérifier la capacité
#     total_weight = route_weight(route, instance)
#     if total_weight > vehicle.max_capacity
#         return false
#     end

#     # Vérifier les time windows
#     time = 0.0
#     current_order_id = instance.depot.id

#     for order_id in route.order_ids
#         # Temps de trajet
#         travel_time = compute_travel_time(current_order_id, order_id, route.family, time, instance)
#         time += travel_time

#         order = instance.orders[order_id]

#         # Attente si on arrive trop tôt
#         if time < order.window_start
#             time = order.window_start
#         end

#         # Vérifier qu'on n'arrive pas trop tard
#         if time > order.window_end
#             return false
#         end

#         # Temps de service
#         time += order.delivery_duration
#         current_order_id = order_id
#     end

#     return true
# end

# # Teste toutes les orientations possibles de fusion et retourne la meilleure
# function best_merge(route1::Route, route2::Route, instance::Instance)
#     vehicle_idx = route1.family
#     total_weight = route_weight(route1, instance) + route_weight(route2, instance)

#     # Vérifier d'abord la capacité
#     if total_weight > instance.vehicles[vehicle_idx].max_capacity
#         return nothing
#     end

#     # Tester les 4 orientations possibles
#     orientations = [
#         (route1.order_ids, route2.order_ids),                    # route1 + route2
#         (route1.order_ids, reverse(route2.order_ids)),           # route1 + reverse(route2)
#         (reverse(route1.order_ids), route2.order_ids),           # reverse(route1) + route2
#         (reverse(route1.order_ids), reverse(route2.order_ids))   # reverse(route1) + reverse(route2)
#     ]

#     best_cost = Inf
#     best_orders = nothing

#     for (orders1, orders2) in orientations
#         merged_orders = vcat(orders1, orders2)
#         candidate_route = Route(vehicle_idx, merged_orders)

#         # Vérifier la faisabilité
#         if is_route_feasible(candidate_route, instance)
#             cost = route_cost(candidate_route, instance)
#             if cost < best_cost
#                 best_cost = cost
#                 best_orders = merged_orders
#             end
#         end
#     end

#     if best_orders === nothing
#         return nothing
#     end

#     return Route(vehicle_idx, best_orders)
# end

# # Recalcule le meilleur véhicule pour une route donnée (version optimisée)
# function optimize_vehicle(route::Route, instance::Instance)
#     total_weight = route_weight(route, instance)

#     # Pré-filtrer les véhicules par capacité
#     candidate_vehicles = [v for v in instance.vehicles
#                          if v.max_capacity >= total_weight]

#     if isempty(candidate_vehicles)
#         return route  # Garder le véhicule actuel si aucun n'est faisable
#     end

#     best_cost = Inf
#     best_family = route.family

#     # Tester uniquement les véhicules faisables par capacité
#     for vehicle in candidate_vehicles
#         candidate_route = Route(vehicle.family, route.order_ids)

#         # Vérifier la faisabilité (time windows principalement)
#         if is_route_feasible(candidate_route, instance)
#             cost = route_cost(candidate_route, instance)
#             if cost < best_cost
#                 best_cost = cost
#                 best_family = vehicle.family
#             end
#         end
#     end

#     return Route(best_family, route.order_ids)
# end

# # (**) Application de l'algorithme de Clarke-Wright (**)

# function clarke_wright_step(solution::Solution, instance::Instance)
#     routes = copy(solution.routes)
#     nb_routes = length(routes)

#     # Matrice des économies avec info sur la route fusionnée
#     best_saving = -Inf
#     best_i, best_j = -1, -1
#     best_merged_route = nothing

#     for i in 1:nb_routes
#         for j in (i+1):nb_routes
#             # Essayer de fusionner les deux routes
#             merged_route = best_merge(routes[i], routes[j], instance)

#             if merged_route !== nothing
#                 # Tester aussi avec différents véhicules
#                 merged_route = optimize_vehicle(merged_route, instance)

#                 # Calculer l'économie
#                 cost_before = route_cost(routes[i], instance) + route_cost(routes[j], instance)
#                 cost_after = route_cost(merged_route, instance)
#                 saving = cost_before - cost_after

#                 if saving > best_saving
#                     best_saving = saving
#                     best_i = i
#                     best_j = j
#                     best_merged_route = merged_route
#                 end
#             end
#         end
#     end

#     # Si aucune fusion rentable, retourner la solution inchangée
#     if best_saving <= 0 || best_merged_route === nothing
#         return solution
#     end

#     # Appliquer la meilleure fusion
#     deleteat!(routes, [best_i, best_j])
#     push!(routes, best_merged_route)

#     return Solution(routes)
# end

# # (**) Optimisations locales (**)

# # Optimisation 2-opt pour une route : inverse un segment pour réduire les croisements
# function two_opt_route(route::Route, instance::Instance)
#     n = length(route.order_ids)
#     if n <= 2
#         return route
#     end

#     improved = true
#     best_route = route

#     while improved
#         improved = false
#         current_cost = route_cost(best_route, instance)

#         for i in 1:(n-1)
#             for j in (i+1):n
#                 # Créer une nouvelle route en inversant le segment [i, j]
#                 new_orders = copy(best_route.order_ids)
#                 new_orders[i:j] = reverse(new_orders[i:j])
#                 new_route = Route(best_route.family, new_orders)

#                 # Vérifier la faisabilité et le coût
#                 if is_route_feasible(new_route, instance)
#                     new_cost = route_cost(new_route, instance)
#                     if new_cost < current_cost
#                         best_route = new_route
#                         current_cost = new_cost
#                         improved = true
#                     end
#                 end
#             end
#         end
#     end

#     return best_route
# end

# # Applique 2-opt sur toutes les routes d'une solution
# function two_opt_solution(solution::Solution, instance::Instance)
#     improved_routes = [two_opt_route(route, instance) for route in solution.routes]
#     return Solution(improved_routes)
# end

# # Relocate : déplace un client d'une route vers une autre
# function relocate_step(solution::Solution, instance::Instance)
#     routes = copy(solution.routes)
#     nb_routes = length(routes)

#     best_improvement = 0.0
#     best_move = nothing

#     for i in 1:nb_routes
#         route_i = routes[i]
#         for pos_i in 1:length(route_i.order_ids)
#             customer = route_i.order_ids[pos_i]

#             # Essayer d'insérer ce client dans une autre route
#             for j in 1:nb_routes
#                 if i == j
#                     continue
#                 end

#                 route_j = routes[j]

#                 # Essayer toutes les positions d'insertion dans route_j
#                 for pos_j in 0:length(route_j.order_ids)
#                     # Nouvelle route i sans le client
#                     new_orders_i = [route_i.order_ids[k] for k in 1:length(route_i.order_ids) if k != pos_i]

#                     # Nouvelle route j avec le client inséré
#                     new_orders_j = copy(route_j.order_ids)
#                     insert!(new_orders_j, pos_j + 1, customer)

#                     # Créer les nouvelles routes
#                     if length(new_orders_i) == 0
#                         # Route i devient vide, on la supprime
#                         new_route_j = Route(route_j.family, new_orders_j)

#                         if is_route_feasible(new_route_j, instance)
#                             new_route_j = optimize_vehicle(new_route_j, instance)

#                             cost_before = route_cost(route_i, instance) + route_cost(route_j, instance)
#                             cost_after = route_cost(new_route_j, instance)
#                             improvement = cost_before - cost_after

#                             if improvement > best_improvement
#                                 best_improvement = improvement
#                                 best_move = (i, j, pos_i, pos_j, new_route_j, nothing)
#                             end
#                         end
#                     else
#                         new_route_i = Route(route_i.family, new_orders_i)
#                         new_route_j = Route(route_j.family, new_orders_j)

#                         if is_route_feasible(new_route_i, instance) && is_route_feasible(new_route_j, instance)
#                             new_route_i = optimize_vehicle(new_route_i, instance)
#                             new_route_j = optimize_vehicle(new_route_j, instance)

#                             cost_before = route_cost(route_i, instance) + route_cost(route_j, instance)
#                             cost_after = route_cost(new_route_i, instance) + route_cost(new_route_j, instance)
#                             improvement = cost_before - cost_after

#                             if improvement > best_improvement
#                                 best_improvement = improvement
#                                 best_move = (i, j, pos_i, pos_j, new_route_j, new_route_i)
#                             end
#                         end
#                     end
#                 end
#             end
#         end
#     end

#     # Appliquer le meilleur mouvement
#     if best_move !== nothing
#         (i, j, pos_i, pos_j, new_route_j, new_route_i) = best_move

#         if new_route_i === nothing
#             # Route i disparaît
#             deleteat!(routes, i)
#             # Ajuster l'indice j si nécessaire
#             j_adjusted = j > i ? j - 1 : j
#             routes[j_adjusted] = new_route_j
#         else
#             routes[i] = new_route_i
#             routes[j] = new_route_j
#         end

#         return Solution(routes), true
#     end

#     return solution, false
# end

# # Exchange : échange deux clients entre deux routes différentes
# function exchange_step(solution::Solution, instance::Instance)
#     routes = copy(solution.routes)
#     nb_routes = length(routes)

#     best_improvement = 0.0
#     best_move = nothing

#     for i in 1:nb_routes
#         route_i = routes[i]
#         for pos_i in 1:length(route_i.order_ids)
#             customer_i = route_i.order_ids[pos_i]

#             for j in (i+1):nb_routes
#                 route_j = routes[j]
#                 for pos_j in 1:length(route_j.order_ids)
#                     customer_j = route_j.order_ids[pos_j]

#                     # Échanger les deux clients
#                     new_orders_i = copy(route_i.order_ids)
#                     new_orders_i[pos_i] = customer_j

#                     new_orders_j = copy(route_j.order_ids)
#                     new_orders_j[pos_j] = customer_i

#                     new_route_i = Route(route_i.family, new_orders_i)
#                     new_route_j = Route(route_j.family, new_orders_j)

#                     if is_route_feasible(new_route_i, instance) && is_route_feasible(new_route_j, instance)
#                         new_route_i = optimize_vehicle(new_route_i, instance)
#                         new_route_j = optimize_vehicle(new_route_j, instance)

#                         cost_before = route_cost(route_i, instance) + route_cost(route_j, instance)
#                         cost_after = route_cost(new_route_i, instance) + route_cost(new_route_j, instance)
#                         improvement = cost_before - cost_after

#                         if improvement > best_improvement
#                             best_improvement = improvement
#                             best_move = (i, j, new_route_i, new_route_j)
#                         end
#                     end
#                 end
#             end
#         end
#     end

#     # Appliquer le meilleur échange
#     if best_move !== nothing
#         (i, j, new_route_i, new_route_j) = best_move
#         routes[i] = new_route_i
#         routes[j] = new_route_j
#         return Solution(routes), true
#     end

#     return solution, false
# end

# # 2-opt* : échange les queues de deux routes
# function two_opt_star_step(solution::Solution, instance::Instance)
#     routes = copy(solution.routes)
#     nb_routes = length(routes)

#     best_improvement = 0.0
#     best_move = nothing

#     for i in 1:nb_routes
#         route_i = routes[i]
#         for cut_i in 1:(length(route_i.order_ids)-1)
#             # Couper route_i en deux parties
#             head_i = route_i.order_ids[1:cut_i]
#             tail_i = route_i.order_ids[(cut_i+1):end]

#             for j in (i+1):nb_routes
#                 route_j = routes[j]
#                 for cut_j in 1:(length(route_j.order_ids)-1)
#                     # Couper route_j en deux parties
#                     head_j = route_j.order_ids[1:cut_j]
#                     tail_j = route_j.order_ids[(cut_j+1):end]

#                     # Échanger les queues : head_i + tail_j et head_j + tail_i
#                     new_orders_i = vcat(head_i, tail_j)
#                     new_orders_j = vcat(head_j, tail_i)

#                     new_route_i = Route(route_i.family, new_orders_i)
#                     new_route_j = Route(route_j.family, new_orders_j)

#                     if is_route_feasible(new_route_i, instance) && is_route_feasible(new_route_j, instance)
#                         new_route_i = optimize_vehicle(new_route_i, instance)
#                         new_route_j = optimize_vehicle(new_route_j, instance)

#                         cost_before = route_cost(route_i, instance) + route_cost(route_j, instance)
#                         cost_after = route_cost(new_route_i, instance) + route_cost(new_route_j, instance)
#                         improvement = cost_before - cost_after

#                         if improvement > best_improvement
#                             best_improvement = improvement
#                             best_move = (i, j, new_route_i, new_route_j)
#                         end
#                     end
#                 end
#             end
#         end
#     end

#     # Appliquer le meilleur échange
#     if best_move !== nothing
#         (i, j, new_route_i, new_route_j) = best_move
#         routes[i] = new_route_i
#         routes[j] = new_route_j
#         return Solution(routes), true
#     end

#     return solution, false
# end

# # Or-opt : déplace un segment de 1, 2 ou 3 clients
# function or_opt_step(solution::Solution, instance::Instance; segment_sizes=[1, 2, 3])
#     routes = copy(solution.routes)
#     nb_routes = length(routes)

#     best_improvement = 0.0
#     best_move = nothing

#     for i in 1:nb_routes
#         route_i = routes[i]

#         for segment_size in segment_sizes
#             if length(route_i.order_ids) < segment_size
#                 continue
#             end

#             # Pour chaque segment de taille segment_size
#             for start_pos in 1:(length(route_i.order_ids) - segment_size + 1)
#                 segment = route_i.order_ids[start_pos:(start_pos + segment_size - 1)]

#                 # Essayer de le déplacer dans la même route ou une autre
#                 for j in 1:nb_routes
#                     route_j = routes[j]

#                     # Positions d'insertion possibles
#                     max_insert_pos = (i == j) ? length(route_j.order_ids) - segment_size : length(route_j.order_ids)

#                     for insert_pos in 0:max_insert_pos
#                         # Ne pas réinsérer au même endroit
#                         if i == j && insert_pos >= start_pos - 1 && insert_pos <= start_pos + segment_size - 1
#                             continue
#                         end

#                         # Construire les nouvelles routes
#                         if i == j
#                             # Mouvement intra-route
#                             new_orders = copy(route_i.order_ids)
#                             deleteat!(new_orders, start_pos:(start_pos + segment_size - 1))

#                             # Ajuster la position d'insertion si nécessaire
#                             adjusted_insert_pos = insert_pos >= start_pos ? insert_pos - segment_size : insert_pos

#                             for k in 1:segment_size
#                                 insert!(new_orders, adjusted_insert_pos + k, segment[k])
#                             end

#                             new_route_i = Route(route_i.family, new_orders)

#                             if is_route_feasible(new_route_i, instance)
#                                 new_route_i = optimize_vehicle(new_route_i, instance)

#                                 cost_before = route_cost(route_i, instance)
#                                 cost_after = route_cost(new_route_i, instance)
#                                 improvement = cost_before - cost_after

#                                 if improvement > best_improvement
#                                     best_improvement = improvement
#                                     best_move = (i, j, new_route_i, nothing, true)
#                                 end
#                             end
#                         else
#                             # Mouvement inter-routes
#                             new_orders_i = [route_i.order_ids[k] for k in 1:length(route_i.order_ids)
#                                           if k < start_pos || k > start_pos + segment_size - 1]

#                             new_orders_j = copy(route_j.order_ids)
#                             for k in 1:segment_size
#                                 insert!(new_orders_j, insert_pos + k, segment[k])
#                             end

#                             if length(new_orders_i) == 0
#                                 # Route i disparaît
#                                 new_route_j = Route(route_j.family, new_orders_j)

#                                 if is_route_feasible(new_route_j, instance)
#                                     new_route_j = optimize_vehicle(new_route_j, instance)

#                                     cost_before = route_cost(route_i, instance) + route_cost(route_j, instance)
#                                     cost_after = route_cost(new_route_j, instance)
#                                     improvement = cost_before - cost_after

#                                     if improvement > best_improvement
#                                         best_improvement = improvement
#                                         best_move = (i, j, nothing, new_route_j, false)
#                                     end
#                                 end
#                             else
#                                 new_route_i = Route(route_i.family, new_orders_i)
#                                 new_route_j = Route(route_j.family, new_orders_j)

#                                 if is_route_feasible(new_route_i, instance) && is_route_feasible(new_route_j, instance)
#                                     new_route_i = optimize_vehicle(new_route_i, instance)
#                                     new_route_j = optimize_vehicle(new_route_j, instance)

#                                     cost_before = route_cost(route_i, instance) + route_cost(route_j, instance)
#                                     cost_after = route_cost(new_route_i, instance) + route_cost(new_route_j, instance)
#                                     improvement = cost_before - cost_after

#                                     if improvement > best_improvement
#                                         best_improvement = improvement
#                                         best_move = (i, j, new_route_i, new_route_j, false)
#                                     end
#                                 end
#                             end
#                         end
#                     end
#                 end
#             end
#         end
#     end

#     # Appliquer le meilleur mouvement
#     if best_move !== nothing
#         (i, j, new_route_i, new_route_j, intra_route) = best_move

#         if intra_route
#             routes[i] = new_route_i
#         elseif new_route_i === nothing
#             # Route i disparaît
#             deleteat!(routes, i)
#             j_adjusted = j > i ? j - 1 : j
#             routes[j_adjusted] = new_route_j
#         else
#             routes[i] = new_route_i
#             routes[j] = new_route_j
#         end

#         return Solution(routes), true
#     end

#     return solution, false
# end

# # Optimisation explicite du radius : réduit les routes trop dispersées
# function minimize_radius_step(solution::Solution, instance::Instance)
#     routes = copy(solution.routes)

#     best_improvement = 0.0
#     best_move = nothing

#     # Identifier les routes avec un fort radius cost
#     for i in 1:length(routes)
#         route_i = routes[i]
#         vehicle_i = instance.vehicles[route_i.family]

#         # Calculer le radius actuel
#         max_dist = 0.0
#         worst_client = nothing
#         worst_client_pos = 0

#         for (pos, order_id) in enumerate(route_i.order_ids)
#             for other_id in route_i.order_ids
#                 if order_id != other_id
#                     dist = instance.euclidean_distances[order_id + 1, other_id + 1]
#                     if dist > max_dist
#                         max_dist = dist
#                         worst_client = order_id
#                         worst_client_pos = pos
#                     end
#                 end
#             end
#         end

#         # Si la route a un fort radius, essayer de déplacer le client le plus éloigné
#         radius = max_dist / 2
#         radius_penalty = vehicle_i.radius_cost * radius

#         # Seuil : optimiser seulement si le radius cost est significatif
#         if radius_penalty > 100 && worst_client !== nothing
#             # Essayer de déplacer ce client vers une autre route
#             for j in 1:length(routes)
#                 if i == j
#                     continue
#                 end

#                 route_j = routes[j]

#                 # Essayer toutes les positions d'insertion
#                 for insert_pos in 0:length(route_j.order_ids)
#                     new_orders_i = [route_i.order_ids[k] for k in 1:length(route_i.order_ids) if k != worst_client_pos]
#                     new_orders_j = copy(route_j.order_ids)
#                     insert!(new_orders_j, insert_pos + 1, worst_client)

#                     if length(new_orders_i) == 0
#                         # Route i disparaît
#                         new_route_j = Route(route_j.family, new_orders_j)

#                         if is_route_feasible(new_route_j, instance)
#                             new_route_j = optimize_vehicle(new_route_j, instance)

#                             cost_before = route_cost(route_i, instance) + route_cost(route_j, instance)
#                             cost_after = route_cost(new_route_j, instance)
#                             improvement = cost_before - cost_after

#                             if improvement > best_improvement
#                                 best_improvement = improvement
#                                 best_move = (i, j, nothing, new_route_j)
#                             end
#                         end
#                     else
#                         new_route_i = Route(route_i.family, new_orders_i)
#                         new_route_j = Route(route_j.family, new_orders_j)

#                         if is_route_feasible(new_route_i, instance) && is_route_feasible(new_route_j, instance)
#                             new_route_i = optimize_vehicle(new_route_i, instance)
#                             new_route_j = optimize_vehicle(new_route_j, instance)

#                             cost_before = route_cost(route_i, instance) + route_cost(route_j, instance)
#                             cost_after = route_cost(new_route_i, instance) + route_cost(new_route_j, instance)
#                             improvement = cost_before - cost_after

#                             if improvement > best_improvement
#                                 best_improvement = improvement
#                                 best_move = (i, j, new_route_i, new_route_j)
#                             end
#                         end
#                     end
#                 end
#             end
#         end
#     end

#     # Appliquer le meilleur mouvement
#     if best_move !== nothing
#         (i, j, new_route_i, new_route_j) = best_move

#         if new_route_i === nothing
#             deleteat!(routes, i)
#             j_adjusted = j > i ? j - 1 : j
#             routes[j_adjusted] = new_route_j
#         else
#             routes[i] = new_route_i
#             routes[j] = new_route_j
#         end

#         return Solution(routes), true
#     end

#     return solution, false
# end

# # (**) Heuristiques d'initialisation (**)

# # Sweep algorithm : balayage angulaire depuis le dépôt
# function sweep_heuristic(instance::Instance)
#     routes = Route[]

#     # Calculer l'angle de chaque client par rapport au dépôt
#     depot = instance.depot
#     angles = Float64[]

#     for order in instance.orders
#         dx = order.longitude - depot.longitude
#         dy = order.latitude - depot.latitude
#         angle = atan(dy, dx)
#         push!(angles, angle)
#     end

#     # Trier les clients par angle
#     sorted_indices = sortperm(angles)

#     # Construire des routes en balayant
#     current_route_orders = Int[]
#     current_vehicle = 1  # Commencer avec le premier véhicule

#     for idx in sorted_indices
#         order_id = instance.orders[idx].id
#         order = instance.orders[order_id]

#         # Essayer d'ajouter à la route actuelle
#         test_orders = vcat(current_route_orders, [order_id])
#         test_route = Route(current_vehicle, test_orders)

#         if is_route_feasible(test_route, instance)
#             # Ajouter à la route actuelle
#             current_route_orders = test_orders
#         else
#             # Finaliser la route actuelle et en commencer une nouvelle
#             if !isempty(current_route_orders)
#                 final_route = Route(current_vehicle, current_route_orders)
#                 final_route = optimize_vehicle(final_route, instance)
#                 push!(routes, final_route)
#             end

#             # Nouvelle route avec ce client
#             current_route_orders = [order_id]

#             # Choisir le meilleur véhicule pour ce client
#             best_vehicle = 1
#             best_cost = Inf
#             for vehicle in instance.vehicles
#                 if vehicle.max_capacity >= order.weight
#                     dist = euclidean_distance(depot, order)
#                     cost = vehicle.rental_cost + vehicle.fuel_cost * dist
#                     if cost < best_cost
#                         best_cost = cost
#                         best_vehicle = vehicle.family
#                     end
#                 end
#             end
#             current_vehicle = best_vehicle
#         end
#     end

#     # Finaliser la dernière route
#     if !isempty(current_route_orders)
#         final_route = Route(current_vehicle, current_route_orders)
#         final_route = optimize_vehicle(final_route, instance)
#         push!(routes, final_route)
#     end

#     return Solution(routes)
# end

# # Clustering spatio-temporel
# function space_geographic_clustering(instance::Instance, nb_clusters::Int)
#     # Définir les plages temporelles (en secondes)
#     # Matin: 0-12h, Après-midi: 12h-18h, Soir: 18h-24h
#     MORNING_END = 12 * 3600
#     AFTERNOON_END = 18 * 3600

#     # Fonction pour déterminer la période de livraison d'une commande
#     function get_time_period(order::Order)
#         # Utiliser le milieu de la fenêtre de livraison
#         mid_time = (order.window_start + order.window_end) / 2

#         if mid_time < MORNING_END
#             return 1  # Matin
#         elseif mid_time < AFTERNOON_END
#             return 2  # Après-midi
#         else
#             return 3  # Soir
#         end
#     end

#     # Séparer les commandes par période temporelle
#     time_groups = Dict(1 => Int[], 2 => Int[], 3 => Int[])
#     for order in instance.orders
#         period = get_time_period(order)
#         push!(time_groups[period], order.id)
#     end

#     # Calculer le nombre de clusters par période (proportionnel au nombre de commandes)
#     total_orders = length(instance.orders)
#     clusters_per_period = Dict{Int, Int}()
#     for (period, order_ids) in time_groups
#         if !isempty(order_ids)
#             clusters_per_period[period] = max(1, round(Int, nb_clusters * length(order_ids) / total_orders))
#         end
#     end

#     # Créer les clusters géographiques pour chaque période temporelle
#     all_clusters = Vector{Int}[]

#     for (period, order_ids) in sort(collect(time_groups))
#         if isempty(order_ids)
#             continue
#         end

#         nb_clusters_period = get(clusters_per_period, period, 1)

#         # Récupérer les coordonnées pour cette période
#         period_orders = [instance.orders[id] for id in order_ids]
#         latitudes = [order.latitude for order in period_orders]
#         longitudes = [order.longitude for order in period_orders]

#         lat_min, lat_max = minimum(latitudes), maximum(latitudes)
#         lon_min, lon_max = minimum(longitudes), maximum(longitudes)

#         # Créer une grille de secteurs pour cette période
#         period_clusters = [Int[] for _ in 1:nb_clusters_period]
#         grid_size = ceil(Int, sqrt(nb_clusters_period))

#         for order in period_orders
#             # Normaliser les coordonnées dans [0, 1]
#             lat_norm = (order.latitude - lat_min) / (lat_max - lat_min + 1e-10)
#             lon_norm = (order.longitude - lon_min) / (lon_max - lon_min + 1e-10)

#             # Trouver la cellule de la grille
#             row = min(floor(Int, lat_norm * grid_size) + 1, grid_size)
#             col = min(floor(Int, lon_norm * grid_size) + 1, grid_size)

#             cluster_id = min((row - 1) * grid_size + col, nb_clusters_period)
#             push!(period_clusters[cluster_id], order.id)
#         end

#         # Ajouter les clusters non vides de cette période
#         for cluster in period_clusters
#             if !isempty(cluster)
#                 push!(all_clusters, cluster)
#             end
#         end
#     end

#     return all_clusters
# end

# # Insertion au plus proche : construit des routes en insérant les clients un par un
# function nearest_insertion_heuristic(instance::Instance)
#     routes = Route[]
#     unvisited = Set(order.id for order in instance.orders)

#     # Créer des clusters géographiques
#     nb_initial_clusters = max(3, length(instance.orders) ÷ 10)
#     clusters = space_geographic_clustering(instance, nb_initial_clusters)

#     # Pour chaque cluster, créer des routes
#     for cluster in clusters
#         cluster_unvisited = Set(cluster)

#         while !isempty(cluster_unvisited)
#             # Commencer une nouvelle route avec le client le plus proche du dépôt
#             closest_to_depot = nothing
#             min_dist = Inf

#             for order_id in cluster_unvisited
#                 order = instance.orders[order_id]
#                 dist = euclidean_distance(instance.depot, order)
#                 if dist < min_dist
#                     min_dist = dist
#                     closest_to_depot = order_id
#                 end
#             end

#             # Choisir le meilleur véhicule pour ce client initial
#             order = instance.orders[closest_to_depot]
#             best_vehicle = nothing
#             best_cost = Inf

#             for vehicle in instance.vehicles
#                 if vehicle.max_capacity >= order.weight
#                     cost = vehicle.rental_cost + vehicle.fuel_cost * min_dist
#                     if cost < best_cost
#                         best_cost = cost
#                         best_vehicle = vehicle.family
#                     end
#                 end
#             end

#             current_route = Route(best_vehicle, [closest_to_depot])
#             delete!(cluster_unvisited, closest_to_depot)
#             delete!(unvisited, closest_to_depot)

#             # Insérer les autres clients un par un
#             improved = true
#             while improved && !isempty(cluster_unvisited)
#                 improved = false
#                 best_insertion_cost = Inf
#                 best_insertion = nothing

#                 for order_id in cluster_unvisited
#                     # Essayer d'insérer à toutes les positions
#                     for pos in 0:length(current_route.order_ids)
#                         new_orders = copy(current_route.order_ids)
#                         insert!(new_orders, pos + 1, order_id)

#                         candidate_route = Route(current_route.family, new_orders)

#                         if is_route_feasible(candidate_route, instance)
#                             cost_increase = route_cost(candidate_route, instance) - route_cost(current_route, instance)

#                             if cost_increase < best_insertion_cost
#                                 best_insertion_cost = cost_increase
#                                 best_insertion = (order_id, pos, candidate_route)
#                                 improved = true
#                             end
#                         end
#                     end
#                 end

#                 # Appliquer la meilleure insertion
#                 if best_insertion !== nothing
#                     (order_id, pos, candidate_route) = best_insertion
#                     current_route = candidate_route
#                     delete!(cluster_unvisited, order_id)
#                     delete!(unvisited, order_id)
#                 end
#             end

#             # Optimiser le véhicule pour cette route
#             current_route = optimize_vehicle(current_route, instance)
#             push!(routes, current_route)
#         end
#     end

#     # Gérer les clients non visités (hors clusters)
#     while !isempty(unvisited)
#         order_id = first(unvisited)
#         order = instance.orders[order_id]

#         best_vehicle = nothing
#         best_cost = Inf

#         for vehicle in instance.vehicles
#             if vehicle.max_capacity >= order.weight
#                 dist = euclidean_distance(instance.depot, order)
#                 cost = vehicle.rental_cost + vehicle.fuel_cost * dist
#                 if cost < best_cost
#                     best_cost = cost
#                     best_vehicle = vehicle.family
#                 end
#             end
#         end

#         push!(routes, Route(best_vehicle, [order_id]))
#         delete!(unvisited, order_id)
#     end

#     return Solution(routes)
# end

# # (**) Variable Neighborhoods Descent (**)

# # VND : recherche locale en changeant systématiquement de voisinage
# function variable_neighborhood_descent(initial_solution::Solution, instance::Instance)
#     solution = initial_solution

#     # Liste des voisinages (opérateurs de recherche locale)
#     neighborhoods = [
#         :relocate,
#         :exchange,
#         :two_opt_star,
#         :or_opt,
#         :minimize_radius
#     ]

#     k = 1  # Indice du voisinage courant

#     while k <= length(neighborhoods)
#         improved = false

#         # Appliquer l'opérateur du voisinage k
#         if neighborhoods[k] == :relocate
#             new_solution, improved = relocate_step(solution, instance)
#         elseif neighborhoods[k] == :exchange
#             new_solution, improved = exchange_step(solution, instance)
#         elseif neighborhoods[k] == :two_opt_star
#             new_solution, improved = two_opt_star_step(solution, instance)
#         elseif neighborhoods[k] == :or_opt
#             new_solution, improved = or_opt_step(solution, instance)
#         elseif neighborhoods[k] == :minimize_radius
#             new_solution, improved = minimize_radius_step(solution, instance)
#         end

#         if improved
#             # Amélioration trouvée : accepter et revenir au premier voisinage
#             solution = new_solution
#             k = 1
#         else
#             # Pas d'amélioration : passer au voisinage suivant
#             k += 1
#         end
#     end

#     return solution
# end
# # (**) Métaheuristique : Ruin & Recreate (**)

# # Ruin : Retire aléatoirement ou spatialement 'nb_remove' clients de la solution
# function destroy_solution(solution::Solution, instance::Instance, nb_remove::Int)
#     current_routes = copy(solution.routes)
#     removed_customers = Int[]
    
#     # On choisit aléatoirement des clients à retirer
#     # Note : Une stratégie plus avancée retirerait les clients d'une zone géographique précise (Radial Ruin)
#     all_customers = Int[]
#     for r in current_routes
#         append!(all_customers, r.order_ids)
#     end
    
#     # Protection si on demande de retirer plus que ce qui existe
#     nb_remove = min(nb_remove, length(all_customers))
    
#     # Sélection aléatoire des victimes
#     targets = Set(sample(all_customers, nb_remove; replace=false))
    
#     # Reconstruction des routes sans les cibles
#     new_routes = Route[]
#     for route in current_routes
#         new_orders = filter(id -> !(id in targets), route.order_ids)
        
#         if !isempty(new_orders)
#             # On garde la route purifiée, en ré-optimisant le véhicule si besoin
#             new_route = Route(route.family, new_orders)
#             # Optionnel : réoptimiser le véhicule ici est coûteux, on peut le faire à la fin
#             push!(new_routes, new_route) 
#         end
#     end
    
#     return Solution(new_routes), collect(targets)
# end

# # Recreate : Réinsère les clients retirés (Logique Best Insertion)
# function repair_solution(solution::Solution, missing_clients::Vector{Int}, instance::Instance)
#     current_routes = copy(solution.routes)
    
#     # Trier les clients manquants (par exemple par poids décroissant, logique Bin Packing Q4)
#     # ou aléatoirement pour varier
#     shuffle!(missing_clients) 
    
#     for customer_id in missing_clients
#         best_cost_increase = Inf
#         best_insertion = nothing
        
#         # 1. Essayer d'insérer dans les routes existantes
#         for (r_idx, route) in enumerate(current_routes)
#             for pos in 0:length(route.order_ids)
#                 new_orders = copy(route.order_ids)
#                 insert!(new_orders, pos + 1, customer_id)
                
#                 # Créer route candidate
#                 candidate = Route(route.family, new_orders)
                
#                 if is_route_feasible(candidate, instance)
#                     # Note : On ne réoptimise pas le véhicule ici pour la vitesse, 
#                     # on suppose qu'on garde la même famille pour l'instant
#                     cost_diff = route_cost(candidate, instance) - route_cost(route, instance)
                    
#                     if cost_diff < best_cost_increase
#                         best_cost_increase = cost_diff
#                         best_insertion = (r_idx, candidate)
#                     end
#                 end
#             end
#         end
        
#         # 2. Essayer de créer une nouvelle route
#         # On cherche le meilleur véhicule pour ce client seul
#         best_new_vehicle_idx = 1
#         min_new_cost = Inf
        
#         for v in instance.vehicles
#             if v.max_capacity >= instance.orders[customer_id].weight
#                 # Création route temporaire
#                 temp_route = Route(v.family, [customer_id])
#                 if is_route_feasible(temp_route, instance)
#                     c = route_cost(temp_route, instance)
#                     if c < min_new_cost
#                         min_new_cost = c
#                         best_new_vehicle_idx = v.family
#                     end
#                 end
#             end
#         end
        
#         if min_new_cost < best_cost_increase
#             # Mieux vaut créer une nouvelle route
#             new_route = Route(best_new_vehicle_idx, [customer_id])
#             push!(current_routes, new_route)
#         elseif best_insertion !== nothing
#             # Appliquer l'insertion
#             r_idx, new_r = best_insertion
#             current_routes[r_idx] = new_r
#         else
#             # Cas de secours : Nouvelle route forcée
#             new_route = Route(best_new_vehicle_idx, [customer_id])
#             push!(current_routes, new_route)
#         end
#     end
    
#     # Petite passe de nettoyage sur les véhicules
#     final_routes = [optimize_vehicle(r, instance) for r in current_routes]
#     return Solution(final_routes)
# end
# # (**) Métaheuristique : Ruin & Recreate (**)

# # Ruin : Retire aléatoirement 'nb_remove' clients de la solution
# function destroy_solution(solution::Solution, instance::Instance, nb_remove::Int)
#     current_routes = copy(solution.routes)
    
#     # Identifier tous les clients présents
#     all_customers = Int[]
#     for r in current_routes
#         append!(all_customers, r.order_ids)
#     end
    
#     # Sécurité : ne pas retirer plus que possible
#     nb_remove = min(nb_remove, length(all_customers))
#     if nb_remove <= 0
#         return solution, Int[]
#     end
    
#     # Sélection aléatoire des victimes (échantillonnage sans remise)
#     targets = Set(sample(all_customers, nb_remove; replace=false))
    
#     # Reconstruction des routes sans les clients ciblés
#     new_routes = Route[]
#     for route in current_routes
#         # On garde seulement les clients qui ne sont PAS dans targets
#         new_orders = filter(id -> !(id in targets), route.order_ids)
        
#         if !isempty(new_orders)
#             # On recrée la route (on garde le même véhicule pour l'instant)
#             new_route = Route(route.family, new_orders)
#             push!(new_routes, new_route) 
#         end
#     end
    
#     return Solution(new_routes), collect(targets)
# end

# # Recreate : Réinsère les clients retirés (Logique Best Insertion)
# function repair_solution(solution::Solution, missing_clients::Vector{Int}, instance::Instance)
#     current_routes = copy(solution.routes)
    
#     # On mélange les clients manquants pour varier l'ordre d'insertion
#     shuffle!(missing_clients) 
    
#     for customer_id in missing_clients
#         best_cost_increase = Inf
#         best_insertion = nothing
        
#         # 1. Essayer d'insérer dans les routes existantes
#         for (r_idx, route) in enumerate(current_routes)
#             # Optimisation: Si la route est déjà pleine à craquer, on skip (heuristique)
#             if route_weight(route, instance) + instance.orders[customer_id].weight > instance.vehicles[route.family].max_capacity
#                 continue
#             end

#             for pos in 0:length(route.order_ids)
#                 new_orders = copy(route.order_ids)
#                 insert!(new_orders, pos + 1, customer_id)
                
#                 candidate = Route(route.family, new_orders)
                
#                 if is_route_feasible(candidate, instance)
#                     cost_diff = route_cost(candidate, instance) - route_cost(route, instance)
                    
#                     if cost_diff < best_cost_increase
#                         best_cost_increase = cost_diff
#                         best_insertion = (r_idx, candidate)
#                     end
#                 end
#             end
#         end
        
#         # 2. Essayer de créer une nouvelle route
#         # On cherche le meilleur véhicule pour ce client seul
#         min_new_cost = Inf
#         best_new_vehicle_idx = 1
#         found_new = false

#         for v in instance.vehicles
#             if v.max_capacity >= instance.orders[customer_id].weight
#                 temp_route = Route(v.family, [customer_id])
#                 # Petite vérification rapide avant is_route_feasible complet
#                 if is_route_feasible(temp_route, instance)
#                     c = route_cost(temp_route, instance)
#                     if c < min_new_cost
#                         min_new_cost = c
#                         best_new_vehicle_idx = v.family
#                         found_new = true
#                     end
#                 end
#             end
#         end
        
#         # Décision : Insérer dans l'existant ou créer une nouvelle route ?
#         if found_new && (min_new_cost < best_cost_increase)
#             push!(current_routes, Route(best_new_vehicle_idx, [customer_id]))
#         elseif best_insertion !== nothing
#             r_idx, new_r = best_insertion
#             current_routes[r_idx] = new_r
#         elseif found_new
#             # Si on ne peut pas insérer mais qu'on peut créer, on crée
#             push!(current_routes, Route(best_new_vehicle_idx, [customer_id]))
#         else
#             # Cas critique : impossible d'insérer le client (ne devrait pas arriver si les instances sont faisables)
#             @warn "Impossible d'insérer le client $customer_id"
#         end
#     end
    
#     # Optimisation finale des véhicules sur les routes modifiées
#     final_routes = [optimize_vehicle(r, instance) for r in current_routes]
#     return Solution(final_routes)
# end
# # Heuristique ILS (Iterated Local Search) avec VND
# function vnd_heuristic(instance::Instance)
#     # --- PHASE 1 : Initialisation ---
#     # On garde votre logique de tester deux initialisations
#     solutions = Solution[]
#     push!(solutions, nearest_insertion_heuristic(instance))
#     push!(solutions, sweep_heuristic(instance))

#     best_cost_global = Inf
#     current_solution = solutions[1]
    
#     for sol in solutions
#         c = cost(sol, instance)
#         if c < best_cost_global
#             best_cost_global = c
#             current_solution = sol
#         end
#     end

#     println("    Init cost: $(round(best_cost_global, digits=2))")

#     # --- PHASE 2 : Construction avancée (Clarke & Wright) ---
#     # On l'applique pour consolider les routes initiales
#     # On limite à 50 itérations pour ne pas perdre trop de temps
#     for _ in 1:50
#         new_sol = clarke_wright_step(current_solution, instance)
#         if cost(new_sol, instance) >= cost(current_solution, instance) - 0.1
#             break
#         end
#         current_solution = new_sol
#     end

#     # --- PHASE 3 : Boucle ILS (Ruin & Recreate) ---
#     # C'est ici que l'amélioration majeure se produit
    
#     best_solution = current_solution
#     best_cost_global = cost(best_solution, instance)
    
#     # Paramètres de la métaheuristique
#     # 200 itérations est un bon compromis pour 10min de temps limite total
#     max_iterations = 200     
#     perturbation_rate = 0.15 # On détruit ~15% des clients à chaque cycle
    
#     println("    Starting ILS Loop (Cost: $(round(best_cost_global, digits=2)))...")

#     for iter in 1:max_iterations
#         # A. Copie de travail
#         candidate = deepcopy(best_solution)
        
#         # B. Ruin & Recreate (Perturbation)
#         # On ne le fait pas à la toute première itération pour laisser le VND optimiser la base d'abord
#         if iter > 1
#             nb_to_remove = max(2, round(Int, length(instance.orders) * perturbation_rate))
#             candidate, removed = destroy_solution(candidate, instance, nb_to_remove)
#             candidate = repair_solution(candidate, removed, instance)
#         end
        
#         # C. Local Search (VND)
#         # On applique votre VND existant pour optimiser la solution perturbée
#         candidate = variable_neighborhood_descent(candidate, instance)
        
#         # D. Critère d'acceptation (Descente simple)
#         current_cost = cost(candidate, instance)
        
#         if current_cost < best_cost_global - 0.01
#             # Amélioration trouvée !
#             # println("      Iter $iter: New best cost $(round(current_cost, digits=2))")
#             best_cost_global = current_cost
#             best_solution = candidate
            
#             # Mécanisme de respiration : si on trouve mieux, on réduit la perturbation pour affiner
#             perturbation_rate = max(0.05, perturbation_rate * 0.90)
#         else
#             # Si on stagne, on augmente la taille de la destruction (kick)
#             perturbation_rate = min(0.35, perturbation_rate * 1.1)
#         end
#     end
    
#     # --- PHASE 4 : Polissage final ---
#     final_solution = two_opt_solution(best_solution, instance)
    
#     return final_solution
# end




# (**) HEURISTIQUE ROBUSTE : CONSTRUCTION CONCENTRIQUE + VND (**)

# --- 1. Fonctions de Calcul & Utilitaires ---

# Gestion explicite des routes vides
function route_weight(route::Route, instance::Instance)
    if isempty(route.order_ids)
        return 0.0
    end
    return sum(instance.orders[order_id].weight for order_id in route.order_ids; init=0.0)
end

# Type 'Number' pour accepter Int et Float
function get_travel_time(from_id::Int, to_id::Int, vehicle::Vehicle, start_time::Number, instance::Instance)
    dist = instance.manhattan_distances[from_id + 1, to_id + 1]
    base_time = dist / vehicle.speed
    
    # Facteur de trafic (Fourier)
    w_val = KIRO2025.ω 
    
    congestion = 0.0
    for k in 1:4
        congestion += vehicle.fourier_cos[k] * cos((k-1) * w_val * start_time) + 
                      vehicle.fourier_sin[k] * sin((k-1) * w_val * start_time)
    end
    
    return base_time * congestion
end

function calculate_radius_cost(order_ids::Vector{Int}, vehicle::Vehicle, instance::Instance)
    n = length(order_ids)
    if n <= 1; return 0.0; end
    
    max_diam = 0.0
    for i in 1:(n-1)
        u = order_ids[i]
        for j in (i+1):n
            v = order_ids[j]
            d = instance.euclidean_distances[u+1, v+1]
            if d > max_diam; max_diam = d; end
        end
    end
    return vehicle.radius_cost * max_diam / 2.0
end

function calculate_ids_cost(ids::Vector{Int}, family::Int, instance::Instance)
    if isempty(ids)
        return 0.0
    end

    vehicle = instance.vehicles[family]
    c = float(vehicle.rental_cost)
    c += calculate_radius_cost(ids, vehicle, instance)
    
    dist = instance.manhattan_distances[1, ids[1] + 1]
    for i in 1:(length(ids)-1)
        dist += instance.manhattan_distances[ids[i]+1, ids[i+1]+1]
    end
    dist += instance.manhattan_distances[ids[end]+1, 1]
    
    c += dist * vehicle.fuel_cost
    return c
end

function route_cost(route::Route, instance::Instance)
    return calculate_ids_cost(route.order_ids, route.family, instance)
end

# Vérification faisabilité (Temps + Capacité)
function check_feasibility(order_ids::Vector{Int}, vehicle_idx::Int, instance::Instance)
    if isempty(order_ids); return true; end

    vehicle = instance.vehicles[vehicle_idx]
    
    # 1. Capacité
    load = sum(instance.orders[id].weight for id in order_ids; init=0.0)
    if load > vehicle.max_capacity; return false; end
    
    # 2. Time Windows
    time = 0.0
    curr = instance.depot.id
    
    for id in order_ids
        tt = get_travel_time(curr, id, vehicle, time, instance)
        time += tt
        
        order = instance.orders[id]
        
        if time < order.window_start
            time = float(order.window_start)
        end
        
        # Marge de sécurité 1.0s
        if time > order.window_end + 1.0
            return false
        end
        
        time += order.delivery_duration
        curr = id
    end
    
    return true
end

function is_route_feasible(route::Route, instance::Instance)
    return check_feasibility(route.order_ids, route.family, instance)
end

function optimize_route_vehicle(order_ids::Vector{Int}, current_fam::Int, instance::Instance)
    if isempty(order_ids)
        return Route(current_fam, Int[])
    end

    best_fam = current_fam
    min_cost = Inf
    load = sum(instance.orders[id].weight for id in order_ids; init=0.0)
    
    for v in instance.vehicles
        if v.max_capacity >= load
            if check_feasibility(order_ids, v.family, instance)
                c = calculate_ids_cost(order_ids, v.family, instance)
                if c < min_cost
                    min_cost = c
                    best_fam = v.family
                end
            end
        end
    end
    
    return Route(best_fam, order_ids)
end

function optimize_vehicle(route::Route, instance::Instance)
    return optimize_route_vehicle(route.order_ids, route.family, instance)
end

# Fonction utilitaire pour le coût total d'une solution
function route_cost_sum(solution::Solution, instance::Instance)
    return sum(route_cost(r, instance) for r in solution.routes; init=0.0)
end


# --- 2. Construction Concentrique (Seed-Based) ---

function solve_concentric(instance::Instance)
    unvisited = Set([o.id for o in instance.orders])
    routes = Route[]
    ref_vehicle = instance.vehicles[end] 
    
    while !isempty(unvisited)
        seed_id = -1
        max_dist = -1.0
        
        for uid in unvisited
            d = instance.euclidean_distances[1, uid+1]
            if d > max_dist
                max_dist = d
                seed_id = uid
            end
        end
        
        current_route = [seed_id]
        delete!(unvisited, seed_id)
        
        full = false
        while !full && !isempty(unvisited)
            best_candidate = -1
            best_score = Inf
            last_id = current_route[end]
            
            for cand in unvisited
                d_last = instance.euclidean_distances[last_id+1, cand+1]
                d_seed = instance.euclidean_distances[seed_id+1, cand+1]
                score = d_last + 3.0 * d_seed 
                
                if score < best_score
                    temp_ids = copy(current_route)
                    push!(temp_ids, cand)
                    if check_feasibility(temp_ids, ref_vehicle.family, instance)
                        best_score = score
                        best_candidate = cand
                    end
                end
            end
            
            if best_candidate != -1
                push!(current_route, best_candidate)
                delete!(unvisited, best_candidate)
            else
                full = true
            end
            
            if length(current_route) > 35; full = true; end
        end
        
        final_route = optimize_route_vehicle(current_route, ref_vehicle.family, instance)
        push!(routes, final_route)
    end
    
    return Solution(routes)
end


# --- 3. Opérateurs de Recherche Locale (VND) ---

# A. 2-Opt Intra-Route
function local_2opt(solution::Solution, instance::Instance)
    # On travaille sur une copie des routes pour éviter les effets de bord
    # (Note: two_opt_route crée déjà de nouvelles structures Route)
    new_routes = [two_opt_route(r, instance) for r in solution.routes]
    return Solution(new_routes)
end

function two_opt_route(route::Route, instance::Instance)
    n = length(route.order_ids)
    if n <= 2; return route; end

    best_route = route
    # Petite limite d'itérations pour la vitesse
    improved = true
    iter = 0
    while improved && iter < 10
        improved = false
        iter += 1
        current_cost = route_cost(best_route, instance)

        for i in 1:(n-1)
            for j in (i+1):n
                new_ids = copy(best_route.order_ids)
                new_ids[i:j] = reverse(new_ids[i:j])
                
                if check_feasibility(new_ids, route.family, instance)
                    new_c = calculate_ids_cost(new_ids, route.family, instance)
                    if new_c < current_cost - 0.01
                        current_cost = new_c
                        best_route = Route(route.family, new_ids)
                        improved = true
                    end
                end
            end
        end
    end
    return best_route
end

# B. Relocate
function local_relocate(solution::Solution, instance::Instance)
    # [IMPORTANT] On copie les routes pour ne pas modifier la solution en place si on rejette
    routes = copy(solution.routes)
    nb_routes = length(routes)
    improved = true
    
    # Stratégie First Improvement pour la vitesse
    while improved
        improved = false
        
        for i in 1:nb_routes
            if isempty(routes[i].order_ids); continue; end
            
            for j in 1:nb_routes
                if i == j; continue; end
                
                for (k, cust) in enumerate(routes[i].order_ids)
                    if route_weight(routes[j], instance) + instance.orders[cust].weight > instance.vehicles[routes[j].family].max_capacity
                        continue
                    end
                    
                    cost_current = route_cost(routes[i], instance) + route_cost(routes[j], instance)
                    
                    ids_src_new = deleteat!(copy(routes[i].order_ids), k)
                    
                    for pos in 0:length(routes[j].order_ids)
                        ids_dest_new = insert!(copy(routes[j].order_ids), pos+1, cust)
                        
                        if check_feasibility(ids_dest_new, routes[j].family, instance)
                            # Approximation : on garde les mêmes véhicules pour aller vite
                            c_src = calculate_ids_cost(ids_src_new, routes[i].family, instance)
                            c_dest = calculate_ids_cost(ids_dest_new, routes[j].family, instance)
                            
                            delta = (c_src + c_dest) - cost_current
                            if delta < -0.1
                                # Apply Move
                                routes[i] = optimize_route_vehicle(ids_src_new, routes[i].family, instance)
                                routes[j] = optimize_route_vehicle(ids_dest_new, routes[j].family, instance)
                                improved = true
                                break # Break pos loop
                            end
                        end
                    end
                    if improved; break; end # Break cust loop
                end
                if improved; break; end # Break j loop
            end
            if improved; break; end # Break i loop
        end
        
        # Nettoyage des routes vides après modifications
        if improved
            filter!(r -> !isempty(r.order_ids), routes)
            nb_routes = length(routes)
        end
    end
    
    return Solution(routes)
end

# C. Swap
function local_swap(solution::Solution, instance::Instance)
    routes = copy(solution.routes)
    nb_routes = length(routes)
    improved = true
    
    while improved
        improved = false
        
        for i in 1:nb_routes
            for j in (i+1):nb_routes
                
                r1 = routes[i]
                r2 = routes[j]
                
                for (k1, c1) in enumerate(r1.order_ids)
                    for (k2, c2) in enumerate(r2.order_ids)
                        # Quick Capacity Check
                        w1 = route_weight(r1, instance) - instance.orders[c1].weight + instance.orders[c2].weight
                        w2 = route_weight(r2, instance) - instance.orders[c2].weight + instance.orders[c1].weight
                        
                        if w1 > instance.vehicles[r1.family].max_capacity || w2 > instance.vehicles[r2.family].max_capacity
                            continue
                        end
                        
                        ids1 = copy(r1.order_ids); ids1[k1] = c2
                        ids2 = copy(r2.order_ids); ids2[k2] = c1
                        
                        if check_feasibility(ids1, r1.family, instance) && check_feasibility(ids2, r2.family, instance)
                            current_c = route_cost(r1, instance) + route_cost(r2, instance)
                            new_c = calculate_ids_cost(ids1, r1.family, instance) + calculate_ids_cost(ids2, r2.family, instance)
                            
                            if new_c < current_c - 0.1
                                routes[i] = Route(r1.family, ids1)
                                routes[j] = Route(r2.family, ids2)
                                improved = true
                                break
                            end
                        end
                    end
                    if improved; break; end
                end
                if improved; break; end
            end
            if improved; break; end
        end
    end
    return Solution(routes)
end


# --- 4. Métaheuristique ILS (Destruction / Réparation) ---

function destroy_solution(solution::Solution, instance::Instance, nb_remove::Int; verbose::Bool=true)
    routes = copy(solution.routes)
    removed = Int[]
    # 1. Suppression de route (pour réduire la flotte)
    removed_by_route = Int[]
    idx_target = -1
    if !isempty(routes)
        idx_target = argmin([length(r.order_ids) for r in routes])
        removed_by_route = collect(routes[idx_target].order_ids)
        if verbose
            @info "destroy_solution: removing smallest route index=$idx_target with $(length(removed_by_route)) customers"
        end
    end

    # 2. Construire la liste des clients restants (après suppression de la route ciblée)
    all_remaining = Int[]
    for (i, r) in enumerate(routes)
        if i == idx_target
            continue
        end
        append!(all_remaining, r.order_ids)
    end

    # 3. Échantillonnage aléatoire depuis les clients restants (éviter de prendre ceux de la route supprimée)
    needed = max(0, nb_remove - length(removed_by_route))
    sampled_targets = Int[]
    targets = Set{Int}()
    if needed > 0 && !isempty(all_remaining)
        sel = sample(all_remaining, min(length(all_remaining), needed); replace=false)
        targets = Set(sel)
        sampled_targets = collect(targets)
        if verbose
            @info "destroy_solution: additionally removed $(length(targets)) random customers"
        end
    end

    # 4. Construire les nouvelles routes en excluant la route cible et les clients échantillonnés
    new_routes = Route[]
    for (i, r) in enumerate(routes)
        if i == idx_target
            continue
        end
        keep = filter(x -> !(x in targets), r.order_ids)
        if !isempty(keep)
            push!(new_routes, Route(r.family, keep))
        end
    end

    # 5. Finaliser la liste removed et vérifier invariants simples
    append!(removed, removed_by_route)
    append!(removed, collect(targets))
    sort!(removed)
    if verbose
        @info "destroy_solution: total removed = $(length(removed))"
    end

    # Quick sanity: none of the removed ids should remain in new_routes
    present_after = Int[]
    for r in new_routes; append!(present_after, r.order_ids); end
    overlap = intersect(Set(removed), Set(present_after))
    if !isempty(overlap)
        @error "destroy_solution: invariant violation — removed ids still present after deletion: $(collect(overlap))"
    end

    diag = Dict(:removed_by_route => removed_by_route, :sampled_targets => sampled_targets)
    return Solution(new_routes), removed, diag
end

function repair_solution(solution::Solution, instance::Instance)
    routes = copy(solution.routes)
    # Deterministic ordering for debugging (avoid shuffle during trace)

    # Build present set and expected missing set for invariant checks
    present = Int[]
    for r in routes; append!(present, r.order_ids); end
    present_set = Set(present)
    all_ids = Set(o.id for o in instance.orders)
    expected_missing = setdiff(all_ids, present_set)

    # Work with a mutable set of clients to insert (compute missing from candidate)
    to_insert = Set(collect(expected_missing))
    inserted = Set{Int}()
    skip_counts = Dict{Int, Int}()
    failed = Int[]

    forced_singletons = Int[]

    while !isempty(to_insert)
        cust = first(to_insert)

        # If already present (by some earlier operation), record and skip
        if any(cust in r.order_ids for r in routes)
            skip_counts[cust] = get(skip_counts, cust, 0) + 1
            delete!(to_insert, cust)
            continue
        end

        best_cost = Inf
        best_pos = (-1, -1) # route_idx, pos

        # 1. Try insert into existing routes
        for (i, r) in enumerate(routes)
            if route_weight(r, instance) + instance.orders[cust].weight > instance.vehicles[r.family].max_capacity
                continue
            end

            for pos in 0:length(r.order_ids)
                new_ids = copy(r.order_ids)
                insert!(new_ids, pos+1, cust)

                if check_feasibility(new_ids, r.family, instance)
                    c_before = calculate_ids_cost(r.order_ids, r.family, instance)
                    c_after = calculate_ids_cost(new_ids, r.family, instance)
                    delta = c_after - c_before

                    if delta < best_cost
                        best_cost = delta
                        best_pos = (i, pos)
                    end
                end
            end
        end

        # 2. Try creating a new route (rescue)
        min_new_cost = Inf
        best_new_vehicle_idx = -1
        for v in instance.vehicles
            if v.max_capacity >= instance.orders[cust].weight
                temp_route = Route(v.family, [cust])
                if check_feasibility(temp_route.order_ids, v.family, instance)
                    c = calculate_ids_cost([cust], v.family, instance)
                    if c < min_new_cost
                        min_new_cost = c
                        best_new_vehicle_idx = v.family
                    end
                end
            end
        end

        if best_new_vehicle_idx != -1 && min_new_cost < best_cost
            # Create new route
            push!(routes, Route(best_new_vehicle_idx, [cust]))
            push!(inserted, cust)
            delete!(to_insert, cust)
            continue
        elseif best_pos[1] > -1
            # Insert into existing route
            r_idx, pos = best_pos
            insert!(routes[r_idx].order_ids, pos+1, cust)
            push!(inserted, cust)
            delete!(to_insert, cust)
            continue
        else
            # Unable to insert: record and force a singleton route as last resort
            @warn "repair_solution: could not feasibly insert customer $cust into any route; forcing singleton"
            push!(routes, Route(instance.vehicles[end].family, [cust]))
            push!(inserted, cust)
            push!(forced_singletons, cust)
            delete!(to_insert, cust)
            continue
        end
    end

    # Apply vehicle optimization and cleanup
    clean_routes = Route[]
    for r in routes
        if !isempty(r.order_ids)
            push!(clean_routes, optimize_route_vehicle(r.order_ids, r.family, instance))
        end
    end

    # Summarize skip counts (aggregate) to avoid log flooding
    if !isempty(skip_counts)
        @info "repair_solution: skipped reinsertion for $(length(keys(skip_counts))) orders; counts=" * string(skip_counts)
    end

    # Final invariant check: every order should now appear at least once
    final_ids = Int[]
    for r in clean_routes; append!(final_ids, r.order_ids); end
    final_set = Set(final_ids)

    if final_set != all_ids
        missing_after = setdiff(all_ids, final_set)
        duplicated_after = [id for id in final_ids if count(==(id), final_ids) > 1]
        @error "repair_solution: invariant violated after repair. Missing: $(collect(missing_after)), Duplicates: $(unique(duplicated_after))"
    end

    diag = Dict(:inserted => collect(inserted), :skip_counts => skip_counts, :forced_singletons => forced_singletons)
    return Solution(clean_routes), diag
end

function variable_neighborhood_descent(solution::Solution, instance::Instance)
    # [CORRECTION] Plus de déstructuration de tuple (sol, bool)
    # On compare simplement les coûts pour savoir si on a amélioré
    
    improved = true
    iter = 0
    while improved && iter < 10
        iter += 1
        improved = false
        current_cost = route_cost_sum(solution, instance)
        
        # 1. 2-Opt
        sol_new = local_2opt(solution, instance)
        new_cost = route_cost_sum(sol_new, instance)
        if new_cost < current_cost - 0.1
            solution = sol_new
            current_cost = new_cost
            improved = true
        end
        
        # 2. Relocate
        sol_new = local_relocate(solution, instance)
        new_cost = route_cost_sum(sol_new, instance)
        if new_cost < current_cost - 0.1
            solution = sol_new
            current_cost = new_cost
            improved = true
            continue
        end
        
        # 3. Swap
        sol_new = local_swap(solution, instance)
        new_cost = route_cost_sum(sol_new, instance)
        if new_cost < current_cost - 0.1
            solution = sol_new
            improved = true
        end
    end
    return solution
end

function vnd_heuristic(instance::Instance; verbose::Bool=true)
    println("    [1/3] Construction Concentrique...")
    # Init 1
    s1 = solve_concentric(instance)
    
    best_sol = s1
    best_c = route_cost_sum(best_sol, instance)
    println("          Initial Cost: $(round(best_c, digits=2))")
    
    println("    [2/3] ILS Loop...")
    max_iter = 50 
    
    for i in 1:max_iter
        nb_rem = max(2, round(Int, length(instance.orders) * 0.15))
        # Destroy with diagnostics
        cand, rem, dest_diag = destroy_solution(best_sol, instance, nb_rem; verbose=verbose)

        # Repair with diagnostics (repair computes missing internally)
        cand, repair_diag = repair_solution(cand, instance)

        # If diagnostics show mismatch, print a concise trace to help debugging
        rem_set = Set(rem)
        inserted_set = Set(repair_diag[:inserted])
        # Log a short trace when sets differ or when skip/forced events occurred
        if (rem_set != inserted_set || !isempty(repair_diag[:skip_counts]) || !isempty(repair_diag[:forced_singletons])) && verbose
            @info "ILS Iter $i trace: removed_by_route=$(dest_diag[:removed_by_route]) sampled_targets=$(dest_diag[:sampled_targets]) removed_total=$(length(rem)) inserted_total=$(length(repair_diag[:inserted])) skips=$(length(keys(repair_diag[:skip_counts]))) forced=$(length(repair_diag[:forced_singletons]))"
        end

        # Enforce uniqueness immediately after repair to avoid duplicates propagating
        cand, uniq_diag = ensure_solution_uniqueness(cand, instance)
        if ( !isempty(uniq_diag[:dropped]) || !isempty(uniq_diag[:added]) ) && verbose
            @info "ILS Iter $i uniqueness_fix: dropped=$(uniq_diag[:dropped]) added=$(uniq_diag[:added])"
        end

        cand = variable_neighborhood_descent(cand, instance)

        c = route_cost_sum(cand, instance)
        if c < best_c - 0.1
            println("          Iter $i: New Best $(round(c, digits=2))")
            best_c = c
            best_sol = cand
        end
    end
    
    println("    [3/3] Final Check...")
    final_routes = Route[]
    for r in best_sol.routes
        if !isempty(r.order_ids)
            push!(final_routes, optimize_route_vehicle(r.order_ids, r.family, instance))
        end
    end

    sol = Solution(final_routes)
    # Ensure global uniqueness: remove duplicate visits and reinsert missing ones if any
    function finalize_solution_unique(solution::Solution, instance::Instance)
        # Keep the first occurrence of each order and drop duplicates
        seen = Set{Int}()
        final_routes = Route[]
        dropped = Int[]
        for r in solution.routes
            new_ids = Int[]
            for oid in r.order_ids
                if !(oid in seen)
                    push!(new_ids, oid)
                    push!(seen, oid)
                else
                    push!(dropped, oid)
                end
            end
            if !isempty(new_ids)
                push!(final_routes, optimize_route_vehicle(new_ids, r.family, instance))
            end
        end

        # Add any missing orders as singleton routes (rescue vehicle)
        all_ids = [o.id for o in instance.orders]
        missing = collect(setdiff(all_ids, collect(seen)))
        added = Int[]
        if !isempty(missing)
            v_rescue = instance.vehicles[end]
            for oid in missing
                push!(final_routes, optimize_route_vehicle([oid], v_rescue.family, instance))
                push!(added, oid)
            end
        end

        # Aggregate logging to reduce noise
        if !isempty(dropped)
            @warn "finalize_solution_unique: dropped duplicate orders during finalization: $(unique(dropped))"
        end
        if !isempty(added)
            @warn "finalize_solution_unique: added missing orders as singletons during finalization: $(added)"
        end

        return Solution(final_routes)
    end

    sol = finalize_solution_unique(sol, instance)
    return sol
end

# Ensure uniqueness helper: removes duplicate occurrences (keeping first) and
# returns diagnostics with lists of dropped and added orders.
function ensure_solution_uniqueness(solution::Solution, instance::Instance)
    seen = Set{Int}()
    final_routes = Route[]
    dropped = Int[]

    for r in solution.routes
        new_ids = Int[]
        for oid in r.order_ids
            if oid in seen
                push!(dropped, oid)
            else
                push!(new_ids, oid)
                push!(seen, oid)
            end
        end
        if !isempty(new_ids)
            push!(final_routes, optimize_route_vehicle(new_ids, r.family, instance))
        end
    end

    all_ids = [o.id for o in instance.orders]
    missing = collect(setdiff(Set(all_ids), seen))
    added = Int[]
    if !isempty(missing)
        v_rescue = instance.vehicles[end]
        for oid in missing
            push!(final_routes, optimize_route_vehicle([oid], v_rescue.family, instance))
            push!(added, oid)
        end
    end

    return Solution(final_routes), Dict(:dropped => dropped, :added => added)
end

# Alias
function nearest_insertion_heuristic(i); return solve_concentric(i); end
function sweep_heuristic(i); return solve_concentric(i); end
function clarke_wright_step(s, i); return s; end
function two_opt_solution(s, i); return local_2opt(s, i); end