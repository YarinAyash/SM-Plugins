#include <sourcemod>
#include <sdktools>
#include <sdktools_sound>
#include <cstrike>
#include <sdkhooks>
#include <zombiereloaded>

#pragma semicolon 1

#define VERSION "1.5 public version"

new offsEyeAngle0;

new g_iCredits[MAXPLAYERS+1];

new bool:g_Bird[MAXPLAYERS+1] = {false, ...};
new bool:x2Damgae[MAXPLAYERS+1] = {false, ...};

new g_ClientTrailGreenEntity[ MAXPLAYERS + 1 ] = { -1, ... };
new g_ClientTrailBlueEntity[ MAXPLAYERS + 1 ] = { -1, ... };


new Handle:kvProps = INVALID_HANDLE;

new Handle:cvarCreditsInfect = INVALID_HANDLE;
new Handle:cvarCreditsKill = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "ZShop",
	author = "EGood",
	description = "For any skills in zm",
	version = VERSION,
	url = "http://GameX.co.il/"
};

public OnPluginStart()
{

	LoadTranslations("zshop.phrases");
	LoadTranslations("common.phrases");
	
	// ======================================================================
	
	HookEvent("player_death", PlayerDeath);
	HookEvent( "player_spawn", EventPlayerSpawn );
	HookEvent( "player_death", EventPlayerDeath );
	HookEvent( "round_end", EventRoundEnd );	
	
	// ======================================================================

	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	
	// ======================================================================   
	
	RegConsoleCmd("sm_zshop", StartMenu);
	RegConsoleCmd("sm_zcredits", MyCredits);
	RegAdminCmd("sm_setcredits", SetCredits, ADMFLAG_RCON);
	
	// ======================================================================
	
	offsEyeAngle0 = FindSendPropInfo("CCSPlayer", "m_angEyeAngles[0]");
	
	if (offsEyeAngle0 == -1)
	{
		SetFailState("Couldn't find \"m_angEyeAngles[0]\"!");
	}
	
	// ======================================================================
	
	cvarCreditsInfect = CreateConVar("zshop_credits_infect", "1", "The number of credits given for infecting a human as zombie");
	cvarCreditsKill = CreateConVar("zshop_credits_kill", "5", "The number of credits given for killing a zombie as human");
	
	AutoExecConfig(true, "zshop");	
	
	CreateConVar("gs_zshop_version", VERSION, "ZShop By EGood", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public OnPluginEnd( )
{

    for(new i = 1; i < MAXPLAYERS; i++)
        ClearClientTrail(i);
}

public OnConfigsExecuted()
{
	
	PrecacheModel("models/pigeon.mdl");
	
	PrecacheModel("models/crow.mdl");
	
}

public OnMapStart()
{
    for(new i = 1; i < MAXPLAYERS; i++)
        ClearClientTrail(i);

    if (kvProps != INVALID_HANDLE)
        CloseHandle(kvProps);
		
    kvProps = CreateKeyValues("zprops");
    
    decl String:path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/zprops.txt");
    
    if (!FileToKeyValues(kvProps, path))
    {
		SetFailState("\"%s\" missing from server", path);
    }

	AddFileToDownloadsTable("materials/sprites/trails/lol.vtf");
	AddFileToDownloadsTable("materials/sprites/trails/lol.vmt");
}

public OnMapEnd( )
{
    // Cleanup test.
    for( new i = 1; i < MAXPLAYERS; i++ )
        ClearClientTrail(i);
}

public Action:Command_Say(client, arg)
{
	decl String:args[192];

	GetCmdArgString(args, sizeof(args));
	ReplaceString(args, sizeof(args), "\"", "");

	if(StrEqual(args, "!zprops", false) || StrEqual(args, "!zprop", false) || StrEqual(args, "/zprop", false))
	{
		if(!IsPlayerAlive(client))
			return Plugin_Handled;

		ZPropMenu(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

ZPropMenu(client)
{
	new Handle:zpropmenu = CreateMenu(MainMenuHandle);
    
	SetGlobalTransTarget(client);
    
	SetMenuTitle(zpropmenu, "%t\n ", "Menu title", g_iCredits[client]);
    
	decl String:propname[64];
	decl String:display[64];
    
	KvRewind(kvProps);
	if (KvGotoFirstSubKey(kvProps))
	{
		do
		{
			KvGetSectionName(kvProps, propname, sizeof(propname));
			new cost = KvGetNum(kvProps, "cost");
			Format(display, sizeof(display), "%t", "Menu Options", propname, cost);
            
			if (g_iCredits[client ] >= cost)
			{
				AddMenuItem(zpropmenu, propname, display);
			}
			else
			{
				AddMenuItem(zpropmenu, propname, display, ITEMDRAW_DISABLED);
			}
		} while (KvGotoNextKey(kvProps));
	}
    
	DisplayMenu(zpropmenu, client, MENU_TIME_FOREVER);
}


public MainMenuHandle(Handle:zpropmenu, MenuAction:action, client, Item)
{
    if (action == MenuAction_Select)
    {
        decl String:propname[64];
        if (GetMenuItem(zpropmenu, Item, propname, sizeof(propname)))
        {
            KvRewind(kvProps);
            if (KvJumpToKey(kvProps, propname))
            {
				new cost = KvGetNum(kvProps, "cost");
				if (g_iCredits[client] < cost)
				{
					PrintToChat(client, "\x04[%s] \x03%t", "ZShop", "Insufficient credits", g_iCredits[client], cost);
					ZPropMenu(client);

					return;
				}
                
				new Float:vecOrigin[3];
				new Float:vecAngles[3];
				new Float:downang[3];

				downang[0] = 90.0;
				downang[1] = 90.0;
				downang[1] = 0.0;
                
				GetClientAbsOrigin(client, vecOrigin);
				GetClientAbsAngles(client, vecAngles);
                
				vecAngles[0] = GetEntDataFloat(client, offsEyeAngle0);
                
				vecOrigin[2] += 5;
                
				decl Float:vecFinal[3];
				AddInFrontOf(vecOrigin, vecAngles, 50, vecFinal);

				TR_TraceRay(vecFinal, downang, CONTENTS_SOLID, RayType_Infinite);
				TR_GetEndPosition(vecFinal, INVALID_HANDLE);
                
				decl String:propmodel[128];
				KvGetString(kvProps, "model", propmodel, sizeof(propmodel));
                
				decl String:proptype[24];
				KvGetString(kvProps, "type", proptype, sizeof(proptype), "prop_physics");
                
				new prop = CreateEntityByName(proptype);
                
				PrecacheModel(propmodel);
				SetEntityModel(prop, propmodel);
                
				DispatchSpawn(prop);
                
				TeleportEntity(prop, vecFinal, NULL_VECTOR, NULL_VECTOR);
                
				g_iCredits[client] -= cost;
                
				PrintToChat(client, "\x04[ZShop] Your credits: %i (-%i)", g_iCredits[client], cost);
				PrintToChat(client, "\x04[%s] \x03%t", "ZShop", "Spawn prop", propname);
            }
        }
    }
    if (action == MenuAction_End)
    {
        CloseHandle(zpropmenu);
    }
}

AddInFrontOf(Float:vecOrigin[3], Float:vecAngle[3], units, Float:output[3])
{
    new Float:vecView[3];
    GetViewVector(vecAngle, vecView);
    
    output[0] = vecView[0] * units + vecOrigin[0];
    output[1] = vecView[1] * units + vecOrigin[1];
    output[2] = vecView[2] * units + vecOrigin[2];
}
 
GetViewVector(Float:vecAngle[3], Float:output[3])
{
    output[0] = Cosine(vecAngle[1] / (180 / FLOAT_PI));
    output[1] = Sine(vecAngle[1] / (180 / FLOAT_PI));
    output[2] = -Sine(vecAngle[0] / (180 / FLOAT_PI));
}


enum WeaponsSlot
{
	Slot_Invalid = -1, /** Invalid weapon (slot). */
	Slot_Primary = 0, /** Primary weapon slot. */
	Slot_Secondary = 1, /** Secondary weapon slot. */
	Slot_Melee = 2, /** Melee (knife) weapon slot. */
	Slot_Projectile = 3, /** Projectile (grenades, flashbangs, etc) weapon slot. */
	Slot_Explosive = 4, /** Explosive (c4) weapon slot. */
}

public Action:OnPlayerSpawn(Handle:timer, any:client)
{
	if (IsClientInGame(client))
	{
		PrintToChat(client, "\x04[ZShop] \x03Type \x03!zshop \x03to spend your credits on prizes");
	}
}

public IsValidClient( client ) 
{ 
	if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
		return false; 
	
	return true; 
}


public Action:PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    
    if (!attacker)
        return;
    
    decl String:weapon[32];
    GetEventString(event, "weapon", weapon, sizeof(weapon));
    
    new g_iAddCredits = StrEqual(weapon, "zombie_claws_of_death") ? GetConVarInt(cvarCreditsInfect) : GetConVarInt(cvarCreditsKill);
    
    g_iCredits[attacker] += g_iAddCredits;
    
    PrintToChat(attacker, "\x04[ZShop] \x03Your credits: %i (+%i)", g_iCredits[attacker], g_iAddCredits);
}

public Action:MyCredits(client, args)
{
	PrintToChat(client, "\x04[ZShop] \x03Your current credits are: %i", g_iCredits[client]);
}

public Action:StartMenu(client,args)
{
	if (IsPlayerAlive(client))
	{
		OpenMenu(client);
		PrintToChat(client, "\x04[ZShop] \x03Your credits: %i", g_iCredits[client]);
	}
	else if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "\x04 [ZShop]\x03 You must be alive to open zshop menu");
	}
}
public Action:OpenMenu(clientId) 
{
	if (ZR_IsClientHuman(clientId))
	{
		new Handle:menuhuman = CreateMenu(MenuHandlerHuman);
		SetMenuTitle(menuhuman, "ZShop. Your credits: %i", g_iCredits[clientId]);
		AddMenuItem(menuhuman, "option1", "View information on the plugin");
		AddMenuItem(menuhuman, "damage", "Damage(x2) - 30 Credits");
		AddMenuItem(menuhuman, "trails", "Trails");
		AddMenuItem(menuhuman, "laser", "Lasers");
		AddMenuItem(menuhuman, "weapons", "Buy Weapons");
		SetMenuExitButton(menuhuman, true);
		DisplayMenu(menuhuman, clientId, MENU_TIME_FOREVER);
	}
	
	if(ZR_IsClientZombie(clientId))
    {
		new Handle:menuzombie = CreateMenu(MenuHandlerZombie);
		SetMenuTitle(menuzombie, "ZShop. Your credits: %i", g_iCredits[clientId]);
		AddMenuItem(menuzombie, "option1", "View information on the plugin");
		AddMenuItem(menuzombie, "speed", "Become Faster - 40  Credits");
		AddMenuItem(menuzombie, "bird", "Become a Bird - 70  Credits");
		SetMenuExitButton(menuzombie, true);
		DisplayMenu(menuzombie, clientId, MENU_TIME_FOREVER);
	}

	return Plugin_Handled;
}

public Action:OpenLaserMenu(clientId)
{
	new Handle:menu1 = CreateMenu(MenuHandler1);
	SetMenuTitle(menu1, "Laser Mines Menu:");
	AddMenuItem(menu1, "buy", "Buy Laser - 5 Credits");
	AddMenuItem(menu1, "use", "Use Laser");
	SetMenuExitBackButton(menu1, true);
	SetMenuExitButton(menu1, true);
	DisplayMenu(menu1, clientId, MENU_TIME_FOREVER);
}

public Action:OpenTrailsMenu(clientId)
{
	new Handle:trailmenu = CreateMenu(MenuHandlerTrails);
	SetMenuTitle(trailmenu, "Trails Menu:");
	AddMenuItem(trailmenu, "green", "Buy Trail (Green) - 25 Credits");
	AddMenuItem(trailmenu, "red", "Buy Trail (Red) - 25 Credits");
	SetMenuExitBackButton(trailmenu, true);
	SetMenuExitButton(trailmenu, true);
	DisplayMenu(trailmenu, clientId, MENU_TIME_FOREVER);
}

public Action:OpenWeaponsMenu(clientId)
{
	new Handle:menu2 = CreateMenu(MenuHandler2);
	SetMenuTitle(menu2, "Select Weapon Type:");
	AddMenuItem(menu2, "all", "All");
	AddMenuItem(menu2, "pistol", "Pistol");
	AddMenuItem(menu2, "shotgun", "Shotgun");
	AddMenuItem(menu2, "smg", "SMG");
	AddMenuItem(menu2, "rifle", "Rifle");
	AddMenuItem(menu2, "sniper", "Sniper");
	AddMenuItem(menu2, "machinegun", "Machine Gun");
	AddMenuItem(menu2, "grenades", "Grenades");
	SetMenuExitBackButton(menu2, true);
	SetMenuExitButton(menu2, true);
	DisplayMenu(menu2, clientId, MENU_TIME_FOREVER);
}
public Action:OpenWeaponsMenuAll(clientId)
{
	new Handle:menu3 = CreateMenu(MenuHandler3);
	SetMenuTitle(menu3, "Weapon Type: All");
	AddMenuItem(menu3, "glock", "Glock - 15 Credits");
	AddMenuItem(menu3, "usp", "USP - 15 Credits");
	AddMenuItem(menu3, "p228", "P228 - 15 Credits");
	AddMenuItem(menu3, "deagle", "Deagle - 20 Credits");
	AddMenuItem(menu3, "elite", "Elite - 20 Credits");
	AddMenuItem(menu3, "fiveseven", "Fiveseven - 20 Credits");
	AddMenuItem(menu3, "m3", "M3 - 30 Credits");
	AddMenuItem(menu3, "xm1014", "XM1014 - 30 Credits");
	AddMenuItem(menu3, "mac10", "Mac10 - 25 Credits");
	AddMenuItem(menu3, "tmp", "TMP - 25 Credits");
	AddMenuItem(menu3, "mp5navy", "MP5Navy - 30 Credits");
	AddMenuItem(menu3, "ump45", "UMP45 - 25 Credits");
	AddMenuItem(menu3, "p90", "P90 - 35 Credits");
	AddMenuItem(menu3, "galil", "Galil - 35 Credits");
	AddMenuItem(menu3, "famas", "Famas - 35 Credits");
	AddMenuItem(menu3, "ak47", "AK47 - 40 Credits");
	AddMenuItem(menu3, "m4a1", "M4A1 - 40 Credits");
	AddMenuItem(menu3, "sg552", "SG552 - 40 Credits");
	AddMenuItem(menu3, "aug", "AUG - 40 Credits");
	AddMenuItem(menu3, "scout", "Scout - 40 Credits");
	AddMenuItem(menu3, "sg550", "SG550 - 40 Credits");
	AddMenuItem(menu3, "g3sg1", "G3SG1 - 40 Credits");
	AddMenuItem(menu3, "awp", "AWP - 50 Credits");
	AddMenuItem(menu3, "m249", "M249 - 50 Credits");
	AddMenuItem(menu3, "hegrenade", "HEGrenade - 15 Credits");
	AddMenuItem(menu3, "flashbang", "Flashbang - 15 Credits");
	AddMenuItem(menu3, "smokegrenade", "Smokegrenade - 15 Credits");
	SetMenuExitBackButton(menu3, true);
	SetMenuExitButton(menu3, true);
	DisplayMenu(menu3, clientId, MENU_TIME_FOREVER);
}
public Action:OpenWeaponsMenuPistol(clientId)
{
	new Handle:menu4 = CreateMenu(MenuHandler4);
	SetMenuTitle(menu4, "Weapon Type: Pistol");
	AddMenuItem(menu4, "glock", "Glock - 15 Credits");
	AddMenuItem(menu4, "usp", "USP - 15 Credits");
	AddMenuItem(menu4, "p228", "P228 - 15 Credits");
	AddMenuItem(menu4, "deagle", "Deagle - 20 Credits");
	AddMenuItem(menu4, "elite", "Elite - 20 Credits");
	AddMenuItem(menu4, "fiveseven", "Fiveseven - 20 Credits");
	SetMenuExitBackButton(menu4, true);
	SetMenuExitButton(menu4, true);
	DisplayMenu(menu4, clientId, MENU_TIME_FOREVER);
}
public Action:OpenWeaponsMenuShotgun(clientId)
{
	new Handle:menu5 = CreateMenu(MenuHandler5);
	SetMenuTitle(menu5, "Weapon Type: Shotgun");
	AddMenuItem(menu5, "m3", "M3 - 30 Credits");
	AddMenuItem(menu5, "xm1014", "XM1014 - 30 Credits");
	SetMenuExitBackButton(menu5, true);
	SetMenuExitButton(menu5, true);
	DisplayMenu(menu5, clientId, MENU_TIME_FOREVER);
}
public Action:OpenWeaponsMenuSmg(clientId)
{
	new Handle:menu6 = CreateMenu(MenuHandler6);
	SetMenuTitle(menu6, "Weapon Type: SMG");
	AddMenuItem(menu6, "mac10", "Mac10 - 25 Credits");
	AddMenuItem(menu6, "tmp", "TMP - 25 Credits");
	AddMenuItem(menu6, "mp5navy", "MP5Navy - 30 Credits");
	AddMenuItem(menu6, "ump45", "UMP45 - 25 Credits");
	AddMenuItem(menu6, "p90", "P90 - 35 Credits");
	SetMenuExitBackButton(menu6, true);
	SetMenuExitButton(menu6, true);
	DisplayMenu(menu6, clientId, MENU_TIME_FOREVER);
}
public Action:OpenWeaponsMenuRifle(clientId)
{
	new Handle:menu7 = CreateMenu(MenuHandler7);
	SetMenuTitle(menu7, "Weapon Type: Rifle");
	AddMenuItem(menu7, "galil", "Galil - 35 Credits");
	AddMenuItem(menu7, "famas", "Famas - 35 Credits");
	AddMenuItem(menu7, "ak47", "AK47 - 40 Credits");
	AddMenuItem(menu7, "m4a1", "M4A1 - 40 Credits");
	AddMenuItem(menu7, "sg552", "SG552 - 40 Credits");
	AddMenuItem(menu7, "aug", "AUG - 40 Credits");
	SetMenuExitBackButton(menu7, true);
	SetMenuExitButton(menu7, true);
	DisplayMenu(menu7, clientId, MENU_TIME_FOREVER);
}
public Action:OpenWeaponsMenuSniper(clientId)
{
	new Handle:menu8 = CreateMenu(MenuHandler8);
	SetMenuTitle(menu8, "Weapon Type: Sniper");
	AddMenuItem(menu8, "scout", "Scout - 40 Credits");
	AddMenuItem(menu8, "sg550", "SG550 - 40 Credits");
	AddMenuItem(menu8, "g3sg1", "G3SG1 - 40 Credits");
	AddMenuItem(menu8, "awp", "AWP - 50 Credits");
	SetMenuExitBackButton(menu8, true);
	SetMenuExitButton(menu8, true);
	DisplayMenu(menu8, clientId, MENU_TIME_FOREVER);
}
public Action:OpenWeaponsMenuMg(clientId)
{
	new Handle:menu9 = CreateMenu(MenuHandler9);
	AddMenuItem(menu9, "m249", "M249 - 50 Credits");
	SetMenuExitBackButton(menu9, true);
	SetMenuExitButton(menu9, true);
	DisplayMenu(menu9, clientId, MENU_TIME_FOREVER);
}
public Action:OpenWeaponsMenuGrenades(clientId)
{
	new Handle:menu10 = CreateMenu(MenuHandler10);
	AddMenuItem(menu10, "hegrenade", "HEGrenade - 15 Credits");
	AddMenuItem(menu10, "flashbang", "Flashbang - 15 Credits");
	AddMenuItem(menu10, "smokegrenade", "Smokegrenade - 15 Credits");
	SetMenuExitBackButton(menu10, true);
	SetMenuExitButton(menu10 , true);
	DisplayMenu(menu10, clientId, MENU_TIME_FOREVER);
}
public MenuHandlerHuman(Handle:menuhuman, MenuAction:action, client, itemN) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
		
		GetMenuItem(menuhuman, itemN, info, sizeof(info));
		
		if ( strcmp(info,"option1") == 0 ) 
		{
			{
				OpenMenu(client);
				PrintToChat(client,"\x04[ZShop] \x03Kill Zombies or infect a Human to earn credits.");
			}
		}
		else if ( strcmp(info,"damage") == 0 ) 
		{
			{
				OpenMenu(client);
				if (g_iCredits[client] >= 30)
				{
					if (IsPlayerAlive(client))
					{
						
						x2Damgae[client] = true;
						g_iCredits[client] -= 30;
						PrintToChat(client, "\x04[ZShop] \x03Now you have x2 Damage ! Your credits: %i (-30)", g_iCredits[client]);
					}
					else
					{
						PrintToChat(client, "\x04[ZShop] \x03You have to be alive to buy prizes");
					}
				}
				else
				{
					PrintToChat(client, "\x04[ZShop] \x03Your credits: %i (Not have enough credit! Requires 30)", g_iCredits[client]);
				}
			}
		}
		else if (strcmp(info, "trails") == 0)
		{
			OpenTrailsMenu(client);
		}
		else if (strcmp(info, "laser") == 0)
		{
			OpenLaserMenu(client);
		}
		else if(strcmp(info, "weapons") == 0)
		{
			OpenWeaponsMenu(client);
		}
	}
}

