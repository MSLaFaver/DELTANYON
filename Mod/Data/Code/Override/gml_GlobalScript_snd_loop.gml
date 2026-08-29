function snd_loop(arg0)
{
	if (global.chapter == 3 && arg0 == snd_nes_intro_extended_part2)
		nyon_toast("nes_intro_extended_part2.ogg");
	else if (global.chapter == 5 && arg0 == snd_pink_stretch_2_troubled)
		nyon_toast("snd_pink_stretch_2_troubled.ogg");
	else if (global.chapter == 5 && arg0 == snd_pink_stretch_2_fixed)
		nyon_toast("snd_pink_stretch_2_fixed.ogg");

	return audio_play_sound(arg0, 50, 1);
}

function sound_loop(arg0)
{
	return snd_loop(arg0);
}
