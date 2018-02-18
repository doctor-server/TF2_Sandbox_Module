#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "2.7"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <vphysics>
#include <build>
#include <tf2_stocks>
#include <tf2items_giveweapon>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] SandBox - PhysicsGun V2 + Door Fix",
	author = PLUGIN_AUTHOR,
	description = "Another PhysicsGun plugin for Tf2Sandbox",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

#define MODEL_PHYSICSGUN "models/weapons/w_physics.mdl"
#define MODEL_PHYSICSLASER "materials/sprites/physbeam.vmt"
#define MODEL_PHYSICSLASER2 "materials/sprites/laserbeam.vmt"
#define MODEL_HALOINDEX "materials/sprites/halo01.vmt"
#define MODEL_BLUEGLOW "materials/sprites/blueglow2.vmt"
#define MODEL_REDGLOW "materials/sprites/redglow2.vmt"
#define SOUND_PICKUP "weapons/physcannon/physcannon_pickup.wav"
#define SOUND_DROP "weapons/physcannon/physcannon_drop.wav"
#define SOUND_LOOP "weapons/physcannon/hold_loop.wav"

int g_iPhysicGunIndex = 66666;
int g_iPhysicGunWeaponIndex = 129;

Handle g_cvGrabOtherProp;
Handle g_cvPhysics;
Handle g_cvGrabPlayer;
Handle g_hHud;

int g_ModelIndex;
int g_ModelIndex2;
int g_HaloIndex;
int g_iBlueGlow;
int g_iRedGlow;

int g_iGrabbingEntity[MAXPLAYERS + 1][3]; //0. Entity, 1. Glow entity index, 2
float g_fGrabbingDistance[MAXPLAYERS + 1]; //MaxDistance
float g_fGrabbingDifference[MAXPLAYERS + 1][3]; //Difference
bool g_bGrabbingAttack2[MAXPLAYERS + 1];

public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_pg_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	g_cvGrabOtherProp = CreateConVar("sm_tf2sb_pg_grabothers", "0", "0 - Can Not grab others props, 1 - Can grab other props(Admin Only), 2 - Everyone can grab other props", 0, true, 0.0, true, 2.0);
	g_cvPhysics = CreateConVar("sm_tf2sb_pg_enablephysics", "1", "0 - Disable Physics function, 1 - Enable Physics function(Admin Only)", 0, true, 0.0, true, 1.0);
	g_cvGrabPlayer = CreateConVar("sm_tf2sb_pg_enablegrabplayer", "1", "0 - Disable Grab Player, 1 - Enable Grab Player(Admin Only), 2 - Everyone can Grab Player(Dangerous!)", 0, true, 0.0, true, 2.0);
	
	RegAdminCmd("sm_sbpg", Command_EquipPhysicsGun, 0, "Equip PhysicsGun!");
	RegAdminCmd("sm_p", Command_EquipPhysicsGun, 0, "Equip PhysicsGun!");
	RegAdminCmd("sm_physicsgun", Command_EquipPhysicsGun, 0, "Equip PhysicsGun!");
	
	g_hHud = CreateHudSynchronizer();
}

public Action Command_EquipPhysicsGun(int client, int args) //Give PhysicsGun v2 to client
{
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		int iWeapon = GetPlayerWeaponSlot(client, 1);
		if(IsValidEntity(iWeapon)) SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, 1));
		
		if(!TF2Items_CheckWeapon(g_iPhysicGunIndex))
		{
			TF2Items_CreateWeapon(g_iPhysicGunIndex, "tf_weapon_builder", g_iPhysicGunWeaponIndex, 1, 9, 99, "", -1, MODEL_PHYSICSGUN, true);
		}
		
		int PhysicsGun = TF2Items_GiveWeapon(client, g_iPhysicGunIndex);
		if(IsValidEntity(PhysicsGun))
		{
			SetEntProp(PhysicsGun, Prop_Send, "m_nSkin", 1); //1 = PhysicsGun 0 = GravityGun
		}
		Build_PrintToChat(client, "You have equip a Physics Gun v2!");
		Build_PrintToChat(client, "Your Physics Gun will be in the Secondary Slot.");
		SendDialogToOne(client, 240, 248, 255, "You have equip a Physics Gun v2!");	
	}
}

