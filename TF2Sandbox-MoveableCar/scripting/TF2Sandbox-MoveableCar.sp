#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Battlefield Duck"
#define PLUGIN_VERSION "2.5"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>
#include <build>
#include <vphysics>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] SandBox - Moveable Car", 
	author = PLUGIN_AUTHOR, 
	description = "Moveable Car System for TF2SB", 
	version = PLUGIN_VERSION, 
	url = "http://steamcommunity.com/id/battlefieldduck/"
};

Handle g_hHud; //sync
Handle g_hHud2; //sync2
Handle g_iSpeedlimit;

bool bEnabled = true;
int g_iSpawnCar[MAXPLAYERS + 1] = -1;

float g_fCarSpeed[MAXPLAYERS + 1] = 0.0;
int g_iCoolDown[MAXPLAYERS + 1] = 0;

public void OnPluginStart()
{
	RegAdminCmd("sm_sbcar", Command_SandboxCar, 0);
	
	CreateConVar("sm_tf2sb_car_version", PLUGIN_VERSION, "", FCVAR_SPONLY | FCVAR_NOTIFY);
	g_iSpeedlimit = CreateConVar("sm_tf2sb_car_speedlimit", "450", "Speed limit of car (100 - 1000)", 0, true, 100.0, true, 1000.0);
	g_hHud = CreateHudSynchronizer();
	g_hHud2 = CreateHudSynchronizer();
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++) g_iSpawnCar[i] = -1;
	TagsCheck("SandBox_Addons");
}

public void OnConfigsExecuted()
{
	TagsCheck("SandBox_Addons");
}

public void OnClientPutInServer(int client)
{
	g_iSpawnCar[client] = -1;
}

