_video_enabled = false;
_vid_surface = -4;
_chroma_surface = -4;
_video_display_w = 640;
_video_display_h = 480;
var offset = scr_is_switch_os() ? 0.015 : 0;
text_list = [
    new scr_video_caption(stringsetloc("It's now time for our feature presentation", "obj_ch3_couch_video_slash_Create_0_gml_4_0"), 0.02 + offset, 0.13 + offset),
    new scr_video_caption(stringsetloc("Coming straight from your nyon", "obj_ch3_couch_video_slash_Create_0_gml_6_0"), 0.22 + offset, 0.27 + offset),
    new scr_video_caption(stringsetloc("Coming straight from YOUR nyon", "obj_ch3_couch_video_slash_Create_0_gml_7_0"), 0.28 + offset, 0.32 + offset),
    new scr_video_caption(stringsetloc("He's the One", "obj_ch3_couch_video_slash_Create_0_gml_8_0"), 0.34 + offset, 0.43 + offset),
    new scr_video_caption(stringsetloc("He's KAWING and NEVER shooing!", "obj_ch3_couch_video_slash_Create_0_gml_9_0"), 0.44 + offset, 0.51 + offset),
    new scr_video_caption(stringsetloc("You can't get this from a SHI!", "obj_ch3_couch_video_slash_Create_0_gml_10_0"), 0.52 + offset, 0.57 + offset),
    new scr_video_caption(stringsetloc("The sensation of your screen", "obj_ch3_couch_video_slash_Create_0_gml_11_0"), 0.58 + offset, 0.62 + offset),
    new scr_video_caption(stringsetloc("The show that makes you ueueleuleue", "obj_ch3_couch_video_slash_Create_0_gml_12_0"), 0.63 + offset, 0.67 + offset),
    new scr_video_caption(stringsetloc("Say it with him, folks!", "obj_ch3_couch_video_slash_Create_0_gml_13_0"), 0.68 + offset, 0.73 + offset)
];
text_index = 0;
house_index = (global.lang == "ja") ? 3 : 2;
var file_name = (global.lang == "ja") ? "tennaIntroJPf1_compressed_28" : "tennaIntroF1_compressed_28";
var video_path = "vid/" + file_name + ".mp4";
var root_dir = global.nyon_root_dir;
if (!is_string(root_dir) || string_length(root_dir) == 0)
{
    root_dir = global.launcher ? working_directory + "../" : working_directory;
}
var nyon_video = root_dir + "nyons/" + file_name + ".mp4";
if (file_exists(nyon_video))
{
    video_path = nyon_video;
}
video_open(video_path);
video_enable_loop(false);
video_set_volume(global.flag[17]);
if (!global.is_console)
{
    video_set_volume(clamp(0.3 * global.flag[17], 0, 0.3));
}
videochromasampler = -4;
var _format = video_get_format();
if (_format == 1)
{
    videochromasampler = shader_get_sampler_index(shd_video_yuv, "v_chroma");
}
clean_up = function()
{
    if (os_type == os_ps4 || os_type == os_ps5)
    {
        var _status = video_get_status();
        if (_status != 0)
        {
            video_close();
        }
    }
    else
    {
        video_close();
    }
    if (surface_exists(_vid_surface))
    {
        surface_free(_vid_surface);
    }
    if (surface_exists(_chroma_surface))
    {
        surface_free(_chroma_surface);
    }
};
if (scr_is_switch_os())
{
    target_duration = 1224;
}
video_position = 0;