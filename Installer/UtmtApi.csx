using System;
using System.IO;
using UndertaleModLib.Compiler;
using UndertaleModLib.Models;
using UndertaleModLib.Scripting;
using UndertaleModLib.Util;

EnsureDataLoaded();

string overrides = "";
string prefixes = "";
string postfixes = "";
string sounds = "";
string listDir = Environment.GetEnvironmentVariable("DRML_LIST_DIR");

if (!string.IsNullOrWhiteSpace(listDir))
{
	string overPath = Path.Combine(listDir, "override.txt");
	string prefixPath = Path.Combine(listDir, "prefix.txt");
	string postPath = Path.Combine(listDir, "postfix.txt");
	string soundsPath = Path.Combine(listDir, "sounds.txt");
	if (File.Exists(overPath)) overrides = File.ReadAllText(overPath);
	if (File.Exists(prefixPath)) prefixes = File.ReadAllText(prefixPath);
	if (File.Exists(postPath)) postfixes = File.ReadAllText(postPath);
	if (File.Exists(soundsPath)) sounds = File.ReadAllText(soundsPath);
}

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

		string targetName;
		string sourceFile;
		int aliasAt = entry.IndexOf('@');
		if (aliasAt >= 0)
		{
			targetName = Path.GetFileNameWithoutExtension(entry[..aliasAt]);
			sourceFile = entry[(aliasAt + 1)..];
		}
		else
		{
			sourceFile = entry;
			targetName = Path.GetFileNameWithoutExtension(entry);
		}

		string path = Path.Combine(job.Item2, sourceFile);
		if (!File.Exists(path)) throw new ScriptException($"Patch file not found: {path}");

		string gml = File.ReadAllText(path);
		if (string.IsNullOrWhiteSpace(gml)) continue;

		var code = Data.Code.ByName(targetName);
		if (code is null)
			throw new ScriptException($"Patch target not found in this chapter: {targetName}");

		switch (job.Item3)
		{
			case "replace":
				group.QueueReplace(code, gml);
				break;
			case "prepend":
				group.QueuePrepend(code, gml);
				break;
			case "append":
				group.QueueAppend(code, gml);
				break;
			default:
				throw new ScriptException($"Unknown patch mode: {job.Item3}");
		}

		applied++;
		codePatches++;
	}
}

foreach (string soundEntry in sounds.Split(';'))
{
	if (string.IsNullOrWhiteSpace(soundEntry)) continue;

	string soundFileName = soundEntry.Trim();
	string assetName = Path.GetFileNameWithoutExtension(soundFileName);
	string soundPath = Path.Combine(soundsRoot, soundFileName);

	if (!File.Exists(soundPath))
	{
		soundPath = null;
		foreach (string ext in new[] { ".ogg", ".wav", ".OGG", ".WAV" })
		{
			string candidate = Path.Combine(soundsRoot, assetName + ext);
			if (File.Exists(candidate))
			{
				soundPath = candidate;
				break;
			}
		}
	}

	if (soundPath is null)
		throw new ScriptException($"Sound file not found for \"{soundFileName}\" in {soundsRoot}");

	ReplaceExistingSound(soundPath, assetName);
	applied++;
}

if (applied == 0) throw new ScriptException("No patch entries matched this chapter.");

if (codePatches > 0)
{
	var result = group.Import();
	if (!result.Successful) throw new ScriptException(result.PrintAllErrors(true));
}

void ReplaceExistingSound(string soundPath, string soundName)
{
	UndertaleSound existingSound = null;
	for (int i = 0; i < Data.Sounds.Count; i++)
	{
		if (Data.Sounds[i]?.Name?.Content == soundName)
		{
			existingSound = Data.Sounds[i];
			break;
		}
	}

	if (existingSound is null)
		throw new ScriptException($"Sound asset not found in this chapter: {soundName}");

	byte[] newData = File.ReadAllBytes(soundPath);
	string externalFile = existingSound.File?.Content;
	bool isExternal = existingSound.AudioFile is null
		&& existingSound.AudioID < 0
		&& !string.IsNullOrWhiteSpace(externalFile);

	if (isExternal)
	{
		string externalPath = Paths.JoinVerifyWithinDirectory(gameDir, externalFile);
		File.WriteAllBytes(externalPath, newData);
		Project?.MarkAssetForExport(existingSound);
		return;
	}

	int audioGroupID = existingSound.GroupID;
	int builtinGroupID = Data.GetBuiltinSoundGroupID();

	if (audioGroupID == builtinGroupID)
	{
		if (existingSound.AudioFile is not null)
		{
			existingSound.AudioFile.Data = newData;
		}
		else if (existingSound.AudioID >= 0 && existingSound.AudioID < Data.EmbeddedAudio.Count)
		{
			Data.EmbeddedAudio[(int)existingSound.AudioID].Data = newData;
		}
		else
		{
			throw new ScriptException($"Sound \"{soundName}\" has no embedded audio to replace.");
		}
	}
	else
	{
		string relativeAudioGroupPath;
		if (audioGroupID < Data.AudioGroups.Count && Data.AudioGroups[audioGroupID] is UndertaleAudioGroup { Path.Content: string customRelativePath })
			relativeAudioGroupPath = customRelativePath;
		else
			relativeAudioGroupPath = $"audiogroup{audioGroupID}.dat";

		string audioGroupPath = Paths.JoinVerifyWithinDirectory(gameDir, relativeAudioGroupPath);
		UndertaleData audioGroupDat;
		using (FileStream audioGroupReadStream = new(audioGroupPath, FileMode.Open, FileAccess.Read))
			audioGroupDat = UndertaleIO.Read(audioGroupReadStream);

		int audioID = (int)existingSound.AudioID;
		if (audioID < 0 || audioID >= audioGroupDat.EmbeddedAudio.Count)
			throw new ScriptException($"Sound \"{soundName}\" has invalid audio index {audioID} in group {audioGroupID}.");

		audioGroupDat.EmbeddedAudio[audioID].Data = newData;

		using FileStream audioGroupWriteStream = new(audioGroupPath, FileMode.Create);
		UndertaleIO.Write(audioGroupWriteStream, audioGroupDat);
	}

	Project?.MarkAssetForExport(existingSound);
}