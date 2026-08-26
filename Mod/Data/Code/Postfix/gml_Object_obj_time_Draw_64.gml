if (global.toast_state != 0)
{
	var gui_w = display_get_gui_width();
	var gui_h = display_get_gui_height();
	var box_w = gui_w * global.toast_box_width_ratio;
	var box_h = gui_h * global.toast_box_height_ratio;
	var slide_duration = room_speed * global.toast_slide_seconds;
	var hidden_y = -box_h - global.toast_hidden_pad;
	var progress = 0;
	if (global.toast_state == 2)
	{
		progress = 1 - (global.toast_timer / slide_duration);
	}
	else if (global.toast_state == 3)
	{
		progress = 1;
	}
	else if (global.toast_state == 4)
	{
		progress = max(0, global.toast_timer / slide_duration);
	}
	var draw_x = gui_w - box_w;
	var draw_y = lerp(hidden_y, 0, progress);
	draw_set_alpha(global.toast_bg_alpha);
	draw_set_color(c_black);
	draw_rectangle(draw_x, draw_y, draw_x + box_w, draw_y + box_h, false);
	draw_set_alpha(1);
	draw_set_halign(fa_center);
	draw_set_valign(fa_middle);
	var pad = global.toast_padding;
	var content_w = box_w - (pad * 2);
	var content_x = draw_x + pad;
	var box_center_x = draw_x + (box_w / 2);
	if (global.toast_scrolls)
	{
		var clip_w = floor(content_w);
		var clip_h = floor(box_h);
		if (!surface_exists(global.toast_clip_surface) || global.toast_clip_w != clip_w || global.toast_clip_h != clip_h)
		{
			if (surface_exists(global.toast_clip_surface))
			{
				surface_free(global.toast_clip_surface);
			}
			global.toast_clip_surface = surface_create(clip_w, clip_h);
			global.toast_clip_w = clip_w;
			global.toast_clip_h = clip_h;
		}
		surface_set_target(global.toast_clip_surface);
		draw_clear_alpha(c_black, 0);
		draw_set_font(global.toast_font);
		draw_set_halign(fa_left);
		draw_set_valign(fa_middle);
		draw_set_color(global.toast_title_color);
		draw_set_alpha(1);
		draw_text(-global.toast_scroll_offset, clip_h * global.toast_title_y_ratio, global.toast_title);
		surface_reset_target();
		draw_surface(global.toast_clip_surface, content_x, draw_y);
	}
	else
	{
		draw_set_font(global.toast_font);
		draw_set_color(global.toast_title_color);
		draw_text(box_center_x, draw_y + (box_h * global.toast_title_y_ratio), global.toast_title);
	}
	draw_set_font(global.toast_font);
	draw_set_halign(fa_center);
	draw_set_color(global.toast_nyonmaker_color);
	draw_text(box_center_x, draw_y + (box_h * global.toast_nyonmaker_y_ratio), global.toast_nyonmaker);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_alpha(1);
}