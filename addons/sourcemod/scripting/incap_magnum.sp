#pragma semicolon               1
#pragma newdecls                required


#include <sdktools>


public Plugin myinfo = {
	name = "IncapMagnum",
	author = "TouchMe",
	description = "Gives incapped players a magnum",
	version = "build0002",
	url = "https://github.com/TouchMe-Inc/l4d2_incap_magnum"
}


#define TEAM_SURVIVOR           2


char g_sWeaponStash[MAXPLAYERS + 1][32];
char g_sMeleeScript[MAXPLAYERS + 1][32];
bool g_bDualPistol[MAXPLAYERS + 1];


/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_Left4Dead2)
	{
		strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("player_incapacitated_start", Event_IncapacitatedStart);
	HookEvent("player_incapacitated", Event_Incapacitated);
	HookEvent("revive_success", Event_ReviveSuccess);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

Action Event_IncapacitatedStart(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	int iEntSecondaryWeapon = GetPlayerWeaponSlot(iClient, 1);

	g_sWeaponStash[iClient][0] = '\0';
	g_sMeleeScript[iClient][0] = '\0';
	g_bDualPistol[iClient] = false;

	if (iEntSecondaryWeapon == -1) {
		return Plugin_Continue;
	}

	char sEntClassName[64]; GetEdictClassname(iEntSecondaryWeapon, sEntClassName, sizeof(sEntClassName));

	if (StrEqual(sEntClassName[7], "melee", false))
	{
		strcopy(g_sWeaponStash[iClient], sizeof(g_sWeaponStash[]), sEntClassName);
		GetEntPropString(iEntSecondaryWeapon, Prop_Data, "m_strMapSetScriptName", g_sMeleeScript[iClient], sizeof(g_sMeleeScript[]));
	}

	else if (StrEqual(sEntClassName[7], "pistol_magnum", false)) {
		strcopy(g_sWeaponStash[iClient], sizeof(g_sWeaponStash[]), sEntClassName);
	}

	else if (StrEqual(sEntClassName[7], "pistol", false))
	{
		strcopy(g_sWeaponStash[iClient], sizeof(g_sWeaponStash[]), sEntClassName);
		g_bDualPistol[iClient] = view_as<bool>(GetEntProp(iEntSecondaryWeapon, Prop_Send, "m_isDualWielding"));
	}

	RemovePlayerItem(iClient, iEntSecondaryWeapon);

	return Plugin_Continue;
}

Action Event_Incapacitated(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsClientSurvivor(iClient)) {
		return Plugin_Continue;
	}

	int iEntSecondaryWeapon = GetPlayerWeaponSlot(iClient, 1);

	if (iEntSecondaryWeapon != -1) {
		RemovePlayerItem(iClient, iEntSecondaryWeapon);
	}

	GivePlayerItem(iClient, "weapon_pistol_magnum");

	return Plugin_Continue;
}

Action Event_ReviveSuccess(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "subject"));
	bool bLerdgeHang = GetEventBool(event, "ledge_hang");

	if (bLerdgeHang) {
		return Plugin_Continue;
	}

	int iEntSecondaryWeapon = GetPlayerWeaponSlot(iClient, 1);

	if (iEntSecondaryWeapon != -1) {
		RemovePlayerItem(iClient, iEntSecondaryWeapon);
	}

	if (g_sWeaponStash[iClient][0] != '\0')
	{
		if (StrEqual(g_sWeaponStash[iClient][7], "melee", false)) {
			GivePlayerItem(iClient, g_sMeleeScript[iClient]);
		} else {
			GivePlayerItem(iClient, g_sWeaponStash[iClient]);
		}


		if (g_bDualPistol[iClient]) {
			GivePlayerItem(iClient, g_sWeaponStash[iClient]);
		}
	}

	return Plugin_Continue;
}

Action Event_PlayerDeath(Event event, const char[] sName, bool bDontBroadcast)
{
	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!iVictim || !IsClientSurvivor(iVictim)) {
		return Plugin_Continue;
	}

	SpawnSecondary(iVictim);

	return Plugin_Continue;
}

bool SpawnSecondary(int iClient)
{
	if (g_sWeaponStash[iClient][0] == '\0') {
		return false;
	}

	int iEnt = -1;

	if (StrEqual(g_sWeaponStash[iClient][7], "melee", false))
	{
		iEnt = CreateEntityByName("weapon_melee");

		if (iEnt == -1) {
			return false;
		}

		DispatchKeyValue(iEnt, "melee_script_name", g_sMeleeScript[iClient]);
	}

	else if (StrEqual(g_sWeaponStash[iClient][7], "pistol_magnum", false)) {
		iEnt = CreateEntityByName("weapon_pistol_magnum");
	}

	else if (StrEqual(g_sWeaponStash[iClient][7], "pistol", false)) {
		iEnt = CreateEntityByName("weapon_pistol");
	}

	if (iEnt == -1) {
		return false;
	}

	DispatchSpawn(iEnt);
	float vOrigin[3]; GetClientEyePosition(iClient, vOrigin);
	TeleportEntity(iEnt, vOrigin, NULL_VECTOR, NULL_VECTOR);

	return true;
}

/**
 * Survivor team player?
 */
bool IsClientSurvivor(int iClient) {
	return (GetClientTeam(iClient) == TEAM_SURVIVOR);
}
