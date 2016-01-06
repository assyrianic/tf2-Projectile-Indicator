#include <sourcemod>
#include <tf2_stocks>
#include <morecolors>
#include <sdkhooks>
#include <macros>

#pragma semicolon		1
#pragma newdecls		required

#define PLUGIN_VERSION		"1.0"

#define IsClientValid(%1)	( 0 < %1 and %1 <= MaxClients )

public Plugin myinfo = { //registers plugin
	name = "projectile indicator",
	author = "Nergal/Assyrian/Ashurian",
	description = "Has players detect nearby projectiles",
	version = PLUGIN_VERSION,
	url = "Alliedmodders",
};

bool benabled[PLYR];

methodmap ProjDetect
{
	/**
	 * constructor
	 */
	public ProjDetect (int index, bool uid = false) {
		if (uid) {
			return view_as<ProjDetect>( index );
		}
		return view_as<ProjDetect>( GetClientUserId(index) );
	}

	/**
	 * Properties
	 */
	property int userid
	{
		public get()				{ return int(this); }
	}
	property int index
	{
		public get()				{ return GetClientOfUserId( this.userid ); }
	}
	property bool bDetect
	{
		public get()				{ return benabled[ this.index ]; }
		public set(bool val)			{ benabled[ this.index ] = val; }
	}

	/**
	 * Displays the Projectile indicator to alert player of nearly projectiles
	 *
	 * @param xpos		x position of the screen
	 * @param ypos		y position of the screen
	 * @noreturn
	 */
/*			This is how SetHudTextParams sets the x and y pos
		|-------------------------------------------------------|
		|			y 0.0				|
		|			|				|
		|			|				|
		|			|				|
		|			|				|
		|			|				|
		|			|				|
		|x 0.0 -----------------|-------------------------> 1.0 |
		|			|				|
		|			|				|
		|			|				|
		|			|				|
		|			V				|
		|			1.0				|
		|-------------------------------------------------------|
*/
	public void DrawIndicator ( float xpos, float ypos, char[] textc )
	{
		Handle indicator = CreateHudSynchronizer();
		if ( not indicator ) return;

		SetHudTextParams(xpos, ypos, 0.1, 255, 100, 0, 255, 0, 0.35, 0.0, 0.1); //orange color for visibility
		ShowSyncHudText(this.index, indicator, textc);
	}

	/**
	 * gets the distance between player and projectile!
	 *
	 * @param entref	serial reference of the entity
	 * @return		distance between player and proj
	 */
	public float GetDistFromProj ( int entref )
	{
		int proj = EntRefToEntIndex(entref);
		if ( proj <= 0 or not IsValidEntity(proj) ) return -1.0;

		float projpos[3]; GetEntPropVector(proj, Prop_Data, "m_vecAbsOrigin", projpos);
		float clientpos[3]; GetEntPropVector(this.index, Prop_Data, "m_vecAbsOrigin", clientpos);
		return GetVectorDistance(clientpos, projpos);
	}

	/**
	 * gets the delta vector between player and projectile!
	 *
	 * @param entref	serial reference of the entity
	 * @param vecBuffer	float buffer to store vector result
	 * @return		delta vector from vecBuffer
	 */
	public void GetDeltaVector ( int entref, float vecBuffer[3] )
	{
		int proj = EntRefToEntIndex(entref);
		if ( proj <= 0 or not IsValidEntity(proj) ) return;

		float vecPlayer[3]; GetClientAbsOrigin(this.index, vecPlayer);
		float vecPos[3]; GetEntPropVector(proj, Prop_Data, "m_vecAbsOrigin", vecPos);
		SubtractVectors( vecPlayer, vecPos, vecBuffer );
	}

	/**
	 * Gets the position of the projectile from the player's position
	 * and converts the data to screen numbers
	 *
	 * @param vecDelta	delta vector to work from
	 * @param xpos		x position of the screen
	 * @param ypos		y position of the screen
	 * @noreturn
	 * @note		set xpos and ypos as references so we can "return" both of them.
	 * @props		Code by Valve from their Source Engine hud_damageindicator.cpp
	 */
	public void GetProjPosToScreen ( const float vecDelta[3], float& xpos, float& ypos )
	{
		//float flRadius = 360.0;
		/*
		 get Player Data: eye position and angles - Why do we need eye pos? it's NEVER used!
		 EVEN IN THE ORIGINAL C++ CODE, playerPosition ISN'T USED. Wtf valve?
		*/		
		//float playerPosition[3]; GetClientEyePosition(this.index, playerPosition);
		float playerAngles[3]; GetClientEyeAngles(this.index, playerAngles);

		float vecforward[3], right[3], up[3] = { 0.0, 0.0, 1.0 };
		GetAngleVectors (playerAngles, vecforward, nullvec, nullvec );
		vecforward[2] = 0.0;

		NormalizeVector(vecforward, vecforward);
		GetVectorCrossProduct(up, vecforward, right);

		float front = GetVectorDotProduct(vecDelta, vecforward);
		float side = GetVectorDotProduct(vecDelta, right);
		/*
			this is part of original c++ code. unfortunately, it didn't work right.
			it made the indicators appear to the side when a projectile was RIGHT IN FRONT OF PLAYER...
			however, switching it made it work as intended =3
		*/
		//xpos = flRadius * -side;
		//ypos = flRadius * -front;

		xpos = 360.0 * -front;
		ypos = 360.0 * -side;

		// Get the rotation (yaw)
		//float flRotation = ArcTangent2(xpos, ypos) + FLOAT_PI;
		//flRotation *= 180.0 / FLOAT_PI; // Convert to degrees

		float flRotation = (ArcTangent2(xpos, ypos) + FLOAT_PI) * (180.0 / FLOAT_PI);

		float yawRadians = -flRotation * FLOAT_PI / 180.0; // Convert back to radians
		//float coss = Cosine(yawRadians);
		//float sinu = Sine(yawRadians);

		// Rotate it around the circle
		xpos = ( 500 + (360.0 * Cosine(yawRadians)) ) / 1000.0; //divide by 1000 to make it fit with HudTextParams
		ypos = ( 500 - (360.0 * Sine(yawRadians)) ) / 1000.0;
	}
};

