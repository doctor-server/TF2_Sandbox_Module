#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Battlefield Duck"
#define PLUGIN_VERSION "1.2"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <build>
#include <tf2items_giveweapon>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] SandBox - WeaponEquip", 
	author = PLUGIN_AUTHOR, 
	description = "Weapon Equip for TF2SandBox", 
	version = PLUGIN_VERSION, 
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

Handle g_hHud;
Handle g_hEnable;

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_weaponequip_ver", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	g_hEnable = CreateConVar("sm_tf2sb_weaponequip_enable", "1", "Enable the Weapon equip Plugin?", 0, true, 0.0, true, 1.0);
	g_hHud = CreateHudSynchronizer();
}

public void OnMapStart()
{
	for (int i = MaxClients; i < MAX_HOOK_ENTITIES; i++)	if (IsValidEdict(i) && IsValidWeapon(i) != -1)
	{
		TF2_CreateGlow(i);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (IsValidEdict(entity) && StrContains(classname, "prop_dynamic") >= 0)	CreateTimer(0.1, Timer_WeaponSpawn, entity);
}



public Action Timer_WeaponSpawn(Handle timer, int entity)
{
	if (IsValidWeapon(entity) != -1)
	{
		TF2_CreateGlow(entity);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(IsValidClient(client) && IsPlayerAlive(client) && GetConVarBool(g_hEnable))	
	{
		int iEntity = Build_ClientAimEntity(client, false);
		int iEntityIndex = IsValidWeapon(iEntity);
		
		if(iEntityIndex != -1)
		{
			SetHudTextParams(-1.0, 0.7, 0.01, 124, 252, 0, 255, 1, 6.0, 0.5, 0.5);
			ShowSyncHudText(client, g_hHud, "Press MOUSE3 to equip the weapon");
			
			float fClientPosition[3], fEntityOrigin[3];
			GetClientEyePosition(client, fClientPosition);
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fEntityOrigin);
				
			if(GetVectorDistance(fClientPosition, fEntityOrigin) < 100.0 &&buttons & IN_ATTACK3)
			{
				int iWeapon;
				for (int iSlot = 0; iSlot < 8; iSlot++) 
    			{ 
    				iWeapon = GetPlayerWeaponSlot(client, iSlot);
    				if(IsValidEntity(iWeapon) && iEntityIndex == GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"))
    				{
	    				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon);
	    				return Plugin_Continue;
    				}
    			}
				if(TF2Items_CheckWeapon(iEntityIndex))
				{
					TF2Items_GiveWeapon(client, iEntityIndex);
					for (int iSlot = 0; iSlot < 8; iSlot++) 
	    			{ 
	    				iWeapon = GetPlayerWeaponSlot(client, iSlot);
	    				if(IsValidEntity(iWeapon) && iEntityIndex == GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"))
	    				{
	    					int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	    					if(GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex") == iEntityIndex)
	    					{
	    						SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon);
	    					}
	    					break;
	    				}
	    			}
				}
			}
			
		}
	}	
	return Plugin_Continue;
}

//From raindowglow.sp--------------
stock int TF2_CreateGlow(int iEnt)
{
	if(!TF2_HasGlow(iEnt))
	{
		char strName[126], strClass[64];
		int red, green, blue, alpha;
	
		GetEntityClassname(iEnt, strClass, sizeof(strClass));
		Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
		DispatchKeyValue(iEnt, "targetname", strName);
	
		red = 255;
		green = 255;
		blue = 0;
		alpha = 100;
	
		char strGlowColor[18];
		Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", red, green, blue, alpha);
	
		int ent = CreateEntityByName("tf_glow");
		if(IsValidEntity(ent))
		{
			DispatchKeyValue(ent, "targetname", "RainbowGlow");
			DispatchKeyValue(ent, "target", strName);
			DispatchKeyValue(ent, "Mode", "0");
			DispatchKeyValue(ent, "GlowColor", strGlowColor);
			DispatchSpawn(ent);
	
			AcceptEntityInput(ent, "Enable");
			return ent;
		}
	}
	return -1;
}

stock bool TF2_HasGlow(int iEnt)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt)
		{
			return true;
		}
	}
	return false;
}

