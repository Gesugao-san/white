SUBSYSTEM_DEF(air)
	name = "Турбо-Атмос"
	init_order = INIT_ORDER_AIR
	priority = FIRE_PRIORITY_AIR
	wait = 0.5 SECONDS
	flags = SS_BACKGROUND
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	var/cached_cost = 0
	var/cost_atoms = 0
	var/cost_turfs = 0
	var/cost_groups = 0
	var/cost_highpressure = 0
	var/cost_hotspots = 0
	var/cost_superconductivity = 0
	var/cost_pipenets = 0
	var/cost_rebuilds = 0
	var/cost_atmos_machinery = 0
	var/cost_equalize = 0

	var/list/active_turfs = list()
	var/list/hotspots = list()
	var/list/networks = list()
	var/list/pipenets_needing_rebuilt = list()
	/// A list of machines that will be processed when currentpart == SSAIR_ATMOSMACHINERY. Use SSair.begin_processing_machine and SSair.stop_processing_machine to add and remove machines.
	var/list/obj/machinery/atmos_machinery = list()
	var/list/pipe_init_dirs_cache = list()

	//atmos singletons
	var/list/gas_reactions = list()

	//Special functions lists
	var/list/turf/active_super_conductivity = list()
	var/list/turf/open/high_pressure_delta = list()
	var/list/atom_process = list()

	/// A cache of objects that perisists between processing runs when resumed == TRUE. Dangerous, qdel'd objects not cleared from this may cause runtimes on processing.
	var/list/currentrun = list()
	var/currentpart = SSAIR_PIPENETS

	var/map_loading = TRUE
	var/list/queued_for_activation

	var/list/paused_z_levels	//Paused z-levels will not add turfs to active
	var/list/turfs_to_activate

/datum/controller/subsystem/air/stat_entry(msg)
	msg += "C:{"
	msg += "EQ:[round(cost_equalize,1)]|"
	msg += "AT:[round(cost_turfs,1)]|"
	msg += "EG:[round(cost_groups,1)]|"
	msg += "HP:[round(cost_highpressure,1)]|"
	msg += "HS:[round(cost_hotspots,1)]|"
	msg += "SC:[round(cost_superconductivity,1)]|"
	msg += "PN:[round(cost_pipenets,1)]|"
	msg += "RB:[round(cost_rebuilds,1)]|"
	msg += "AM:[round(cost_atmos_machinery,1)]"
	msg += "AO:[round(cost_atoms, 1)]|"
	msg += "} "
	msg += "AT:[active_turfs.len]|"
	msg += "EG:[get_amt_excited_groups()]|"
	msg += "HS:[hotspots.len]|"
	msg += "PN:[networks.len]|"
	msg += "HP:[high_pressure_delta.len]|"
	msg += "AS:[active_super_conductivity.len]|"
	msg += "AO:[atom_process.len]|"
	msg += "AT/MS:[round((cost ? active_turfs.len/cost : 0),0.1)]"
	return ..()


/datum/controller/subsystem/air/Initialize(timeofday)
	extools_update_ssair()
	map_loading = FALSE
	setup_allturfs()
	setup_atmos_machinery()
	setup_pipenets()
	gas_reactions = init_gas_reactions()
	extools_update_reactions()

	return ..()

/datum/controller/subsystem/air/proc/extools_update_ssair()
/datum/controller/subsystem/air/proc/extools_update_reactions()

