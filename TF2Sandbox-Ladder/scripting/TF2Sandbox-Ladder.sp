/***************
Credits
https://forums.alliedmods.net/showthread.php?t=190625

( Moosehead ): https://forums.alliedmods.net/member.php?u=45690

****************/
#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.0"
#define SOUND_STEP	"player/footsteps/concrete4.wav"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <build>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] SandBox - Ladder", 
	author = PLUGIN_AUTHOR, 
	description = "Ladder on Sandbox", 
	version = PLUGIN_VERSION, 
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

Handle g_hEnabled;
float lastZ[MAXPLAYERS + 1];
int iTouching[MAXPLAYERS + 1];
bool soundCooldown[MAXPLAYERS + 1];

public void OnPluginStart()
{
	HookEvent("player_spawn", OnPlayerSpawn);
	
	CreateConVar("sm_tf2sb_ladder_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	RegAdminCmd("sm_ladder", Command_Ladder, 0, "Build Ladder!");
	g_hEnabled = CreateConVar("sm_tf2sb_ladder", "1", "Enable the Ladder plugin?", 0, true, 0.0, true, 1.0);
	
	//HookEntityOutput("trigger_multiple", "OnStartTouch", StartTouchTrigger);
	//HookEntityOutput("trigger_multiple", "OnEndTouch", EndTouchTrigger);
}

public Action OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	iTouching[client] = 0;
}

