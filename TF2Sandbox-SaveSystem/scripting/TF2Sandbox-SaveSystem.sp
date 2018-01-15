 ////////////////////////
// Table of contents: 
//		Main Menu	  
//					  
//	1.Load...     	  
//	2.Save...	 	  
//	3.Delete...		  
//  4.Set Permission...
//  5.Load others project...
//	6.Check Cache System...
//		  		      
////////////////////////

#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Battlefield Duck"
#define PLUGIN_VERSION "6.5"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <build>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] SandBox - SaveSystem", 
	author = PLUGIN_AUTHOR, 
	description = "Save System for TF2SB", 
	version = PLUGIN_VERSION, 
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

Handle g_hFileEditting[MAXPLAYERS + 1] = INVALID_HANDLE;
Handle cviCoolDownsec;
Handle cviStoreSlot;
Handle cviLoadMode;
Handle cviLoadSec;
Handle cviLoadProps;
Handle cvPluginVersion;
Handle cviAdvertisement;
Handle cvMapname;

char CurrentMap[64];

bool bEnabled = true;
bool bPermission[MAXPLAYERS + 1][51]; //client, slot

//Cache system
bool IsClientInServer[MAXPLAYERS + 1] = false;
bool g_bWaitingForPlayers;
//------------

int iCoolDown[MAXPLAYERS + 1] = 0;
int iSelectedClient[MAXPLAYERS + 1];

