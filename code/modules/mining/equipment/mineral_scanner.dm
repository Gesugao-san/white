/**********************Mining Scanners**********************/
/obj/item/mining_scanner
	desc = "Сканер, проверяющий окружающую породу на наличие полезных минералов; его также можно использовать для остановки детонации гибтонита."
	name = "ручной шахтёрский сканнер"
	icon = 'white/valtos/icons/items.dmi'
	icon_state = "miningmanual"
	inhand_icon_state = "analyzer"
	worn_icon_state = "analyzer"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	flags_1 = CONDUCT_1
	slot_flags = ITEM_SLOT_BELT
	var/cooldown = 35
	var/current_cooldown = 0

/obj/item/mining_scanner/attack_self(mob/user)
	if(!user.client)
		return
	if(current_cooldown <= world.time)
		current_cooldown = world.time + cooldown
		mineral_scan_pulse(get_turf(user))

//Debug item to identify all ore spread quickly
/obj/item/mining_scanner/admin

/obj/item/mining_scanner/admin/attack_self(mob/user)
	for(var/turf/closed/mineral/M in world)
		if(M.scan_state)
			M.icon_state = M.scan_state
	qdel(src)

/obj/item/t_scanner/adv_mining_scanner
	desc = "Сканер, автоматически проверяющий окружающую породу на наличие полезных минералов; его также можно использовать для остановки детонации гибтонита. У этого есть расширенный диапазон."
	name = "продвинутый автоматический шахтёрский сканнер"
	icon_state = "adv_mining0"
	inhand_icon_state = "analyzer"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	flags_1 = CONDUCT_1
	slot_flags = ITEM_SLOT_BELT
	var/cooldown = 35
	var/current_cooldown = 0
	var/range = 7

/obj/item/t_scanner/adv_mining_scanner/cyborg/Initialize()
	. = ..()
	toggle_on()

/obj/item/t_scanner/adv_mining_scanner/lesser
	name = "автоматический шахтёрский сканнер"
	desc = "Сканер, автоматически проверяющий окружающую породу на наличие полезных минералов; его также можно использовать для остановки детонации гибтонита."
	icon_state = "mining0"
	range = 4
	cooldown = 50

/obj/item/t_scanner/adv_mining_scanner/scan()
	if(current_cooldown <= world.time)
		current_cooldown = world.time + cooldown
		var/turf/t = get_turf(src)
		mineral_scan_pulse(t, range)

/proc/mineral_scan_pulse(turf/T, range = world.view)
	var/list/minerals = list()
	for(var/turf/closed/mineral/M in range(range, T))
		if(M.scan_state)
			minerals += M
	if(LAZYLEN(minerals))
		for(var/turf/closed/mineral/M in minerals)
			var/obj/effect/temp_visual/mining_overlay/oldC = locate(/obj/effect/temp_visual/mining_overlay) in M
			if(oldC)
				qdel(oldC)
			var/obj/effect/temp_visual/mining_overlay/C = new /obj/effect/temp_visual/mining_overlay(M)
			C.icon_state = M.scan_state

/obj/effect/temp_visual/mining_overlay
	plane = FULLSCREEN_PLANE
	layer = FLASH_LAYER
	icon = 'icons/effects/ore_visuals.dmi'
	appearance_flags = 0 //to avoid having TILE_BOUND in the flags, so that the 480x480 icon states let you see it no matter where you are
	duration = 35
	pixel_x = -224
	pixel_y = -224

/obj/effect/temp_visual/mining_overlay/Initialize()
	. = ..()
	animate(src, alpha = 0, time = duration, easing = EASE_IN)
