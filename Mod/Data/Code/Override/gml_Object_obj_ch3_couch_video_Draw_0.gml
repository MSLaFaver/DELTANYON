if (!_video_enabled)
{
	exit;
}
var _video_data = video_draw();
var _video_status = _video_data[0];
if (_video_status == 0)
{
	switch (video_get_format())
	{
		case 0:
			_vid_surface = _video_data[1];
			if (surface_exists(_vid_surface))
			{
				draw_surface_stretched(_vid_surface, 0, 0, _video_display_w, _video_display_h);
			}
			break;
		case 1:
			_vid_surface = _video_data[1];
			_chroma_surface = _video_data[2];
			if (surface_exists(_vid_surface) && surface_exists(_chroma_surface))
			{
				shader_set(shd_video_yuv);
				var _tex_id = surface_get_texture(_vid_surface);
				var _chroma_tex_id = surface_get_texture(_chroma_surface);
				texture_set_stage(videochromasampler, _chroma_tex_id);
				gpu_set_texfilter(false);
				var sw = _video_display_w;
				var sh = _video_display_h;
				draw_primitive_begin_texture(pr_trianglestrip, _tex_id);
				draw_vertex_texture(0, 0, 0, 0);
				draw_vertex_texture(sw, 0, 1, 0);
				draw_vertex_texture(0, sh, 0, 1);
				draw_vertex_texture(sw, sh, 1, 1);
				draw_primitive_end();
				gpu_set_texfilter(true);
				shader_reset();
			}
			break;
	}
	if (scr_debug())
	{
		if (keyboard_check_pressed(vk_space))
		{
			var _status = video_get_status();
			if (_status == 2)
			{
				video_pause();
			}
			else if (_status == 3)
			{
				video_resume();
			}
		}
	}
	if (scr_is_switch_os())
	{
		video_position += 1;
	}
	else
	{
		target_duration = video_get_duration() - 150;
		video_position = video_get_position();
	}
	if (video_position >= target_duration)
	{
		if (!i_ex(obj_ch3_couch_video_screenshot))
		{
			var _screenshot = instance_create(0, 0, obj_ch3_couch_video_screenshot);
			_screenshot.depth = depth - 10;
		}
	}
	if (text_index > (array_length_1d(text_list) - 1))
	{
		exit;
	}
	var _duration = video_get_duration() / 1000;
	var track_position = video_get_position() / 1000;
	var track_progress = track_position / _duration;
	if (track_progress >= text_list[text_index].time_end)
	{
		text_index++;
		if (text_index > (array_length_1d(text_list) - 1))
		{
			exit;
		}
	}
	if (track_progress >= text_list[text_index].time_start && track_progress < text_list[text_index].time_end)
	{
		if (text_index == house_index)
		{
			scr_84_set_draw_font("main");
			draw_set_halign(fa_center);
			draw_set_color(c_black);
			draw_text(camerax() + (view_wport[0] / 4) + 2, cameray() + 40 + 2, text_list[text_index].caption_text);
			draw_text(camerax() + (view_wport[0] / 4) + 4, cameray() + 40 + 4, text_list[text_index].caption_text);
			draw_set_color(c_yellow);
			draw_text_outline(camerax() + (view_wport[0] / 4), cameray() + 40, text_list[text_index].caption_text, 8388608);
			draw_set_color(c_white);
			draw_set_halign(fa_left);
		}
		else
		{
			scr_84_set_draw_font("mainbig");
			draw_set_halign(fa_center);
			draw_set_color(c_black);
			draw_text(camerax() + (view_wport[0] / 2) + 2, ((cameray() + view_hport[0]) - 60) + 2, text_list[text_index].caption_text);
			draw_text(camerax() + (view_wport[0] / 2) + 4, ((cameray() + view_hport[0]) - 60) + 4, text_list[text_index].caption_text);
			draw_set_color(c_yellow);
			draw_text_outline(camerax() + (view_wport[0] / 2), (cameray() + view_hport[0]) - 60, text_list[text_index].caption_text, 8388608);
			draw_set_color(c_white);
			draw_set_halign(fa_left);
		}
	}
}
gpu_set_texfilter(false);