public MenuHandlerZombie(Handle:menuzombie, MenuAction:action, client, itemN) 
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32];
		
		GetMenuItem(menuzombie, itemN, info, sizeof(info));
		
		if ( strcmp(info,"option1") == 0 ) 
		{
			{
				OpenMenu(client);
				PrintToChat(client,"\x04[ZShop] \x03Kill Zombies or infect a Human to earn credits.");
			}
			
		}

		else if ( strcmp(info,"speed") == 0 ) 
		{
			{
				OpenMenu(client);
				if (g_iCredits[client] >= 40)
				{
					if (IsPlayerAlive(client))
					{
						SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.8);
						
						g_iCredits[client] -= 40;
						
						PrintToChat(client, "\x04[ZShop] \x03Now you have x2 Damage ! Your credits: %i (-40)", g_iCredits[client]);
					}
					else
					{
						PrintToChat(client, "\x04[ZShop] \x03You have to be alive to buy prizes");
					}
				}
				else
				{
					PrintToChat(client, "\x04[ZShop] \x03Your credits: %i (Not have enough credit! Requires 40)", g_iCredits[client]);
				}
			}	
		}

		else if(strcmp(info,"bird") == 0) 
		{
			{
				OpenMenu(client);
				if (g_iCredits[client] >= 70)
				{
					if (IsPlayerAlive(client))
					{
						
						SetEntityMoveType(client, MOVETYPE_FLY);
						
						if (GetClientTeam(client) == CS_TEAM_CT)
						{
							SetEntityModel(client, "models/pigeon.mdl");
						}
						else
						{
							SetEntityModel(client, "models/crow.mdl");
						}
						
						g_Bird[client] = true;
						
						g_iCredits[client] -= 70;
						
						PrintToChat(client, "\x04[ZShop] \x03You are now a bird and you can fly! Your credits: %i (-70)", g_iCredits[client]);
					}
					else
					{
						PrintToChat(client, "\x04[ZShop] \x03You have to be alive to buy prizes");
					}
				}
				else
				{
					PrintToChat(client, "\x04[ZShop] \x03Your credits: %i (Not have enough credit! Requires 70)", g_iCredits[client]);
				}	
			}
		}	
	}
}

