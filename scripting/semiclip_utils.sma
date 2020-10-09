#include <amxmodx>
#include <fakemeta>
#include <engine>

// delete/comment this if you don't want to replace the heal function with my custom one
// requires celltrie, hamsandwich and orpheu, along with updated signatures
#define USE_MEDKIT_REMAKE 1 

#if defined USE_MEDKIT_REMAKE
#include <hamsandwich>
#include <celltrie>
#include <orpheu>

#define TASK_NUM 6742398
#define HEAL_SOUND "items/medshot4.wav"
#define HEAL_SOUND_DENY "items/medshotno1.wav"

#define HEALTH_AMMO 576

new Trie:g_tcBusyHealthkits;
#endif
new g_iGroupInfoBuffer[32];

public plugin_init() 
{
	register_plugin("Semiclip Utils","1.2","Gabe Iggy")
	register_forward(FM_AddToFullPack, "semiclip_pre", 0)
	register_forward(FM_AddToFullPack, "semiclip_post", 1)

#if defined USE_MEDKIT_REMAKE
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_medkit", "heal_pre", 0);
	RegisterHam(Ham_SC_Weapon_ShouldWeaponIdle, "weapon_medkit", "check_busy", 0);
	//RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_medkit", "heal_post", 1);

	g_tcBusyHealthkits = TrieCreate();
#endif
}

#if defined USE_MEDKIT_REMAKE
public plugin_precache()
{
	precache_sound(HEAL_SOUND);
	precache_sound(HEAL_SOUND_DENY);
}

public heal_pre(weaponID)
{
	new key[3];
	num_to_str(weaponID,key,charsmax(key));
	if(!TrieKeyExists(g_tcBusyHealthkits, key))
	{
		new id = get_pdata_ehandle(weaponID, 404, 16);
		new target;
		get_user_aiming(id, target);
		if(ExecuteHam(Ham_SC_IsMonster, target) && !is_user_alive(target))
			return HAM_IGNORED;

		new ammo = get_pdata_int(id, HEALTH_AMMO, 4, 4); 
		if(ammo >= 20)
		{
			new tempid = -1; 
			new Float:v_Player[3];
			pev(id, pev_origin, v_Player)
			while((tempid = find_ent_in_sphere(tempid, v_Player, 100.0)))
			{
				if(tempid == 0 
					|| tempid > MaxClients 
					|| pev(tempid, pev_deadflag) & DEAD_DYING
					|| pev(tempid, pev_deadflag) & DEAD_DEAD
					|| tempid == id)
						continue;

				new Float:target_max_health;
				new Float:target_health;

				pev(tempid, pev_max_health, target_max_health);
				pev(tempid, pev_health, target_health);

				if(target_max_health <= target_health)
					continue;

				ExecuteHam(Ham_Weapon_SendWeaponAnim, weaponID, 3, 0, 0);
				set_pev(id, pev_frame, 1.0);
				set_pev(id, pev_animtime, 0.0);
				set_pev(id, pev_framerate, 1.0); 
				OrpheuCall(OrpheuGetFunction("SC_SetAnimation"), id, 5, 0);

				new newammo = clamp(ammo-20, 0, 100);
				set_pdata_int(id, HEALTH_AMMO, newammo, 4, 4);

				TrieSetCell(g_tcBusyHealthkits, key, 0, true);
				healgroup(id, weaponID);
				set_task(1.0, "remove_from_busy_hk", TASK_NUM+weaponID);
				break;
			}
		}
		else
		{
			emit_sound(id, CHAN_ITEM, HEAL_SOUND_DENY, 0.5, ATTN_NORM, 0, PITCH_NORM);
			TrieSetCell(g_tcBusyHealthkits, key, 0, true);
			set_task(1.0, "remove_from_busy_hk", TASK_NUM+weaponID);
		}
	}
	
	return HAM_SUPERCEDE;
}

