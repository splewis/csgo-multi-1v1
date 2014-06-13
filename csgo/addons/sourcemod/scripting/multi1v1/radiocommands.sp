/**
 * This blocks all radio commands, assuming AddRadioCommandListeners is called.
 */

new String:g_radioCommands[][] = {
    "go", "cheer", "fallback", "sticktog", "holdpos", "followme",
    "roger", "negative", "cheer", "compliment", "thanks",
    "enemyspot", "needbackup", "takepoint", "sectorclear", "inposition",
    "takingfire", "reportingin", "getout", "enemydown"
};

public AddRadioCommandListeners() {
    for (new i = 0; i < sizeof(g_radioCommands); i++)
        AddCommandListener(Command_Radio, g_radioCommands[i]);
}

public Action:Command_Radio(client, const String:command[], argc) {
    return Plugin_Handled;
}