/datum/controller/subsystem/air/fire(resumed = FALSE)
	var/timer = TICK_USAGE_REAL
	var/delta_time = wait * 0.1

	// Every time we fire, we want to make sure pipenets are rebuilt. The game state could have changed between each fire() proc call
	// and anything missing a pipenet can lead to unintended behaviour at worse and various runtimes at best.
	if(length(pipenets_needing_rebuilt))
		var/list/pipenet_rebuilds = pipenets_needing_rebuilt
		for(var/thing in pipenet_rebuilds)
			var/obj/machinery/atmospherics/AT = thing
			if(AT)
				AT.build_network()
		pipenets_needing_rebuilt.Cut()
		if(state != SS_RUNNING)
			return
		cost_rebuilds = MC_AVERAGE(cost_rebuilds, TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer))

	if(currentpart == SSAIR_PIPENETS || !resumed)
		process_pipenets(delta_time, resumed)
		cost_pipenets = MC_AVERAGE(cost_pipenets, TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer))
		if(state != SS_RUNNING)
			return
		resumed = FALSE
		currentpart = SSAIR_ATMOSMACHINERY

	if(currentpart == SSAIR_ATMOSMACHINERY)
		timer = TICK_USAGE_REAL
		process_atmos_machinery(delta_time, resumed)
		cost_atmos_machinery = MC_AVERAGE(cost_atmos_machinery, TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer))
		if(state != SS_RUNNING)
			return
		resumed = 0
		currentpart = SSAIR_EQUALIZE

	if(currentpart == SSAIR_EQUALIZE)
		timer = TICK_USAGE_REAL
		process_turf_equalize(resumed)
		cost_equalize = MC_AVERAGE(cost_equalize, TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer))
		if(state != SS_RUNNING)
			return
		resumed = 0
		currentpart = SSAIR_ACTIVETURFS

	if(currentpart == SSAIR_ACTIVETURFS)
		timer = TICK_USAGE_REAL
		process_active_turfs(resumed)
		cost_turfs = MC_AVERAGE(cost_turfs, TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer))
		if(state != SS_RUNNING)
			return
		resumed = FALSE
		currentpart = SSAIR_EXCITEDGROUPS

	if(currentpart == SSAIR_EXCITEDGROUPS)
		timer = TICK_USAGE_REAL
		process_excited_groups(resumed)
		cost_groups = MC_AVERAGE(cost_groups, TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer))
		if(state != SS_RUNNING)
			return
		resumed = FALSE
		currentpart = SSAIR_HIGHPRESSURE

	if(currentpart == SSAIR_HIGHPRESSURE)
		timer = TICK_USAGE_REAL
		process_high_pressure_delta(resumed)
		cost_highpressure = MC_AVERAGE(cost_highpressure, TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer))
		if(state != SS_RUNNING)
			return
		resumed = FALSE
		currentpart = SSAIR_HOTSPOTS

	if(currentpart == SSAIR_HOTSPOTS)
		timer = TICK_USAGE_REAL
		process_hotspots(delta_time, resumed)
		cost_hotspots = MC_AVERAGE(cost_hotspots, TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer))
		if(state != SS_RUNNING)
			return
		resumed = FALSE
		currentpart = SSAIR_SUPERCONDUCTIVITY

	if(currentpart == SSAIR_SUPERCONDUCTIVITY)
		timer = TICK_USAGE_REAL
		process_super_conductivity(resumed)
		cost_superconductivity = MC_AVERAGE(cost_superconductivity, TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer))
		if(state != SS_RUNNING)
			return
		resumed = FALSE
		currentpart = SSAIR_PROCESS_ATOMS

	if(currentpart == SSAIR_PROCESS_ATOMS)
		timer = TICK_USAGE_REAL
		process_atoms(resumed)
		if(state != SS_RUNNING)
			return
		cost_atoms = MC_AVERAGE(cost_atoms, TICK_DELTA_TO_MS(TICK_USAGE_REAL - timer))
		resumed = FALSE
	currentpart = SSAIR_PIPENETS

/datum/controller/subsystem/air/proc/process_pipenets(delta_time, resumed = FALSE)
	if (!resumed)
		src.currentrun = networks.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/datum/thing = currentrun[currentrun.len]
		currentrun.len--
		if(thing)
			thing.process(delta_time)
		else
			networks.Remove(thing)
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/add_to_rebuild_queue(atmos_machine)
	if(istype(atmos_machine, /obj/machinery/atmospherics))
		pipenets_needing_rebuilt += atmos_machine