//-----[ Start and End ]---------------------------(
public void OnMapStart() //Precache Sound and Model
{
	g_ModelIndex = PrecacheModel(MODEL_PHYSICSLASER);
	g_HaloIndex = PrecacheModel(MODEL_HALOINDEX);
	g_iBlueGlow = PrecacheModel(MODEL_BLUEGLOW);
	g_iRedGlow = PrecacheModel(MODEL_REDGLOW);
	g_ModelIndex2 = PrecacheModel(MODEL_PHYSICSLASER2);
	PrecacheSound(SOUND_PICKUP);
	PrecacheSound(SOUND_DROP);
	PrecacheSound(SOUND_LOOP);
	
	TagsCheck("SandBox_Addons");
	CreateTimer(15.0, Timer_CreateWeapon, 0);
	
	for (int i = 1; i < MAXPLAYERS; i++)
	{
		g_iGrabbingEntity[i][0] = -1; //Grab entity
		g_iGrabbingEntity[i][1] = -1; //tf_glow
	}
}

public Action Timer_CreateWeapon(Handle timer, int client)
{
	PrecacheModel(MODEL_PHYSICSGUN);
	//if(!TF2Items_CheckWeapon(g_iPhysicGunIndex))
	TF2Items_CreateWeapon(g_iPhysicGunIndex, "tf_weapon_builder", g_iPhysicGunWeaponIndex, 1, 9, 99, "", -1, MODEL_PHYSICSGUN, true); //tf_weapon_shotgun  tf_weapon_builder
}

public void OnConfigsExecuted()
{
	TagsCheck("SandBox_Addons");	
}

