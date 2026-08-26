function snd_play(arg0, arg1 = 1, arg2 = 1)
{
    var _snd = audio_play_sound(arg0, 50, 0);

    if (global.chapter == 3 && (arg0 == snd_nes_intro || arg0 == snd_nes_intro_extended))
        nyon_toast("nes_intro_extended_part2.ogg");

    if (arg1 != 1)
        snd_volume(_snd, arg1, 0);

    if (arg2 != 1)
        snd_pitch(_snd, arg2);

    return _snd;
}

function soundplay(arg0, arg1 = 1, arg2 = 1)
{
    var _snd = audio_play_sound(arg0, 50, 0);

    if (arg1 != 1)
        snd_volume(_snd, arg1, 0);

    if (arg2 != 1)
        snd_pitch(_snd, arg2);

    return _snd;
}

function sound_play(arg0, arg1 = 1, arg2 = 1)
{
    var _snd = audio_play_sound(arg0, 50, 0);

    if (arg1 != 1)
        snd_volume(_snd, arg1, 0);

    if (arg2 != 1)
        snd_pitch(_snd, arg2);

    return _snd;
}
