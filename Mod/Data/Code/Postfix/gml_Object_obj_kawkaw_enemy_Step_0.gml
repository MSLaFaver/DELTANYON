if (acting == 101 && button3_p() == 1 && shoo_act_con == 0.3 && shoo_act_timer == 0)
{
    if (tearsize >= 6)
        snd_play(snd_ominous_hell_super);
    else if (tearsize >= 4)
        snd_play(snd_ominous_hell);
    else
        snd_play(snd_ominous);
}

if (acting == 103.21 && tearsize >= 7)
{
    global.irredeemable_monster = true;
    scr_damage_all(999);
}
