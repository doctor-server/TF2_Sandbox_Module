#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "4.6"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <build>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] SandBox - Elevator", 
	author = PLUGIN_AUTHOR, 
	description = "Elevator on Sandbox", 
	version = PLUGIN_VERSION, 
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

#define SOUND_START "items/cart_rolling_start.wav"
#define SOUND_STOP "items/cart_rolling_stop.wav"
#define SOUND_STOPHORN "misc/hologram_stop.wav"
#define MODEL_ELEVATORGROUND "models/props_trainyard/crane_platform001.mdl"
#define MODEL_ELEVATORBODY "models/props_lab/freightelevator.mdl"

int g_iElevatorIndex[MAXPLAYERS + 1][2];
int g_iElevatorAction[MAXPLAYERS + 1];

float g_fElevatorLowest[MAXPLAYERS + 1];
float g_fElevatorHighest[MAXPLAYERS + 1];

bool g_bElevatorAuto[MAXPLAYERS + 1];
int g_iElevatorAutoAction[MAXPLAYERS + 1];

int g_iCoolDown[MAXPLAYERS + 1] = 0;

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_elevator_ver", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	RegAdminCmd("sm_sbelevator", Command_ElevatorMenu, 0, "Build Elevator!");
	RegAdminCmd("sm_sblift", Command_ElevatorMenu, 0, "Build Elevator!");
}

public void OnMapStart()
{
	PrecacheSound(SOUND_START);
	PrecacheSound(SOUND_STOP);
	PrecacheSound(SOUND_STOPHORN);
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		g_iElevatorIndex[i][0] = -1;
		g_iElevatorIndex[i][1] = -1;
	}
	TagsCheck("SandBox_Addons");
}

public void OnConfigsExecuted()
{
	TagsCheck("SandBox_Addons");
}

public void OnClientPutInServer(int client)
{
	g_iElevatorIndex[client][0] = -1;
	g_iElevatorIndex[client][1] = -1;

	g_iElevatorAction[client] = -1;
	g_bElevatorAuto[client] = false;
	g_iElevatorAutoAction[client] = -1;
	
	g_iCoolDown[client] = 0;
}

public void OnClientDisconnect(int client)
{
	g_iElevatorIndex[client][0] = -1;
	g_iElevatorIndex[client][1] = -1;
	
	g_iElevatorAction[client] = -1;
	g_bElevatorAuto[client] = false;
	g_iElevatorAutoAction[client] = -1;
}

