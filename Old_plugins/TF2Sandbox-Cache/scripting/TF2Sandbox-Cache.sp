#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <build>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] SandBox - Cache",
	author = PLUGIN_AUTHOR,
	description = "Cache System for TF2SB",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

Handle g_hFileEditting[MAXPLAYERS + 1] = INVALID_HANDLE;
//Handle cviCoolDownsec;
char CurrentMap[64];

bool bEnabled = true;
bool IsClientInServer[MAXPLAYERS + 1] = false;
//bool IsRoundStarted = false;

/*******************************************************************************************
	Start
*******************************************************************************************/
public void OnPluginStart()
{
	CreateConVar("sm_tf2sb_cache_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_NOTIFY);
        
    //HookEvent("teamplay_round_start", OnRoundStart);
	//cviCoolDownsec = CreateConVar("sm_tf2sb_ss_cooldownsec", "2", "Set CoolDown seconds to prevent flooding.", 0, true, 0.0, true, 50.0);
	
	char cCheckPath[128];
	BuildPath(Path_SM, cCheckPath, sizeof(cCheckPath), "data/TF2SBCache");
	if(!DirExists(cCheckPath))
	{
		CreateDirectory(cCheckPath, 511);
		
		if(DirExists(cCheckPath))
			PrintToServer("[TF2SB] Folder TF2SBCache created under addons/sourcemod/data/ sucessfully!");
		else
			SetFailState("[TF2SB] Failed to create directory at addons/sourcemod/data/TF2SBCache/ - Please manually create that path and reload this plugin.");
	}
}

//public Action OnRoundStart(Handle event, char[] name, bool dontBroadcast)
//{	
//	IsRoundStarted = true;
//}

public void OnMapStart()
{
	for(int i = 1; i < MAXPLAYERS; i++) if(IsValidClient(i))
	{
		OnClientPutInServer(i);
	}
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
}

public void OnClientPutInServer(int client)
{
	IsClientInServer[client] = true;
	CreateTimer(5.0, Timer_Load, client);
}

public void OnClientDisconnect(int client)
{
	IsClientInServer[client] = false;
}

public Action Timer_Save(Handle timer, int client)
{
	if(IsValidClient(client) && !IsFakeClient(client))
		SaveData(client);
	
	if(IsClientInServer[client])
		CreateTimer(10.0, Timer_Save, client);
}
	
public Action Timer_Load(Handle timer, int client)
{
	if(IsValidClient(client) && !IsFakeClient(client))
		Command_MainMenu(client, -1);
}

/*******************************************************************************************
	Main Menu
*******************************************************************************************/
public Action Command_MainMenu(int client, int args) 
{
	if (bEnabled)
	{	
		char menuinfo[1024];
		Menu menu = new Menu(Handler_MainMenu);
			
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Cache Main Menu %s \n \nThe server had saved your props when you disconnected.\nWould you like to load the Cache?\n ", PLUGIN_VERSION);
		menu.SetTitle(menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Yes, Load it.", client);	
		menu.AddItem("LOAD", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " No, Dont't load it", client);	
		menu.AddItem("DELETE", menuinfo);
		
		menu.ExitBackButton = false;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_MainMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (StrEqual(info, "LOAD"))
		{
			LoadDataSteamID(client);
		}
		else if (StrEqual(info, "DELETE"))
		{
			char cFileName[255];
			GetBuildPath(client, cFileName);
			
			if(FileExists(cFileName))
			{
				DeleteFile(cFileName);
			}
		}
		CreateTimer(5.0, Timer_Save, client);
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

/*******************************************************************************************
	 Stock
*******************************************************************************************/
//-----------[ Load data Function ]--------------------------------------------------------------------------------------
void LoadDataSteamID(int client)  // Load Data from data file (loader, client steamid64 in data file)
{
	char SteamID64[64];
	GetClientSteamID(client, SteamID64);
	
	char cFileName[255];
	GetBuildPath(client, cFileName);
	
	LoadFunction(client, cFileName);
}

void LoadFunction(int loader, char[] cFileName)
{
	if(FileExists(cFileName))
	{
		g_hFileEditting[loader] = OpenFile(cFileName, "r");
		if(g_hFileEditting[loader] != INVALID_HANDLE)
		{		
			float fOrigin[3], fAngles[3], fSize;
			char szModel[128], szClass[64], szBuffer[20][255];
			int g_iCountEntity = 0;
			int g_iCountLoop = 0;
			int Obj_LoadEntity, iCollision, iRed, iGreen, iBlue, iAlpha, iRenderFx, iRandom;
			
			char szLoadString[255];
			char szFormatStr[255];
			char DoorIndex[5];
			RenderFx FxRender = RENDERFX_NONE;
			
			for(int i = 0; i < 4096; i++) if (ReadFileLine(g_hFileEditting[loader], szLoadString, sizeof(szLoadString))) 
			{
				if (StrContains(szLoadString, "ent") != -1 && StrContains(szLoadString, ";") == -1) //Map name have ent sytax??? Holy
				{
					ExplodeString(szLoadString, " ", szBuffer, 20, 255);
					Format(szClass, sizeof(szClass), "%s", szBuffer[1]);
					Format(szModel, sizeof(szModel), "%s", szBuffer[2]);
					fOrigin[0] = StringToFloat(szBuffer[3]);
					fOrigin[1] = StringToFloat(szBuffer[4]);
					fOrigin[2] = StringToFloat(szBuffer[5]);
					fAngles[0] = StringToFloat(szBuffer[6]);
					fAngles[1] = StringToFloat(szBuffer[7]);
					fAngles[2] = StringToFloat(szBuffer[8]);
					iCollision = StringToInt(szBuffer[9]);
					fSize 	   = StringToFloat(szBuffer[10]);
					iRed       = StringToInt(szBuffer[11]);
					iGreen     = StringToInt(szBuffer[12]);
					iBlue	   = StringToInt(szBuffer[13]);
					iAlpha     = StringToInt(szBuffer[14]);
					iRenderFx  = StringToInt(szBuffer[15]);
					
					if(strlen(szBuffer[9]) == 0)
						iCollision = 5;
					if(strlen(szBuffer[10]) == 0)
						fSize = 1.0;
					if(strlen(szBuffer[11]) == 0)
						iRed = 255;
					if(strlen(szBuffer[12]) == 0)
						iGreen = 255;
					if(strlen(szBuffer[13]) == 0)
						iBlue = 255;
					if(strlen(szBuffer[14]) == 0)
						iAlpha = 255;
					if(strlen(szBuffer[15]) == 0)
						iRenderFx = 1;
						
					//iHealth = StringToInt(szBuffer[9]);
					//if (iHealth == 2)
					//	iHealth = 999999999;
					//if (iHealth == 1)
					//	iHealth = 50;
					if (StrContains(szClass, "prop_dynamic") >= 0) 
					{
						Obj_LoadEntity = CreateEntityByName("prop_dynamic_override");
						SetEntProp(Obj_LoadEntity, Prop_Send, "m_nSolidType", 6);
						SetEntProp(Obj_LoadEntity, Prop_Data, "m_nSolidType", 6);
					} 
					else if (StrEqual(szClass, "prop_physics"))
						Obj_LoadEntity = CreateEntityByName("prop_physics_override");
					else if (StrContains(szClass, "prop_physics") >= 0)
						Obj_LoadEntity = CreateEntityByName(szClass);
					
					if (Obj_LoadEntity > MaxClients && IsValidEntity(Obj_LoadEntity) && GetClientSpawnedEntities(loader) < GetClientMaxHoldEntities()) 
					{
						if (Build_RegisterEntityOwner(Obj_LoadEntity, loader)) 
						{
							if (!IsModelPrecached(szModel))
								PrecacheModel(szModel);
								
							DispatchKeyValue(Obj_LoadEntity, "model", szModel);
							TeleportEntity(Obj_LoadEntity, fOrigin, fAngles, NULL_VECTOR);
							DispatchSpawn(Obj_LoadEntity);
							
							SetEntProp(Obj_LoadEntity, Prop_Data, "m_CollisionGroup", iCollision);
							SetEntPropFloat(Obj_LoadEntity, Prop_Send, "m_flModelScale", fSize);
							SetEntityRenderColor(Obj_LoadEntity, iRed, iGreen, iBlue, iAlpha);
							
							switch(iRenderFx)
							{
								case 1:FxRender = RENDERFX_NONE;
								case 2:FxRender = RENDERFX_PULSE_SLOW;
								case 3:FxRender = RENDERFX_PULSE_FAST;
								case 4:FxRender = RENDERFX_PULSE_SLOW_WIDE;
								case 5:FxRender = RENDERFX_PULSE_FAST_WIDE;
								case 6:FxRender = RENDERFX_FADE_SLOW;
								case 7:FxRender = RENDERFX_FADE_FAST;
								case 8:FxRender = RENDERFX_SOLID_SLOW;
								case 9:FxRender = RENDERFX_SOLID_FAST;
								case 10:FxRender = RENDERFX_STROBE_SLOW;
								case 11:FxRender = RENDERFX_STROBE_FAST;
								case 12:FxRender = RENDERFX_STROBE_FASTER;
								case 13:FxRender = RENDERFX_FLICKER_SLOW;
								case 14:FxRender = RENDERFX_FLICKER_FAST;
								case 15:FxRender = RENDERFX_NO_DISSIPATION;
								case 16:FxRender = RENDERFX_DISTORT;
								case 17:FxRender = RENDERFX_HOLOGRAM;
							}
							SetEntityRenderFx(Obj_LoadEntity, FxRender);
		
							//SetVariantInt(iHealth);
							//AcceptEntityInput(Obj_LoadEntity, "sethealth", -1);
							//AcceptEntityInput(Obj_LoadEntity, "disablemotion", -1);
							g_iCountEntity++;
							
							//light bulb
							if(StrEqual(szModel, "models/props_2fort/lightbulb001.mdl"))
							{
								//char 
								//fAngles[1] = StringToFloat(szBuffer[9]); //brightness
								//fAngles[2] = StringToFloat(szBuffer[10]); //Red
								//fAngles[2] = StringToFloat(szBuffer[10]); //Green
								//fAngles[2] = StringToFloat(szBuffer[10]); //Blue

								int Obj_LightDynamic = CreateEntityByName("light_dynamic");
								
								char szColor[32];
								Format(szColor, sizeof(szColor), "255 255 255");
								
								SetVariantString("500");
								AcceptEntityInput(Obj_LightDynamic, "distance", -1);
								SetVariantString("7");
								AcceptEntityInput(Obj_LightDynamic, "brightness", -1);
								SetVariantString("2");
								AcceptEntityInput(Obj_LightDynamic, "style", -1);
								SetVariantString(szColor);
								AcceptEntityInput(Obj_LightDynamic, "color", -1);
								
								if (Obj_LightDynamic != -1) 
								{
									DispatchSpawn(Obj_LightDynamic);
									TeleportEntity(Obj_LightDynamic, fOrigin, fAngles, NULL_VECTOR);
									
									char szNameMelon[64];
									Format(szNameMelon, sizeof(szNameMelon), "Obj_LoadEntity%i", GetRandomInt(1000, 5000));
									DispatchKeyValue(Obj_LoadEntity, "targetname", szNameMelon);
									SetVariantString(szNameMelon);
									AcceptEntityInput(Obj_LightDynamic, "setparent", -1);
									AcceptEntityInput(Obj_LightDynamic, "turnon", loader, loader);
								}	
							}
							
							//door
							if (StrEqual(szModel, "models/props_lab/blastdoor001c.mdl")) 
							{
								iRandom = GetRandomInt(1000, 5000);
								IntToString(iRandom, DoorIndex, sizeof(DoorIndex));
								Format(szFormatStr, sizeof(szFormatStr), "door%s", DoorIndex);
								DispatchKeyValue(Obj_LoadEntity, "targetname", szFormatStr);
								
								Format(szFormatStr, sizeof(szFormatStr), "door%s,setanimation,dog_open,0", DoorIndex);
								DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
								Format(szFormatStr, sizeof(szFormatStr), "door%s,DisableCollision,,1", DoorIndex);
								DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
								Format(szFormatStr, sizeof(szFormatStr), "door%s,setanimation,close,5", DoorIndex);
								DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
								Format(szFormatStr, sizeof(szFormatStr), "door%s,EnableCollision,,5.1", DoorIndex);
								DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
							} 
							else if (StrEqual(szModel, "models/props_lab/RavenDoor.mdl")) 
							{
								iRandom = GetRandomInt(1000, 5000);
								IntToString(iRandom, DoorIndex, sizeof(DoorIndex));
								Format(szFormatStr, sizeof(szFormatStr), "door%s", DoorIndex);
								DispatchKeyValue(Obj_LoadEntity, "targetname", szFormatStr);
								
								Format(szFormatStr, sizeof(szFormatStr), "door%s,setanimation,RavenDoor_Open,0", DoorIndex);
								DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
								Format(szFormatStr, sizeof(szFormatStr), "door%s,setanimation,RavenDoor_Drop,7", DoorIndex);
								DispatchKeyValue(Obj_LoadEntity, "OnHealthChanged", szFormatStr);
							} 
							
						} 
						else 
						{
							RemoveEdict(Obj_LoadEntity);
						}
					}
					g_iCountLoop++;
				}
				if(IsEndOfFile(g_hFileEditting[loader]))
					break;
			}
			CloseHandle(g_hFileEditting[loader]);

			Build_PrintToChat(loader, "Load Result >> Loaded: \x04%i\x01, Error: \x04%i\x01 >> Cache Loaded", g_iCountEntity, g_iCountLoop -g_iCountEntity);
			if(GetClientSpawnedEntities(loader) >= GetClientMaxHoldEntities())
			{
				ClientCommand(loader, "playgamesound \"%s\"", "buttons/button10.wav");
				Build_PrintToChat(loader, "You've hit the prop limit!");
				PrintCenterText(loader, "You've hit the prop limit!");
			}
		}
	}
}

//-----------[ Save data Function ]-------------------------------------
void SaveData(int client)  // Save Data from data file
{
	char SteamID64[64];
	GetClientSteamID(client, SteamID64);
	
	char cFileName[255];
	GetBuildPath(client, cFileName);
	
	int g_iCountEntity = -1;
	//----------------------------------------------------Open file and start write-----------------------------------------------------------------
	g_hFileEditting[client] = OpenFile(cFileName, "w");
	if(g_hFileEditting[client] != INVALID_HANDLE)
	{
		g_iCountEntity = 0;

		float fOrigin[3], fAngles[3], fSize;
		char szModel[64], szClass[64];
		int iOrigin[3], iAngles[3], iCollision, iRed, iGreen, iBlue, iAlpha, iRenderFx;
		RenderFx EntityRenderFx;
		
		char szTime[64];
		FormatTime(szTime, sizeof(szTime), "%Y/%m/%d");
		
		WriteFileLine(g_hFileEditting[client], ";--- Saved Map: %s", CurrentMap);
		WriteFileLine(g_hFileEditting[client], ";--- SteamID64: %s (%N)", SteamID64, client);
		WriteFileLine(g_hFileEditting[client], ";--- Saved on : %s", szTime);
		for (int i = MaxClients; i < MAX_HOOK_ENTITIES; i++) 	if (IsValidEdict(i))
		{
			GetEdictClassname(i, szClass, sizeof(szClass));
			if ((StrContains(szClass, "prop_dynamic") >= 0 || StrContains(szClass, "prop_physics") >= 0) && !StrEqual(szClass, "prop_ragdoll") && Build_ReturnEntityOwner(i) == client) 
			{
				GetEntPropString(i, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", fOrigin);
				GetEntPropVector(i, Prop_Data, "m_angRotation", fAngles);
				iCollision = GetEntProp(i, Prop_Data, "m_CollisionGroup", 4);
				fSize = GetEntPropFloat(i, Prop_Send, "m_flModelScale");
				GetEntityRenderColor(i, iRed, iGreen, iBlue, iAlpha);
				EntityRenderFx = GetEntityRenderFx(i);
				
				iRenderFx = 1;
				if(EntityRenderFx == RENDERFX_PULSE_SLOW)
					iRenderFx = 2;
				else if(EntityRenderFx == RENDERFX_PULSE_FAST)
					iRenderFx = 3;
				else if(EntityRenderFx == RENDERFX_PULSE_SLOW_WIDE)
					iRenderFx = 4;
				else if(EntityRenderFx == RENDERFX_PULSE_FAST_WIDE)
					iRenderFx = 5;
				else if(EntityRenderFx == RENDERFX_FADE_SLOW)
					iRenderFx = 6;
				else if(EntityRenderFx == RENDERFX_FADE_FAST)
					iRenderFx = 7;
				else if(EntityRenderFx == RENDERFX_SOLID_SLOW)
					iRenderFx = 8;
				else if(EntityRenderFx == RENDERFX_SOLID_FAST)
					iRenderFx = 9;	
				else if(EntityRenderFx == RENDERFX_STROBE_SLOW)
					iRenderFx = 10;
				else if(EntityRenderFx == RENDERFX_STROBE_FAST)
					iRenderFx = 11;
				else if(EntityRenderFx == RENDERFX_STROBE_FASTER)
					iRenderFx = 12;
				else if(EntityRenderFx == RENDERFX_FLICKER_SLOW)
					iRenderFx = 13;
				else if(EntityRenderFx == RENDERFX_FLICKER_FAST)
					iRenderFx = 14;
				else if(EntityRenderFx == RENDERFX_NO_DISSIPATION)
					iRenderFx = 15;
				else if(EntityRenderFx == RENDERFX_DISTORT)
					iRenderFx = 16;
				else if(EntityRenderFx == RENDERFX_HOLOGRAM)
					iRenderFx = 17;	
							
				for (int j = 0; j < 3; j++) 
				{
					iOrigin[j] = RoundToNearest(fOrigin[j]);
					iAngles[j] = RoundToNearest(fAngles[j]);
				}
				/*
				iHealth = GetEntProp(i, Prop_Data, "m_iHealth", 4);
				if (iHealth > 100000000)
					iHealth = 2;
				else if (iHealth > 0)
					iHealth = 1;
				else
					iHealth = 0;
				*/
				WriteFileLine(g_hFileEditting[client], "ent%i %s %s %f %f %f %f %f %f %i %f %i %i %i %i %i", g_iCountEntity, szClass, szModel, fOrigin[0], fOrigin[1], fOrigin[2], fAngles[0], fAngles[1], fAngles[2], iCollision, fSize, iRed, iGreen, iBlue, iAlpha, iRenderFx);
				g_iCountEntity++;
			}
		}
		WriteFileLine(g_hFileEditting[client], ";--- Data File End | %i Props Saved", g_iCountEntity);
		WriteFileLine(g_hFileEditting[client], ";--- File Generated By TF2Sandbox-Cache.smx", g_iCountEntity);
		
		FlushFile(g_hFileEditting[client]);
		//-------------------------------------------------------------Close file-------------------------------------------------------------------
		CloseHandle(g_hFileEditting[client]);
	}
	if(g_iCountEntity == -1)
		Build_PrintToChat(client, "Save Result >> ERROR!!!, please contact server admin.");
}

//-----------[ Get data Function ]----------------------------------------------------------------------------------
void GetBuildPath(int client, char[] cFileNameout) //Get the sourcemod Build path
{
	char SteamID64[64];
	GetClientSteamID(client, SteamID64);
	
	char cFileName[255];
	BuildPath(Path_SM, cFileName, sizeof(cFileName), "data/TF2SBCache/%s&%s.tf2sb", CurrentMap, SteamID64);
	
	strcopy(cFileNameout, sizeof(cFileName), cFileName);
}

void GetClientSteamID(int client, char[] SteamID64out)
{
	char SteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, SteamID64, sizeof(SteamID64), true);
	
	strcopy(SteamID64out, sizeof(SteamID64), SteamID64);
}

//-----------[ Check Function ]--------------------------------------------------------
stock bool IsValidClient(int client) 
{ 
    if(client <= 0 ) return false; 
    if(client > MaxClients) return false; 
    if(!IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
}

int GetClientSpawnedEntities(int client)
{
	char szClass[32];
	int iCount = 0;
	for (int i = MaxClients; i < MAX_HOOK_ENTITIES; i++) if (IsValidEdict(i))
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

bool IsClientInServers(char[] SteamID64in)
{
	char SteamID64[64];
	for(int i = 1; i < MAXPLAYERS; i++) if(IsValidClient(i) && IsFakeClient(i))
	{	
		GetClientSteamID(i, SteamID64)
		if(StrEqual(SteamID64, SteamID64in)
			return true;
	}
	return false;
}