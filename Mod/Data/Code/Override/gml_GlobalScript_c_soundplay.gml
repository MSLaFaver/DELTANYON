function c_soundplay(arg0)
{
    c_cmd("soundplay", arg0, 0, 0, 0);
}

function c_sndplay(arg0)
{
    c_soundplay(arg0);
}

function c_snd_play(arg0)
{
    c_soundplay(arg0);
}

function c_sound_play(arg0)
{
    if (arg0 == snd_pianonoise && audio_exists(snd_pianonyon))
    {
        arg0 = snd_pianonyon;
        nyon_toast("snd_pianonoise.ogg");
    }

    c_soundplay(arg0);
}