#pragma semicolon 1

#define PLUGIN_AUTHOR "AI"
#define PLUGIN_VERSION "0.2.1"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>

ConVar g_hRocketDamage;
ConVar g_hRocketSpeed;
ConVar g_hTeam;
ConVar g_hSnapLock;
ConVar g_hSnapInterval;

bool g_bTank[MAXPLAYERS+1] = {false, ...};
bool g_bSnap[MAXPLAYERS+1] = {true, ...};

int g_iOffsetDamage;

public Plugin myinfo = {
	name = "Panzer Tank Rockets",
	author = PLUGIN_AUTHOR,
	description = "Shoot rockets from panzer taunt's cannon",
	version = PLUGIN_VERSION,
	url = "https://github.com/geominorai/panzerrockets"
};

public void OnPluginStart() {
	CreateConVar("sm_panzerrockets_version", PLUGIN_VERSION, "Panzer rockets version -- Do not modify", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_hRocketDamage = CreateConVar("sm_panzerrockets_damage", "120.0", "Rocket base damage", FCVAR_NONE, true, 0.0, false);
	g_hRocketSpeed = CreateConVar("sm_panzerrockets_speed", "4000.0", "Rocket speed", FCVAR_NONE, true, 0.0, false);
	g_hSnapLock = CreateConVar("sm_panzerrockets_lockforced", "0", "Force lock aim to turret angle", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hSnapInterval = CreateConVar("sm_panzerrockets_locksnap", "80", "Mouse movement needed before disabling aim lock (0 to disable aim lock)", FCVAR_NONE, true, 0.0);
	g_hTeam = CreateConVar("sm_panzerrockets_team", "1", "Enable for team (0: none, 1: any, 2: red, 3: blue)", FCVAR_NONE, true, 0.0, true, 3.0);
	g_iOffsetDamage = FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4;

	AutoExecConfig(true);
}

public void OnMapStart() {
	for (int i=1; i<=MaxClients; i++) {
		g_bTank[i] = false;
		g_bSnap[i] = true;
	}
}

public void OnClientConnected(int iClient) {
	g_bTank[iClient] = false;
	g_bSnap[iClient] = true;
}

public void TF2_OnConditionRemoved(int iClient, TFCond iCondition) {
	if (iCondition == TFCond_Taunting) {
		g_bTank[iClient] = false;
		g_bSnap[iClient] = true;
	}
}

public void OnEntityCreated(int iEntity, const char[] sClassName) {
	if (StrEqual(sClassName, "instanced_scripted_scene", false)) {
		SDKHook(iEntity, SDKHook_SpawnPost, Hook_SpawnTaunt);
	}
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &iWeapon, int& iSubType, int& iCmdNum, int& iTickCount, int& iSeed, int iMouse[2]) {
	if (!g_bTank[iClient] || !g_hSnapInterval.IntValue) {
		return Plugin_Continue;
	}

	if (iButtons & IN_BACK) {
		g_bSnap[iClient] = true;
	} else if (FloatAbs(float(iMouse[0])) > g_hSnapInterval.FloatValue) {
		g_bSnap[iClient] = false;
	}

	if (!g_bSnap[iClient] && !g_hSnapLock.BoolValue) {
		return Plugin_Continue;
	}

	float fParam = GetEntPropFloat(iClient, Prop_Send, "m_flPoseParameter", 4);
	float fAim = (fParam-0.5) * 120.0;

	float fAngDesired[3];
	GetClientEyeAngles(iClient, fAngDesired);

	fAngDesired[0] = clamp(fAngDesired[0] + 0.1*float(iMouse[1]), -90.0, 90.0);
	fAngDesired[1] = fAng[1] + fAim;

	TeleportEntity(iClient, NULL_VECTOR, fAngDesired, NULL_VECTOR);

	return Plugin_Continue;
}

public void Hook_SpawnTaunt(int iEntity) {
	char sSceneFile[PLATFORM_MAX_PATH];
	GetEntPropString(iEntity, Prop_Data, "m_iszSceneFile", sSceneFile, sizeof(sSceneFile));

	int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwner");

	if (StrEqual(sSceneFile, "scenes\\player\\soldier\\low\\taunt_vehicle_tank.vcd")) {
		g_bTank[iOwner] = true;
		return;
	} else if (StrEqual(sSceneFile, "scenes\\player\\soldier\\low\\taunt_vehicle_tank_end.vcd")) {
		g_bTank[iOwner] = false;
		return;
	} else if (!StrEqual(sSceneFile, "scenes\\player\\soldier\\low\\taunt_vehicle_tank_fire.vcd")) {
		return;
	}

	int iTeam = GetClientTeam(iOwner);

	if (!g_hTeam.IntValue || (g_hTeam.IntValue > 1 && iTeam != g_hTeam.IntValue)) {
		return;
	}

	int iRocketEntity = CreateEntityByName("tf_projectile_rocket");
	if (!IsValidEntity(iRocketEntity)) {
		return;
	}

	SetEntPropEnt(iRocketEntity, Prop_Send, "m_hOwnerEntity", iOwner);
	SetEntProp(iRocketEntity, Prop_Send, "m_iTeamNum", iTeam);

	SetEntDataFloat(iRocketEntity, g_iOffsetDamage, g_hRocketDamage.FloatValue, true);  

	float fPos[3];
	float fAng[3];
	float fVel[3];
	GetClientEyePosition(iOwner, fPos);
	GetClientAbsAngles(iOwner, fAng);

	fPos[2] -= 25.0;

	float fParam = GetEntPropFloat(iOwner, Prop_Send, "m_flPoseParameter", 4);

	float fAim = (fParam-0.5) * 120.0;
	fAng[1] += fAim;

	float fProj[2];
	fProj[0] = Cosine(DegToRad(fAng[1]));
	fProj[1] = Sine(DegToRad(fAng[1]));

	fVel[0] = g_hRocketSpeed.FloatValue * fProj[0];
	fVel[1] = g_hRocketSpeed.FloatValue * fProj[1];

	fPos[0] += 20.0 * fProj[0];
	fPos[1] += 20.0 * fProj[1];

	TeleportEntity(iRocketEntity, fPos, fAng, fVel);

	DispatchSpawn(iRocketEntity);
}

float clamp(float fValue, float fMin, float fMax) {
	if (fValue < fMin) {
		fValue = fMin;
	} else if (fValue > fMax) {
		fValue = fMax;
	}

	return fValue;
}