/datum/controller/subsystem/air/proc/process_atoms(resumed = FALSE)
	if(!resumed)
		src.currentrun = atom_process.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/atom/talk_to = currentrun[currentrun.len]
		currentrun.len--
		if(!talk_to)
			return
		talk_to.process_exposure()
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_atmos_machinery(delta_time, resumed = FALSE)
	if (!resumed)
		src.currentrun = atmos_machinery.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/obj/machinery/M = currentrun[currentrun.len]
		currentrun.len--
		if(!M || (M.process_atmos(delta_time) == PROCESS_KILL))
			atmos_machinery.Remove(M)
		if(MC_TICK_CHECK)
			return


/datum/controller/subsystem/air/proc/process_super_conductivity(resumed = FALSE)
	if (!resumed)
		src.currentrun = active_super_conductivity.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/turf/T = currentrun[currentrun.len]
		currentrun.len--
		T.super_conduct()
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_hotspots(delta_time, resumed = FALSE)
	if (!resumed)
		src.currentrun = hotspots.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/obj/effect/hotspot/H = currentrun[currentrun.len]
		currentrun.len--
		if (H)
			H.process(delta_time)
		else
			hotspots -= H
		if(MC_TICK_CHECK)
			return


/datum/controller/subsystem/air/proc/process_high_pressure_delta(resumed = FALSE)
	while (high_pressure_delta.len)
		var/turf/open/T = high_pressure_delta[high_pressure_delta.len]
		high_pressure_delta.len--
		T.high_pressure_movements()
		T.pressure_difference = 0
		T.pressure_specific_target = null
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_turf_equalize(resumed = 0)
	//cache for sanic speed
	var/fire_count = times_fired
	if (!resumed)
		src.currentrun = active_turfs.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/turf/open/T = currentrun[currentrun.len]
		currentrun.len--
		if (istype(T))
			T.equalize_pressure_in_zone(fire_count)
		if (MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_active_turfs(resumed = 0)
	//cache for sanic speed
	var/fire_count = times_fired
	if (!resumed)
		src.currentrun = active_turfs.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/turf/open/T = currentrun[currentrun.len]
		currentrun.len--
		if (T)
			T.process_cell(fire_count)
		if (MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_excited_groups(resumed = 0)
	if(process_excited_groups_extools(resumed, (Master.current_ticklimit - TICK_USAGE) * 0.01 * world.tick_lag))
		pause()

/datum/controller/subsystem/air/proc/process_excited_groups_extools()
/datum/controller/subsystem/air/proc/get_amt_excited_groups()

/datum/controller/subsystem/air/proc/remove_from_active(turf/open/T)
	active_turfs -= T
	if(currentpart == SSAIR_ACTIVETURFS)
		currentrun -= T
	#ifdef VISUALIZE_ACTIVE_TURFS //Use this when you want details about how the turfs are moving, display_all_groups should work for normal operation
	T.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, COLOR_VIBRANT_LIME)
	#endif
	if(istype(T))
		T.set_excited(FALSE)
		T.eg_garbage_collect()

/datum/controller/subsystem/air/proc/add_to_active(turf/open/T, blockchanges = 1)
	if(LAZYLEN(paused_z_levels) && (T.z in paused_z_levels))
		LAZYADD(turfs_to_activate, T)
	else if(istype(T) && T.air)
		#ifdef VISUALIZE_ACTIVE_TURFS
		T.add_atom_colour(COLOR_VIBRANT_LIME, TEMPORARY_COLOUR_PRIORITY)
		#endif
		T.set_excited(TRUE)
		active_turfs |= T
		if(currentpart == SSAIR_ACTIVETURFS)
			currentrun |= T
		if(blockchanges)
			T.eg_garbage_collect()
	else if(T.flags_1 & INITIALIZED_1)
		for(var/turf/S in T.atmos_adjacent_turfs)
			add_to_active(S)
	else if(map_loading)
		if(queued_for_activation)
			queued_for_activation[T] = T
		return
	else
		T.requires_activation = TRUE

/datum/controller/subsystem/air/proc/pause_z(z_level)
	LAZYADD(paused_z_levels, z_level)

/datum/controller/subsystem/air/proc/unpause_z(z_level)
	LAZYREMOVE(paused_z_levels, z_level)
	for(var/turf/T as() in turfs_to_activate)
		if(T.z == z_level)
			LAZYREMOVE(turfs_to_activate, T)
			add_to_active(T)

/datum/controller/subsystem/air/StartLoadingMap()
	LAZYINITLIST(queued_for_activation)
	map_loading = TRUE

/datum/controller/subsystem/air/StopLoadingMap()
	map_loading = FALSE
	for(var/T in queued_for_activation)
		add_to_active(T)
	queued_for_activation.Cut()

/datum/controller/subsystem/air/proc/setup_allturfs()
	var/list/turfs_to_init = block(locate(1, 1, 1), locate(world.maxx, world.maxy, world.maxz))
	var/list/active_turfs = src.active_turfs
	var/times_fired = ++src.times_fired

	// Clear active turfs - faster than removing every single turf in the world
	// one-by-one, and Initalize_Atmos only ever adds `src` back in.
	active_turfs.Cut()

	for(var/thing in turfs_to_init)
		var/turf/T = thing
		if (T.blocks_air)
			continue
		T.Initalize_Atmos(times_fired)
		CHECK_TICK

	if(active_turfs.len)
		var/starting_ats = active_turfs.len
		sleep(world.tick_lag)
		var/timer = world.timeofday
		log_mapping("There are [starting_ats] active turfs at roundstart caused by a difference of the air between the adjacent turfs. You can see its coordinates using \"Mapping -> Show roundstart AT list\" verb (debug verbs required).")
		for(var/turf/T in active_turfs)
			GLOB.active_turfs_startlist += T

		//now lets clear out these active turfs
		var/list/turfs_to_check = active_turfs.Copy()
		do
			var/list/new_turfs_to_check = list()
			for(var/turf/open/T in turfs_to_check)
				new_turfs_to_check += T.resolve_active_graph()
			CHECK_TICK

			active_turfs += new_turfs_to_check
			turfs_to_check = new_turfs_to_check

		while (turfs_to_check.len)
		var/ending_ats = active_turfs.len

		var/msg = "ЭЙ! СЛЫШ! [DisplayTimeText(world.timeofday - timer)] было потрачено на [starting_ats] активных турфов (которые подключены к [ending_ats] другим) с разностями в атмосфере при инициализации."
		message_admins("[msg]")
		warning(msg)

/turf/open/proc/resolve_active_graph()
	. = list()

/turf/open/space/resolve_active_graph()
	return list()

/datum/controller/subsystem/air/proc/setup_atmos_machinery()
	for (var/obj/machinery/atmospherics/AM in atmos_machinery)
		AM.atmosinit()
		CHECK_TICK

//this can't be done with setup_atmos_machinery() because
//	all atmos machinery has to initalize before the first
//	pipenet can be built.
/datum/controller/subsystem/air/proc/setup_pipenets()
	for (var/obj/machinery/atmospherics/AM in atmos_machinery)
		AM.build_network()
		CHECK_TICK

/datum/controller/subsystem/air/proc/setup_template_machinery(list/atmos_machines)
	if(!initialized) // yogs - fixes randomized bars
		return // yogs
	var/obj/machinery/atmospherics/AM
	for(var/A in 1 to atmos_machines.len)
		AM = atmos_machines[A]
		AM.atmosinit()
		CHECK_TICK

	for(var/A in 1 to atmos_machines.len)
		AM = atmos_machines[A]
		AM.build_network()
		CHECK_TICK

/datum/controller/subsystem/air/proc/get_init_dirs(type, dir)
	if(!pipe_init_dirs_cache[type])
		pipe_init_dirs_cache[type] = list()

	if(!pipe_init_dirs_cache[type]["[dir]"])
		var/obj/machinery/atmospherics/temp = new type(null, FALSE, dir)
		pipe_init_dirs_cache[type]["[dir]"] = temp.GetInitDirections()
		qdel(temp)

	return pipe_init_dirs_cache[type]["[dir]"]
