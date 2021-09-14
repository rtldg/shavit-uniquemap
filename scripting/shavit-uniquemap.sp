#include <sourcemod>
#include <shavit>

//MySQL settings
Database gH_SQL = null;
char gS_MySQLPrefix[32];


char gS_ServerIP[32];
char gS_MapName[128];

ArrayList g_MapList = null;

int g_mapListSerial = -1;

bool ForcedMapChange;
bool LastTimeForcedMapChange;


public Plugin myinfo =
{
	name = "[shavit] Unique Map",
	author = "theSaint, Updated by Charles_(hypnos)",
	description = "Disallow to play the same map on different shavit-timer servers",
	version = "1.6",
	url = ""
}

public void OnPluginStart()
{
	int arraySize = ByteCountToCells(PLATFORM_MAX_PATH);
	g_MapList = new ArrayList(arraySize);

	// THIS IS TO GET SERVERIP
	char server_port[10];
	char server_ip[16];
	
	Handle cvar_port = FindConVar("hostport");
	GetConVarString(cvar_port, server_port, sizeof(server_port));
	CloseHandle(cvar_port);
	
	Handle cvar_ip = FindConVar("ip");
	GetConVarString(cvar_ip, server_ip, sizeof(server_ip));
	CloseHandle(cvar_ip);
	
	FormatEx(gS_ServerIP,32,"%s:%s",server_ip,server_port);

	// DATABASE CONNECTIONS
	SQL_SetPrefix();
	SetSQLInfo();	
}

public void OnConfigsExecuted()
{
	if (ReadMapList(g_MapList, g_mapListSerial, "default", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) == null)
	{
		if (g_mapListSerial == -1)
		{
			LogError("Unable to create a valid map list.");
		}
	}
}

public void OnMapStart() 
{ 
	//Getting MapName
	GetCurrentMap(gS_MapName, 128);
	//Secure Change of Bools
	ForcedMapChange = false;
	LastTimeForcedMapChange = false;
	
	UniqueMapProcedure();
}


// --------------------
// Functions
// --------------------

void UniqueMapProcedure()
{
	CreateTimer(1.0, GetDataFromCurrentMapTable);
	CreateTimer(1.2, ReplaceMapInfo);
	CreateTimer(60.0, PrintChangedMapInfo);
}


public Action GetDataFromCurrentMapTable(Handle timer)
{
	char[] sQuery = new char[256];
	FormatEx(sQuery, 256, "SELECT * FROM %scurrentmap;", gS_MySQLPrefix);
	
	if (gH_SQL == null) 
	{
		LogError("gH_SQL to null!!!");
	}
	
	gH_SQL.Query(SQL_GetDataFromCurrentMapTable_Callback, sQuery);
	
	return Plugin_Handled;
}

public void SQL_GetDataFromCurrentMapTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{	
		LogError("COS SIE SPIERDOLILO W GetDataFromCurrentMapTable");
	}
	
	while(results.FetchRow())
	{
		char ip[32];
		char map[128];
		
		results.FetchString(0, ip, 32);
		results.FetchString(1, map, 128);
		int changed = results.FetchInt(2);
				
		if (StrEqual(ip, gS_ServerIP))
		{
			if (changed == 1)
			{
				LastTimeForcedMapChange = true;
			}	
		}
		
		if (StrEqual(map, gS_MapName) && !StrEqual(ip, gS_ServerIP))
		{	
			ForcedMapChange = true;
			CreateTimer(0.1, ChangeMap);
		}
	}
}

public Action ReplaceMapInfo(Handle timer)
{
	char[] sQuery = new char[512];
	FormatEx(sQuery, 512, "REPLACE INTO %scurrentmap (server_ip, current_map, last_time_changed) VALUES ('%s', '%s', %i);", gS_MySQLPrefix, gS_ServerIP , gS_MapName , ForcedMapChange)

	gH_SQL.Query(SQL_ReplaceMapInfo, sQuery);
	
	return Plugin_Handled;
}

public void SQL_ReplaceMapInfo(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{	
		LogError("COS SIE SPIERDOLILO W SQL_ReplaceMapInfo == '%s'", error);
	}
}

public Action ChangeMap(Handle timer)
{
	if(ForcedMapChange)
	{
		char map[PLATFORM_MAX_PATH];

		//GetNextMap(map, 128);
		//Get random map to prevent map change loop
		int b = GetRandomInt(0, g_MapList.Length - 1);
		g_MapList.GetString(b, map, sizeof(map));

		ForceChangeLevel(map, "Played on Another Server");
	}
	
	return Plugin_Handled;
}

public Action PrintChangedMapInfo(Handle timer)
{
	if(LastTimeForcedMapChange)
	{
		PrintToChatAll("===MAP CHANGED AUTOMATICALY, BECAUSE IT'S ALREADY PLAYED ON THE OTHER SERVER===");
		PrintToChatAll("===MAP CHANGED AUTOMATICALY, BECAUSE IT'S ALREADY PLAYED ON THE OTHER SERVER===");
		PrintToChatAll("===MAP CHANGED AUTOMATICALY, BECAUSE IT'S ALREADY PLAYED ON THE OTHER SERVER===");
		LastTimeForcedMapChange = false;
	}
	
	return Plugin_Handled;
}

// --------------------
// DATABASE CONNECTIONS
// --------------------

public void Shavit_OnDatabaseLoaded()
{
	gH_SQL = Shavit_GetDatabase();
	SetSQLInfo();
}

public Action CheckForSQLInfo(Handle Timer)
{
	return SetSQLInfo();
}

Action SetSQLInfo()
{
	if(gH_SQL == null)
	{
		gH_SQL = Shavit_GetDatabase();

		CreateTimer(0.5, CheckForSQLInfo);
	}

	else
	{
		SQL_DBConnect();

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void SQL_SetPrefix()
{
	char[] sFile = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, PLATFORM_MAX_PATH, "configs/shavit-prefix.txt");

	File fFile = OpenFile(sFile, "r");

	if(fFile == null)
	{
		SetFailState("Cannot open \"configs/shavit-prefix.txt\". Make sure this file exists and that the server has read permissions to it.");
	}
	
	char[] sLine = new char[PLATFORM_MAX_PATH*2];

	while(fFile.ReadLine(sLine, PLATFORM_MAX_PATH*2))
	{
		TrimString(sLine);
		strcopy(gS_MySQLPrefix, 32, sLine);

		break;
	}

	delete fFile;
}

void SQL_DBConnect()
{
	if(gH_SQL != null)
	{
		char[] sDriver = new char[8];
		gH_SQL.Driver.GetIdentifier(sDriver, 8);
		bool gB_MySQL = StrEqual(sDriver, "mysql", false);
		
		char[] sQuery = new char[512];
		
		if(gB_MySQL)
		{
			FormatEx(sQuery, 512, "CREATE TABLE IF NOT EXISTS `%scurrentmap` (`server_ip` VARCHAR(32), `current_map` VARCHAR(128), `last_time_changed` INT, PRIMARY KEY (`server_ip`));",gS_MySQLPrefix);
		}

		else
		{
			FormatEx(sQuery, 512, "CREATE TABLE IF NOT EXISTS `%scurrentmap` (`server_ip` VARCHAR(32) PRIMARY KEY, `current_map` VARCHAR(128), `last_time_changed` INT);",gS_MySQLPrefix);
		}

		gH_SQL.Query(SQL_CreateTable_Callback, sQuery, 0, DBPrio_High);
	}
}

public void SQL_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (uniquemap module) error! currenttimes table creation failed. Reason: %s", error);

		return;
	}
}