public Action Command_ElevatorMenu(int client, int args) //HackMenu
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_ElevatorMenu);
	
	Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Elevator Control Panel v%s\n Highest: %f\n Lowest: %f", PLUGIN_VERSION, g_fElevatorHighest[client], g_fElevatorLowest[client]);
	menu.SetTitle(menuinfo);
	
	if (IsValidEntity(g_iElevatorIndex[client][0]) && !g_bElevatorAuto[client])
	{
		Format(menuinfo, sizeof(menuinfo), " Delete the Elevator", client);
		menu.AddItem("DELETE", menuinfo);
		Format(menuinfo, sizeof(menuinfo), " Set Current position as highest position", client);
		menu.AddItem("SETHIGHEST", menuinfo);
		Format(menuinfo, sizeof(menuinfo), " Set Current position as lowest position", client);
		menu.AddItem("SETLOWEST", menuinfo);
		Format(menuinfo, sizeof(menuinfo), " Go Up", client);
		menu.AddItem("UP", menuinfo);
		Format(menuinfo, sizeof(menuinfo), " Go Down", client);
		menu.AddItem("DOWN", menuinfo);
		Format(menuinfo, sizeof(menuinfo), " Stop", client);
		menu.AddItem("STOP", menuinfo);
	}
	else
	{
		if(g_bElevatorAuto[client])
		{
			Format(menuinfo, sizeof(menuinfo), " Delete the Elevator", client);
			menu.AddItem("BUILD", menuinfo, ITEMDRAW_DISABLED);
		}
		else 
		{	
			Format(menuinfo, sizeof(menuinfo), " Spawn a Elevator", client);
			menu.AddItem("BUILD", menuinfo);
		}
		Format(menuinfo, sizeof(menuinfo), " Set Current Elevator position as highest position", client);
		menu.AddItem("SETHIGHEST", menuinfo, ITEMDRAW_DISABLED);
		Format(menuinfo, sizeof(menuinfo), " Set Current Elevator position as lowest position", client);
		menu.AddItem("SETLOWEST", menuinfo, ITEMDRAW_DISABLED);
		Format(menuinfo, sizeof(menuinfo), " Go Up", client);
		menu.AddItem("UP", menuinfo, ITEMDRAW_DISABLED);
		Format(menuinfo, sizeof(menuinfo), " Go Down", client);
		menu.AddItem("DOWN", menuinfo, ITEMDRAW_DISABLED);
		Format(menuinfo, sizeof(menuinfo), " Stop", client);
		menu.AddItem("STOP", menuinfo, ITEMDRAW_DISABLED);
	}
	
	if(IsValidEntity(g_iElevatorIndex[client][0]))
	{
		Format(menuinfo, sizeof(menuinfo), " Automatic move", client);
		if(g_bElevatorAuto[client])	Format(menuinfo, sizeof(menuinfo), " Automatic move: ON", client);
		else Format(menuinfo, sizeof(menuinfo), " Automatic move: OFF", client);
		menu.AddItem("AUTO", menuinfo);
 	}
	else
	{
		Format(menuinfo, sizeof(menuinfo), " Automatic move: OFF", client);
		menu.AddItem("AUTO", menuinfo, ITEMDRAW_DISABLED);
	}
	
	menu.ExitBackButton = false;
	menu.ExitButton = true;
	menu.Display(client, -1);
	return Plugin_Handled;
}

