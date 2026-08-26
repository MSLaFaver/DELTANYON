function nyon_toast_seen(arg0)
{
	if (!is_array(global.nyon_toasted))
	{
		return false;
	}
	var i = 0;
	while (i < array_length(global.nyon_toasted))
	{
		if (global.nyon_toasted[i] == arg0)
		{
			return true;
		}
		i++;
	}
	return false;
}

function nyon_find_entry(arg0)
{
	if (!ds_exists(global.nyon_data, ds_type_list))
	{
		return undefined;
	}
	var i = 0;
	var _count = ds_list_size(global.nyon_data);
	while (i < _count)
	{
		var _entry = ds_list_find_value(global.nyon_data, i);
		if (ds_exists(_entry, ds_type_map) && ds_map_exists(_entry, "filename") && ds_map_find_value(_entry, "filename") == arg0)
		{
			return _entry;
		}
		i++;
	}
	return undefined;
}

function nyon_songname_from_stream(arg0)
{
	var i = 0;
	var _count = instance_number(obj_astream);
	while (i < _count)
	{
		var _astream = instance_find(obj_astream, i);
		if (_astream.mystream == arg0)
		{
			return _astream.songname;
		}
		i++;
	}
	return undefined;
}

function nyon_on_music_stream(arg0)
{
	var _songname = nyon_songname_from_stream(arg0);
	if (_songname == undefined)
	{
		return;
	}
	if (nyon_find_entry(_songname) == undefined)
	{
		return;
	}
	nyon_toast(_songname);
}

function nyon_toast(arg0)
{
	if (!is_array(global.nyon_toasted))
	{
		global.nyon_toasted = [];
	}
	if (nyon_toast_seen(arg0))
	{
		return;
	}
	global.nyon_toasted[array_length(global.nyon_toasted)] = arg0;
	var _entry = nyon_find_entry(arg0);
	if (_entry == undefined)
	{
		return;
	}
	var nyonmaker = "";
	if (ds_map_exists(_entry, "nyonmaker"))
	{
		nyonmaker = string(ds_map_find_value(_entry, "nyonmaker"));
	}
	var title = arg0;
	if (ds_map_exists(_entry, "title"))
	{
		var _title = ds_map_find_value(_entry, "title");
		if (string_length(string(_title)) > 0)
		{
			title = string(_title);
		}
	}
	var nyonmaker_color = c_white;
	if (nyonmaker == "Atlas2007")
	{
		nyonmaker_color = c_yellow;
	}
	var _toast = ds_map_create();
	ds_map_set(_toast, "nyonmaker", nyonmaker);
	ds_map_set(_toast, "title", title);
	ds_map_set(_toast, "nyonmaker_color", nyonmaker_color);
	ds_queue_enqueue(global.toast_queue, _toast);
}

function snd_init(arg0)
{
	var root_dir = global.nyon_root_dir;
	if (!is_string(root_dir) || string_length(root_dir) == 0)
	{
		root_dir = working_directory;
		if (global.launcher)
		{
			root_dir = working_directory + "../";
		}
	}
	var dir = global.launcher ? root_dir + "mus/" : "mus/";
	if (nyon_find_entry(arg0) != undefined && file_exists(root_dir + "nyons/" + arg0))
	{
		dir = root_dir + "nyons/";
	}
	initsongvar = dir + arg0;
	_mystream = audio_create_stream(initsongvar);
	_astream = instance_create(0, 0, obj_astream);
	_astream.mystream = _mystream;
	_astream.songname = arg0;

	if (arg0 == "cyber_battle_prelude.ogg")
	{
		nyon_toast(arg0);
	}

	return _mystream;
}

function sound_init(arg0)
{
	snd_init(arg0);
}