public void OnMapStart()
{
	PrecacheSound(SOUND_STEP, true);
	
	char szClass[64];
	for (int i = MaxClients; i < MAX_HOOK_ENTITIES; i++)if (IsValidEdict(i))
	{
		GetEdictClassname(i, szClass, sizeof(szClass));
		if (StrContains(szClass, "prop_dynamic") >= 0)
		{
			char szModel[100];
			GetEntPropString(i, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
			if (StrEqual(szModel, "models/props_2fort/ladder001.mdl"))
			{
				//Function
				SDKHook(i, SDKHook_StartTouch, OnStartTouch);
			}
		}
	}
}

public Action Command_Ladder(int client, int args)
{
	if (!GetConVarBool(g_hEnabled) || !IsValidClient(client))
		return;
	
	if (GetClientSpawnedEntities(client) >= GetClientMaxHoldEntities())
	{
		ClientCommand(client, "playgamesound \"%s\"", "buttons/button10.wav");
		Build_PrintToChat(client, "You've hit the prop limit!");
		PrintCenterText(client, "You've hit the prop limit!");
		return;
	}
	
	float fAimPos[3];
	if (GetAimOrigin(client, fAimPos))
	{
		BuildLadder(client, fAimPos);
		Build_PrintToChat(client, "The ladder Built.");
	}
	else
	{
		Build_PrintToChat(client, "Fail to build Ladder.");
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (IsValidEdict(entity))
	{
		if ((StrContains(classname, "prop_dynamic") >= 0))
		{
			CreateTimer(0.1, Timer_LadderSpawn, entity);
		}
	}
}

public Action Timer_LadderSpawn(Handle timer, int entity)
{
	char szModel[100];
	GetEntPropString(entity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	if (StrEqual(szModel, "models/props_2fort/ladder001.mdl"))
	{
		//Function
		SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
	}
}

/*
public void StartTouchTrigger(const char[] name, int entity, int client, float delay)
{
	char szModel[100];
	GetEntPropString(entity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	
	if (StrEqual(szModel, "models/props_2fort/ladder001.mdl")) 
	{
		iTouching[client]++;
		if (iTouching[client] == 1) 
		{
			MountLadder(client);
		}
	}
}

public void EndTouchTrigger(const char[] name, int entity, int client, float delay)
{
	char szModel[100];
	GetEntPropString(entity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	
	if (StrEqual(szModel, "models/props_2fort/ladder001.mdl")) 
	{
		iTouching[client]--;
		if (iTouching[client] <= 0) 
		{
			DismountLadder(client);
		}
	}
}

void MountLadder(int client)
{
	SetEntityGravity(client, 0.001);
	SDKHook(client, SDKHook_PreThink, MoveOnLadder);
}

void DismountLadder(int client)
{
	SetEntityGravity(client, 1.0);
	SDKUnhook(client, SDKHook_PreThink, MoveOnLadder);
}
*/

public Action OnStartTouch(int entity, int client)
{
	if (IsValidEdict(entity))
	{
		if (IsValidClient(client))
		{
			SDKHook(entity, SDKHook_Touch, OnTouch);
			SDKHook(entity, SDKHook_EndTouch, OnEndTouch);
		}
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action OnEndTouch(int entity, int client)
{
	iTouching[client]--;
	//PrintToChat(client, "endtouch %i", iTouching[client]);
	if (iTouching[client] <= 0)
	{
		SetEntityGravity(client, 1.0);
		SDKUnhook(client, SDKHook_PreThink, MoveOnLadder);
	}
	SDKUnhook(entity, SDKHook_EndTouch, OnEndTouch);
	return Plugin_Handled;
}

public Action OnTouch(int entity, int client)
{
	float vOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);
	
	float vAngles[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TEF_ExcludeEntity, entity);
	
	if (!TR_DidHit(trace))
	{
		CloseHandle(trace);
		return Plugin_Continue;
	}
	else
	{
		iTouching[client]++;
		//PrintToChat(client, "touch %i", iTouching[client]);
		if (iTouching[client] == 1)
		{
			SetEntityGravity(client, 0.001);
			SDKHook(client, SDKHook_PreThink, MoveOnLadder);
		}
	}
	
	CloseHandle(trace);
	
	SDKUnhook(entity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}

public bool TEF_ExcludeEntity(int entity, int contentsMask, any data)
{
	return (entity != data);
}

public void MoveOnLadder(int client)
{
	float speed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	
	int buttons;
	buttons = GetClientButtons(client);
	
	float origin[3];
	GetClientAbsOrigin(client, origin);
	
	bool movingUp = (origin[2] > lastZ[client]);
	lastZ[client] = origin[2];
	
	float angles[3];
	GetClientEyeAngles(client, angles);
	
	float velocity[3];
	
	if (buttons & IN_FORWARD || buttons & IN_JUMP) {
		velocity[0] = speed * Cosine(DegToRad(angles[1]));
		velocity[1] = speed * Sine(DegToRad(angles[1]));
		velocity[2] = -1 * speed * Sine(DegToRad(angles[0]));
		
		if (!movingUp && angles[0] < -25.0 && velocity[2] > 0 && velocity[2] < 250.0) {
			velocity[2] = 251.0;
		}
		PlayClimbSound(client);
	} else if (buttons & IN_MOVELEFT) {
		velocity[0] = speed * Cosine(DegToRad(angles[1] + 45));
		velocity[1] = speed * Sine(DegToRad(angles[1] + 45));
		velocity[2] = -1 * speed * Sine(DegToRad(angles[0]));
		PlayClimbSound(client);
	} else if (buttons & IN_MOVERIGHT) {
		velocity[0] = speed * Cosine(DegToRad(angles[1] - 45));
		velocity[1] = speed * Sine(DegToRad(angles[1] - 45));
		velocity[2] = -1 * speed * Sine(DegToRad(angles[0]));
		PlayClimbSound(client);
	} else if (buttons & IN_BACK) {
		velocity[0] = -1 * speed * Cosine(DegToRad(angles[1]));
		velocity[1] = -1 * speed * Sine(DegToRad(angles[1]));
		velocity[2] = speed * Sine(DegToRad(angles[0]));
		PlayClimbSound(client);
	} else if (buttons & IN_DUCK) {
		velocity[0] = 0.0;
		velocity[1] = 0.0;
		velocity[2] = 0.0;
	} else if (buttons & IN_DUCK) {
		velocity[0] = 0.0;
		velocity[1] = 0.0;
		velocity[2] = 0.0;
	}
	
	TeleportEntity(client, origin, NULL_VECTOR, velocity);
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

int BuildLadder(int iBuilder, float fOrigin[3])
{
	char szModel[100];
	strcopy(szModel, sizeof(szModel), "models/props_2fort/ladder001.mdl");
	
	int iLadder = CreateEntityByName("prop_dynamic_override");
	if (iLadder > MaxClients && IsValidEntity(iLadder))
	{
		SetEntProp(iLadder, Prop_Send, "m_nSolidType", 6);
		SetEntProp(iLadder, Prop_Data, "m_nSolidType", 6);
		Build_RegisterEntityOwner(iLadder, iBuilder);
		
		if (!IsModelPrecached(szModel))
			PrecacheModel(szModel);
		
		SetEntityModel(iLadder, szModel);
		
		TeleportEntity(iLadder, fOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iLadder);
		
		return iLadder;
	}
	return 0;
}

void PlayClimbSound(int client)
{
	if (!soundCooldown[client])
	{
		EmitSoundToClient(client, SOUND_STEP);
		
		soundCooldown[client] = true;
		CreateTimer(0.35, Timer_Cooldown, client);
	}
}

public Action Timer_Cooldown(Handle timer, any client)
{
	soundCooldown[client] = false;
}

int GetClientSpawnedEntities(int client)
{
	char szClass[32];
	int iCount = 0;
	for (int i = MaxClients; i < MAX_HOOK_ENTITIES; i++)if (IsValidEdict(i))
	{
		GetEdictClassname(i, szClass, sizeof(szClass));
		if ((StrContains(szClass, "prop_dynamic") >= 0 || StrContains(szClass, "prop_physics") >= 0) && !StrEqual(szClass, "prop_ragdoll") && Build_ReturnEntityOwner(i) == client)
			iCount++;
	}
	return iCount;
}

int GetClientMaxHoldEntities()
{
	Handle iMax = FindConVar("sbox_maxpropsperplayer");
	return GetConVarInt(iMax);
} 