ConVar PluginEnabled,
	DetectGrenades,
	DetectStickies,
	DetectGrenadeRadius,
	DetectStickyRadius,
	DetectFriendly
;

public void OnPluginStart () //be a rebel and detach parameter parenthesis from func name !
{
	PluginEnabled = CreateConVar("projindic_enabled", "1", "Enable Projectile Indicator plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	DetectGrenades = CreateConVar("projindic_grenades", "1", "Enable the Projectile Indicator plugin to detect pipe grenades", FCVAR_PLUGIN, true, 0.0, true, 1.0); //THIS INCLUDES CANNONBALLS

	DetectStickies = CreateConVar("projindic_stickies", "1", "Enable the Projectile Indicator plugin to detect stickybombs", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	DetectGrenadeRadius = CreateConVar("projindic_grenaderadius", "300.0", "Detection radius for pipe grenades in Hammer Units", FCVAR_PLUGIN, true, 0.0, true, 99999.0);

	DetectStickyRadius = CreateConVar("projindic_stickyradius", "300.0", "Detection radius for stickybombs in Hammer Units", FCVAR_PLUGIN, true, 0.0, true, 99999.0);

	DetectFriendly = CreateConVar("projindic_detectfriendly", "1", "Detect friendly projectiles", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	//RegAdminCmd("sm_command", CommandTemplate, ADMFLAG_SLAY, "AdminCommandTemplate");
	RegConsoleCmd("sm_detect", ToggleIndicator);
	RegConsoleCmd("sm_indic", ToggleIndicator);
	RegConsoleCmd("sm_forcedetecton", ForceDetection);

	AutoExecConfig(true, "Projectile-Indicator");

	for (int i = 1; i <= MaxClients; ++i)
	{
		if ( not IsValidClient(i) ) continue;
		OnClientPutInServer(i);
	}
}

public void OnClientPutInServer (int client)
{
	ProjDetect player = ProjDetect(client);
	player.bDetect = false;
	//SDKHook(client, SDKHook_PostThinkPost, BarBarKhashab);
	CreateTimer(0.1, TimerIndicatorThink, player.userid, TIMER_REPEAT);
}

public Action TimerIndicatorThink (Handle timer, any userid)
{
	if ( not PluginEnabled.BoolValue ) return Plugin_Continue;

	ProjDetect player = ProjDetect(userid, true);
	if ( not player.bDetect ) return Plugin_Continue;

	if ( not IsPlayerAlive(player.index) or IsClientObserver(player.index) ) return Plugin_Continue;

	float screenx, screeny;
	float vecGrenDelta[3], vecStickyDelta[3];

	int iEntity = -1, entref, thrower; //make variables OUTSIDE loop
	if (DetectGrenades.BoolValue)
	{
		while ( (iEntity = FindEntityByClassname2(iEntity, "tf_projectile_pipe")) not_eq -1 )
		{
			entref = EntIndexToEntRef(iEntity);
			if ( player.GetDistFromProj(entref) > DetectGrenadeRadius.FloatValue ) {
				continue;
			}

			thrower = GetThrower(EntRefToEntIndex(entref));
			if ( GetClientTeam(thrower) eq GetClientTeam(player.index) and not DetectFriendly.BoolValue )
			{
				continue;
			}
			player.GetDeltaVector(entref, vecGrenDelta);
			NormalizeVector(vecGrenDelta, vecGrenDelta);
			player.GetProjPosToScreen(vecGrenDelta, screenx, screeny);
			player.DrawIndicator(screenx, screeny, "O");
		}
	}
	iEntity = -1;
	if (DetectStickies.BoolValue)
	{
		while ( (iEntity = FindEntityByClassname2(iEntity, "tf_projectile_pipe_remote")) not_eq -1 )
		{
			entref = EntIndexToEntRef(iEntity);
			if ( player.GetDistFromProj(entref) > DetectStickyRadius.FloatValue ) {
				continue;
			}

			thrower = GetThrower(EntRefToEntIndex(entref));
			if ( GetClientTeam(thrower) eq GetClientTeam(player.index) and not DetectFriendly.BoolValue ) {
				continue;
			}

			player.GetDeltaVector(entref, vecStickyDelta);
			NormalizeVector(vecGrenDelta, vecGrenDelta);
			player.GetProjPosToScreen(vecStickyDelta, screenx, screeny);
			player.DrawIndicator(screenx, screeny, "X");
		}
	}
	return Plugin_Continue;
}
public Action ToggleIndicator (int client, int args)
{
	if ( not PluginEnabled.BoolValue ) return Plugin_Continue;

	ProjDetect player = ProjDetect(client);
	player.bDetect = true; //not player.bDetect;
	ReplyToCommand(player.index, "Projectile Indicator on");
	return Plugin_Handled;
}
public Action ForceDetection (int client, int args) //forces players to become the tank class regardless of team cvars
{
	if (PluginEnabled.BoolValue)
	{
		if (args < 1)
		{
			ReplyToCommand(client, "[Projectile Indicator] Usage: sm_forcedetecton <player/target>");
			return Plugin_Handled;
		}
		char name[PLATFORM_MAX_PATH]; GetCmdArg(1, name, sizeof(name));

		char target_name[MAX_TARGET_LENGTH];
		int target_list[PLYR], target_count;
		bool tn_is_ml;
		if ((target_count = ProcessTargetString(name, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, target_name, sizeof(target_name), tn_is_ml)) <= 0)
		{
			/* This function replies to the admin with a failure message */
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		ProjDetect player;
		for (int i = 0; i < target_count; ++i)
		{
			if (IsValidClient(target_list[i]))
			{
				player = ProjDetect(target_list[i]);
				player.bDetect = true;
			}
		}
		ReplyToCommand(client, "Forcing Projectile Indicators");
	}
	return Plugin_Continue;
}
/*
public Action CommandTemplate(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[Speed Mod] Usage: !command <target> <parameter>");
		return Plugin_Handled;
	}
	char szTargetname[64]; GetCmdArg(1, szTargetname, sizeof(szTargetname));
	char szNum[64]; GetCmdArg(2, szNum, sizeof(szNum));


	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS+1], target_count;
	bool tn_is_ml;
	if ( (target_count = ProcessTargetString(szTargetname, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0 )
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for (int i = 0; i < target_count; i++)
	{
		if ( IsValidClient(target_list[i]) )
		{

		}
	}
	return Plugin_Handled;
}*/

stock bool IsValidClient (int client, bool replaycheck = true)
{
	if ( not IsClientValid(client) ) return false;
	if ( not IsClientInGame(client) ) return false;
	if ( GetEntProp(client, Prop_Send, "m_bIsCoaching") ) return false;
	if ( replaycheck ) if ( IsClientSourceTV(client) or IsClientReplay(client) ) return false;
	return true;
}
stock int GetOwner (int ent)
{
	if ( IsValidEdict(ent) && IsValidEntity(ent) ) return GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
	return -1;
}
stock int GetThrower (int ent)
{
	if ( IsValidEdict(ent) && IsValidEntity(ent) ) return GetEntPropEnt(ent, Prop_Send, "m_hThrower");
	return -1;
}
stock int FindEntityByClassname2 (int startEnt, const char[] classname)
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 and not IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, classname);
}