public MenuHandler1(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(StrEqual("buy", s_MenuItem))
		{
			{
				if(g_iCredits[client] >= 25)
				{
					if(ZR_IsClientHuman(client))
					{
						g_iCredits[client] -=25;
						
						PrintToChat(client, "\x04[ZShop] \x03You bought a Lasermine! Your credits: %i (-25)", g_iCredits[client]);
						ClientCommand(client, "sm_blm");
						DisplayMenu(menu, client, MENU_TIME_FOREVER);
					}
					else if(!ZR_IsClientHuman(client))
						PrintToChat(client,"\x04[ZShop] \x03 You must be human to buy Lasermines");
				}
				else
				{
					PrintToChat(client, "\x04[ZShop] \x03Your credits: %i (Not enough credits! Requires 25)", g_iCredits[client]);
				}
			}
		}
		else if(StrEqual("use", s_MenuItem))
		{
			{
				ClientCommand(client, "sm_lm");
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenMenu(client);
		}
	}
}

public MenuHandlerTrails(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(StrEqual("green", s_MenuItem))
		{
			{
				if(g_iCredits[client] >= 25)
				{
					if(ZR_IsClientHuman(client))
					{
						g_iCredits[client] -=25;
						
						PrintToChat(client, "\x04[ZShop] \x03You bought a Trail (Green)! Your credits: %i (-25)", g_iCredits[client]);
						GreenTrail(client);
						DisplayMenu(menu, client, MENU_TIME_FOREVER);
					}
					else if(!ZR_IsClientHuman(client))
						PrintToChat(client,"\x04[ZShop] \x03 You must be human to buy trails");
				}
				else
				{
					PrintToChat(client, "\x04[ZShop] \x03Your credits: %i (Not enough credits! Requires 25)", g_iCredits[client]);
				}
			}
		}
		else if(StrEqual("red", s_MenuItem))
		{
			{
				if(g_iCredits[client] >= 25)
				{
					if(ZR_IsClientHuman(client))
					{
						g_iCredits[client] -=25;
						
						PrintToChat(client, "\x04[ZShop] \x03You bought a Trail (Red)! Your credits: %i (-25)", g_iCredits[client]);
						BlueTrail(client);
						DisplayMenu(menu, client, MENU_TIME_FOREVER);
					}
					else if(!ZR_IsClientHuman(client))
						PrintToChat(client,"\x04[ZShop] \x03 You must be human to buy trails");
				}
				else
				{
					PrintToChat(client, "\x04[ZShop] \x03Your credits: %i (Not enough credits! Requires 25)", g_iCredits[client]);
				}
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenMenu(client);
		}
	}
}

