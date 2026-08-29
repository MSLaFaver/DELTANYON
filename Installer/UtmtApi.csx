using System;
using System.IO;
using UndertaleModLib.Compiler;
using UndertaleModLib.Models;
using UndertaleModLib.Scripting;
using UndertaleModLib.Util;

EnsureDataLoaded();

string ReadList(string dir, string file)
{
	if (string.IsNullOrWhiteSpace(dir)) return "";
	string path = Path.Combine(dir, file);
	return File.Exists(path) ? File.ReadAllText(path) : "";
}

string listDir = Environment.GetEnvironmentVariable("DRML_LIST_DIR");
string overrides = ReadList(listDir, "override.txt");
string prefixes = ReadList(listDir, "prefix.txt");
string postfixes = ReadList(listDir, "postfix.txt");
string sounds = ReadList(listDir, "sounds.txt");

if (string.IsNullOrWhiteSpace(overrides) && string.IsNullOrWhiteSpace(prefixes) && string.IsNullOrWhiteSpace(postfixes) && string.IsNullOrWhiteSpace(sounds))
	throw new ScriptException("No patch file list provided (DRML_LIST_DIR).");

string modRoot = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(ScriptPath), "..", "Mod"));
string codeRoot = Path.Combine(modRoot, "Data", "Code");
string soundsRoot = Path.Combine(modRoot, "Data", "Sounds");
string gameDir = Environment.GetEnvironmentVariable("DRML_GAME_DIR");
if (string.IsNullOrWhiteSpace(gameDir))
	gameDir = Path.GetDirectoryName(FilePath);

var group = new CodeImportGroup(Data);
int applied = 0;
int codePatches = 0;

foreach (var job in new[] {
	(overrides, Path.Combine(codeRoot, "Override"), "replace"),
	(prefixes, Path.Combine(codeRoot, "Prefix"), "prepend"),
	(postfixes, Path.Combine(codeRoot, "Postfix"), "append")
})
{
	if (string.IsNullOrWhiteSpace(job.Item1)) continue;

	foreach (string entry in job.Item1.Split(';'))
	{
		if (string.IsNullOrWhiteSpace(entry)) continue;

		int aliasAt = entry.IndexOf('@');
		string sourceFile = aliasAt >= 0 ? entry[(aliasAt + 1)..] : entry;
		string targetName = Path.GetFileNameWithoutExtension(aliasAt >= 0 ? entry[..aliasAt] : entry);
		string path = Path.Combine(job.Item2, sourceFile);
		if (!File.Exists(path)) throw new ScriptException($"Patch file not found: {path}");

		string gml = File.ReadAllText(path);
		if (string.IsNullOrWhiteSpace(gml)) continue;

		var code = Data.Code.ByName(targetName);
		if (code is null)
			throw new ScriptException($"Patch target not found in this chapter: {targetName}");

		switch (job.Item3)
		{
			case "replace": group.QueueReplace(code, gml); break;
			case "prepend": group.QueuePrepend(code, gml); break;
			case "append": group.QueueAppend(code, gml); break;
			default: throw new ScriptException($"Unknown patch mode: {job.Item3}");
		}

		applied++;
		codePatches++;
	}
}

foreach (string soundEntry in sounds.Split(';'))
{
	if (string.IsNullOrWhiteSpace(soundEntry)) continue;
	string soundPath = ResolveSoundPath(soundsRoot, soundEntry.Trim());
	PatchSound(soundPath, Path.GetFileNameWithoutExtension(soundPath));
	applied++;
}

if (applied == 0) throw new ScriptException("No patch entries matched this chapter.");
if (codePatches > 0)
{
	var result = group.Import();
	if (!result.Successful) throw new ScriptException(result.PrintAllErrors(true));
}

UndertaleString Str(string value) => Data.Strings.MakeString(value);
int BuiltinGroup() => Data.GetBuiltinSoundGroupID();
void Mark(UndertaleSound sound) => Project?.MarkAssetForExport(sound);

string ResolveSoundPath(string root, string soundFileName)
{
	string direct = Path.Combine(root, soundFileName);
	if (File.Exists(direct)) return direct;

	string assetName = Path.GetFileNameWithoutExtension(soundFileName);
	foreach (string ext in new[] { ".ogg", ".wav", ".OGG", ".WAV" })
	{
		string candidate = Path.Combine(root, assetName + ext);
		if (File.Exists(candidate)) return candidate;
	}

	throw new ScriptException($"Sound file not found for \"{soundFileName}\" in {root}");
}

