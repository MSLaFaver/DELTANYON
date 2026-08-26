function scr_get_bromide_data(arg0) constructor
{
	key_item_id = arg0;
	bromide_sprite = 6187;
	bromide_audio = 663;
	if (key_item_id == 33)
	{
		bromide_sprite = (scr_flag_get(349) == 0) ? 4793 : 7708;
		bromide_audio = 656;
		nyon_toast("snd_flowery_bromide_f.ogg");
	}
	else
	{
		nyon_toast("snd_flowery_bromide_r.ogg");
	}
}