/*******************************************************************************************
	Start
*******************************************************************************************/
public void OnPluginStart()
{
	cvPluginVersion = CreateConVar("sm_tf2sb_ss_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	
	cviCoolDownsec = CreateConVar("sm_tf2sb_ss_cooldownsec", "2", "(1 - 50) Set CoolDown seconds to prevent flooding.", 0, true, 1.0, true, 50.0);
	cviStoreSlot = CreateConVar("sm_tf2sb_ss_storeslots", "4", "(1 - 50) How many slots for client to save", 0, true, 1.0, true, 50.0);
	cviLoadMode = CreateConVar("sm_tf2sb_ss_loadmode", "1", "1 = Load instantly, 2 = Load Props by Timer (Slower but less lag?)", 0, true, 1.0, true, 2.0);
	cviLoadSec = CreateConVar("sm_tf2sb_ss_loadsec", "0.01", "(0.01 - 1.00) Load Props/Sec (Work on sm_tf2sb_ss_loadmode 2 only)", 0, true, 0.01, true, 1.0);
	cviLoadProps = CreateConVar("sm_tf2sb_ss_loadprops", "3", "(1 - 60) Load Sec/Props (Work on sm_tf2sb_ss_loadmode 2 only)", 0, true, 1.0, true, 60.0);
	cviAdvertisement = CreateConVar("sm_tf2sb_ss_ads", "30.0", "(10.0 - 60.0) Advertisement loop time", 0, true, 10.0, true, 60.0);
	cvMapname = CreateConVar("sm_tf2sb_ss_mapcheck", "", "Load map name of the file. (Nothing = Current map)");
	
	RegAdminCmd("sm_ss", Command_MainMenu, 0, "Open SaveSystem menu");
	RegAdminCmd("sm_ssload", Command_LoadDataFromDatabase, ADMFLAG_GENERIC, "Usage: sm_ssload <targetname|steamid64> <slot>");
	
	char cCheckPath[128];
	BuildPath(Path_SM, cCheckPath, sizeof(cCheckPath), "data/TF2SBSaveSystem");
	if (!DirExists(cCheckPath))
	{
		CreateDirectory(cCheckPath, 511);
		
		if (DirExists(cCheckPath))
			PrintToServer("[TF2SB] Folder TF2SBSaveSystem created under addons/sourcemod/data/ sucessfully!");
		else
			SetFailState("[TF2SB] Failed to create directory at addons/sourcemod/data/TF2SBSaveSystem/ - Please manually create that path and reload this plugin.");
	}
	
	BuildPath(Path_SM, cCheckPath, sizeof(cCheckPath), "data/TF2SBCache");
	if (!DirExists(cCheckPath))
	{
		CreateDirectory(cCheckPath, 511);
		
		if (DirExists(cCheckPath))
			PrintToServer("[TF2SB] Folder TF2SBCache created under addons/sourcemod/data/ sucessfully!");
		else
			SetFailState("[TF2SB] Failed to create directory at addons/sourcemod/data/TF2SBCache/ - Please manually create that path and reload this plugin.");
	}
	
	AutoExecConfig();
	CreateTimer(5.0, Timer_LoadMap, 0);
}

public Action Command_LoadDataFromDatabase(int client, int args)
{
	if (Build_IsClientValid(client, client))
	{
		if (iCoolDown[client] != 0)
			Build_PrintToChat(client, "Load Function is currently cooling down, please wait \x04%i\x01 seconds.", iCoolDown[client]);
		else if (args == 2)
		{
			//char cArg[64], szBuffer[3][255], cTarget[20], cSlot[8];
			//GetCmdArgString(cArg, sizeof(cArg));
			//ExplodeString(cArg, " ", szBuffer, args, 255);
			//Format(cTarget, sizeof(cTarget), "%s", szBuffer[0]);
			//Format(cSlot, sizeof(cSlot), "%s", szBuffer[1]);
			
			char cTarget[20], cSlot[8];
			GetCmdArg(1, cTarget, sizeof(cTarget));
			GetCmdArg(2, cSlot, sizeof(cSlot));
			
			int targets[1]; // When not target multiple players, COMMAND_FILTER_NO_MULTI 
			char target_name[MAX_TARGET_LENGTH];
			bool tn_is_ml;
			int targets_found = ProcessTargetString(cTarget, client, targets, sizeof(targets), COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_MULTI, target_name, sizeof(target_name), tn_is_ml);
			
			if (targets_found <= COMMAND_TARGET_AMBIGUOUS)
				Build_PrintToChat(client, "Error: More then one client have the name : \x04%s\x01", cTarget);
			else if (targets_found <= COMMAND_TARGET_NONE)
			{
				Build_PrintToChat(client, "Searching steamid(\x04%s\x01)... Searching file slot\x04%i\x01...", cTarget, StringToInt(cSlot));
				
				char cFileName[255];
				BuildPath(Path_SM, cFileName, sizeof(cFileName), "data/TF2SBSaveSystem/%s&%s@%i.tf2sb", CurrentMap, cTarget, StringToInt(cSlot));
				
				if (FileExists(cFileName))
					LoadDataSteamID(client, cTarget, StringToInt(cSlot));
				else
					Build_PrintToChat(client, "Error: Fail to find the Data File...");
			}
			else
			{
				Build_PrintToChat(client, "Found target(\x04%N\x01)... Searching file slot\x04%i\x01...", targets[0], StringToInt(cSlot));
				if (DataFileExist(targets[0], StringToInt(cSlot)))
					LoadData(client, targets[0], StringToInt(cSlot));
				else
					Build_PrintToChat(client, "Error: Fail to find the Data File...");
			}
			iCoolDown[client] = GetConVarInt(cviCoolDownsec);
			CreateTimer(0.05, Timer_CoolDownFunction, client);
		}
		else
			Build_PrintToChat(client, "Usage: sm_ssload <\x04targetname\x01|\x04steamid\x01> <\x04slot\x01>");
	}
	return;
}

public void OnMapStart()
{
	for (int i = 1; i < MAXPLAYERS; i++)
	OnClientPutInServer(i);
	
	CreateTimer(10.0, Timer_Ads, 0, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(6.0, Timer_LoadMap, 0, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
	iCoolDown[client] = 0;
	for (int j = 0; j < 50; j++)
	bPermission[client][j] = false;
	
	//Cache system
	IsClientInServer[client] = true;
	CreateTimer(10.0, Timer_Load, client);
	//------------
}

public void OnClientDisconnect(int client)
{
	//Cache system
	IsClientInServer[client] = false;
	//------------
}

public void TF2_OnWaitingForPlayersStart()
{
	//Cache system
	g_bWaitingForPlayers = true;
}

public void TF2_OnWaitingForPlayersEnd()
{
	//Cache system
	g_bWaitingForPlayers = false;
}

/*******************************************************************************************
	Timer
*******************************************************************************************/
public Action Timer_CoolDownFunction(Handle timer, int client)
{
	iCoolDown[client] -= 1;
	
	if (iCoolDown[client] >= 1)
		CreateTimer(1.0, Timer_CoolDownFunction, client);
	else
		iCoolDown[client] = 0;
}

public Action Timer_Ads(Handle timer, int LoopNumber)
{
	switch (LoopNumber)
	{
		case (0):Build_PrintToAll(" Type \x04/ss\x01 to SAVE or LOAD your buildings!");
		case (1):Build_PrintToAll(" Remember to SAVE your buildings! Type \x04/ss\x01 in chat box to save.");
		case (2):Build_PrintToAll(" Cache System will help you to cache your props automatically.");
		case (3):Build_PrintToAll(" If you disconnect for some reasons.. Nevermind! Cache System will cache your props!");
		case (4):CPrintToChatAll("[{green}Save System{default}] {orange}Developer{default}: {yellow}BattlefieldDuck{default}, {green}aIM{default}, {pink}Leadkiller{default}, {red}Danct12{default}.");
	}
	LoopNumber++;
	
	if (LoopNumber > 4)
		LoopNumber = 0;
	
	CreateTimer(GetConVarFloat(cviAdvertisement), Timer_Ads, LoopNumber, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_LoadMap(Handle timer, int client)
{
	char Mapname[64];
	GetConVarString(cvMapname, Mapname, sizeof(Mapname));
	
	if (strlen(Mapname) == 0)
		GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	else
		strcopy(CurrentMap, sizeof(Mapname), Mapname);
}

//Cache system
public Action Timer_Save(Handle timer, int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
		SaveData(client, 0);
	
	if (IsClientInServer[client])
		CreateTimer(10.0, Timer_Save, client);
}

public Action Timer_Load(Handle timer, int client)
{
	if (IsValidClient(client) && !IsFakeClient(client) && !g_bWaitingForPlayers)
	{
		if (DataFileExist(client, 0))
			Command_CacheMenu(client, -1);
		else
			CreateTimer(5.0, Timer_Save, client);
	}
	else
		CreateTimer(5.0, Timer_Load, client);
}
//------------

/*******************************************************************************************
	Cache Menu
*******************************************************************************************/
public Action Command_CacheMenu(int client, int args)
{
	if (bEnabled)
	{
		char menuinfo[1024];
		Menu menu = new Menu(Handler_CacheMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Cache Menu v%s (In Development)\n \nThe server had saved your props when you disconnected.\nWould you like to load the Cache?\n ", PLUGIN_VERSION);
		menu.SetTitle(menuinfo);
		
		int iSlot = 0;
		char cDate[11];
		char cSlot[6];
		IntToString(iSlot, cSlot, sizeof(cSlot));
		if (DataFileExist(client, iSlot))
		{
			GetDataDate(client, iSlot, cDate, sizeof(cDate));
			Format(menuinfo, sizeof(menuinfo), " Cache (Stored %s, %i Props)", cDate, GetDataProps(client, iSlot));
		}
		else
			Format(menuinfo, sizeof(menuinfo), " Cache (No Data)");
		
		menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
		
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

public int Handler_CacheMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (StrEqual(info, "LOAD"))
			LoadData(client, client, 0); //Load Cache
		else if (StrEqual(info, "DELETE"))
		{
			char cFileName[255];
			GetBuildPath(client, 0, cFileName);
			
			if (FileExists(cFileName))
				DeleteFile(cFileName); //Delete
		}
		CreateTimer(5.0, Timer_Save, client);
	}
	/*
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
			
		}
	}
	*/
	else if (action == MenuAction_End)
		delete menu;
}
//--------------------------------------------------

/*******************************************************************************************
	1. Main Menu
*******************************************************************************************/
public Action Command_MainMenu(int client, int args)
{
	if (bEnabled)
	{
		char menuinfo[1024];
		Menu menu = new Menu(Handler_MainMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s\n ", PLUGIN_VERSION, CurrentMap);
		menu.SetTitle(menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Load... ", client);
		menu.AddItem("LOAD", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Save... ", client);
		menu.AddItem("SAVE", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Delete... ", client);
		menu.AddItem("DELETE", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Set Permission... ", client);
		menu.AddItem("PERMISSION", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Load other's projects... ", client);
		if (GetClientInGame() > 1)
			menu.AddItem("LOADOTHERS", menuinfo);
		else
			menu.AddItem("LOADOTHERS", menuinfo, ITEMDRAW_DISABLED);
		
		Format(menuinfo, sizeof(menuinfo), " Check Cache System... ", client);
		menu.AddItem("CACHE", menuinfo);
		
		menu.ExitBackButton = true;
		menu.ExitButton = true;
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
			Command_LoadMenu(client, -1);
		else if (StrEqual(info, "SAVE"))
			Command_SaveMenu(client, -1);
		else if (StrEqual(info, "DELETE"))
			Command_DeleteMenu(client, -1);
		else if (StrEqual(info, "PERMISSION"))
			Command_PermissionMenu(client, -1);
		else if (StrEqual(info, "LOADOTHERS"))
			Command_LoadOthersMenu(client, -1);
		else if (StrEqual(info, "CACHE"))
			Command_CheckCacheMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
			FakeClientCommand(client, "sm_build");
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 2. Load Menu
*******************************************************************************************/
public Action Command_LoadMenu(int client, int args)
{
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_LoadMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s \n \nSelect a Slot to LOAD....", PLUGIN_VERSION, CurrentMap);
		menu.SetTitle(menuinfo);
		
		char cSlot[6];
		char cDate[11];
		for (int iSlot = 1; iSlot <= GetConVarInt(cviStoreSlot); iSlot++)
		{
			IntToString(iSlot, cSlot, sizeof(cSlot));
			if (DataFileExist(client, iSlot))
			{
				GetDataDate(client, iSlot, cDate, sizeof(cDate));
				Format(menuinfo, sizeof(menuinfo), " Slot %i (Stored %s, %i Props)", iSlot, cDate, GetDataProps(client, iSlot));
				menu.AddItem(cSlot, menuinfo);
			}
			else
			{
				Format(menuinfo, sizeof(menuinfo), " Slot %i (No Data)", iSlot);
				menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
			}
		}
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_LoadMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSlot = StringToInt(info);
		
		if (iCoolDown[client] == 0)
		{
			LoadData(client, client, iSlot);
			iCoolDown[client] = GetConVarInt(cviCoolDownsec);
			CreateTimer(0.05, Timer_CoolDownFunction, client);
		}
		else
			Build_PrintToChat(client, "Load Function is currently cooling down, please wait \x04%i\x01 seconds.", iCoolDown[client]);
		
		Command_LoadMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
			Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 3. Save Menu
*******************************************************************************************/
public Action Command_SaveMenu(int client, int args)
{
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_SaveMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s \n \nSelect a Slot to SAVE....", PLUGIN_VERSION, CurrentMap);
		menu.SetTitle(menuinfo);
		
		char cSlot[6];
		char cDate[11];
		for (int iSlot = 1; iSlot <= GetConVarInt(cviStoreSlot); iSlot++)
		{
			IntToString(iSlot, cSlot, sizeof(cSlot));
			if (DataFileExist(client, iSlot))
			{
				GetDataDate(client, iSlot, cDate, sizeof(cDate));
				Format(menuinfo, sizeof(menuinfo), " Slot %i (Stored %s, %i Props)", iSlot, cDate, GetDataProps(client, iSlot));
				menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
			}
			else
			{
				Format(menuinfo, sizeof(menuinfo), " Slot %i (No Data)", iSlot);
				menu.AddItem(cSlot, menuinfo);
			}
		}
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_SaveMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSlot = StringToInt(info);
		
		if (iCoolDown[client] == 0)
		{
			SaveData(client, iSlot);
			iCoolDown[client] = GetConVarInt(cviCoolDownsec);
			CreateTimer(0.05, Timer_CoolDownFunction, client);
		}
		else
			Build_PrintToChat(client, "Save Function is currently cooling down, please wait \x04%i\x01 seconds.", iCoolDown[client]);
		
		Command_SaveMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
			Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 4. Delete Menu
*******************************************************************************************/
public Action Command_DeleteMenu(int client, int args)
{
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_DeleteMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s \n \nSelect a Slot to DELETE....", PLUGIN_VERSION, CurrentMap);
		menu.SetTitle(menuinfo);
		
		char cSlot[6];
		char cDate[11];
		for (int iSlot = 1; iSlot <= GetConVarInt(cviStoreSlot); iSlot++)
		{
			IntToString(iSlot, cSlot, sizeof(cSlot));
			if (DataFileExist(client, iSlot))
			{
				GetDataDate(client, iSlot, cDate, sizeof(cDate));
				Format(menuinfo, sizeof(menuinfo), " Slot %i (Stored %s, %i Props)", iSlot, cDate, GetDataProps(client, iSlot));
				menu.AddItem(cSlot, menuinfo);
			}
			else
			{
				Format(menuinfo, sizeof(menuinfo), " Slot %i (No Data)", iSlot);
				menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
			}
		}
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_DeleteMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSlot = StringToInt(info);
		
		Command_DeleteConfirmMenu(client, iSlot);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
			Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 4.1. Delete Confirm (2) Menu
*******************************************************************************************/
public Action Command_DeleteConfirmMenu(int client, int iSlot)
{
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_DeleteConfirmMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s \n \n Are you sure to DELETE slot %i?", PLUGIN_VERSION, CurrentMap, iSlot);
		menu.SetTitle(menuinfo);
		
		char cSlot[8];
		IntToString(iSlot, cSlot, sizeof(cSlot));
		Format(menuinfo, sizeof(menuinfo), " Yes, Delete it.");
		menu.AddItem(cSlot, menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " No, go back!");
		menu.AddItem("NO", menuinfo);
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_DeleteConfirmMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (!StrEqual(info, "NO"))
			DeleteData(client, StringToInt(info));
		
		Command_DeleteMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
			Command_DeleteMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 5. Permission Menu
*******************************************************************************************/
public Action Command_PermissionMenu(int client, int args)
{
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_PermissionMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s\nMap: %s\n \nSet Permission on project:\n [Private]: Only you can load the project (Default)\n [Public]: Let others to load your project\n ", PLUGIN_VERSION, CurrentMap);
		menu.SetTitle(menuinfo);
		
		char cSlot[6];
		char cDate[11];
		char cPermission[8] = "Private";
		for (int iSlot = 1; iSlot <= GetConVarInt(cviStoreSlot); iSlot++)
		{
			IntToString(iSlot, cSlot, sizeof(cSlot));
			if (DataFileExist(client, iSlot))
			{
				GetDataDate(client, iSlot, cDate, sizeof(cDate));
				
				if (bPermission[client][iSlot])
					cPermission = "Public";
				else
					cPermission = "Private";
				
				Format(menuinfo, sizeof(menuinfo), " Slot %i (Stored %s, %i Props) : [%s]", iSlot, cDate, GetDataProps(client, iSlot), cPermission);
				menu.AddItem(cSlot, menuinfo);
			}
			else
			{
				Format(menuinfo, sizeof(menuinfo), " Slot %i (No Data) : [Private]", iSlot);
				menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
			}
		}
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_PermissionMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSlot = StringToInt(info);
		
		if (iCoolDown[client] == 0)
		{
			if (bPermission[client][iSlot])
			{
				bPermission[client][iSlot] = false;
				Build_PrintToChat(client, "Slot\x04%i\x01 Permission have set to \x04Private\x01.", iSlot);
			}
			else
			{
				bPermission[client][iSlot] = true;
				Build_PrintToChat(client, "Slot\x04%i\x01 Permission have set to \x04Public\x01.", iSlot);
			}
			iCoolDown[client] = GetConVarInt(cviCoolDownsec);
			CreateTimer(0.05, Timer_CoolDownFunction, client);
		}
		else
			Build_PrintToChat(client, "Permission Function is currently cooling down, please wait \x04%i\x01 seconds.", iCoolDown[client]);
		
		Command_PermissionMenu(client, -1);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
			Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 6. LoadOthers Menu
*******************************************************************************************/
public Action Command_LoadOthersMenu(int client, int args)
{
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_LoadOthersMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s\nMap: %s\n \nLoad others project,\nPlease select a Player:\n ", PLUGIN_VERSION, CurrentMap);
		menu.SetTitle(menuinfo);
		
		char cClient[4];
		char cName[48];
		for (int i = 1; i < MAXPLAYERS; i++)if (IsValidClient(i) && i != client && !IsFakeClient(i))
		{
			IntToString(i, cClient, sizeof(cClient));
			GetClientName(i, cName, sizeof(cName));
			
			Format(menuinfo, sizeof(menuinfo), " %s", cName);
			menu.AddItem(cClient, menuinfo);
		}
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_LoadOthersMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iClient = StringToInt(info);
		
		if (IsValidClient(iClient))
		{
			Command_LoadOthersProjectsMenu(client, iClient);
			iSelectedClient[client] = iClient;
		}
		else
		{
			Build_PrintToChat(client, "Error: Client %i not found", iClient);
			Command_LoadOthersMenu(client, -1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
			Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

/*******************************************************************************************
	 6.1. LoadOthersProjects Menu
*******************************************************************************************/
public Action Command_LoadOthersProjectsMenu(int client, int selectedclient) //client, selected client
{
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_LoadOthersProjectsMenu);
		
		char cSelectedclentName[48];
		if (IsValidClient(selectedclient))
			GetClientName(selectedclient, cSelectedclentName, sizeof(cSelectedclentName));
		else
		{
			Build_PrintToChat(client, "Error: Client %i not found", selectedclient);
			Command_LoadOthersMenu(client, -1);
		}
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s\nMap: %s\n \nSelected Player: %s\n \nSelect a Slot to LOAD....", PLUGIN_VERSION, CurrentMap, cSelectedclentName);
		menu.SetTitle(menuinfo);
		
		char cSlot[6];
		char cDate[11];
		char cPermission[8] = "Private";
		for (int iSlot = 1; iSlot <= GetConVarInt(cviStoreSlot); iSlot++)
		{
			IntToString(iSlot, cSlot, sizeof(cSlot));
			if (DataFileExist(selectedclient, iSlot))
			{
				GetDataDate(selectedclient, iSlot, cDate, sizeof(cDate));
				
				if (bPermission[selectedclient][iSlot])
				{
					cPermission = "Public";
					Format(menuinfo, sizeof(menuinfo), " Slot %i (Stored %s, %i Props) : [%s]", iSlot, cDate, GetDataProps(selectedclient, iSlot), cPermission);
					menu.AddItem(cSlot, menuinfo);
				}
				else
				{
					cPermission = "Private";
					Format(menuinfo, sizeof(menuinfo), " Slot %i (Stored %s, %i Props) : [%s]", iSlot, cDate, GetDataProps(selectedclient, iSlot), cPermission);
					menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
				}
			}
			else
			{
				Format(menuinfo, sizeof(menuinfo), " Slot %i (No Data) : [Private]", iSlot);
				menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
			}
		}
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_LoadOthersProjectsMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSlot = StringToInt(info);
		
		if (IsValidClient(iSelectedClient[client]))
		{
			if (iCoolDown[client] == 0)
			{
				LoadData(client, iSelectedClient[client], iSlot);
				
				char cName[48];
				GetClientName(client, cName, sizeof(cName));
				Build_PrintToChat(iSelectedClient[client], "Player \x04%s\x01 have load your Slot\x04%i\x01!", cName, iSlot);
				PrintCenterText(iSelectedClient[client], "Player %s have load your Slot %i!", cName, iSlot);
				iCoolDown[client] = GetConVarInt(cviCoolDownsec);
				CreateTimer(0.05, Timer_CoolDownFunction, client);
			}
			else
				Build_PrintToChat(client, "Load Function is currently cooling down, please wait \x04%i\x01 seconds.", iCoolDown[client]);
		}
		
		Command_LoadOthersProjectsMenu(client, iSelectedClient[client]);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
			Command_LoadOthersMenu(client, -1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/*******************************************************************************************
	 7. CheckCache Menu
*******************************************************************************************/
public Action Command_CheckCacheMenu(int client, int args)
{
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_CheckCacheMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Save System Main Menu %s \nMap: %s\n \nPlugin Author: BattlefieldDuck\nCredits: Danct12, Leadkiller, aIM...\n \nCache System (In Development): RUNNING\n ", PLUGIN_VERSION, CurrentMap);
		menu.SetTitle(menuinfo);
		
		int iSlot = 0;
		char cDate[11];
		char cSlot[6];
		IntToString(iSlot, cSlot, sizeof(cSlot));
		if (DataFileExist(client, iSlot))
		{
			GetDataDate(client, iSlot, cDate, sizeof(cDate));
			Format(menuinfo, sizeof(menuinfo), " Cache (Stored %s, %i Props)", cDate, GetDataProps(client, iSlot));
		}
		else
			Format(menuinfo, sizeof(menuinfo), " Cache (No Data)");
		
		menu.AddItem(cSlot, menuinfo, ITEMDRAW_DISABLED);
		
		Format(menuinfo, sizeof(menuinfo), " Refresh");
		menu.AddItem("REFRESH", menuinfo);
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Handler_CheckCacheMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if (StrEqual("REFRESH", info))
			Command_CheckCacheMenu(client, 0);
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
			Command_MainMenu(client, -1);
	}
	else if (action == MenuAction_End)
		delete menu;
}


/*******************************************************************************************
	 Stock
*******************************************************************************************/
//-----------[ Load data Function ]--------------------------------------------------------------------------------------
void LoadData(int loader, int client, int slot) // Load Data from data file (loader, client in data file, slot number)
{
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	if (FileExists(cFileName))
		LoadFunction(loader, slot, cFileName);
}

void LoadDataSteamID(int loader, char[] SteamID64, int slot) // Load Data from data file (loader, client steamid64 in data file, slot number) //Special!! X Cache
{
	char cFileName[255];
	BuildPath(Path_SM, cFileName, sizeof(cFileName), "data/TF2SBSaveSystem/%s&%s@%i.tf2sb", CurrentMap, SteamID64, slot);
	
	if (FileExists(cFileName))
		LoadFunction(loader, slot, cFileName);
}

void LoadFunction(int loader, int slot, char cFileName[255])
{
	if (GetClientSpawnedEntities(loader) >= GetClientMaxHoldEntities())
	{
		ClientCommand(loader, "playgamesound \"%s\"", "buttons/button10.wav");
		Build_PrintToChat(loader, "You've hit the prop limit!");
		PrintCenterText(loader, "You've hit the prop limit!");
	}
	else if (GetConVarInt(cviLoadMode) == 2)
	{
		Handle dp;
		CreateDataTimer(0.05, Timer_LoadProps, dp);
		WritePackCell(dp, loader);
		WritePackCell(dp, slot);
		WritePackString(dp, cFileName);
		WritePackCell(dp, 0);
		WritePackCell(dp, 0);
		WritePackCell(dp, 0);
	}
	else if (GetConVarInt(cviLoadMode) == 1)
	{
		if (FileExists(cFileName))
		{
			g_hFileEditting[loader] = OpenFile(cFileName, "r");
			if (g_hFileEditting[loader] != INVALID_HANDLE)
			{
				int g_iCountEntity = 0;
				int g_iCountLoop = 0;
				char szLoadString[255];
				
				for (int i = 0; i < 4096; i++)if (ReadFileLine(g_hFileEditting[loader], szLoadString, sizeof(szLoadString)))
				{
					if (StrContains(szLoadString, "ent") != -1 && StrContains(szLoadString, ";") == -1) //Map name have ent sytax??? Holy
					{
						if (LoadProps(loader, szLoadString))
							g_iCountEntity++;
						g_iCountLoop++;
					}
					/*
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
						fSize = StringToFloat(szBuffer[10]);
						iRed = StringToInt(szBuffer[11]);
						iGreen = StringToInt(szBuffer[12]);
						iBlue = StringToInt(szBuffer[13]);
						iAlpha = StringToInt(szBuffer[14]);
						iRenderFx = StringToInt(szBuffer[15]);
						
						if (strlen(szBuffer[9]) == 0)
							iCollision = 5;
						if (strlen(szBuffer[10]) == 0)
							fSize = 1.0;
						if (strlen(szBuffer[11]) == 0)
							iRed = 255;
						if (strlen(szBuffer[12]) == 0)
							iGreen = 255;
						if (strlen(szBuffer[13]) == 0)
							iBlue = 255;
						if (strlen(szBuffer[14]) == 0)
							iAlpha = 255;
						if (strlen(szBuffer[15]) == 0)
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
								
								switch (iRenderFx)
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
								if (StrEqual(szModel, "models/props_2fort/lightbulb001.mdl"))
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
								RemoveEdict(Obj_LoadEntity);
						}
						g_iCountLoop++;
					}
					*/
					if (IsEndOfFile(g_hFileEditting[loader]))
						break;
				}
				CloseHandle(g_hFileEditting[loader]);
				
				if (slot == 0)
					Build_PrintToChat(loader, "Load Result >> Loaded: \x04%i\x01, Error: \x04%i\x01 >> Cache Loaded", g_iCountEntity, g_iCountLoop - g_iCountEntity);
				else
					Build_PrintToChat(loader, "Load Result >> Loaded: \x04%i\x01, Error: \x04%i\x01 >> Loaded Slot\x04%i\x01", g_iCountEntity, g_iCountLoop - g_iCountEntity, slot);
				
				if (GetClientSpawnedEntities(loader) >= GetClientMaxHoldEntities())
				{
					ClientCommand(loader, "playgamesound \"%s\"", "buttons/button10.wav");
					Build_PrintToChat(loader, "You've hit the prop limit!");
					PrintCenterText(loader, "You've hit the prop limit!");
				}
			}
		}
	}
}

public Action Timer_LoadProps(Handle timer, Handle dp)
{
	ResetPack(dp);
	int loader = ReadPackCell(dp);
	int slot = ReadPackCell(dp);
	char cFileName[255];
	ReadPackString(dp, cFileName, sizeof(cFileName));
	int Fileline = ReadPackCell(dp);
	int g_iCountEntity = ReadPackCell(dp);
	int g_iCountLoop = ReadPackCell(dp);
	
	if (FileExists(cFileName))
	{
		g_hFileEditting[loader] = OpenFile(cFileName, "r");
		if (g_hFileEditting[loader] != INVALID_HANDLE)
		{
			char szLoadString[255];
			
			for (int i = 0; i < Fileline; i++)
			ReadFileLine(g_hFileEditting[loader], szLoadString, sizeof(szLoadString));
			
			for (int i = 0; i < GetConVarInt(cviLoadProps); i++)if (ReadFileLine(g_hFileEditting[loader], szLoadString, sizeof(szLoadString)))
			{
				Fileline++;
				if (StrContains(szLoadString, "ent") != -1 && StrContains(szLoadString, ";") == -1) //Map name have ent sytax??? Holy
				{
					if (LoadProps(loader, szLoadString))
						g_iCountEntity++;
					g_iCountLoop++;
				}
				/*
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
					fSize = StringToFloat(szBuffer[10]);
					iRed = StringToInt(szBuffer[11]);
					iGreen = StringToInt(szBuffer[12]);
					iBlue = StringToInt(szBuffer[13]);
					iAlpha = StringToInt(szBuffer[14]);
					iRenderFx = StringToInt(szBuffer[15]);
					
					if (strlen(szBuffer[9]) == 0)
						iCollision = 5;
					if (strlen(szBuffer[10]) == 0)
						fSize = 1.0;
					if (strlen(szBuffer[11]) == 0)
						iRed = 255;
					if (strlen(szBuffer[12]) == 0)
						iGreen = 255;
					if (strlen(szBuffer[13]) == 0)
						iBlue = 255;
					if (strlen(szBuffer[14]) == 0)
						iAlpha = 255;
					if (strlen(szBuffer[15]) == 0)
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
							
							switch (iRenderFx)
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
							if (StrEqual(szModel, "models/props_2fort/lightbulb001.mdl"))
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
							RemoveEdict(Obj_LoadEntity);
					}
					g_iCountLoop++;
				}
				*/
				if (IsEndOfFile(g_hFileEditting[loader]))
					break;
			}
			if (IsEndOfFile(g_hFileEditting[loader]))
			{
				if (slot == 0)
					Build_PrintToChat(loader, "Load Result >> Loaded: \x04%i\x01, Error: \x04%i\x01 >> Cache Loaded", g_iCountEntity, g_iCountLoop - g_iCountEntity);
				else
					Build_PrintToChat(loader, "Load Result >> Loaded: \x04%i\x01, Error: \x04%i\x01 >> Loaded Slot\x04%i\x01", g_iCountEntity, g_iCountLoop - g_iCountEntity, slot);
				
				if (GetClientSpawnedEntities(loader) >= GetClientMaxHoldEntities())
				{
					ClientCommand(loader, "playgamesound \"%s\"", "buttons/button10.wav");
					Build_PrintToChat(loader, "You've hit the prop limit!");
					PrintCenterText(loader, "You've hit the prop limit!");
				}
			}
			else
			{
				CreateDataTimer(GetConVarFloat(cviLoadSec), Timer_LoadProps, dp);
				WritePackCell(dp, loader);
				WritePackCell(dp, slot);
				WritePackString(dp, cFileName);
				WritePackCell(dp, Fileline);
				WritePackCell(dp, g_iCountEntity);
				WritePackCell(dp, g_iCountLoop);
			}
			CloseHandle(g_hFileEditting[loader]);
		}
	}
}

bool LoadProps(int loader, char szLoadString[255])
{
	float fOrigin[3], fAngles[3], fSize;
	char szModel[128], szClass[64], szFormatStr[255], DoorIndex[5], szBuffer[20][255];
	int Obj_LoadEntity, iCollision, iRed, iGreen, iBlue, iAlpha, iRenderFx, iRandom;
	RenderFx FxRender = RENDERFX_NONE;
	
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
	fSize = StringToFloat(szBuffer[10]);
	iRed = StringToInt(szBuffer[11]);
	iGreen = StringToInt(szBuffer[12]);
	iBlue = StringToInt(szBuffer[13]);
	iAlpha = StringToInt(szBuffer[14]);
	iRenderFx = StringToInt(szBuffer[15]);
	
	if (strlen(szBuffer[9]) == 0)
		iCollision = 5;
	if (strlen(szBuffer[10]) == 0)
		fSize = 1.0;
	if (strlen(szBuffer[11]) == 0)
		iRed = 255;
	if (strlen(szBuffer[12]) == 0)
		iGreen = 255;
	if (strlen(szBuffer[13]) == 0)
		iBlue = 255;
	if (strlen(szBuffer[14]) == 0)
		iAlpha = 255;
	if (strlen(szBuffer[15]) == 0)
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
			
			switch (iRenderFx)
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
			
			//light bulb
			if (StrEqual(szModel, "models/props_2fort/lightbulb001.mdl"))
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
			
			return true;
		}
		else
			RemoveEdict(Obj_LoadEntity);
	}
	return false;
}

//-----------[ Save data Function ]-------------------------------------
void SaveData(int client, int slot) // Save Data from data file (CLIENT INDEX, SLOT ( 0 = cache, 1 >= save))
{
	char SteamID64[64];
	GetClientSteamID(client, SteamID64);
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	int g_iCountEntity = -1;
	//----------------------------------------------------Open file and start write-----------------------------------------------------------------
	g_hFileEditting[client] = OpenFile(cFileName, "w");
	if (g_hFileEditting[client] != INVALID_HANDLE)
	{
		g_iCountEntity = 0;
		
		float fOrigin[3], fAngles[3], fSize;
		char szModel[64], szTime[64], szClass[64];
		int iOrigin[3], iAngles[3], iCollision, iRed, iGreen, iBlue, iAlpha, iRenderFx;
		RenderFx EntityRenderFx;
		
		FormatTime(szTime, sizeof(szTime), "%Y/%m/%d");
		WriteFileLine(g_hFileEditting[client], ";- Saved Map: %s", CurrentMap);
		WriteFileLine(g_hFileEditting[client], ";- SteamID64: %s (%N)", SteamID64, client);
		WriteFileLine(g_hFileEditting[client], ";- Data Slot: %i", slot);
		WriteFileLine(g_hFileEditting[client], ";- Saved on : %s", szTime);
		for (int i = MaxClients; i < MAX_HOOK_ENTITIES; i++)if (IsValidEdict(i))
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
				{
					iRenderFx = 1;
					if (EntityRenderFx == RENDERFX_PULSE_SLOW)
						iRenderFx = 2;
					else if (EntityRenderFx == RENDERFX_PULSE_FAST)
						iRenderFx = 3;
					else if (EntityRenderFx == RENDERFX_PULSE_SLOW_WIDE)
						iRenderFx = 4;
					else if (EntityRenderFx == RENDERFX_PULSE_FAST_WIDE)
						iRenderFx = 5;
					else if (EntityRenderFx == RENDERFX_FADE_SLOW)
						iRenderFx = 6;
					else if (EntityRenderFx == RENDERFX_FADE_FAST)
						iRenderFx = 7;
					else if (EntityRenderFx == RENDERFX_SOLID_SLOW)
						iRenderFx = 8;
					else if (EntityRenderFx == RENDERFX_SOLID_FAST)
						iRenderFx = 9;
					else if (EntityRenderFx == RENDERFX_STROBE_SLOW)
						iRenderFx = 10;
					else if (EntityRenderFx == RENDERFX_STROBE_FAST)
						iRenderFx = 11;
					else if (EntityRenderFx == RENDERFX_STROBE_FASTER)
						iRenderFx = 12;
					else if (EntityRenderFx == RENDERFX_FLICKER_SLOW)
						iRenderFx = 13;
					else if (EntityRenderFx == RENDERFX_FLICKER_FAST)
						iRenderFx = 14;
					else if (EntityRenderFx == RENDERFX_NO_DISSIPATION)
						iRenderFx = 15;
					else if (EntityRenderFx == RENDERFX_DISTORT)
						iRenderFx = 16;
					else if (EntityRenderFx == RENDERFX_HOLOGRAM)
						iRenderFx = 17;
				}
				
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
		WriteFileLine(g_hFileEditting[client], ";- Data File End | %i Props Saved", g_iCountEntity);
		WriteFileLine(g_hFileEditting[client], ";- File Generated By TF2Sandbox-SaveSystem.smx v%f", g_iCountEntity, GetConVarFloat(cvPluginVersion));
		
		FlushFile(g_hFileEditting[client]);
		//-------------------------------------------------------------Close file-------------------------------------------------------------------
		CloseHandle(g_hFileEditting[client]);
		
		if (FileExists(cFileName) && g_iCountEntity == 0)
		{
			if (slot != 0)
				Build_PrintToChat(client, "Save Result >> ERROR!!!. You didnt build anything, please build something and save again.");
			
			DeleteFile(cFileName);
		}
		else if (slot != 0)
			Build_PrintToChat(client, "Save Result >> Saved: \x04%i\x01, Error:\x04 0\x01 >> Saved in Slot\x04%i\x01", g_iCountEntity, slot);
	}
	if (g_iCountEntity == -1)
	{
		if (slot == 0)
			Build_PrintToChat(client, "Cache Result >> ERROR!!!, please contact server admin.");
		else
			Build_PrintToChat(client, "Save Result >> ERROR!!! >> Error in Slot\x04%i\x01, please contact server admin.", slot);
	}
}

//-----------[ Delete data Function ]-----------------------------------
void DeleteData(int client, int slot) // Delete Data from data file
{
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	if (DataFileExist(client, slot))
	{
		DeleteFile(cFileName);
		
		if (DataFileExist(client, slot))
			Build_PrintToChat(client, "Fail to deleted Slot\x04%i\x01 Data, please contact server admin.", slot);
		else
			Build_PrintToChat(client, "Deleted Slot\x04%i\x01 Data successfully", slot);
	}
}

//-----------[ Get data Function ]----------------------------------------------------------------------------------
void GetDataDate(int client, int slot, char[] data, int maxlength) //Get the date inside the data file
{
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	if (DataFileExist(client, slot))
	{
		g_hFileEditting[client] = OpenFile(cFileName, "r");
		if (g_hFileEditting[client] != INVALID_HANDLE)
		{
			char cDate[11], szBuffer[6][255];
			char szLoadString[255];
			for (int i = 1; i < MAX_HOOK_ENTITIES; i++)if (ReadFileLine(g_hFileEditting[client], szLoadString, sizeof(szLoadString)))
			{
				if (StrContains(szLoadString, "Saved on :") != -1)
				{
					ExplodeString(szLoadString, " ", szBuffer, 6, 255);
					Format(cDate, sizeof(cDate), "%s", szBuffer[4]);
					strcopy(data, maxlength, cDate);
					break;
				}
			}
			CloseHandle(g_hFileEditting[client]);
		}
	}
}

int GetDataProps(int client, int slot) //Get how many props inside data file
{
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	if (DataFileExist(client, slot))
	{
		g_hFileEditting[client] = OpenFile(cFileName, "r");
		if (g_hFileEditting[client] != INVALID_HANDLE)
		{
			int iProps;
			char szBuffer[9][255];
			char szLoadString[255];
			for (int i = 1; i < MAX_HOOK_ENTITIES; i++)if (ReadFileLine(g_hFileEditting[client], szLoadString, sizeof(szLoadString)))
			{
				if (StrContains(szLoadString, "Data File End |") != -1)
				{
					ExplodeString(szLoadString, " ", szBuffer, 9, 255);
					iProps = StringToInt(szBuffer[5]);
					break;
				}
			}
			CloseHandle(g_hFileEditting[client]);
			return iProps;
		}
	}
	return -1;
}

void GetBuildPath(int client, int slot, char[] cFileNameout) //Get the sourcemod Build path
{
	char SteamID64[64];
	GetClientSteamID(client, SteamID64);
	
	char cFileName[255];
	if (slot == 0)
		BuildPath(Path_SM, cFileName, sizeof(cFileName), "data/TF2SBCache/%s&%s.tf2sb", CurrentMap, SteamID64);
	else
		BuildPath(Path_SM, cFileName, sizeof(cFileName), "data/TF2SBSaveSystem/%s&%s@%i.tf2sb", CurrentMap, SteamID64, slot);
	
	strcopy(cFileNameout, sizeof(cFileName), cFileName);
}

void GetClientSteamID(int client, char[] SteamID64out)
{
	char SteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, SteamID64, sizeof(SteamID64), true);
	
	strcopy(SteamID64out, sizeof(SteamID64), SteamID64);
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

//-----------[ Check Function ]--------------------------------------------------------
bool DataFileExist(int client, int slot) //Is the data file exist? true : false 
{
	char cFileName[255];
	GetBuildPath(client, slot, cFileName);
	
	if (FileExists(cFileName))
		return true;
	return false;
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}

int GetClientInGame()
{
	int iCount = 0;
	for (int i = 1; i < MAXPLAYERS; i++)if (IsValidClient(i) && !IsFakeClient(i))
		iCount++;
	
	return iCount;
}