public MenuHandler2(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(StrEqual("all", s_MenuItem))
			OpenWeaponsMenuAll(client);
			
		else if(StrEqual("pistol", s_MenuItem))
			OpenWeaponsMenuPistol(client);
			
		else if(StrEqual("shotgun", s_MenuItem))
			OpenWeaponsMenuShotgun(client);
			
		else if(StrEqual("smg", s_MenuItem))
			OpenWeaponsMenuSmg(client);
			
		else if(StrEqual("rifle", s_MenuItem))
			OpenWeaponsMenuRifle(client);
			
		else if(StrEqual("sniper", s_MenuItem))
			OpenWeaponsMenuSniper(client);
			
		else if(StrEqual("machinegun", s_MenuItem))
			OpenWeaponsMenuMg(client);
			
		else if(StrEqual("grenades", s_MenuItem))
			OpenWeaponsMenuGrenades(client);
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenMenu(client);
		}
	}
}
public MenuHandler3(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new weaponIndex;
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(strcmp("glock", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;

					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);

					GivePlayerItem(client, "weapon_glock");
					PrintToChat(client, "\x04[ZShop] \x03You bought a glock! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client,"\x04[ZShop] \x03You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop] \x03Your credits: %i (Not enough credits! Requires 15)", g_iCredits[client]);
			}
		}
		else if(strcmp("usp", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;
				
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
				
					GivePlayerItem(client, "weapon_usp");
					PrintToChat(client, "\x04[ZShop] \x03You bought a usp! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop] \x03You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop] \x03 Your credits: %i (Not enough credits! Requires 15)", g_iCredits[client]);
			}
		}
		else if(strcmp("p228", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_p228");
					PrintToChat(client, "\x04[ZShop] \x03You bought a p228! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop] \x03You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop] \x03Your credits: %i (Not enought credits! Requires 15)", g_iCredits[client]);
			}
		}
		else if(strcmp("deagle", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 20)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 20;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_deagle");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a deagle! Your credits: %i (-20)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop] \x03You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[Zshop]\x03 Your credits: %i (Not enough credits! Requires 20).", g_iCredits[client]);
			}
		}
		else if(strcmp("elite", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 20)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 20;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_elite");
					PrintToChat(client, "\x04[ZShop\x03 You bought an elite! Your credits: %i (-20)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop] \x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 20).", g_iCredits[client]);
			}
		}
		else if(strcmp("fiveseven", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 20)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 20;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_fiveseven");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a fiveseven! Your credits: %i (-20)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 20).", g_iCredits[client]);
			}
		}
		else if(strcmp("m3", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 30)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 30;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_m3");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a m3!, Your credits: %i (-30)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 30).", g_iCredits[client]);
			}
		}
		else if(strcmp("xm1014", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 30)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 30;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_xm1014");
					PrintToChat(client, "\x04[ZShop]\x03You bought a xm1014! Your credits: %i (-30)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 30).");
			}
		}
		else if(strcmp("mac10", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 25)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 25;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_mac10");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a mac10! Your credits: %i (-25)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 25).");
			}
		}
		else if(strcmp("tmp", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 25)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 25;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_tmp");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a tmp! Your credits: %i (-25)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 25).");
			}
		}
		else if(strcmp("mp5navy", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 30)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 30;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_mp5navy");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a mp5navy! Your credits: %i (-30)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 30).");
			}
		}
		else if(strcmp("ump45", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 25)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 25;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_ump45");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an ump45! Your credits: %i (-25)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 25).");
			}
		}
		else if(strcmp("p90", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 35)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 35;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_p90");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a p90! Your credits: %i (-35)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 35).");
			}
		}
		else if(strcmp("galil", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 35)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 35;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_galil");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a galil! Your credits: %i (-35)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 35).");
			}
		}
		else if(strcmp("famas", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 35)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 35;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_famas");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a famas! Your credits: %i (-35)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 35).");
			}
		}
		else if(strcmp("ak47", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_ak47");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an ak47! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).");
			}
		}
		else if(strcmp("m4a1", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_m4a1");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an m4a1! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).");
			}
		}
		else if(strcmp("sg552", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_sg552");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a sg552! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).");
			}
		}
		else if(strcmp("aug", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_aug");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an aug! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).");
			}
		}
		else if(strcmp("scout", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_scout");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a scout! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).");
			}
		}
		else if(strcmp("sg550", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_sg550");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an sg550! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).");
			}
		}
		else if(strcmp("g3sg1", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_g3sg1");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an g3sg1! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).");
			}
		}
		else if(strcmp("awp", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 50)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 50;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_awp");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an awp! Your credits: %i (-50)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 50).");
			}
		}
		else if(strcmp("m249", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 50)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 50;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_m249");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an m249! Your credits: %i (-50)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 50).");
			}
		}
		else if(strcmp("hegrenade", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;

					GivePlayerItem(client, "weapon_hegrenade");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a hegrenade! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 15).");
			}
		}
		else if(strcmp("flashbang", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;
					
					GivePlayerItem(client, "weapon_flashbang");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a flashbang! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 15).");
			}
		}
		else if(strcmp("smokegrenade", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;
					
					GivePlayerItem(client, "weapon_smokegrenade");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a smokegrenade! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 15).");
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenWeaponsMenu(client);
		}
	}
}
public MenuHandler4(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new weaponIndex;
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(strcmp("glock", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_glock");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a glock! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 15).", g_iCredits[client]);
			}
		}
		else if(strcmp("usp", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_usp");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a usp! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 15).", g_iCredits[client]);
			}
		}
		else if(strcmp("p228", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_p228");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a p228! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 15).", g_iCredits[client]);
			}
		}
		else if(strcmp("deagle", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 20)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 20;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_deagle");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a deagle! Your credits: %i (-20)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 20).", g_iCredits[client]);
			}
		}
		else if(strcmp("elite", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 20)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 20;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_elite");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a elite! Your credits: %i (-20)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 20).", g_iCredits[client]);
			}
		}
		else if(strcmp("fiveseven", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 20)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 20;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_fiveseven");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a fiveseven! Your credits: %i (-20)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 20).", g_iCredits[client]);
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenWeaponsMenu(client);
		}
	}
}
public MenuHandler5(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new weaponIndex;
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(strcmp("m3", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 30)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 30;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_m3");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a m3! Your credits: %i (-30)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 30).", g_iCredits[client]);
			}
		}
		else if(strcmp("xm1014", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 30)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 30;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_xm1014");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a xm1014! Your credits: %i (-30)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 30).", g_iCredits[client]);
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenWeaponsMenu(client);
		}
	}
}
public MenuHandler6(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new weaponIndex;
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(strcmp("mac10", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 25)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 25;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_mac10");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a mac10! Your credits: %i (-25)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 25).", g_iCredits[client]);
			}
		}
		else if(strcmp("tmp", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 25)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 25;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_tmp");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a tmp! Your credits: %i (-25)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 25).", g_iCredits[client]);
			}
		}
		else if(strcmp("mp5navy", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 30)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 30;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_mp5navy");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a mp5navy! Your credits: %i (-30)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 30).", g_iCredits[client]);
			}
		}
		else if(strcmp("ump45", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 25)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 25;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_ump45");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a ump45! Your credits: %i (-25)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 25).", g_iCredits[client]);
			}
		}
		else if(strcmp("p90", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 35)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 35;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_p90");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a p90! Your credits: %i (-35)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 35).", g_iCredits[client]);
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenWeaponsMenu(client);
		}
	}
}
public MenuHandler7(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new weaponIndex;
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(strcmp("galil", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 35)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 35;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_galil");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a galil! Your credits: %i (-35)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 35).", g_iCredits[client]);
			}
		}
		else if(strcmp("famas", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 35)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 35;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_famas");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a famas! Your credits: %i (-35)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 35).", g_iCredits[client]);
			}
		}
		else if(strcmp("ak47", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_ak47");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an ak47! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).", g_iCredits[client]);
			}
		}
		else if(strcmp("m4a1", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_m4a1");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a m4a1! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).", g_iCredits[client]);
			}
		}
		else if(strcmp("sg552", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_sg552");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a sg552! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).", g_iCredits[client]);
			}
		}
		else if(strcmp("aug", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_aug");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an aug! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).", g_iCredits[client]);
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenWeaponsMenu(client);
		}
	}
}
public MenuHandler8(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new weaponIndex;
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(strcmp("scout", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_scout");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a scout! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).", g_iCredits[client]);
			}
		}
		else if(strcmp("sg550", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_sg550");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a sg550! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).", g_iCredits[client]);
			}
		}
		else if(strcmp("g3sg1", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_g3sg1");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a g3sg1! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).", g_iCredits[client]);
			}
		}
		else if(strcmp("sg550", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 40)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 40;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_sg550");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a sg550! Your credits: %i (-40)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 40).", g_iCredits[client]);
			}
		}
		else if(strcmp("awp", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 50)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 50;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_awp");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an awp! Your credits: %i (-50)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 50).", g_iCredits[client]);
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenWeaponsMenu(client);
		}
	}
}
public MenuHandler9(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new weaponIndex;
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(strcmp("m249", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 50)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 50;
					
					if((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
						RemovePlayerItem(client, weaponIndex);
						
					GivePlayerItem(client, "weapon_m249");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a m249! Your credits: %i (-50)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 50).", g_iCredits[client]);
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenWeaponsMenu(client);
		}
	}
}
public MenuHandler10(Handle:menu, MenuAction:action, client, itemN)
{
	if(action == MenuAction_Select)
	{
		new String:s_MenuItem[128];
		GetMenuItem(menu, itemN, s_MenuItem, sizeof(s_MenuItem));
		
		if(strcmp("hegrenade", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;

					GivePlayerItem(client, "weapon_hegrenade");
					PrintToChat(client, "\x04[ZShop]\x03 You bought an hegrenade! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 15).");
			}
		}
		else if(strcmp("flashbang", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;

					GivePlayerItem(client, "weapon_flashbang");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a flashbang! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 15).");
			}
		}
		if(strcmp("smokegrenade", s_MenuItem) == 0)
		{
			if(g_iCredits[client] >= 15)
			{
				if(ZR_IsClientHuman(client))
				{
					g_iCredits[client] -= 15;

					GivePlayerItem(client, "weapon_smokegrenade");
					PrintToChat(client, "\x04[ZShop]\x03 You bought a smokegrenade! Your credits: %i (-15)", g_iCredits[client]);
				}
				else if(ZR_IsClientZombie(client))
				{
					PrintToChat(client, "\x04[ZShop]\x03 You must be human to buy weapons.");
				}
			}
			else
			{
				PrintToChat(client, "\x04[ZShop]\x03 Your credits: %i (Not enough credits! Requires 15).");
			}
		}
	}
	if(action == MenuAction_Cancel)
	{
		if(itemN == MenuCancel_ExitBack)
		{
			OpenWeaponsMenu(client);
		}
	}
}
public Action:SetCredits(client, args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "\x04[ZShop] \x03Use: sm_setcredits <#userid|name> [amount]");
		return Plugin_Handled;
	}
	
	decl String:arg2[10];
	GetCmdArg(2, arg2, sizeof(arg2));
	
	new amount = StringToInt(arg2);
	
	decl String:strTarget[32]; GetCmdArg(1, strTarget, sizeof(strTarget)); 
	
	// Process the targets 
	decl String:strTargetName[MAX_TARGET_LENGTH]; 
	decl TargetList[MAXPLAYERS], TargetCount; 
	decl bool:TargetTranslate; 
	
	if ((TargetCount = ProcessTargetString(strTarget, client, TargetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, 
	strTargetName, sizeof(strTargetName), TargetTranslate)) <= 0) 
	{ 
		ReplyToTargetError(client, TargetCount); 
		return Plugin_Handled; 
	} 
	
	// Apply to all targets 
	for (new i = 0; i < TargetCount; i++) 
	{ 
		new iClient = TargetList[i]; 
		if (IsClientInGame(iClient)) 
		{ 
			g_iCredits[iClient] = amount;
			PrintToChat(client, "\x04[ZShop] \x03Set %i credits in the player %N", amount, iClient);
		} 
	}
	return Plugin_Continue;
}


