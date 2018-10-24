#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "AI"
#define PLUGIN_VERSION "0.1.0"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <smlib/entities>
#include <tf2_stocks>

ConVar g_hRocketDamage;
ConVar g_hRocketSpeed;
int g_iOffsetDamage;

public Plugin myinfo = 
{
	name = "Panzer Rockets",
	author = PLUGIN_AUTHOR,
	description = "Shoot rockets from panzer taunt's cannon",
	version = PLUGIN_VERSION,
	url = "https://github.com/geominorai/panzerrockets"
};

public void OnPluginStart()
{
	CreateConVar("sm_panzerrockets", PLUGIN_VERSION, "Panzer rocket version -- Do not modify", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_hRocketDamage = CreateConVar("sm_panzerrockets_damage", "120.0", "Rocket base damage", FCVAR_NONE, true, 0.0, false);
	g_hRocketSpeed = CreateConVar("sm_panzerrockets_speed", "4000.0", "Rocket speed", FCVAR_NONE, true, 0.0, false);
	g_iOffsetDamage = FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4;
}

public void OnEntityCreated(int iEntity, const char[] sClassName)
{
	if (StrEqual(sClassName, "instanced_scripted_scene", false)) {
		SDKHook(iEntity, SDKHook_Spawn, OnTaunt);
    }
}

public Action OnTaunt(int iEntity) {
	char sSceneFile[PLATFORM_MAX_PATH];
	GetEntPropString(iEntity, Prop_Data, "m_iszSceneFile", sSceneFile, sizeof(sSceneFile));
	
	if (StrEqual(sSceneFile, "scenes\\player\\soldier\\low\\taunt_vehicle_tank_fire.vcd")) {
		int iRocketEntity = CreateEntityByName("tf_projectile_rocket");
		if (IsValidEntity(iRocketEntity)) {
			int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwner");
			Entity_SetOwner(iRocketEntity, iOwner);
			int iTeam = GetClientTeam(iOwner);
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

			Entity_SetAbsOrigin(iRocketEntity, fPos);
			Entity_SetAbsAngles(iRocketEntity, fAng);
			Entity_SetAbsVelocity(iRocketEntity, fVel);

			DispatchSpawn(iRocketEntity);
		}
	}

	return Plugin_Continue;
}