UndertaleSound FindSound(string soundName)
{
	foreach (var sound in Data.Sounds)
		if (sound?.Name?.Content == soundName)
			return sound;
	return null;
}

UndertaleSound FindSoundTemplate(string soundName)
{
	UndertaleSound best = null, embedded = null, any = null;
	int bestPrefix = 0;
	int builtin = BuiltinGroup();

	foreach (var sound in Data.Sounds)
	{
		if (sound?.Name?.Content is not string name) continue;
		any ??= sound;
		if (sound.GroupID == builtin && sound.AudioFile is not null)
			embedded ??= sound;

		int prefix = 0;
		int len = Math.Min(soundName.Length, name.Length);
		while (prefix < len && soundName[prefix] == name[prefix])
			prefix++;
		if (prefix > bestPrefix)
		{
			bestPrefix = prefix;
			best = sound;
		}
	}

	return (best != null && bestPrefix >= 4) ? best : embedded ?? any;
}

bool IsExternal(UndertaleSound sound) =>
	sound.AudioFile is null && sound.AudioID < 0 && !string.IsNullOrWhiteSpace(sound.File?.Content);

string GroupPath(int groupId)
{
	if (groupId < Data.AudioGroups.Count && Data.AudioGroups[groupId] is UndertaleAudioGroup { Path.Content: string path })
		return Paths.JoinVerifyWithinDirectory(gameDir, path);
	return Paths.JoinVerifyWithinDirectory(gameDir, $"audiogroup{groupId}.dat");
}

UndertaleSound CloneSound(UndertaleSound template, string soundName, string soundPath) => new()
{
	Name = Str(soundName),
	Flags = template.Flags,
	Type = Str(Path.GetExtension(soundPath).ToLowerInvariant()),
	File = Str(Path.GetFileName(soundPath)),
	Effects = template.Effects,
	Volume = template.Volume,
	Pitch = template.Pitch,
	Preload = template.Preload,
	AudioGroup = template.AudioGroup,
	GroupID = template.GroupID,
};

void SetSoundAudio(UndertaleSound sound, byte[] data, bool create)
{
	if (IsExternal(sound))
	{
		File.WriteAllBytes(Paths.JoinVerifyWithinDirectory(gameDir, sound.File.Content), data);
		Mark(sound);
		return;
	}

	if (sound.GroupID == BuiltinGroup())
	{
		if (create)
		{
			var embedded = new UndertaleEmbeddedAudio { Name = Str(sound.Name.Content), Data = data };
			Data.EmbeddedAudio.Add(embedded);
			sound.AudioFile = embedded;
		}
		else if (sound.AudioFile is not null)
			sound.AudioFile.Data = data;
		else if (sound.AudioID >= 0 && sound.AudioID < Data.EmbeddedAudio.Count)
			Data.EmbeddedAudio[(int)sound.AudioID].Data = data;
		else
			throw new ScriptException($"Sound \"{sound.Name?.Content}\" has no embedded audio to replace.");

		Mark(sound);
		return;
	}

	string groupFile = GroupPath(sound.GroupID);
	UndertaleData groupDat;
	using (var read = File.OpenRead(groupFile))
		groupDat = UndertaleIO.Read(read);

	if (create)
	{
		groupDat.EmbeddedAudio.Add(new UndertaleEmbeddedAudio { Name = Str(sound.Name.Content), Data = data });
		sound.AudioID = groupDat.EmbeddedAudio.Count - 1;
		sound.AudioFile = null;
	}
	else
	{
		int audioId = (int)sound.AudioID;
		if (audioId < 0 || audioId >= groupDat.EmbeddedAudio.Count)
			throw new ScriptException($"Sound \"{sound.Name?.Content}\" has invalid audio index {audioId} in group {sound.GroupID}.");
		groupDat.EmbeddedAudio[audioId].Data = data;
	}

	using (var write = File.Create(groupFile))
		UndertaleIO.Write(write, groupDat);

	Mark(sound);
}

void PatchSound(string soundPath, string soundName)
{
	byte[] data = File.ReadAllBytes(soundPath);
	var existing = FindSound(soundName);
	if (existing is not null)
	{
		SetSoundAudio(existing, data, create: false);
		return;
	}

	var template = FindSoundTemplate(soundName)
		?? throw new ScriptException($"Sound asset not found in this chapter and no template available to create it: {soundName}");

	var sound = CloneSound(template, soundName, soundPath);
	if (IsExternal(template))
	{
		sound.AudioFile = template.AudioFile;
		sound.AudioID = template.AudioID;
	}

	Data.Sounds.Add(sound);
	SetSoundAudio(sound, data, create: !IsExternal(template));
}