public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	decl String:sWeapon[32];
	GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));

	if (IsValidClient(attacker))
	{
		if (x2Damgae[attacker])
		{
			if (GetClientTeam(attacker) != GetClientTeam(victim))
			{
				damage *= 2.0;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:OnWeaponCanUse(client, weapon)
{
	if (g_Bird[client])
	{
		decl String:sClassname[32];
		GetEdictClassname(weapon, sClassname, sizeof(sClassname));
		if (!StrEqual(sClassname, "weapon_knife"))
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public OnClientDisconnect(client)
{
	x2Damgae[client] = false;
	g_Bird[client] = false;
	ClearClientTrail(client);

}

public bool:OnClientConnect( client, String:rejectmsg[], maxlen )
{
    // Cleanup client slot.
    ClearClientTrail( client );
    return true;
}

public ClearClientTrail( client )
{
    if( g_ClientTrailGreenEntity[ client ] != -1 || g_ClientTrailBlueEntity[ client ] != -1)
    {
        if( IsValidEdict( g_ClientTrailGreenEntity[ client ] ) || ( g_ClientTrailBlueEntity[ client ]) )
        {
            new String:clientName[64];
            GetClientName(client, clientName, sizeof(clientName));
            
            RemoveEdict(g_ClientTrailGreenEntity[client]);
            RemoveEdict( g_ClientTrailBlueEntity[client]);
        }
    }
    g_ClientTrailGreenEntity[ client ] = -1;
    g_ClientTrailBlueEntity[ client ] = -1;
}

// Event : player_spawn
public Action:EventPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new pClient = GetClientOfUserId(GetEventInt(event, "userid"));
    if(!IsPlayerAlive(pClient) || IsFakeClient(pClient))
        return Plugin_Continue;
    
    if(g_ClientTrailGreenEntity[pClient] != -1 || g_ClientTrailBlueEntity[pClient] != -1)
        ClearClientTrail(pClient);

    
    return Plugin_Continue;
}

// Event : player_death
public Action:EventPlayerDeath( Handle:event, const String:name[], bool:dontBroadcast )
{
    new pClient = GetClientOfUserId( GetEventInt( event, "userid" ) );
    ClearClientTrail( pClient );
    return Plugin_Continue;
}


public GreenTrail(client)
{
    new String:clientName[ 64 ];
    GetClientName( client, clientName, sizeof( clientName ) );
    
    new Entity = CreateEntityByName("env_spritetrail");
    if(!IsValidEntity(Entity))
    {
        PrintToChatAll("Failed to create env_spritetrail for client: %s", clientName);
        return;
    }
    
    DispatchKeyValue(client, "targetname", clientName);
    DispatchKeyValue(Entity, "parentname", clientName);
    DispatchKeyValue(Entity, "lifetime", "5.0");
    DispatchKeyValue(Entity, "startwidth", "30.0");
    DispatchKeyValue(Entity, "endwidth", "30.0");
    DispatchKeyValue(Entity, "spritename", "materials/sprites/crystal_beam1.vmt");
    DispatchKeyValue(Entity, "renderamt", "255");
    DispatchKeyValue(Entity, "rendercolor", "0 255 0");
    DispatchKeyValue(Entity, "rendermode", "5");
    
    DispatchSpawn(Entity);
    
    new Float:vPosClient[3];
    GetClientAbsOrigin(client, vPosClient);
    vPosClient[2] += 10;
    TeleportEntity(Entity, vPosClient, NULL_VECTOR, NULL_VECTOR);
    
    SetVariantString(clientName);
    AcceptEntityInput(Entity, "SetParent");
    
    g_ClientTrailGreenEntity[client] = Entity;
    
}

public BlueTrail(client)
{
    new String:clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    
    new g_Entity = CreateEntityByName("env_spritetrail");
    if(!IsValidEntity(g_Entity))
    {
        PrintToChatAll("Failed to create env_spritetrail for client: %s", clientName);
        return;
    }
    
    DispatchKeyValue( client, "targetname", clientName );
    DispatchKeyValue( g_Entity, "parentname", clientName );
    DispatchKeyValue( g_Entity, "lifetime", "1.0" );
    DispatchKeyValue( g_Entity, "startwidth", "6.0" );
    DispatchKeyValue( g_Entity, "endwidth", "6.0" );
    DispatchKeyValue( g_Entity, "spritename", "materials/sprites/trails/lol.vmt");
    DispatchKeyValue( g_Entity, "renderamt", "255" );
    DispatchKeyValue( g_Entity, "rendercolor", "0 0 255" );
    DispatchKeyValue( g_Entity, "rendermode", "1" );   
    DispatchSpawn(g_Entity);
    
    new Float:vPosClient[3];
    GetClientAbsOrigin(client, vPosClient);
    vPosClient[2] += 10;
    TeleportEntity(g_Entity, vPosClient, NULL_VECTOR, NULL_VECTOR);
    
    SetVariantString(clientName);
    AcceptEntityInput(g_Entity, "SetParent");
    
    g_ClientTrailBlueEntity[client] = g_Entity;    
}

// Event : round_end
public Action:EventRoundEnd( Handle:event, const String:name[], bool:dontBroadcast )
{
    for( new i = 1; i < MAXPLAYERS; i++ )
	{
		ClearClientTrail( i );
		g_Bird[i] = false;
	}
    return Plugin_Continue;
}  