/*******************************************************************************************
	Main Menu
*******************************************************************************************/
public Action Command_SandboxCar(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_MainMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Car Main Menu v%s \n ", PLUGIN_VERSION);
		menu.SetTitle(menuinfo);
		
		if (IsValidEntity(g_iSpawnCar[client]))
		{
			Format(menuinfo, sizeof(menuinfo), " Delete the car ", client);
			menu.AddItem("DELETECAR", menuinfo);
		}
		else
		{
			Format(menuinfo, sizeof(menuinfo), " Spawn a car ", client);
			menu.AddItem("BUILDCAR", menuinfo);
		}
		
		if (IsValidEntity(g_iSpawnCar[client]))
		{
			Format(menuinfo, sizeof(menuinfo), " Set Colour ", client);
			menu.AddItem("SETCOLOR", menuinfo);
		}
		else
		{
			Format(menuinfo, sizeof(menuinfo), " Set Colour ", client);
			menu.AddItem("SETCOLOR", menuinfo, ITEMDRAW_DISABLED);
		}
		
		Format(menuinfo, sizeof(menuinfo), " How to Control the car? ", client);
		menu.AddItem("CONTROL", menuinfo);
		
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
		
		if (StrEqual(info, "DELETECAR"))
		{
			if (IsValidEntity(g_iSpawnCar[client]))
			{
				AcceptEntityInput(g_iSpawnCar[client], "Kill");
				g_iSpawnCar[client] = -1;
				Build_SetLimit(client, -1);
			}
			//DeleteDispenser(client, g_iDispenser[client]);
			Command_SandboxCar(client, -1);
			
		}
		else if (StrEqual(info, "BUILDCAR"))
		{
			Command_SelectCar(client, -1);
		}
		else if (StrEqual(info, "SETCOLOR"))
		{
			Command_ColorCar(client, -1);
		}
		else if (StrEqual(info, "CONTROL"))
		{
			Command_ControlCar(client, -1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
			FakeClientCommand(client, "sm_build");
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}
/*******************************************************************************************
	Select Menu
*******************************************************************************************/
public Action Command_SelectCar(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_SelectMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Car Main Menu v%s \nPlease select:\n ", PLUGIN_VERSION);
		menu.SetTitle(menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " [HL2] Simple Car", client);
		menu.AddItem("1", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " [HL2] White Car", client);
		menu.AddItem("2", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " [HL2] Green Car", client);
		menu.AddItem("3", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " [HL2] AirBoat", client);
		menu.AddItem("4", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " [TF2] Bus", client);
		menu.AddItem("5", menuinfo);
		
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}
public int Handler_SelectMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		if(g_iCoolDown[client] == 0)
		{
			g_iSpawnCar[client] = BuildCar(client, StringToInt(info));
			
			if(Build_ReturnEntityOwner(g_iSpawnCar[client]) != client)
			{
				if(IsValidEntity(g_iSpawnCar[client]))	AcceptEntityInput(g_iSpawnCar[client], "kill");
				Build_PrintToChat(client, "Fail to spawn the car.");
				g_iSpawnCar[client] = -1;
			}	
			else
				Build_PrintToChat(client, "The car spawned.");
				
			g_iCoolDown[client] = 1;
			CreateTimer(0.05, Timer_CoolDownFunction, client);
		}
			
		Command_SandboxCar(client, -1);
		
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
			Command_SandboxCar(client, -1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/*******************************************************************************************
	Colour Menu
*******************************************************************************************/
public Action Command_ColorCar(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_ColorMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Car Colour Menu v%s \n Please select a colour below: \n ", PLUGIN_VERSION);
		menu.SetTitle(menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Default ", client);
		menu.AddItem("0", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Red ", client);
		menu.AddItem("1", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Orange ", client);
		menu.AddItem("2", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Yellow ", client);
		menu.AddItem("3", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Green ", client);
		menu.AddItem("4", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Blue ", client);
		menu.AddItem("5", menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Purple ", client);
		menu.AddItem("6", menuinfo);
		
		
		
		menu.ExitBackButton = true;
		menu.ExitButton = false;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}
public int Handler_ColorMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int info_num = StringToInt(info);
		
		int red = 255;
		int green = 255;
		int blue = 255;
		
		if (info_num == 1)
		{
			green = 0;
			blue = 0;
		}
		else if (info_num == 2)
		{
			green = 128;
			blue = 0;
		}
		else if (info_num == 3)
		{
			blue = 0;
		}
		else if (info_num == 4)
		{
			red = 0;
			blue = 0;
		}
		else if (info_num == 5)
		{
			red = 0;
			green = 128;
		}
		else if (info_num == 6)
		{
			red = 127;
			green = 0;
		}
		
		if (IsValidEntity(g_iSpawnCar[client]))
		{
			SetEntityRenderColor(g_iSpawnCar[client], red, green, blue, _);
			Command_SandboxCar(client, -1);
		}
		else
		{
			Command_ColorCar(client, -1);
			Build_PrintToChat(client, "ERROR. Your Car is INVALID!");
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
			Command_SandboxCar(client, -1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/*******************************************************************************************
	Main Menu
*******************************************************************************************/
public Action Command_ControlCar(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	if (bEnabled)
	{
		char menuinfo[255];
		Menu menu = new Menu(Handler_ControlMenu);
		
		Format(menuinfo, sizeof(menuinfo), "TF2 Sandbox - Car Control Menu v%s \n ", PLUGIN_VERSION);
		menu.SetTitle(menuinfo);
		
		Format(menuinfo, sizeof(menuinfo), " Hold Ctrl key(DUCK) to drive the car.", client);
		menu.AddItem("0", menuinfo, ITEMDRAW_DISABLED);
		
		Format(menuinfo, sizeof(menuinfo), " WASD to control the movement and direction.", client);
		menu.AddItem("1", menuinfo, ITEMDRAW_DISABLED);
		
		Format(menuinfo, sizeof(menuinfo), " Press R to beep beep.", client);
		menu.AddItem("2", menuinfo, ITEMDRAW_DISABLED);
		
		menu.ExitBackButton = true;
		menu.ExitButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}
public int Handler_ControlMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack)
		{
			Command_SandboxCar(client, -1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/*******************************************************************************************
	Main Function
*******************************************************************************************/
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	if (IsValidEntity(g_iSpawnCar[client]) && Phys_IsPhysicsObject(g_iSpawnCar[client]) && Phys_IsGravityEnabled(g_iSpawnCar[client]))
	{
		int iSpeedlimit = GetConVarInt(g_iSpeedlimit);
		float clientEye[3], fcarPosition[3], fcarAngle[3], fCarVel[3];
		
		GetClientEyePosition(client, clientEye);
		GetEntPropVector(g_iSpawnCar[client], Prop_Send, "m_vecOrigin", fcarPosition);
		GetEntPropVector(g_iSpawnCar[client], Prop_Send, "m_angRotation", fcarAngle);
		
		char szModel[128];
		GetEntPropString(g_iSpawnCar[client], Prop_Data, "m_ModelName", szModel, sizeof(szModel));
		
		//PrintCenterText(client, "Distance %f \n Angle %f %f %f", GetVectorDistance(clientEye, fcarPosition), fcarAngle[0], fcarAngle[1], fcarAngle[2]);
		
		if (GetVectorDistance(clientEye, fcarPosition) < 150.0)
		{
			if (buttons & IN_DUCK)
			{
				TeleportEntity(client, fcarPosition, NULL_VECTOR, NULL_VECTOR);
				
				//Movement
				{
					//Angle fix
					{
						if (fcarAngle[0] > 0)
						{
							fcarAngle[0] -= fcarAngle[0] / 40;
						}
						else if (fcarAngle[0] < 0)
						{
							fcarAngle[0] += fcarAngle[0] / -40;
						}
						
						if (fcarAngle[2] > 0)
						{
							fcarAngle[2] -= fcarAngle[2] / 40;
						}
						else if (fcarAngle[2] < 0)
						{
							fcarAngle[2] += fcarAngle[2] / -40;
						}
					}
					
					if (g_fCarSpeed[client] != 0.0 && buttons & IN_MOVELEFT && !(buttons & IN_MOVERIGHT)) //Left
					{  //Left
						if (buttons & IN_FORWARD && g_fCarSpeed[client] < iSpeedlimit)
						{
							g_fCarSpeed[client] += 1.0;
						}
						else if (buttons & IN_BACK && g_fCarSpeed[client] > iSpeedlimit * -1)
						{
							g_fCarSpeed[client] -= 1.0;
						}
						else if (g_fCarSpeed[client] > 0)
						{  //Reduce speed due to ground + air friction
							g_fCarSpeed[client] -= 1.0;
						}
						else if (g_fCarSpeed[client] < 0)
						{  //Reduce speed due to ground + air friction
							g_fCarSpeed[client] += 1.0;
						}
						
						if (g_fCarSpeed[client] > 0)
							fcarAngle[1] += g_fCarSpeed[client] / 500;
						else
							fcarAngle[1] += g_fCarSpeed[client] / 500;
						
						TeleportEntity(g_iSpawnCar[client], NULL_VECTOR, fcarAngle, NULL_VECTOR);
						
						if (StrEqual(szModel, "models/airboat.mdl"))
							fcarAngle[1] += 90.0;
						
						AnglesNormalize(fcarAngle);
						
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}
					else if (g_fCarSpeed[client] != 0.0 && !(buttons & IN_MOVELEFT) && buttons & IN_MOVERIGHT) //Right
					{  //Right
						if (buttons & IN_FORWARD && g_fCarSpeed[client] < iSpeedlimit)
						{
							g_fCarSpeed[client] += 1.0;
						}
						else if (buttons & IN_BACK && g_fCarSpeed[client] > iSpeedlimit * -1)
						{
							g_fCarSpeed[client] -= 1.0;
						}
						else if (g_fCarSpeed[client] > 0)
						{  //Reduce speed due to ground + air friction
							g_fCarSpeed[client] -= 1.0;
						}
						else if (g_fCarSpeed[client] < 0)
						{  //Reduce speed due to ground + air friction
							g_fCarSpeed[client] += 1.0;
						}
						
						if (g_fCarSpeed[client] > 0)
							fcarAngle[1] -= g_fCarSpeed[client] / 500;
						else
							fcarAngle[1] -= g_fCarSpeed[client] / 500;
						
						TeleportEntity(g_iSpawnCar[client], NULL_VECTOR, fcarAngle, NULL_VECTOR);
						
						
						if (StrEqual(szModel, "models/airboat.mdl"))
							fcarAngle[1] += 90.0;
						
						AnglesNormalize(fcarAngle);
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}
					else if (buttons & IN_FORWARD && !(buttons & IN_BACK) && g_fCarSpeed[client] < iSpeedlimit) //Forward
					{  //Forward
						g_fCarSpeed[client] += 2.0;
						
						if (StrEqual(szModel, "models/airboat.mdl"))
							fcarAngle[1] += 90.0;
						
						AnglesNormalize(fcarAngle);
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}
					else if (buttons & IN_BACK && !(buttons & IN_FORWARD) && g_fCarSpeed[client] > iSpeedlimit * -1) //Back
					{  //Back
						g_fCarSpeed[client] -= 2.0;
						
						if (StrEqual(szModel, "models/airboat.mdl"))
							fcarAngle[1] += 90.0;
						
						AnglesNormalize(fcarAngle);
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}
					else if (g_fCarSpeed[client] > 0) //Reduce speed due to ground + air friction
					{  //Reduce speed due to ground + air friction
						g_fCarSpeed[client] -= 1.0;
						
						if (StrEqual(szModel, "models/airboat.mdl"))
							fcarAngle[1] += 90.0;
						
						AnglesNormalize(fcarAngle);
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}
					else if (g_fCarSpeed[client] < 0) //Reduce speed due to ground + air friction
					{  //Reduce speed due to ground + air friction
						g_fCarSpeed[client] += 1.0;
						
						if (StrEqual(szModel, "models/airboat.mdl"))
							fcarAngle[1] += 90.0;
						
						AnglesNormalize(fcarAngle);
						GetVecCar(fcarAngle, g_fCarSpeed[client], fCarVel);
						Phys_SetVelocity(g_iSpawnCar[client], fCarVel, NULL_VECTOR, true);
					}
					
					
					if (buttons & IN_RELOAD) //Break
					{
						char cSoundPath[100] = "ambient_mp3/mvm_warehouse/car_horn_01.mp3";
						if (StrEqual(szModel, "models/airboat.mdl"))
							cSoundPath = "ambient_mp3/mvm_warehouse/car_horn_01.mp3";
						
						else if (StrEqual(szModel, "models/props_vehicles/car004a.mdl"))
							cSoundPath = "ambient_mp3/mvm_warehouse/car_horn_02.mp3";
						
						else if (StrEqual(szModel, "models/props_vehicles/car005a.mdl"))
							cSoundPath = "ambient_mp3/mvm_warehouse/car_horn_03.mp3";
						
						else if (StrEqual(szModel, "models/airboat.mdl"))
							cSoundPath = "ambient_mp3/mvm_warehouse/car_horn_04.mp3";
						
						else if (StrEqual(szModel, "models/props_soho/bus001.mdl"))
							cSoundPath = "ambient_mp3/mvm_warehouse/car_horn_05.mp3";
						
						PrecacheSound(cSoundPath);
						EmitSoundToAll(cSoundPath, g_iSpawnCar[client], SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS);
					}
				}
				
				
				if (StrEqual(szModel, "models/airboat.mdl"))
					fcarPosition[2] += 13.0;
				else if (StrEqual(szModel, "models/props_well/hand_truck01.mdl"))
					fcarPosition[2] += 13.0;
				else
					fcarPosition[2] -= 25.5;
				
				TeleportEntity(client, fcarPosition, NULL_VECTOR, NULL_VECTOR);
				
				SetHudTextParams(-1.0, 0.8, 0.01, 255, 215, 0, 255, 1, 6.0, 0.5, 0.5);
				ShowSyncHudText(client, g_hHud2, "Speed ⁅%i⁆", RoundFloat(g_fCarSpeed[client]));
				
				//PrintCenterText(client, "Distance %f \n Angle %f %f %f \n Vel %f %f %f", GetVectorDistance(clientEye, fcarPosition), fcarAngle[0], fcarAngle[1], fcarAngle[2], fCarVel[0], fCarVel[1], fCarVel[2]);
			}
			else if (!(buttons & IN_SCORE))
			{
				g_fCarSpeed[client] = 0.0;
				SetHudTextParams(-1.0, 0.6, 0.01, 255, 215, 0, 255, 1, 6.0, 0.5, 0.5);
				ShowSyncHudText(client, g_hHud, "Hold Ctrl(DUCK) to drive the car");
			}
		}
	}
	return Plugin_Continue;
}

int BuildCar(int client, int model)
{
	char strModel[100];
	
	if (model == 1)
		strcopy(strModel, sizeof(strModel), "models/props_vehicles/car002a.mdl");
	else if (model == 2)
		strcopy(strModel, sizeof(strModel), "models/props_vehicles/car004a.mdl");
	else if (model == 3)
		strcopy(strModel, sizeof(strModel), "models/props_vehicles/car005a.mdl");
	else if (model == 4)
		strcopy(strModel, sizeof(strModel), "models/airboat.mdl");
	else if (model == 5)
		strcopy(strModel, sizeof(strModel), "models/props_soho/bus001.mdl");
	//strcopy(strModel, sizeof(strModel), "models/props_vehicles/truck001a.mdl");
	
	int car = CreateEntityByName("prop_physics_override");
	
	if (car > MaxClients && IsValidEntity(car))
	{
		SetEntProp(car, Prop_Send, "m_nSolidType", 6);
		SetEntProp(car, Prop_Data, "m_nSolidType", 6);
		Build_RegisterEntityOwner(car, client);
		PrecacheModel(strModel);
		DispatchKeyValue(car, "model", strModel);
		float fOrigin[3];
		GetClientEyePosition(client, fOrigin);
		TeleportEntity(car, fOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(car);
		
		if (Phys_IsPhysicsObject(car))
		{
			Phys_EnableGravity(car, true);
			Phys_EnableMotion(car, true);
			Phys_EnableCollisions(car, true);
			Phys_EnableDrag(car, false);
		}
	}
	return car;
}

public Action Timer_CoolDownFunction(Handle timer, int client)
{
	g_iCoolDown[client] -= 1;
	
	if (g_iCoolDown[client] >= 1)	CreateTimer(1.0, Timer_CoolDownFunction, client);
	else	g_iCoolDown[client] = 0;
}

int BuildDispenser(int iBuilder)
{
	int iTeam = GetClientTeam(iBuilder);
	int iHealth = 150;
	int iAmmo = 0;
	char strModel[100];
	strcopy(strModel, sizeof(strModel), "models/buildables/dispenser.mdl");
	
	int iDispenser = CreateEntityByName("obj_dispenser");
	if (iDispenser > MaxClients && IsValidEntity(iDispenser))
	{
		DispatchSpawn(iDispenser);
		
		SetEntityModel(iDispenser, strModel);
		
		SetVariantInt(iTeam);
		AcceptEntityInput(iDispenser, "TeamNum");
		SetVariantInt(iTeam);
		AcceptEntityInput(iDispenser, "SetTeam");
		
		ActivateEntity(iDispenser);
		
		SetEntProp(iDispenser, Prop_Send, "m_iObjectType", TFObject_Dispenser);
		SetEntProp(iDispenser, Prop_Send, "m_iTeamNum", iTeam);
		SetEntProp(iDispenser, Prop_Send, "m_nSkin", iTeam - 2);
		SetEntProp(iDispenser, Prop_Send, "m_iHighestUpgradeLevel", 3);
		SetEntPropFloat(iDispenser, Prop_Send, "m_flPercentageConstructed", 100.0);
		float VecMax[3] =  { -1.354, 137.2, 0.0 };
		SetEntPropVector(iDispenser, Prop_Send, "m_vecBuildMaxs", VecMax);
		SetEntPropEnt(iDispenser, Prop_Send, "m_hBuilder", iBuilder);
		SetEntProp(iDispenser, Prop_Send, "m_iAmmoMetal", iAmmo);
		SetEntProp(iDispenser, Prop_Send, "m_iHealth", iHealth);
		SetEntProp(iDispenser, Prop_Send, "m_iMaxHealth", iHealth);
		
		return iDispenser;
	}
	return 0;
}

void DeleteDispenser(int client, int DispenserIndex)
{
	if (IsValidEntity(DispenserIndex) && Build_ReturnEntityOwner(DispenserIndex) == client)
	{
		AcceptEntityInput(DispenserIndex, "Kill");
	}
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}

void GetVecCar(float angle[3], float speed, float outVel[3])
{
	float local_angle[3];
	local_angle[0] *= -1.0;
	local_angle[0] = DegToRad(angle[0]);
	local_angle[1] = DegToRad(angle[1]);
	local_angle[2] *= -1.0;
	local_angle[2] = DegToRad(angle[2]);
	
	outVel[0] = speed * Cosine(local_angle[0]) * Cosine(local_angle[1]);
	outVel[1] = speed * Cosine(local_angle[0]) * Sine(local_angle[1]);
	outVel[2] = speed * Sine(local_angle[0]) * Cosine(local_angle[1]) * Sine(local_angle[2]); //speed*Sine(local_angle[0]); 
}

public void AnglesNormalize(float vAngles[3])
{
	while (vAngles[0] > 89.0)vAngles[0] -= 360.0;
	while (vAngles[0] < -89.0)vAngles[0] += 360.0;
	while (vAngles[1] > 180.0)vAngles[1] -= 360.0;
	while (vAngles[1] < -180.0)vAngles[1] += 360.0;
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