public int Handler_ElevatorMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (StrEqual(info, "BUILD"))
		{
			if(g_iCoolDown[client] == 0)
			{
				float fAimPos[3];
				if (GetAimOrigin(client, fAimPos))
				{
					g_fElevatorHighest[client] = 999999.0;
					g_fElevatorLowest[client] = -999999.0;
					g_iElevatorAction[client] = 0;
					g_bElevatorAuto[client] = false;
					g_iElevatorIndex[client][0] = BuildElevator(client, fAimPos);
					
					g_iCoolDown[client] = 1;
					CreateTimer(0.05, Timer_CoolDownFunction, client);
				}
			}
			else
			{
				Build_PrintToChat(client, "Elevator build Function is currently cooling down, please wait \x04%i\x01 seconds.", g_iCoolDown[client]);
			}
		}
		else if (StrEqual(info, "DELETE"))
		{	
			if (IsValidEntity(g_iElevatorIndex[client][0]))
			{
				if (IsValidEntity(g_iElevatorIndex[client][0])) AcceptEntityInput(g_iElevatorIndex[client][0], "kill");
				if (IsValidEntity(g_iElevatorIndex[client][1]))  AcceptEntityInput(g_iElevatorIndex[client][1], "kill");
				g_iElevatorIndex[client][0] = -1;
				g_iElevatorIndex[client][1] = -1;
				g_iElevatorAction[client] = -1;
				g_fElevatorHighest[client] = 999999.0;
				g_fElevatorLowest[client] = -999999.0;
				g_iElevatorAction[client] = 0;
				g_bElevatorAuto[client] = false;
				Build_SetLimit(client, -1);
			}		
		}
		else if (IsValidEntity(g_iElevatorIndex[client][0]))
		{
			if (StrEqual(info, "SETLOWEST"))
			{
				float fOrigin[3];
				GetEntPropVector(g_iElevatorIndex[client][0], Prop_Send, "m_vecOrigin", fOrigin);
				if(fOrigin[2] < g_fElevatorHighest[client])
				{
					g_fElevatorLowest[client] = fOrigin[2];
				}
				else
				{
					PrintCenterText(client, "Error! You can NOT set the position higher than the highest position as Lowest position!");
				}
			}
			else if (StrEqual(info, "SETHIGHEST"))
			{
				float fOrigin[3];
				GetEntPropVector(g_iElevatorIndex[client][0], Prop_Send, "m_vecOrigin", fOrigin);
				if(fOrigin[2] > g_fElevatorLowest[client])
				{
					g_fElevatorHighest[client] = fOrigin[2];
				}
				else
				{
					PrintCenterText(client, "Error! You can NOT set the position lower than the lowest position as Lowest position!");
				}
			}
			else if (StrEqual(info, "UP"))		g_iElevatorAction[client] = 1;
			else if (StrEqual(info, "DOWN"))	g_iElevatorAction[client] = 2;
			else if (StrEqual(info, "STOP"))	g_iElevatorAction[client] = 0;
			else if (StrEqual(info, "AUTO"))
			{
				if(g_bElevatorAuto[client]) g_bElevatorAuto[client] = false;
				else	
				{
					g_bElevatorAuto[client] = true;
					g_iElevatorAutoAction[client] = 0;
					CreateTimer(5.0, Timer_ElevatorAction, client);
				}
			}	
		}			
		Command_ElevatorMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)//@
{
	if(IsValidClient(client))
	{
		if(IsValidEntity(g_iElevatorIndex[client][0]))
		{
			//float fSize = GetEntPropFloat(g_iElevatorIndex[client][0], Prop_Send, "m_flModelScale");
			char szModel[255];
			GetEntPropString(g_iElevatorIndex[client][0], Prop_Data, "m_ModelName", szModel, sizeof(szModel));
			
			if(StrEqual(szModel, "models/props_trainyard/crane_platform001.mdl"))// && fSize == 0.435314)
			{
				float fOrigin[3];
				GetEntPropVector(g_iElevatorIndex[client][0], Prop_Send, "m_vecOrigin", fOrigin);
				if(g_bElevatorAuto[client])
				{
					if((g_fElevatorHighest[client] <= fOrigin[2] && g_iElevatorAutoAction[client] == 1) || (g_fElevatorLowest[client] <= fOrigin[2]) && g_iElevatorAutoAction[client] == 3) //Down
					{
						g_iElevatorAutoAction[client] = 3;
						fOrigin[2] -= 2.0;
						TeleportEntity(g_iElevatorIndex[client][0], fOrigin, NULL_VECTOR, NULL_VECTOR);
						EmitSoundToAll(SOUND_START, g_iElevatorIndex[client][0], SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.15);
						
						if (g_fElevatorLowest[client] >= fOrigin[2])
						{
							g_iElevatorAutoAction[client] = 0;
							CreateTimer(10.0, Timer_ElevatorAction, client);
						}
					}
					else if((g_fElevatorLowest[client] >= fOrigin[2] && g_iElevatorAutoAction[client] == 1) || (g_fElevatorHighest[client] >= fOrigin[2]) && g_iElevatorAutoAction[client] == 2) //UP
					{
						g_iElevatorAutoAction[client] = 2;
						fOrigin[2] += 2.0;
						TeleportEntity(g_iElevatorIndex[client][0], fOrigin, NULL_VECTOR, NULL_VECTOR);
						EmitSoundToAll(SOUND_START, g_iElevatorIndex[client][0], SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.15);
						
						if (g_fElevatorHighest[client] <= fOrigin[2])
						{
							g_iElevatorAutoAction[client] = 0;
							CreateTimer(10.0, Timer_ElevatorAction, client);
						}
					}
					else if(g_iElevatorAutoAction[client] == 0)
					{
						DamageDoor(g_iElevatorIndex[client][0], client);
						EmitSoundToAll(SOUND_STOP, g_iElevatorIndex[client][0], SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
						EmitSoundToAll(SOUND_STOPHORN, g_iElevatorIndex[client][0], SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);		
						g_iElevatorAutoAction[client] = -1;
					}
					//PrintCenterText(client, "Value: %i", g_iElevatorAutoAction[client]); //DeBug -1 = waiting, 0 = stop, 1 = Ready move, 2 = UP 3 = Down
				}
				else if(g_iElevatorAction[client] == 1 && g_fElevatorHighest[client] >= fOrigin[2])
				{
					fOrigin[2] += 2.0;
					TeleportEntity(g_iElevatorIndex[client][0], fOrigin, NULL_VECTOR, NULL_VECTOR);
					EmitSoundToAll(SOUND_START, g_iElevatorIndex[client][0], SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.15);
				}
				else if(g_iElevatorAction[client] == 2 && g_fElevatorLowest[client] <= fOrigin[2])
				{
					fOrigin[2] -= 2.0;
					TeleportEntity(g_iElevatorIndex[client][0], fOrigin, NULL_VECTOR, NULL_VECTOR);
					EmitSoundToAll(SOUND_START, g_iElevatorIndex[client][0], SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.15);
				}
				else if((g_iElevatorAction[client] == 0 || g_fElevatorHighest[client] >= fOrigin[2] || g_fElevatorLowest[client] <= fOrigin[2]) && g_iElevatorAction[client] != -1)
				{
					DamageDoor(g_iElevatorIndex[client][0], client);
					EmitSoundToAll(SOUND_STOP, g_iElevatorIndex[client][0], SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
					EmitSoundToAll(SOUND_STOPHORN, g_iElevatorIndex[client][0], SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);			
					g_iElevatorAction[client] = -1;
				}
			}
			else
			{
				if(IsValidEntity(g_iElevatorIndex[client][1])) AcceptEntityInput(g_iElevatorIndex[client][1], "kill");
				g_iElevatorIndex[client][1] = -1;
				if(IsValidEntity(g_iElevatorIndex[client][0])) AcceptEntityInput(g_iElevatorIndex[client][0], "kill");
				g_iElevatorIndex[client][0] = -1;
			}
		}
		else if(g_iElevatorIndex[client][0] != -1)	
		{
			if(IsValidEntity(g_iElevatorIndex[client][1])) AcceptEntityInput(g_iElevatorIndex[client][1], "kill");
			g_bElevatorAuto[client] = false;
			g_iElevatorIndex[client][1] = -1;
			g_iElevatorIndex[client][0] = -1;
		}
		
		if (IsPlayerAlive(client) && GetEntityMoveType(client) != MOVETYPE_NOCLIP && IsPlayerStuckInEnt(client))
		{
			float iPosition[3];
			GetClientAbsOrigin(client, iPosition);
			iPosition[2] += 5.0;
			TeleportEntity(client, iPosition, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public Action Timer_ElevatorAction(Handle timer, int client)
{
	g_iElevatorAutoAction[client] = 1;
}

public Action Timer_CoolDownFunction(Handle timer, int client)
{
	g_iCoolDown[client] -= 1;
	
	if (g_iCoolDown[client] >= 1)	CreateTimer(1.0, Timer_CoolDownFunction, client);
	else	g_iCoolDown[client] = 0;
}


//Stock
stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}

stock bool GetAimOrigin(int client, float hOrigin[3])
{
	float vAngles[3], fOrigin[3];
	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(fOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(hOrigin, trace);
		CloseHandle(trace);
		return true;
	}
	
	CloseHandle(trace);
	return false;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > GetMaxClients();
}

int BuildElevator(int iBuilder, float fOrigin[3])
{
	int iElevatorBody = CreateEntityByName("prop_dynamic_override");//CreateEntityByName("prop_dynamic_override");
	if (iElevatorBody > MaxClients && IsValidEntity(iElevatorBody))
	{
		SetEntProp(iElevatorBody, Prop_Send, "m_nSolidType", 6);
		SetEntProp(iElevatorBody, Prop_Data, "m_nSolidType", 6);
		
		if (!IsModelPrecached(MODEL_ELEVATORBODY))
			PrecacheModel(MODEL_ELEVATORBODY);
		
		SetEntityModel(iElevatorBody, MODEL_ELEVATORBODY);
		
		TeleportEntity(iElevatorBody, fOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iElevatorBody);
	}
	
	int iElevator = CreateEntityByName("prop_dynamic_override");
	if (iElevator > MaxClients && IsValidEntity(iElevator))
	{
		SetEntProp(iElevator, Prop_Send, "m_nSolidType", 6);
		SetEntProp(iElevator, Prop_Data, "m_nSolidType", 6);
		SetEntPropFloat(iElevator, Prop_Send, "m_flModelScale", 0.435314);  
		Build_RegisterEntityOwner(iElevator, iBuilder);
		
		if (!IsModelPrecached(MODEL_ELEVATORGROUND))
			PrecacheModel(MODEL_ELEVATORGROUND);
		
		SetEntityModel(iElevator, MODEL_ELEVATORGROUND);
		
		TeleportEntity(iElevator, fOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iElevator);
				
		char Buffer[64];
		Format(Buffer, sizeof(Buffer), "Entity%d", iElevator);
		DispatchKeyValue(iElevator, "targetname", Buffer);
		SetVariantString(Buffer);
		AcceptEntityInput(iElevatorBody, "SetParent");
	}
	
	if(Build_ReturnEntityOwner(iElevator) != iBuilder)
	{
		if(IsValidEntity(iElevator))	AcceptEntityInput(iElevator, "kill");
		if(IsValidEntity(iElevatorBody))	AcceptEntityInput(iElevatorBody, "kill");
		Build_PrintToChat(iBuilder, "Fail to build elevator.");
		return -1;
	}	
	else
		Build_PrintToChat(iBuilder, "The elevator built.");
		
	g_iElevatorIndex[iBuilder][1] = iElevatorBody;
	return iElevator;
}

stock bool IsPlayerStuckInEnt(int client)
{
	float vecMin[3], vecMax[3], vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	
	GetClientAbsOrigin(client, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_ALL, TraceRayHitOnlyEnt);
	return TR_DidHit();
}

public bool TraceRayHitOnlyEnt(int entity, int contentsMask)
{
	if (IsValidEntity(entity) && GetEntProp(entity, Prop_Data, "m_CollisionGroup", 4) != 2)
	{
		char szClass[64];
		GetEdictClassname(entity, szClass, sizeof(szClass));
		if ((StrContains(szClass, "prop_dynamic") >= 0 || StrContains(szClass, "prop_physics") >= 0) && !StrEqual(szClass, "prop_ragdoll"))
		{
			char szModel[64];
			GetEntPropString(entity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
			//float fSize = GetEntPropFloat(i, Prop_Send, "m_flModelScale");
			if(StrEqual(szModel, "models/props_trainyard/crane_platform001.mdl"))// && fSize == 0.43)
				return true;
		}
	}
	return false;
}

void TagsCheck(const char[] tag) //TF2Stat.sp
{
	Handle hTags = FindConVar("sv_tags");
	char tags[255];
	GetConVarString(hTags, tags, sizeof(tags));

	if (!(StrContains(tags, tag, false)>-1))
	{
		char newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		SetConVarString(hTags, newTags);
		GetConVarString(hTags, tags, sizeof(tags));
	}
	CloseHandle(hTags);
}

void DamageDoor(int iElevator, int client)
{
	if(IsValidEntity(iElevator))
	{
		float fPos[3], fPosDoor[3];
		GetEntPropVector(iElevator, Prop_Send, "m_vecOrigin", fPos);

		int ent = -1;
		while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)
   		{
   			if (IsPropDoor(ent))
   			{
   				GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fPosDoor);
   				if(GetVectorDistance(fPos, fPosDoor) < 90.0)
   				{
   					SDKHooks_TakeDamage(ent, client, client, 0.01, DMG_BLAST);
   				}
   			}
   		}
   	}
}

bool IsPropDoor(int iEntity) 
{
	if(IsValidEntity(iEntity))
	{
		char szModel[64];
		GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
		if(StrEqual(szModel, "models/combine_gate_citizen.mdl") 
		||	StrEqual(szModel, "models/combine_gate_Vehicle.mdl") 
		||	StrEqual(szModel, "models/props_doors/doorKLab01.mdl") 
		|| StrEqual(szModel, "models/props_lab/elevatordoor.mdl") 
		||  StrEqual(szModel, "models/props_lab/RavenDoor.mdl")
		||  StrEqual(szModel, "models/props_lab/blastdoor001c.mdl"))	
			return true;
	}
	return false;
}
