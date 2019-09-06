PROCESSING_SUBSYSTEM_DEF(btension)
	name = "Battle Tension"
	priority = 15
	flags = SS_NO_INIT
	wait = 10

/datum/component/battletension
	var/mob/living/owner

	var/tension = 0
	var/sound/bm

/datum/component/battletension/Initialize()
	START_PROCESSING(SSbtension, src)

	if(isliving(parent))
		owner = parent
		pick_sound()

/datum/component/battletension/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_BULLET_ACT, .proc/bulletact_react)
	RegisterSignal(parent, COMSIG_PARENT_ATTACKBY, .proc/attackby_react)

/datum/component/battletension/UnregisterFromParent()
	UnregisterSignal(parent, list(	COMSIG_ATOM_BULLET_ACT,
									COMSIG_PARENT_ATTACKBY
									))

/datum/component/battletension/Destroy()
	if(bm)
		bm.volume = 0
		bm.status = SOUND_UPDATE
		SEND_SOUND(owner, bm)

	STOP_PROCESSING(SSbtension, src)
	owner = null
	return ..()

/datum/component/battletension/process()
	if(tension < 0 || !bm || !bm.file)
		return

	bm.volume = tension
	bm.status = SOUND_UPDATE
	SEND_SOUND(owner, bm)

	switch(tension)
		if(0 to 30)
			tension--

		if(80 to INFINITY)
			tension = 80

	if(tension > 0)
		tension--
		if(tension <= 0)
			bm.volume = 0
			SEND_SOUND(owner, bm)
			qdel(bm)
			bm = null
			pick_sound()

/datum/component/battletension/proc/bulletact_react(datum/source, obj/item/projectile/P, def_zone)
	create_tension(P.damage)

	if(!P.firer || P.firer == owner)
		return

	var/datum/component/battletension/BT = P.firer.GetComponent(/datum/component/battletension)

	if(BT)
		BT.create_tension(P.damage)


/datum/component/battletension/proc/attackby_react(datum/source, obj/item/I, mob/user)
	create_tension(I.force * 1.2)

	if(!user || user == owner)
		return

	var/datum/component/battletension/BT = user.GetComponent(/datum/component/battletension)

	if(BT)
		BT.create_tension(I.force * 1.2)

/datum/component/battletension/proc/create_tension(amount)
	if(tension)
		tension += amount
	else
		tension = amount

/datum/component/battletension/proc/pick_sound()
	var/sound/S = sound(pick(get_sound_list()))
	if(!S || !S.file)
		return
	S.repeat = 1
	S.channel = 1015
	S.falloff = 2
	S.wait = 0
	S.volume = 0
	S.status = 0

	bm = S
	SEND_SOUND(owner, bm)

/datum/component/battletension/proc/get_sound_list()
	var/list/result = list()
	var/list/sounds = (
						list("gladiator.ogg"),
						list("digitalonslaught.ogg", "03 NARC.ogg"),
						list("80sspark.ogg","badapple.ogg"),
						list()
						)
	if(!owner || !owner.client || !owner.client.prefs)
		return

	var/list/settings = owner.client.prefs.btprefs
	for(var/i = 2, i<settings.len, i++)
		if(settings[i])
			result += sounds[i-1]

	for(var/i in result)
		i = "code/shitcode/hule/battletension/bm/" + i

	return result

/client/verb/customize_battletension()
	set name = "Customize Battle Tension"
	set desc = "Allows for advanced prikol immersion."
	set category = "Preferences"

	//list shit: 1 - toggle, 2 - prikols, 3 - synth, 4 - toho, 5 - mc
	var/list/settings = prefs.btprefs

	var/list/menu = list("����������", "��������", "��������", "����", "��")

	for(var/i = 1, i<settings.len, i++)
		menu[i] = "[settings[i] ? "������" : "����"]" + menu[i]

	var/selected = input(null, "BT Customization") as null|anything in menu
	selected = splittext(selected, " ")[2]

	var/settnum = 1
	switch(selected)
		if("����������")
			settnum = 1
		if("��������")
			settnum = 2
		if("��������")
			settnum = 3
		if("����")
			settnum = 4
		if("��")
			settnum = 5

	settings[settnum] = !settings[settnum]
	to_chat(usr, "<span class='danger'>[settings[settnum] ? "������ �� ������" : "�� ������ �� ������"] [selected].</span>")

	prefs.btprefs = settings
	prefs.save_preferences()