public void OnPluginEnd()
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		char strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		if(StrEqual(strName, "RainbowGlow"))
		{
			AcceptEntityInput(index, "Kill");
		}
	}
}
//---------------------------------

//Stock------------------------------
stock bool IsValidClient(int client) 
{ 
    if(client <= 0 ) return false; 
    if(client > MaxClients) return false; 
    if(!IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
}

int IsValidWeapon(int iEntity) //Return Weapon Index
{
	if(IsValidEntity(iEntity))
	{
		char szModel[100];
		GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
		if (StrContains(szModel, "models/weapons/w_models/", false) != -1)
		{
			if(StrEqual(szModel, "models/weapons/w_models/w_bat.mdl"))					return 0; //Scout 
			else if(StrEqual(szModel, "models/weapons/w_models/w_bonesaw.mdl")) 		return 8; //Medic
			else if(StrEqual(szModel, "models/weapons/w_models/w_bottle.mdl")) 			return 1; //Demo
			else if(StrEqual(szModel, "models/weapons/w_models/w_pistol.mdl")) 			return 22; //Engin
			else if(StrEqual(szModel, "models/weapons/w_models/w_fireaxe.mdl")) 		return 2; //Pyro
			else if(StrEqual(szModel, "models/weapons/w_models/w_frontierjustice.mdl")) return 141; //Engin
			else if(StrEqual(szModel, "models/weapons/w_models/w_grenadelauncher.mdl")) return 19; //Demo
			else if(StrEqual(szModel, "models/weapons/w_models/w_knife.mdl")) 			return 4; //Spy
			else if(StrEqual(szModel, "models/weapons/w_models/w_minigun.mdl")) 		return 15; //Heavy
			else if(StrEqual(szModel, "models/weapons/w_models/w_revolver.mdl")) 		return 24; //Spy
			else if(StrEqual(szModel, "models/weapons/w_models/w_rocketlauncher.mdl")) 	return 18; //Soldier
			else if(StrEqual(szModel, "models/weapons/w_models/w_sapper.mdl")) 			return 735; //Spy
			else if(StrEqual(szModel, "models/weapons/w_models/w_scattergun.mdl")) 		return 13; //Scout
			else if(StrEqual(szModel, "models/weapons/w_models/w_sd_sapper.mdl")) 		return 810; //Spy
			else if(StrEqual(szModel, "models/weapons/w_models/w_shotgun.mdl")) 		return 199; //10, 199
			else if(StrEqual(szModel, "models/weapons/w_models/w_shovel.mdl")) 			return 6; //Soldier
			else if(StrEqual(szModel, "models/weapons/w_models/w_smg.mdl")) 			return 16; //Sniper
			else if(StrEqual(szModel, "models/weapons/w_models/w_sniperrifle.mdl")) 	return 14; //Sniper
			else if(StrEqual(szModel, "models/weapons/w_models/w_stickybomb_launcher.mdl")) return 20; //Demo
			else if(StrEqual(szModel, "models/weapons/w_models/w_syringegun.mdl")) 		return 17; //Medic
			else if(StrEqual(szModel, "models/weapons/w_models/w_ttg_max_gun.mdl"))		return 294; //Scout    Lugermorph lol
			else if(StrEqual(szModel, "models/weapons/w_models/w_wrangler.mdl")) 		return 140; //Engin
			else if(StrEqual(szModel, "models/weapons/w_models/w_wrench.mdl")) 			return 7; //Engin	
			else if(StrEqual(szModel, "models/weapons/w_models/w_medigun.mdl"))			return 29; //Medic
			//case ("models/weapons/w_models/w_builder.mdl"): 		return 28; //Engin
			//case ("models/weapons/w_models/w_cigarette_case.mdl"):	return ; //Spy
			//case ("models/weapons/w_models/w_pda_engineer.mdl"): 	return 25; //Engin
		}
	}
	return -1;
}