public void OnClientPutInServer(int client)
{
	ResetClientAttribute(client);
	g_iGrabbingEntity[client][0] = -1; //Grab entity
	g_iGrabbingEntity[client][1] = -1; //tf_glow
	g_iGrabbingEntity[client][2] = -1;
	g_fGrabbingDistance[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	ResetClientAttribute(client);
	g_iGrabbingEntity[client][0] = -1; //Grab entity
	g_iGrabbingEntity[client][1] = -1; //tf_glow
	g_iGrabbingEntity[client][2] = -1;
	g_fGrabbingDistance[client] = 0.0;
}
//-------------------------------------------------)

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!IsValidClient(client))
		return;
		
	if(IsPlayerAlive(client))
	{
		int iEntity = Build_ClientAimEntity(client, false, true);
		if(IsPropBuggedDoor(iEntity))
		{
			char szName[64];
			SetHudTextParams(-1.0, 0.6, 3.0, 255, 0, 0, 230, 1, 6.0, 1.0, 2.0);
			int iEntityOwner = Build_ReturnEntityOwner(iEntity);
			GetEntPropString(iEntity, Prop_Data, "m_iName", szName, sizeof(szName));
			if(IsValidClient(iEntityOwner)) ShowSyncHudText(client, g_hHud, "%s\n built by %N", szName, iEntityOwner);
			else ShowSyncHudText(client, g_hHud, "%s\n built by *World", szName);
		}
			
		int iWeapon = GetPlayerWeaponSlot(client, 1);
		int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

		if(IsValidEntity(iWeapon) && iWeapon == iActiveWeapon && GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex") == g_iPhysicGunWeaponIndex && GetEntProp(iActiveWeapon, Prop_Send, "m_iEntityQuality") == 9)
		{
			float vector[3], fZero[3];
			if(buttons & IN_ATTACK)//When In_Attack
			{
				//int iEntity = Build_ClientAimEntity(client, false, true);
				if(IsValidEntity(iEntity) && (Build_ReturnEntityOwner(iEntity) == client || ((GetConVarInt(g_cvGrabOtherProp) == 1 && CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC)) || GetConVarInt(g_cvGrabOtherProp) == 2)) && !IsValidEntity(g_iGrabbingEntity[client][0])) //g_iGrabbingEntity[client][0] to iEntity when 
				{
					g_iGrabbingEntity[client][0] = iEntity; //Bind Entity
					if(!TF2_HasGlow(g_iGrabbingEntity[client][0]) && !IsValidEntity(g_iGrabbingEntity[client][1])) g_iGrabbingEntity[client][1] = TF2_CreateGlow(iEntity, GetClientTeam(client));
					g_fGrabbingDistance[client] = GetEntitiesDistance(client, g_iGrabbingEntity[client][0]);
					
					float fEOrigin[3], fEndPosition[3], fDummy[3];
					GetEntPropVector(g_iGrabbingEntity[client][0], Prop_Data, "m_vecOrigin", fEOrigin);
					GetClientAimPosition(client, g_fGrabbingDistance[client], fEndPosition, fDummy, tracerayfilterrocket, client);
					
					g_fGrabbingDifference[client][0] = fEOrigin[0] - fEndPosition[0];
					g_fGrabbingDifference[client][1] = fEOrigin[1] - fEndPosition[1];
					g_fGrabbingDifference[client][2] = fEOrigin[2] - fEndPosition[2];
					
					if(GetConVarBool(g_cvPhysics)) g_bGrabbingAttack2[client] = false;
					
					EmitSoundToAll(SOUND_PICKUP, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
					EmitSoundToAll(SOUND_LOOP, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
				}
				else if((GetConVarInt(g_cvGrabPlayer) == 2 || (GetConVarInt(g_cvGrabPlayer) == 1 && CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))) && IsValidEntity(iEntity) && IsValidClient(iEntity) && !IsValidEntity(g_iGrabbingEntity[client][0]))
				{
					g_iGrabbingEntity[client][0] = iEntity; //Bind Entity
					if(!TF2_HasGlow(g_iGrabbingEntity[client][0]) && !IsValidEntity(g_iGrabbingEntity[client][1])) g_iGrabbingEntity[client][1] = TF2_CreateGlow(iEntity, GetClientTeam(client));
					g_fGrabbingDistance[client] = GetEntitiesDistance(client, g_iGrabbingEntity[client][0]);
					
					float fEOrigin[3], fEndPosition[3], fDummy[3];
					GetEntPropVector(g_iGrabbingEntity[client][0], Prop_Data, "m_vecOrigin", fEOrigin);
					GetClientAimPosition(client, g_fGrabbingDistance[client], fEndPosition, fDummy, tracerayfilterrocket, client);
					
					g_fGrabbingDifference[client][0] = fEOrigin[0] - fEndPosition[0];
					g_fGrabbingDifference[client][1] = fEOrigin[1] - fEndPosition[1];
					g_fGrabbingDifference[client][2] = fEOrigin[2] - fEndPosition[2];
					
					if(GetConVarBool(g_cvPhysics)) g_bGrabbingAttack2[client] = false;
					
					EmitSoundToAll(SOUND_PICKUP, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
					EmitSoundToAll(SOUND_LOOP, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
				}
				
				if (IsValidEntity(g_iGrabbingEntity[client][0]))
				{
					TF2_AddCondition(client, TFCond_CritOnWin, 0.1);
					TF2_AddCondition(client, TFCond_TeleportedGlow, 0.1);
					float fOrigin[3], fEOrigin[3], fEndPosition[3], fDummy[3];
	
					GetClientEyePosition(client, fOrigin);
					GetEntPropVector(g_iGrabbingEntity[client][0], Prop_Data, "m_vecOrigin", fEOrigin);
								
					fEOrigin[0] = fEOrigin[0] - g_fGrabbingDifference[client][0];
					fEOrigin[1] = fEOrigin[1] - g_fGrabbingDifference[client][1];
					fEOrigin[2] = fEOrigin[2] - g_fGrabbingDifference[client][2];
					SetEntityGlows(fOrigin, fEOrigin, GetClientTeam(client));			
					
					if(buttons & IN_RELOAD) //Press R
					{
						vel[0] = 0.0;
						vel[1] = 0.0;
						vel[2] = 0.0;
						
						float fAngle[3], fFixAngle[3];
						GetEntPropVector(g_iGrabbingEntity[client][0], Prop_Send, "m_angRotation", fAngle);
						
						GetVectorAnglesTwoPoints(fOrigin, fEOrigin, fFixAngle);
						AnglesNormalize(fFixAngle);
						
						TeleportEntity(client, NULL_VECTOR, fFixAngle, NULL_VECTOR);
							
						if(buttons & IN_MOVELEFT)
						{
							fAngle[1] -= 1.0;
							AnglesNormalize(fAngle);
							TeleportEntity(g_iGrabbingEntity[client][0], NULL_VECTOR, fAngle, NULL_VECTOR);
						}
						else if(buttons & IN_MOVERIGHT)
						{
							fAngle[1] += 1.0;
							AnglesNormalize(fAngle);
							TeleportEntity(g_iGrabbingEntity[client][0], NULL_VECTOR, fAngle, NULL_VECTOR);
						}
						else if(buttons & IN_FORWARD)
						{
							fAngle[0] -= 1.0;
							AnglesNormalize(fAngle);
							TeleportEntity(g_iGrabbingEntity[client][0], NULL_VECTOR, fAngle, NULL_VECTOR);
						}
						else if(buttons & IN_BACK)
						{
							fAngle[0] += 1.0;
							AnglesNormalize(fAngle);
							TeleportEntity(g_iGrabbingEntity[client][0], NULL_VECTOR, fAngle, NULL_VECTOR);
						}
					}
					else 
					{		
						GetClientAimPosition(client, g_fGrabbingDistance[client], fEndPosition, fDummy, tracerayfilterrocket, client);
						
						fEndPosition[0] = fEndPosition[0] + g_fGrabbingDifference[client][0];
						fEndPosition[1] = fEndPosition[1] + g_fGrabbingDifference[client][1];
						fEndPosition[2] = fEndPosition[2] + g_fGrabbingDifference[client][2];
						
						MakeVectorFromPoints(fEOrigin, fEndPosition, vector); //Set velocity
						ScaleVector(vector, 10.0);
							
						char szClass[64];
						GetEdictClassname(g_iGrabbingEntity[client][0], szClass, sizeof(szClass));
						if(StrEqual(szClass, "prop_physics") && Phys_IsGravityEnabled(g_iGrabbingEntity[client][0]))
						{
							Phys_SetVelocity(EntRefToEntIndex(g_iGrabbingEntity[client][0]), vector, fZero, true);
							Phys_Wake(g_iGrabbingEntity[client][0]);
						}	
						else TeleportEntity(g_iGrabbingEntity[client][0], fEndPosition, NULL_VECTOR, NULL_VECTOR);
					}		
					
					if(GetConVarBool(g_cvPhysics) && CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC) && !IsPropBuggedDoor(g_iGrabbingEntity[client][0])) //Enable Physics function, Optional reason: FPS drop
					{
						if(buttons & IN_ATTACK2 && !(buttons & IN_RELOAD))
						{
							if(!g_bGrabbingAttack2[client])	
							{	
								char szClass[64];
								GetEdictClassname(g_iGrabbingEntity[client][0], szClass, sizeof(szClass));
								
								if (StrEqual(szClass, "prop_physics"))
								{
									if(Phys_IsPhysicsObject(g_iGrabbingEntity[client][0]))
									{
										//SetHudTextParams(0.8, 0.7, 3.0, 255, 215, 0, 255, 1, 6.0, 0.5, 1.5);
										if(Phys_IsGravityEnabled(g_iGrabbingEntity[client][0]))
										{				
											//ShowSyncHudText(client, g_hHud, "Prop freezed");										
											Phys_EnableGravity(g_iGrabbingEntity[client][0], false);
											Phys_EnableMotion(g_iGrabbingEntity[client][0], false);
											Phys_Sleep(g_iGrabbingEntity[client][0]);
											PrintHintText(client, "Prop freezed");
										}
										else 
										{
											//ShowSyncHudText(client, g_hHud, "Prop unfreezed");
											Phys_EnableGravity(g_iGrabbingEntity[client][0], true);
											Phys_EnableMotion(g_iGrabbingEntity[client][0], true);
											Phys_Wake(g_iGrabbingEntity[client][0]);
											PrintHintText(client, "Prop unfreezed");
										}
									}									
								}
								else if (StrEqual(szClass, "prop_dynamic")) //Set prop_dynamic to Prop_Physics
								{
									//SendDialogToOne(client, 240, 248, 255, "Error: Prop NOT prop_physics");
									int iNewEntity = PhysicsGun_ChangeToPropPhysics(client, g_iGrabbingEntity[client][0]);
									if(IsValidEntity(iNewEntity))
									{
										if(IsValidEntity(g_iGrabbingEntity[client][1]))	
										{
											AcceptEntityInput(g_iGrabbingEntity[client][1], "Kill");
											g_iGrabbingEntity[client][1] = -1;
										}
										AcceptEntityInput(g_iGrabbingEntity[client][0], "Kill");
										g_iGrabbingEntity[client][0] = iNewEntity;
									}
								}
								g_bGrabbingAttack2[client] = true;
							}
						}
						else if(g_bGrabbingAttack2[client])	 
						{
							g_bGrabbingAttack2[client] = false;
						}
					}
				}				
			}
			else 
			{
				if(IsValidEntity(g_iGrabbingEntity[client][0]))	
				{
					if(IsPropBuggedDoor(g_iGrabbingEntity[client][0])) //Respawn the bugged door
					{
						PhysicsGun_RespawnProp(g_iGrabbingEntity[client][0]); //Respawn (Copy) the door
					}
					StopSound(client, SNDCHAN_AUTO, SOUND_LOOP);
					EmitSoundToAll(SOUND_DROP, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
					g_iGrabbingEntity[client][0] = -1; //Set grab entity to NULL
				} 
				ResetClientAttribute(client);
			}
		}
		else 
		{
			ResetClientAttribute(client);
		}
	}
}

//-------[Stock]----------------------------------------------(
stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}

//From raindowglow.sp--------------
stock int TF2_CreateGlow(int iEnt, int team, int test = 0)
{
	if(!TF2_HasGlow(iEnt))
	{
		char oldEntName[64];
		GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
		
		char strName[126], strClass[64];
		int red, green, blue, alpha;
	
		GetEntityClassname(iEnt, strClass, sizeof(strClass));
		Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
		DispatchKeyValue(iEnt, "targetname", strName);

		if(team == 2)
		{
			red = 255;
			green = 100;
			blue = 100;
		}
		else if(team == 3)
		{
			red = 135;
			green = 206;
			blue = 250;
		}
		
		if(test == 0) alpha = 255;
		else alpha = 190;
	
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
			
			//Change name back to old name because we don't need it anymore.
			SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
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
void SetEntityGlows(float fOrigin[3], float fEOrigin[3], int team) //Set the Glow and laser
{
	float fEndPosition[3];
	fOrigin[2] -= 10.0;
	GetClientSightEnd(fOrigin, fEOrigin, fEndPosition);	//Glow on Grab Entity
	if(team == 2)	TE_SetupGlowSprite(fEndPosition, g_iRedGlow, 0.1, 0.3, 100); 
	else if(team == 3)	TE_SetupGlowSprite(fEndPosition, g_iBlueGlow, 0.1, 0.3, 100);	
	TE_SendToAll();												
	
	//TE_SetupBeamFollow(g_iGrabbingEntity[client][0], g_ModelIndex, g_HaloIndex, 0.1, 1.0, 0.1, 3, {255, 255, 255, 200});
	
	if(team == 2) TE_SetupBeamPoints(fOrigin, fEOrigin, g_ModelIndex2, g_HaloIndex, 0, 15, 0.15, 3.0, 3.0, 1, 0.0, {255, 100, 100, 200}, 10);	//Laser on client and Entity
	if(team == 3) TE_SetupBeamPoints(fOrigin, fEOrigin, g_ModelIndex, g_HaloIndex, 0, 15, 0.15, 3.0, 3.0, 1, 0.0, {255, 255, 255, 200}, 10);
	TE_SendToAll();		
	
	fOrigin[2] -= 15.0;
	if(team == 2)	TE_SetupGlowSprite(fOrigin, g_iRedGlow, 0.1, 0.2, 50); //Glow on Client
	else if(team == 3)	TE_SetupGlowSprite(fOrigin, g_iBlueGlow, 0.1, 0.2, 50); //Glow on Client
	TE_SendToAll();
	fOrigin[2] += 25.0;
}

int PhysicsGun_ChangeToPropPhysics(int client, int iEntity) //Change To prop_physics
{
	//Get Value-----------
	float fOrigin[3], fAngles[3], fSize;
	char szModel[64], szName[128];
	int iCollision, iRed, iGreen, iBlue, iAlpha, iSkin, iOwner;
	RenderFx EntityRenderFx;
	
	iOwner = Build_ReturnEntityOwner(iEntity);
	GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fAngles);
	iCollision = GetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 4);
	fSize = GetEntPropFloat(iEntity, Prop_Send, "m_flModelScale");
	GetEntityRenderColor(iEntity, iRed, iGreen, iBlue, iAlpha);
	EntityRenderFx = GetEntityRenderFx(iEntity);
		
	iSkin = GetEntProp(iEntity, Prop_Send, "m_nSkin");
	GetEntPropString(iEntity, Prop_Data, "m_iName", szName, sizeof(szName));
	//--------------------
	int iNewEntity = CreateEntityByName("prop_physics_override");
	
	if (iNewEntity > MaxClients && IsValidEntity(iNewEntity))
	{
		SetEntProp(iNewEntity, Prop_Send, "m_nSolidType", 6);
		SetEntProp(iNewEntity, Prop_Data, "m_nSolidType", 6);
		
		Build_SetLimit(iOwner, -1);
		if (Build_RegisterEntityOwner(iNewEntity, iOwner))
		{
			if (!IsModelPrecached(szModel))
				PrecacheModel(szModel);
			
			DispatchKeyValue(iNewEntity, "model", szModel);
			TeleportEntity(iNewEntity, fOrigin, fAngles, NULL_VECTOR);
			DispatchSpawn(iNewEntity);
			
			SetEntProp(iNewEntity, Prop_Data, "m_CollisionGroup", iCollision);
			SetEntPropFloat(iNewEntity, Prop_Send, "m_flModelScale", fSize);
			if(iAlpha < 255)	SetEntityRenderMode(iNewEntity, RENDER_TRANSCOLOR);
			else	SetEntityRenderMode(iNewEntity, RENDER_NORMAL);
			SetEntityRenderColor(iNewEntity, iRed, iGreen, iBlue, iAlpha);
			SetEntityRenderFx(iNewEntity, EntityRenderFx);
			SetEntProp(iNewEntity, Prop_Send, "m_nSkin", iSkin);
			SetEntPropString(iNewEntity, Prop_Data, "m_iName", szName);
			
			if (Phys_IsPhysicsObject(iNewEntity))
			{
				Phys_EnableGravity(iNewEntity, true);
				Phys_EnableMotion(iNewEntity, true);
				//SetHudTextParams(0.8, 0.7, 3.0, 255, 215, 0, 255, 1, 6.0, 0.5, 1.5);
				//ShowSyncHudText(client, g_hHud, "Prop unfreezed");
				PrintHintText(client, "Prop unfreezed");
			}
		}
		return iNewEntity;
	}
	return -1;
}

bool IsPropBuggedDoor(int iEntity) //For reload bug door
{
	if(IsValidEntity(iEntity))
	{
		char szModel[64];
		GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
		if(StrEqual(szModel, "models/combine_gate_citizen.mdl") 
		||	StrEqual(szModel, "models/combine_gate_Vehicle.mdl") 
		||	StrEqual(szModel, "models/props_doors/doorKLab01.mdl") 
		|| StrEqual(szModel, "models/props_lab/elevatordoor.mdl") 
		||  StrEqual(szModel, "models/props_lab/RavenDoor.mdl"))	
			return true;
	}
	return false;
}

int PhysicsGun_RespawnProp(int iEntity) //For reload bug door
{
	//Get Value-----------
	float fOrigin[3], fAngles[3], fSize;
	char szModel[64], szName[128], szClass[32];
	int iCollision, iRed, iGreen, iBlue, iAlpha, iSkin, iOwner;
	RenderFx EntityRenderFx;
	
	iOwner = Build_ReturnEntityOwner(iEntity);
	GetEntityClassname(iEntity, szClass, sizeof(szClass));
	GetEntPropString(iEntity, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", fAngles);
	iCollision = GetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 4);
	fSize = GetEntPropFloat(iEntity, Prop_Send, "m_flModelScale");
	GetEntityRenderColor(iEntity, iRed, iGreen, iBlue, iAlpha);
	EntityRenderFx = GetEntityRenderFx(iEntity);
		
	iSkin = GetEntProp(iEntity, Prop_Send, "m_nSkin");
	GetEntPropString(iEntity, Prop_Data, "m_iName", szName, sizeof(szName));
	//--------------------
	int iNewEntity = CreateEntityByName("prop_dynamic");
	
	if (iNewEntity > MaxClients && IsValidEntity(iNewEntity))
	{
		SetEntProp(iNewEntity, Prop_Send, "m_nSolidType", 6);
		//SetEntProp(iNewEntity, Prop_Data, "m_nSolidType", 6);
		
		Build_SetLimit(iOwner, -1);
		if (Build_RegisterEntityOwner(iNewEntity, iOwner))
		{
			if (!IsModelPrecached(szModel))
				PrecacheModel(szModel);
			
			DispatchKeyValue(iNewEntity, "model", szModel);
			TeleportEntity(iNewEntity, fOrigin, fAngles, NULL_VECTOR);
			DispatchSpawn(iNewEntity);
			SetEntProp(iNewEntity, Prop_Data, "m_CollisionGroup", iCollision);
			SetEntPropFloat(iNewEntity, Prop_Send, "m_flModelScale", fSize);
			if(iAlpha < 255)	SetEntityRenderMode(iNewEntity, RENDER_TRANSCOLOR);
			else	SetEntityRenderMode(iNewEntity, RENDER_NORMAL);
			SetEntityRenderColor(iNewEntity, iRed, iGreen, iBlue, iAlpha);
			SetEntityRenderFx(iNewEntity, EntityRenderFx);
			SetEntProp(iNewEntity, Prop_Send, "m_nSkin", iSkin);
			
			
			
			if(StrContains(szName, "door") == -1)	
			{
				Format(szName, sizeof(szName), "door%i", GetRandomInt(1000, 5000));
			}	
			//SetEntPropString(iNewEntity, Prop_Data, "m_iName", szName);	
			DispatchKeyValue(iNewEntity, "targetname", szName);
			SetVariantString(szName);
			
						
			char szFormatStr[64];
			Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,open,0", szName);
			DispatchKeyValue(iNewEntity, "OnHealthChanged", szFormatStr);
			Format(szFormatStr, sizeof(szFormatStr), "%s,setanimation,close,4", szName);
			DispatchKeyValue(iNewEntity, "OnHealthChanged", szFormatStr);
			AcceptEntityInput(iEntity, "Kill");
		}
		return iNewEntity;
	}
	return -1;
}

void ResetClientAttribute(int client)
{
	if(IsValidEntity(g_iGrabbingEntity[client][1]))	
	{
		AcceptEntityInput(g_iGrabbingEntity[client][1], "Kill");
		g_iGrabbingEntity[client][1] = -1;
	}
	if(IsValidEntity(g_iGrabbingEntity[client][0]))	
	{
		g_iGrabbingEntity[client][0] = -1;
	}
	g_iGrabbingEntity[client][2] = -1;
}

stock float GetEntitiesDistance(int ent1, int ent2)
{
	float orig1[3];
	GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", orig1);
	
	float orig2[3];
	GetEntPropVector(ent2, Prop_Send, "m_vecOrigin", orig2);
	
	return GetVectorDistance(orig1, orig2);
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

void GetClientSightEnd(float TE_ClientEye[3], float TE_iEye[3], float out[3])
{
    TR_TraceRayFilter(TE_ClientEye, TE_iEye, MASK_SOLID, RayType_EndPoint, TraceRayDontHitPlayers);
    if (TR_DidHit())
        TR_GetEndPosition(out);
}

public bool TraceRayDontHitPlayers(int entity, int mask, any data)
{
    if (0 < entity <= MaxClients)
        return false;

    return true;
}

stock bool GetClientAimPosition(int client, float maxtracedistance, float resultvecpos[3], float resultvecnormal[3], TraceEntityFilter Tfunction, int filter)
{
	float cleyepos[3], cleyeangle[3], eyeanglevector[3];
	GetClientEyePosition(client, cleyepos); 
	GetClientEyeAngles(client, cleyeangle);
	
	Handle traceresulthandle = INVALID_HANDLE;
	
	traceresulthandle = TR_TraceRayFilterEx(cleyepos, cleyeangle, MASK_SOLID, RayType_Infinite, Tfunction, filter);
	
	if(TR_DidHit(traceresulthandle) == true){
		
		float endpos[3];
		TR_GetEndPosition(endpos, traceresulthandle);
		TR_GetPlaneNormal(traceresulthandle, resultvecnormal);
		
		if((GetVectorDistance(cleyepos, endpos) <= maxtracedistance) || maxtracedistance <= 0){
			
			resultvecpos[0] = endpos[0];
			resultvecpos[1] = endpos[1];
			resultvecpos[2] = endpos[2];
			
			CloseHandle(traceresulthandle);
			return true;
			
		}
		else
		{	
			GetAngleVectors(cleyeangle, eyeanglevector, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(eyeanglevector, eyeanglevector);
			ScaleVector(eyeanglevector, maxtracedistance);
			
			AddVectors(cleyepos, eyeanglevector, resultvecpos);
			
			CloseHandle(traceresulthandle);
			return true;
		}	
	}
	CloseHandle(traceresulthandle);
	return false;
}

public bool tracerayfilterrocket(int entity, int mask, any data)
{
	if (IsValidEntity(entity))
	//if (0 < entity <= MaxClients)
		return false;
	
	return true;	
}

float GetVectorAnglesTwoPoints(const float vStartPos[3], const float vEndPos[3], float vAngles[3])
{
	static float tmpVec[3];
	tmpVec[0] = vEndPos[0] - vStartPos[0];
	tmpVec[1] = vEndPos[1] - vStartPos[1];
	tmpVec[2] = vEndPos[2] - vStartPos[2];
	GetVectorAngles(tmpVec, vAngles);
}

void AnglesNormalize(float vAngles[3])
{
	while (vAngles[0] > 89.0)vAngles[0] -= 360.0;
	while (vAngles[0] < -89.0)vAngles[0] += 360.0;
	while (vAngles[1] > 180.0)vAngles[1] -= 360.0;
	while (vAngles[1] < -180.0)vAngles[1] += 360.0;
}

void SendDialogToOne(int client, int red, int green, int blue, const char[] text, any ...)
{
	char message[100];
	VFormat(message, sizeof(message), text, 4);	
	
	KeyValues kv = new KeyValues("Stuff", "title", message);
	kv.SetColor("color", red, green, blue, 255);
	kv.SetNum("level", 1);
	kv.SetNum("time", 10);
	
	CreateDialog(client, kv, DialogType_Msg);

	delete kv;
}
