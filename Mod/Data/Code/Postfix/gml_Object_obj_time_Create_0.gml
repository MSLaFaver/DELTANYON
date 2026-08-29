global.toast_queue = ds_queue_create();
global.toast_state = 0;
global.toast_timer = 0;
global.toast_title = "";
global.toast_nyonmaker = "";
global.toast_title_color = c_gray;
global.toast_nyonmaker_color = c_white;
global.toast_scrolls = false;
global.toast_scroll_offset = 0;
global.toast_scroll_max = 0;
global.toast_padding = 0;
global.toast_phase = 0;
global.toast_scroll_duration = 0;
global.toast_clip_surface = -1;
global.toast_clip_w = 0;
global.toast_clip_h = 0;
global.toast_font = fnt_main;
global.toast_nyonmaker_font = fnt_mainbig;
global.toast_box_width_ratio = 0.25;
global.toast_box_height_ratio = 0.1;
global.toast_padding_ratio = 0.1;
global.toast_title_y_ratio = 0.25;
global.toast_nyonmaker_y_ratio = 0.65;
global.toast_bg_alpha = 0.65;
global.toast_slide_seconds = 0.25;
global.toast_pre_slide_seconds = 0.5;
global.toast_display_seconds = 5;
global.toast_scroll_hold_seconds = 2;
global.toast_scroll_pixels_per_second = 50;
global.toast_hidden_pad = 2;
global.nyon_toasted = [];
global.nyon_json = -1;
global.nyon_data = -1;
global.nyon_root_dir = global.launcher ? working_directory + "../" : working_directory;
global.irredeemable_monster = false;
var nyon_path = global.nyon_root_dir + "nyon.json";
if (file_exists(nyon_path))
{
	var nyon_file = file_text_open_read(nyon_path);
	var nyon_text = "";
	while (!file_text_eof(nyon_file))
	{
		nyon_text += file_text_read_string(nyon_file);
		file_text_readln(nyon_file);
	}
	file_text_close(nyon_file);
	try
	{
		var _decoded = json_decode(nyon_text);
		if (ds_exists(_decoded, ds_type_map))
		{
			global.nyon_json = _decoded;
			var _list = ds_map_find_value(_decoded, "default");
			if (ds_exists(_list, ds_type_list))
			{
				global.nyon_data = _list;
			}
		}
	}
	catch (_err)
	{
	}
}