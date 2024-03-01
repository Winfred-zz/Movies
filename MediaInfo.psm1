#
# Winfred 3/2011
#
#
$RedLine = $Null; $WindowWidth =(Get-Host).UI.RawUI.WindowSize.Width; $i = 1; do {$RedLine += "-"; $i++}while ($i -le $WindowWidth)
write-host "Loading MediaInfo" -fore Yellow
write-host "Get-MediaInfo -MovieFile `$File [-verbose]" -fore cyan
Write-host $RedLine -fore yellow -NoNewline; Write-host ""

#=====================================================================
# Get-MediaInfo
#=====================================================================
Function Get-MediaInfo
{
<#

.SYNOPSIS

 Returns an array of objects, consisting of the Audio and Video tracks from a media container file.
	
 Usage: Get-MediaInfo -MovieFile `$MovieFile [-Verbose]
 
 Dependencies: MediaInfo.exe and MediaInfo.dll 
 (files should be located in the Module Folder)
 
 Media Info supplies technical and tag information about a video or audio file. 

.EXAMPLE

$MovieObject = Get-MediaInfo "Path\Movie.mkv"

$MovieObject[0]

Complete_name       : Path\Movie.mkv
Duration            : 1h 50mn
File_size           : 700 MiB
Format              : AVI
Format_Info         : Audio Video Interleave
Overall_bit_rate    : 886 Kbps
type                : General
Writing_application : Nandub v1.0rc2
Writing_library     : Nandub build 1852/release

The other tracks are audio and video and can be queried like this:

(Get-MediaInfo "Path\Movie.mkv") | where {$_.type -eq "Audio"}
(Get-MediaInfo "Path\Movie.mkv") | where {$_.type -eq "Video"}

Keep in mind that multiple audio and/or video tracks can be returned (but only one General)

.NOTES

 Supported formats: 
 Video : MKV, OGM, MP4, AVI, MPG, VOB, MPEG1, MPEG2, MPEG4, 
 DVD, WMV, ASF, DivX, XviD, MOV (Quicktime), SWF(Flash), FLV, FLI, RM/RMVB. 
 Audio : OGG, MP3, WAV, RA, AC3, DTS, AAC, M4A, AU, AIFF, WMA. 

Uses the 0.7.60 version. https://mediaarea.net/en/MediaInfo/Download/Windows

.LINK

http://mediainfo.sourceforge.net/en

#>
param(
[Parameter(Position=0, Mandatory=$true)]$MovieFile
)
	if(!($MovieFile)){get-help Get-MediaInfo; Break}
	$ExtensionsArray = ".aac", ".ac3", ".aifc", ".aiff", ".ape", ".asf", ".au", ".avi", ".avr", ".dat", ".divx", ".dts", ".dvd", ".flac", ".fli", ".flv", ".iff", ".ifo", ".irca", ".m1v", ".m2v", ".m4a", ".mac", ".mat", ".mka", ".mks", ".mkv", ".mov", ".mp2", ".mp3", ".mp4", ".mpeg", ".mpeg1", ".mpeg2", ".mpeg4", ".mpg", ".mpgv", ".mpv", ".ogg", ".ogm", ".paf", ".pvf", ".qt", ".ra", ".rm", ".rmvb", ".sd2", ".sds", ".sw", ".vob", ".w64", ".wav", ".wma", ".wmv", ".xi", ".xvid"
	if(test-path $MovieFile)
	{
		$Executable = (join-path $PsScriptRoot MediaInfo.exe).tostring()
		$MovieFileObject = (get-item $MovieFile | where {$ExtensionsArray -eq $_.Extension.ToString().tolower()})
		$xmldata = new-object "System.Xml.XmlDocument"
		$xmldata.LoadXml((Invoke-Expression "$Executable --Output=XML `"$MovieFile`""))
		$i = 0
		$Collection = @()
		foreach($Track in $xmldata.Mediainfo.File.Track)
		{
			$myobj = new-object object
			foreach($Attribute in ($Track | get-member -MemberType properties))
			{
				write-Verbose "$($Attribute.Name) - $($Track.($Attribute.Name))"
				$myobj | add-member -membertype NoteProperty -Name ($Attribute.Name) -value ($Track.($Attribute.Name))
			}
			$Collection += $myobj
		}
		return $Collection
	}else{
		Write-host "$MovieFile Not Found" -fore Red
	}
}
