switch (global.toast_state)
{
	case 0:
		if (!ds_queue_empty(global.toast_queue))
		{
			var _toast = ds_queue_dequeue(global.toast_queue);
			global.toast_nyonmaker = ds_map_find_value(_toast, "nyonmaker");
			global.toast_title = ds_map_find_value(_toast, "title");
			global.toast_nyonmaker_color = ds_map_find_value(_toast, "nyonmaker_color");
			ds_map_destroy(_toast);
			draw_set_font(global.toast_font);
			var _gui_w = display_get_gui_width();
			var _box_w = _gui_w * global.toast_box_width_ratio;
			global.toast_padding = _box_w * global.toast_padding_ratio;
			var _approved_w = _box_w - (global.toast_padding * 2);
			var _text_w = string_width(global.toast_title);
			global.toast_scrolls = _text_w > _approved_w;
			global.toast_scroll_offset = 0;
			global.toast_phase = 0;
			global.toast_scroll_max = 0;
			global.toast_scroll_duration = 0;
			if (global.toast_scrolls)
			{
				global.toast_scroll_max = _text_w - _approved_w;
			}
			global.toast_state = 1;
			global.toast_timer = room_speed * global.toast_pre_slide_seconds;
		}
		break;
	case 1:
		global.toast_timer--;
		if (global.toast_timer <= 0)
		{
			global.toast_state = 2;
			global.toast_timer = room_speed * global.toast_slide_seconds;
		}
		break;
	case 2:
		global.toast_timer--;
		if (global.toast_timer <= 0)
		{
			global.toast_state = 3;
			if (global.toast_scrolls)
			{
				global.toast_phase = 0;
				global.toast_scroll_offset = 0;
				global.toast_timer = room_speed * global.toast_scroll_hold_seconds;
			}
			else
			{
				global.toast_timer = room_speed * global.toast_display_seconds;
			}
		}
		break;
	case 3:
		if (global.toast_scrolls)
		{
			switch (global.toast_phase)
			{
				case 0:
					global.toast_timer--;
					if (global.toast_timer <= 0)
					{
						global.toast_phase = 1;
						global.toast_scroll_duration = room_speed * max(1, global.toast_scroll_max / global.toast_scroll_pixels_per_second);
						global.toast_timer = global.toast_scroll_duration;
					}
					break;
				case 1:
					global.toast_timer--;
					var _elapsed = global.toast_scroll_duration - global.toast_timer;
					global.toast_scroll_offset = min(global.toast_scroll_max, (_elapsed / global.toast_scroll_duration) * global.toast_scroll_max);
					if (global.toast_timer <= 0)
					{
						global.toast_scroll_offset = global.toast_scroll_max;
						global.toast_phase = 2;
						global.toast_timer = room_speed * global.toast_scroll_hold_seconds;
					}
					break;
				case 2:
					global.toast_timer--;
					if (global.toast_timer <= 0)
					{
						global.toast_state = 4;
						global.toast_timer = room_speed * global.toast_slide_seconds;
					}
					break;
			}
		}
		else
		{
			global.toast_timer--;
			if (global.toast_timer <= 0)
			{
				global.toast_state = 4;
				global.toast_timer = room_speed * global.toast_slide_seconds;
			}
		}
		break;
	case 4:
		global.toast_timer--;
		if (global.toast_timer <= 0)
		{
			global.toast_state = 0;
		}
		break;
}