public healgroup(id, weaponID)
{
	//server_print("heal group");
	//new user_current_ammo = get_pdata_int(id, 2312, 4);
	//server_print("current ammo is %i", user_current_ammo);
	emit_sound(id, CHAN_ITEM, HEAL_SOUND, 0.5, ATTN_NORM, 0, PITCH_NORM);
	new Float:v_Player[3];
	new tempid = -1;
	pev(id, pev_origin, v_Player)
	new message_buffer[512];
	while((tempid = find_ent_in_sphere(tempid, v_Player, 100.0)))
	{
		if(tempid == 0 
		|| tempid > MaxClients 
		|| pev(tempid, pev_deadflag) & DEAD_DYING
		|| pev(tempid, pev_deadflag) & DEAD_DEAD
		|| tempid == id)
			continue;

		new Float:target_max_health;
		new Float:target_health;

		pev(tempid, pev_max_health, target_max_health);
		pev(tempid, pev_health, target_health);

		if(target_max_health <= target_health)
			continue;

		new Float:target_new_health;
		target_new_health = floatclamp(target_health+15.0, 0.0, 100.0);
		set_pev(tempid, pev_health, target_new_health);

		new name[32];
		get_user_name(tempid, name, charsmax(name));

		format(message_buffer, charsmax(message_buffer), "%s%s (+15)^n", message_buffer, name);  
		
		//set_pdata_int(id, 2312, user_current_ammo-10, 4);
	}

	format(message_buffer, charsmax(message_buffer), "Healed:^n^n%s", message_buffer);
	set_hudmessage(0, 200, 0, -1.0, 0.60, 0, 0.2, 1.0, 0.2, 0.1);
	show_hudmessage(id, message_buffer);
}

public check_busy(weaponID)
{
	new key[3];
	num_to_str(weaponID,key,charsmax(key));
	if(TrieKeyExists(g_tcBusyHealthkits, key))
		return HAM_SUPERCEDE;
	else 
		return HAM_IGNORED;
}

public remove_from_busy_hk(taskID)
{
	new weaponID = taskID-TASK_NUM;
	new key[3];
	num_to_str(weaponID,key,charsmax(key));
	TrieDeleteKey(g_tcBusyHealthkits, key);
}
#endif

/*
AddToFullPack
Return 1 if the entity state has been filled in for the ent and the entity 
will be propagated to the client, 0 otherwise

· "ent_state" is the server maintained copy of the state info that is transmitted 
	to the client a MOD could alter values copied into state to send the "host" a 
	different look for a particular entity update, etc.
· "e" and "edict_t_ent" are the entity that is being added to the update, if 1 is returned
· "edict_t_host" is the player's edict of the player whom we are sending the update to
· "player" is 1 if the ent/e is a player and 0 otherwise
· "pSet" is either the PAS or PVS that we previous set up.  
	We can use it to ask the engine to filter the entity against the PAS or PVS.
	we could also use the pas/ pvs that we set in SetupVisibility, if we wanted to.  Caching the value is valid in that case, but still only for the current frame
*/
public semiclip_pre(ent_state,e,edict_t_ent,edict_t_host,hostflags,player,pSet) 
{	
	if(player)
	{
		g_iGroupInfoBuffer[edict_t_ent] = pev(edict_t_ent, pev_groupinfo);
		set_pev(edict_t_ent, pev_groupinfo, pev(edict_t_host, pev_groupinfo));
	}
	
	return FMRES_IGNORED;
}

public semiclip_post(ent_state,e,edict_t_ent,edict_t_host,hostflags,player,pSet) 
{	
	if(player)
	{
		if(pev(edict_t_host, pev_groundentity) == edict_t_ent)
			set_es(ent_state, ES_Solid, 1);
		else
			set_es(ent_state, ES_Solid, 0);

		set_pev(edict_t_ent, pev_groupinfo, g_iGroupInfoBuffer[edict_t_ent]);
	}
	
	return FMRES_IGNORED;
}