#
# This is a powershell module for managing movies and TV shows. To use it, you'll have to save it as a .psm1 file in your module folder.
#
$RedLine = $Null; $WindowWidth =(Get-Host).UI.RawUI.WindowSize.Width; $i = 1; do {$RedLine += "-"; $i++}while ($i -le $WindowWidth)
write-host "Loading Movies" -fore Yellow
write-host "get-help Convert-HandbrakeCommand -full" -fore cyan
write-host "get-help ConvertTo-x265 -full" -fore cyan
write-host "get-help Get-MovieClassification -full" -fore cyan
write-host "get-help Merge-Movies -full" -fore cyan
write-host "get-help New-Playlist -full" -fore cyan
write-host "get-help Rename-Movies -full" -fore cyan
write-host "get-help Rename-TVSeasons -full" -fore cyan
write-host "Get-MediaInfo -MovieFile `$File [-verbose]" -fore cyan
Write-host $RedLine -fore yellow -NoNewline; Write-host ""

#============================================================================================
# New-Playlist
#============================================================================================

function New-Playlist
{
<#

.SYNOPSIS
This commandlet makes a new M3U8 playlist, that can be used by programs that support them,
Like: Winamp, VLC and SMPlayer

.DESCRIPTION
Creates a new playlist based on a provided SearchString. The SearchString can contain wild cards:

* matches any set of characters.
? matches a single character.
\w matches any word character, meaning letters and numbers.
\s matches any white space character, such as tabs, spaces, and so forth.
\d matches any digit character.

\W (capital W) any non-word character
\S any non-white space.
\D any non digit. 

.EXAMPLE

New-Playlist (get-childitem d:\movies | Where-Object {($_.Name -match "Dora") -and ($_.Name -match "Dutch")} | foreach-Object {$_.FullName}) -verbose

.EXAMPLE
New-Playlist (get-childitem \\Uchuujin-san\movies | Where-Object {(($_.Name -match "Dora") -or `
			($_.Name -match "Diego")) -and ($_.Name -match "Dutch")} | foreach-Object `
			{$_.FullName}) -M3U8File "DoraDiego" -verbose
.EXAMPLE
New-Playlist (get-childitem \\Uchuujin-san\movies | Where-Object {($_.Name -match "- Dutch")} | foreach-Object `
			{$_.FullName}) -M3U8File "Dutch" -verbose
.EXAMPLE
New-Playlist (get-childitem \\Uchuujin-san\movies | Where-Object {($_.Name -match "- Spanish") `
-and ($_.Name -ne "The Rosetta Stone - Spanish")} | foreach-Object `
{$_.FullName}) -M3U8File "Spanish" -verbose

.NOTES
M3U is for Playlists, M3U8 is for UTF-8 playlists.
UTF supports additional characters which are frequently used for foreign languages.

.PARAMETER Folders

Folders (or files for that matter) to add to the M3U8 file.

.PARAMETER M3U8File

Name of the file to save to. If a path is missing, current path is used.
If a dot is missing, m3u8 is assumed.

.LINK

http://en.wikipedia.org/wiki/M3U
http://www.computerperformance.co.uk/powershell/powershell_conditional_operators.htm

#>
param(
[Parameter(Position=0, Mandatory=$true)]$Folders,
[Parameter(Position=1, Mandatory=$false)]$M3U8File
)
	if(!$M3U8File){$M3U8File = "Playlist.m3u8"}
	if(!($M3U8File.contains(".")))
	{
		#Missing . so, adding extention.
		$M3U8File = $M3U8File + ".m3u8"
	}
	if(split-path $M3U8File)
	{
		#There's a path in M3U8File
	}else{
		#There's no path in M3U8File, use current folder.
		$M3U8File = Join-path (Get-Location -PSProvider FileSystem).ProviderPath $M3U8File
	}
	$ExtensionsArray = ".aac", ".ac3", ".aifc", ".aiff", ".ape", ".asf", ".au", ".avi", ".avr", ".dat", ".divx", ".dts", ".dvd", ".flac", ".fli", ".flv", ".iff", ".ifo", ".irca", ".m1v", ".m2v", ".m4a", ".mac", ".mat", ".mka", ".mks", ".mkv", ".mov", ".mp2", ".mp3", ".mp4", ".mpeg", ".mpeg1", ".mpeg2", ".mpeg4", ".mpg", ".mpgv", ".mpv", ".ogg", ".ogm", ".paf", ".pvf", ".qt", ".ra", ".rm", ".rmvb", ".sd2", ".sds", ".sw", ".vob", ".w64", ".wav", ".wma", ".wmv", ".xi", ".xvid"
	$M3U8Content = @()
	$M3U8Content += "#EXTM3U"

	foreach($Folder in $Folders)
	{
		$MovieFileObjects = (get-childitem $Folder | Where-Object {$ExtensionsArray -eq $_.Extension.ToString().tolower()})
		foreach($MovieFileObject in $MovieFileObjects)
		{
			write-Verbose "$($MovieFileObject.fullname)"
			$Duration = (Get-MediaInfo "$($MovieFileObject.fullname)" -verbose:$verbose)[0].Duration
			if($Duration)
			{
				# This can probably be done better by a regular expression, but this will work for now.
				if($Duration.split(" ")[0].contains("h"))
				{
					# There's an hour mark in there (I'm not checking for days, if that happens, the script will break).
					# Not sure what it does when a movie is less than 1 minute.
					$DurationInSeconds = (([int]$Duration.split(" ")[0].replace("h","") * 60) + ([int]$Duration.split(" ")[1].replace("mn",""))) * 60
				}else{
					# There's only minutes in there.
					$DurationInSeconds = ([int]$Duration.split(" ")[0].replace("mn","")) * 60
				}
			}else{
				$DurationInSeconds = 1
			}
			# Have to replace dashes, because VLC interprets them as Artist/Title
			$M3U8Content += "#EXTINF:$DurationInSeconds,$(($MovieFileObject.directory.name).Replace("-"," ")) $($MovieFileObject.BaseName)"
			$M3U8Content += "$($MovieFileObject.fullname)"
		}
		write-Verbose "Saving to $M3U8File"
		$M3U8Content | out-file $M3U8File -Encoding "UTF8"
	}
}

#============================================================================================
# Rename-Movies
#============================================================================================
Function Rename-Movies
{
param(
<#

.SYNOPSIS
Renames all similar files in a folder also removes underscores and dots and removes leading/trailing spaces.

.DESCRIPTION
will remove [ and ] and everything in between them.
needs get-LongestCommonSubstring and get-LongestCommonSubstringArray

.EXAMPLE
Rename-Movies "K:\Movie7\D.Gray-man - Season 2 (2007)"
.NOTES

.LINK


#>
[Parameter(Position=0, Mandatory=$True)]$MovieFolder
)
	if(!(test-path $MovieFolder))
	{
		Break
	}
	Push-Location
	set-location $MovieFolder
	# First remove square brackets.
	if(Get-ChildItem '*``[*``]*')
	{
		do
		{
			$SquareBracketFiles = Get-ChildItem '*``[*``]*' | Where-Object { $_.Attributes -notlike "Directory" }
			foreach($SquareBracketFile in $SquareBracketFiles)
			{
				$SquareBracketOpen = ($SquareBracketFile.Name).IndexOf("[")
				$SquareBracketClose =($SquareBracketFile.Name).IndexOf("]")
				$ReplaceThis = ($SquareBracketFile.Name).Substring($SquareBracketOpen, $SquareBracketClose - $SquareBracketOpen + 1)
				Move-Item -literalpath $SquareBracketFile.Name $SquareBracketFile.Name.Replace($ReplaceThis, "")
			}
		}while(Get-ChildItem '*``[*``]*')
	}
	#Let's get rid of the _ and .
	# Find common string.
	$LongestCommonSubstring = get-LongestCommonSubstringArray (get-childitem $MovieFolder  | Where-Object { $_.Attributes -notlike "Directory" } | ForEach-Object{$_.BaseName})
	if($LongestCommonSubstring -and ($LongestCommonSubstring.length -gt 2))
	{
		$NewFileName = $Null
		Foreach($File in (get-childitem $MovieFolder | Where-Object { $_.Attributes -notlike "Directory" }))
		{
			$NewFileName = $File.BaseName.Replace($LongestCommonSubstring, "")
			$NewFileName = $NewFileName.Replace("_", " ")
			$NewFileName = $NewFileName.Replace(".", " ")
			$NewFileName = $NewFileName.Trim()
			$NewFileName = $NewFileName + $File.Extension
			Move-Item -literalpath $File.Name $NewFileName
		}
	}
	# Trim spaces
	Pop-Location
}

#============================================================================================
# get-LongestCommonSubstring
#============================================================================================
Function get-LongestCommonSubstring
{
Param(
[string]$String1, 
[string]$String2
)
    if((!$String1) -or (!$String2)){Break}
	# .Net Two dimensional Array:
	$Num = New-Object 'object[,]' $String1.Length, $String2.Length
    [int]$maxlen = 0
    [int]$lastSubsBegin = 0
	$sequenceBuilder = New-Object -TypeName "System.Text.StringBuilder"

    for ([int]$i = 0; $i -lt $String1.Length; $i++)
    {
        for ([int]$j = 0; $j -lt $String2.Length; $j++)
        {
            if ($String1[$i] -ne $String2[$j])
			{
                    $Num[$i, $j] = 0
            }else{
                if (($i -eq 0) -or ($j -eq 0))
				{
                        $Num[$i, $j] = 1
                }else{
                        $Num[$i, $j] = 1 + $Num[($i - 1), ($j - 1)]
				}
                if ($Num[$i, $j] -gt $maxlen)
                {
                    $maxlen = $Num[$i, $j]
                    [int]$thisSubsBegin = $i - $Num[$i, $j] + 1
                    if($lastSubsBegin -eq $thisSubsBegin)
                    {#if the current LCS is the same as the last time this block ran
                            [void]$sequenceBuilder.Append($String1[$i]);
                    }else{ #this block resets the string builder if a different LCS is found
                        $lastSubsBegin = $thisSubsBegin
                        $sequenceBuilder.Length = 0 #clear it
                        [void]$sequenceBuilder.Append($String1.Substring($lastSubsBegin, (($i + 1) - $lastSubsBegin)))
                    }
                }
            }
        }
    }
	return $sequenceBuilder.ToString()
}
#============================================================================================
# get-LongestCommonSubstringArray
#============================================================================================
Function get-LongestCommonSubstringArray
{
Param(
[Parameter(Position=0, Mandatory=$True)][Array]$Array
)
    $PreviousSubString = $Null
    $LongestCommonSubstring = $Null
    foreach($SubString in $Array)
    {
    	if($LongestCommonSubstring)
    	{
    		$LongestCommonSubstring = get-LongestCommonSubstring $SubString $LongestCommonSubstring
    		write-verbose "Consequtive diff: $SubString - $LongestCommonSubstring = $LongestCommonSubstring"
    	}else{
    		if($PreviousSubString)
    		{
    			$LongestCommonSubstring = get-LongestCommonSubstring $SubString $PreviousSubString
    			write-verbose "first diff: $SubString - $PreviousSubString = $LongestCommonSubstring"
    		}else{
    			$PreviousSubString = $SubString
    			write-verbose "No PreviousSubstring yet, setting it to: $PreviousSubString"
    		}
    	}
    }
    Return $LongestCommonSubstring
}




#============================================================================================
# Get-MovieClassification
#============================================================================================
$apikeys = get-content (join-path $PsScriptRoot apikeys.txt).tostring()
$TheMovieDBapikey = $apikeys | Where-Object {$_ -match "TheMovieDBapikey"} | ForEach-Object {$_ -replace "TheMovieDBapikey="}
$TheTVDBAuthentication = @{
	"apikey" = $apikeys | Where-Object {$_ -match "TVDBapikey"} | ForEach-Object {$_ -replace "TVDBapikey="}
	"userkey" = $apikeys | Where-Object {$_ -match "TVDBuserkey"} | ForEach-Object {$_ -replace "TVDBuserkey="}
	"username" = $apikeys | Where-Object {$_ -match "TVDBusername"} | ForEach-Object {$_ -replace "TVDBusername="}
}
Function Get-MovieClassification
{
<#

.SYNOPSIS
	Will classify a movie based on the name and year. Uses themoviedb.org and thetvdb.com
.DESCRIPTION

.EXAMPLE
	Get-MovieClassification -MovieName "Am I Normal (2007)"
.EXAMPLE
	Get-MovieClassification -MovieName "American Photography - A Century of Images (1999)" -Verbose
	Get-MovieClassification -MovieName "Andy Hamilton's Search For Satan (2011)" -Verbose
	Get-MovieClassification -MovieName "Animals In Love (2007)" -Verbose
	Get-MovieClassification -MovieName "De Helaasheid Der Dingen (2009)" -Verbose
	Get-MovieClassification -MovieName "Brass Eye (1997)" -Verbose
	Get-MovieClassification -MovieName "Building the Biggest (2006)" -Verbose
	Get-MovieClassification -MovieName "Colour Me Kubrick - A True...Ish Story (2005)" -Verbose
	Get-MovieClassification -MovieName "Baukunst (2001)" -Verbose
	
.EXAMPLE
	remove-module movies
	IPMO C:\movies\Movies.psm1
	$Unknown = @()
	$Documentaries = @()
	$Movies = @()
	$Anime = @()
	$TV = @()
	$Dutch = @()
	$MovieNames = get-content C:\movies\movienames.txt
	$i = 0
	foreach($MovieName in $MovieNames)
	{
		write-host "$i $MovieName" -fore yellow
		$Result = $Null
		$Result = Get-MovieClassification -MovieName $MovieName
		if($Result -eq "Documentary")
		{
			$Documentaries += $MovieName
		}elseif($Result -eq "Movie"){
			$Movies += $MovieName
		}elseif($Result -eq "Anime"){
			$Anime += $MovieName
		}elseif($Result -eq "TV"){
			$TV += $MovieName
		}elseif($Result -eq "Dutch"){
			$Dutch += $MovieName
		}else{
			$Unknown += $MovieName
		}
		start-sleep -Milliseconds 500
		$i++
	}
.NOTES
	apikeys are stored in a file called apikeys.txt in the module folder and will have to be set before this works.
.LINK


#>
param(
$MovieName,
[switch]$TitleSplit,
[switch]$Verbose
)
	# $Genres = (Invoke-RestMethod -Uri "https://api.themoviedb.org/3/genre/movie/list?api_key=apikeyhere&language=en-US").genres
	#$Genres = @{
	#	Action=28
	#	Adventure=12
	#	Animation=16
	#	Comedy=35
	#	Crime=80
	#	Documentary=99
	#	Drama=18
	#	Family=10751
	#	Fantasy=14
	#	History=36
	#	Horror=27
	#	Music=10402
	#	Mystery=9648
	#	Romance=10749
	#	"Science Fiction"=878
	#	"TV Movie"=10770
	#	Thriller=53
	#	War=10752
	#	Western=37
	#}

	$MovieName = $MovieName.tolower().Replace(" -",":")
	[int]$MovieYear = $Null
	if($MovieName -match "\([0-9][0-9][0-9][0-9]\)")
	{
		$MovieYear = $MovieName.split("(")[1].Replace(")","")
		$MovieName = $MovieName.split("(")[0].Trim()
		$MovieYears = (($MovieYear + 1),$MovieYear,($MovieYear -1))
	}
	$TheMovieDBMatch = $Null
	Add-Type -AssemblyName System.Web
	$URLMovieName = [System.Web.HttpUtility]::UrlEncode($MovieName)
	$SearchResult = $Null
	$SearchResult = Invoke-RestMethod -Uri "https://api.themoviedb.org/3/search/movie?api_key=$($TheMovieDBapikey)&query=$URLMovieName"
	$DutchLanguage = $Null

	if($SearchResult)
	{
		if($SearchResult.total_results -ge 1)
		{
			$PossibleVideoObjects = @()
			foreach($VideoObject in $SearchResult.Results)
			{
				$NameMatchFound = $Null
				if($VideoObject.title.tolower().StartsWith($MovieName))
				{
					if($Verbose)
					{
						write-host "TheMovieDB Title match: $MovieName - $($VideoObject.title)" -fore green
					}
					$NameMatchFound = $True
				}else{
					if($VideoObject.original_title.tolower().StartsWith($MovieName))
					{
						if($Verbose)
						{
							write-host "TheMovieDB Title match on original_title: $MovieName - $($VideoObject.original_title)" -fore green

						}
						$NameMatchFound = $True
						if($VideoObject.original_language.tolower() -eq "nl")
						{
							$DutchLanguage = $True
							if($Verbose)
							{
								write-host "TheMovieDB Language is Dutch: $MovieName - $($VideoObject.title)" -fore green

							}
						}
					}else{
						write-host "TheMovieDB - mismatching on title: $MovieName - $($VideoObject.title.tolower())" -for red
					}
				}
				if($NameMatchFound)
				{
					if($VideoObject.release_date)
					{
						$VideoObjectReleaseYear = $VideoObject.release_date.split("-")[0]
						if($VideoObjectReleaseYear -and $MovieYear)
						{
							if($MovieYears -eq $VideoObjectReleaseYear)
							{
								if($Verbose)
								{
									write-host "TheMovieDB Year match: $MovieYear - $VideoObjectReleaseYear" -fore green
								}
								$TheMovieDBMatch = $True
								
								break
							}else{
								if($Verbose)
								{
									write-host "TheMovieDB - No match on year: $MovieName $MovieYears" -for red
								}
							}
						}else{
							if(!$MovieYear)
							{
								write-host "TheMovieDB - Year is missing but we have a potential match: $MovieName - $($VideoObject.release_date.split("-")[0])" -for red
							}
						}
					}

				}
			}
		}else{
			if($Verbose)
			{
				write-host "TheMovieDB - Nothing matched on title: $MovieName" -for red
			}
		}
	}else{
		if($Verbose)
		{
			write-host "TheMovieDB - Nothing returned at all?" -for red
		}
	}
	$theTVDBMatch = $Null
	if(!$TheMovieDBMatch)
	{
		$TheTVDBToken = (Invoke-RestMethod -Uri "https://api.thetvdb.com/login" -Method Post -Body ($TheTVDBAuthentication | ConvertTo-Json) -ContentType 'application/json').token
		$TVDBHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
		$TVDBHeaders.Add("Accept", "application/json")
		$TVDBHeaders.Add("Authorization", "Bearer $TheTVDBToken")
		$SearchResult = $Null
		try
		{
			$SearchResult = (Invoke-RestMethod -Uri "https://api.thetvdb.com/search/series?name=$URLMovieName" -Headers $TVDBHeaders)
		}catch [System.Net.WebException]
		{
			# Looks like it wasn't found
		}
		if($SearchResult)
		{
			$PossibleVideoObjects = @()
			foreach($VideoObject in $SearchResult.data)
			{
				if($VideoObject.seriesName.tolower().StartsWith($MovieName))
				{
					if($Verbose)
					{
						write-host "theTVDB Title match: $MovieName - $($VideoObject.seriesName)" -fore green
					}
					if($VideoObject.firstAired)
					{
						$VideoObjectReleaseYear = $VideoObject.firstAired.split("-")[0]
						if($VideoObjectReleaseYear -and $MovieYear)
						{
							if($MovieYears -eq $VideoObjectReleaseYear)
							{
								if($Verbose)
								{
									write-host "theTVDB Year match: $MovieYear - $VideoObjectReleaseYear" -fore green
								}
								$theTVDBMatch = $True
								
								break
							}else{
								if($Verbose)
								{
									write-host "theTVDB - No match on year: $MovieName $MovieYears" -for red
								}
							}
						}else{
							if($Verbose)
							{
								write-host "theTVDB $MovieName - Something wrong with Year: $MovieYears -eq $VideoObjectReleaseYear" -fore magenta
							}
						}
					}else{
						if($Verbose)
						{
							write-host "theTVDB Title match: $MovieName - No year in TVDB" -fore magenta
						}
						$PossibleVideoObjects += $VideoObject
					}
				}else{
					write-host "theTVDB - mismatching on title: $MovieName - $($VideoObject.seriesName.tolower())" -for red
				}
			}
			if((!$theTVDBMatch) -and $PossibleVideoObjects)
			{
				if($PossibleVideoObjects.count -eq 1)
				{
					$theTVDBMatch = $True
					$VideoObject = $PossibleVideoObjects
					write-host "theTVDB - matched on title missing year: $MovieName - $($VideoObject.seriesName.tolower())" -for green
				}else{
					write-host "theTVDB - multiple potentials found without year: $MovieName - $($PossibleVideoObjects.seriesName.tolower())" -for red
				}
			}
		}else{
			if($Verbose)
			{
				write-host "theTVDB - Nothing returned on title: $MovieName" -for red
			}
		}
	}
	$DocuWikiNotFound = $Null
	$DocuWikiFound = $Null
	$WebPageYear = $Null
	$DocuWikiMatch = $Null
	if(!$theTVDBMatch -and !$TheMovieDBMatch)
	{
		$URL = "https://docuwiki.net/index.php?title=$URLMovieName"
		$WebPage = Invoke-WebRequest -uri $URL 
		
		if(!($WebPage.StatusCode -eq "200"))
		{
			Write-host "Couldn't query docuwiki.net" -fore red
		}else{
			foreach($Line in $WebPage.Content.split("`n"))
			{
				if(!$DocuWikiNotFound)
				{
					if($DocuWikiFound)
					{
						if($Line.StartsWith('<a href="/index.php?title=Category:Year" title="Category:Year">Year</a> &gt; <a href="/index.php?title=Category:'))
						{
							$Line = $Line.Replace('<a href="/index.php?title=Category:Year" title="Category:Year">Year</a> &gt; <a href="/index.php?title=Category:',"")
							$WebPageYear = $Line.Split('"')[0]
						}
					}else{
						if($line.trim().tolower() -eq '<meta name="robots" content="noindex,nofollow" />')
						{
							if($Verbose)
							{
								write-host "docuwiki - $MovieName not found" -fore red
							}
							$DocuWikiNotFound = $True
						}elseif($line.trim().tolower() -eq "<h1 class=`"firstheading`">$MovieName</h1>")
						{
							if($Verbose)
							{
								write-host "docuwiki Title match: $MovieName" -fore green
							}
							$DocuWikiFound = $True
						}elseif($line.trim().tolower().StartsWith("<h1 class=`"firstheading`">"))
						{
							$DocuWikiFound = $True
							if($line.trim().tolower() -eq "<h1 class=`"firstheading`">$MovieName</h1>")
							{
								if($Verbose)
								{
									write-host "docuwiki Title match: $MovieName" -fore green
								}
							}else{
								$TranslatedName = $Null
								$TranslatedName = $line.trim().tolower().Split(">")[1].Replace("</h1>","")
								write-host "docuwiki Title match under translated Name: $MovieName - $TranslatedName" -fore green
							}
						}
					}
				}
			}
		}
		if($DocuWikiFound)
		{
			if($MovieYear)
			{
				if($WebPageYear)
				{
					if($MovieYears -eq $WebPageYear)
					{
						$DocuWikiMatch = $True
					}else{
						if($Verbose)
						{
							write-host "docuwiki - $MovieName found, but years mismatch: $WebPageYear - $MovieYears" -fore red
						}
					}
				}
			}else{
				$DocuWikiMatch = $True
			}
		}
	}
	if(($theTVDBMatch -or $TheMovieDBMatch -or $DocuWikiMatch) -and $TitleSplit)
	{
		write-host "$MovieName Split title found! Update name" -fore yellow
	}
	if($theTVDBMatch)
	{
		$SeriesResult = (Invoke-RestMethod -Uri "https://api.thetvdb.com/series/$($VideoObject.id)" -Headers $TVDBHeaders)
		$SeriesObject = $SeriesResult.data
		$TVGenres = "Reality", "Comedy"
		if(($SeriesObject.genre -eq "Documentary") -or ($SeriesObject.genre -eq "News"))
		{
			return "Documentary"
		}else{
			if(($SeriesObject.genre -eq "Anime") -or ($SeriesObject.genre -eq "Animation"))
			{
				return "Anime"
			}elseif($TVGenres -eq $SeriesObject.genre){
				return "TV"
			}else{
				write-host "uncategorized genres theTVDBMatch"
				write-host "$($SeriesObject.genre)" -fore magenta
			}
		}
	}
	if($TheMovieDBMatch)
	{
		if($DutchLanguage)
		{
			return "Dutch"
		}
		if($VideoObject.genre_ids -eq 99)
		{
			return "Documentary"
		}else{
			if($Verbose)
			{
				write-host "uncategorized genre_ids TheMovieDBMatch"
				write-host "$($VideoObject.genre_ids)" -fore magenta
			}
			return "Movie"
		}
	}
	if($DocuWikiMatch)
	{
		return "Documentary"
	}

	if(!($theTVDBMatch) -and !($TheMovieDBMatch) -and !($DocuWikiMatch) -and ($MovieName -match ":"))
	{
		$NewMovieName = $Null
		if($MovieYear)
		{
			$NewMovieName = "$($MovieName.split(":")[0].trim()) ($MovieYear)"
		}else{
			$NewMovieName = $MovieName.split(":")[0].trim()
		}
		if($Verbose)
		{
			write-host "Trying with a split name for $MovieName |now trying: $NewMovieName" -fore Magenta
		}
		Get-MovieClassification -MovieName $NewMovieName -TitleSplit -Verbose:$Verbose
	}
}

#============================================================================================
# Rename-TVSeasons
#============================================================================================
Function Rename-TVSeasons
{
<#

.SYNOPSIS
	Will change the way seasons are sorted. Creates a top folder without -Season,
	then adds the -season folders into it.
.DESCRIPTION

.EXAMPLE
	Rename-TVSeasons -Folder "F:\TV"
.NOTES

.LINK

#>
param(
$Folder
)
	$DutchFolders = get-childitem $Folder | Where-Object {$_.name -match "  "}
	foreach($Folder in $DutchFolders)
	{
		Rename-Item -Path $Folder.fullname -NewName $Folder.fullname.Replace("  "," ")
	}
	if($Folder -match "Dutch")
	{
		$DutchFolders = get-childitem $Folder | Where-Object {$_.name -match "- Dutch "}
		foreach($Folder in $DutchFolders)
		{
			Rename-Item -Path $Folder.fullname -NewName $Folder.fullname.Replace("- Dutch","")
		}
	}
	
	$SeasonFolders = get-childitem $Folder | Where-Object {$_.name -match "- Season "}
	
	foreach($SubFolder in $SeasonFolders)
	{
		$SplitFolderNameArray = $SubFolder.Name.split("-").Trim()
		$i = 0
		$TopLevelFolderName = ""
		Foreach($NamePart in $SplitFolderNameArray)
		{
			if($NamePart -match "Season ")
			{
				break
			}else{
				if($i -gt 0)
				{
					$TopLevelFolderName += " - $($SplitFolderNameArray[$i])"
				}else{
					$TopLevelFolderName += "$($SplitFolderNameArray[$i])"
				}
			}
			$i++
		}
		if(!(Test-path "$($Folder)\$($TopLevelFolderName)"))
		{
			mkdir "$($Folder)\$($TopLevelFolderName)"
		}
		Move-Item -Path $SubFolder.FullName -Destination "$($Folder)\$($TopLevelFolderName)"
	}
}

#============================================================================================
# Group-Movies
#============================================================================================
Function Group-Movies
{
<#

.SYNOPSIS
	
.DESCRIPTION

.EXAMPLE
	Group-Movies -Folder "G:\Movie1"
.EXAMPLE
	Group-Movies -Folder "G:\Movie1" -Verbose
.NOTES

.LINK

#>
param(
$Folder,
[switch]$Verbose
)
	$Drive = $Folder.split("\")[0] + "\"

	# Exclude all seasons (going to be TV and anime) and dutch (will make a separate step for these)
	$SubFolders = $Null
	$SubFolders = get-childitem $Folder
	Foreach($SubFolder in $SubFolders)
	{
		$Unknown = $Null
		$MovieName = $SubFolder.Name
		$MovieName = $MovieName.Tolower().Replace("- Season ","")
		write-host "$MovieName" -fore yellow
		$Result = $Null
		if($MovieName -match " - Dutch ")
		{
			$NewFolderPath = Join-Path $Drive Dutch
		}else{
			$Result = Get-MovieClassification -MovieName $MovieName -verbose:$Verbose
			if($Result -eq "Documentary")
			{
				$NewFolderPath = Join-Path $Drive Documentaries
			}elseif($Result -eq "Movie"){
				$NewFolderPath = Join-Path $Drive Movies
			}elseif($Result -eq "Anime"){
				$NewFolderPath = Join-Path $Drive Anime
			}elseif($Result -eq "TV"){
				$NewFolderPath = Join-Path $Drive TV
			}elseif($Result -eq "Dutch"){
				$NewFolderPath = Join-Path $Drive Dutch
			}else{
				$Unknown += $MovieName
				$Unknown = $True
			}
		}
		if(!$Unknown)
		{
			if(!(test-path $NewFolderPath))
			{
				write-host "making $NewFolderPath"
				start-sleep 1
				mkdir $NewFolderPath
			}
			$NewFolderName = Join-Path $NewFolderPath $MovieName
			if(test-path $NewFolderName)
			{
				write-host "=== $NewFolderName already exists! ===" -fore red
			}else{
				Move-Item -Path $SubFolder.FullName -Destination $NewFolderPath
			}
		}
		start-sleep -Milliseconds 500
	}
	if(Join-Path $Drive Anime)
	{
		Rename-TVSeasons -Folder (Join-Path $Drive Anime)
	}
	if(Join-Path $Drive TV)
	{
		Rename-TVSeasons -Folder (Join-Path $Drive TV)
	}
	if(Join-Path $Drive Documentaries)
	{
		Rename-TVSeasons -Folder (Join-Path $Drive Documentaries)
	}
	if(Join-Path $Drive Dutch)
	{
		Rename-TVSeasons -Folder (Join-Path $Drive Dutch)
	}
}


#============================================================================================
# ConvertTo-x265
#============================================================================================
Function ConvertTo-x265
{
<#

.SYNOPSIS
	Copiess a moviefile to \\ferb\Video\ToBeRemoved, then makes a new x265 file.
.DESCRIPTION

.EXAMPLE
	ConvertTo-x265 -FolderName "\\ferb\Video\Anime1\One-Punch Man"
	ConvertTo-x265 -FolderName "\\ferb\Video\Anime1\One-Punch Man" -onlyover1gb
.EXAMPLE
	ConvertTo-x265 -FolderName "\\ferb\Video\Anime1\One-Punch Man\Season 2\One-Punch Man - S02E01 - Return of the Hero - HDTV-1080p - x265 Opus.mkv"
.NOTES
	Will only copy back the x265 file if it is at least 5% smaller than the old file.
.LINK

#>
param(
$FolderName,
[switch]$onlyover1gb,
$Quality=22,
[switch]$To1080
)
	$Folder = get-item $FolderName
	$ItsaFile = $False
	if($Folder.gettype().Name -eq "FileInfo")
	{
		$ItsaFile = $True
		$File = get-item $FolderName
		$Folder = get-item $File.Directory.FullName
	}
	if($env:computername -eq "phineas")
	{
		$driveletter = "E:\"
		$ToBeRemovedFolder = Join-path "\\ferb\Video\ToBeRemoved2" $Folder.Name
	}elseif($env:computername -eq "ender"){
		$driveletter = "K:\"
		$ToBeRemovedFolder = Join-path "Z:\ToBeRemoved2" $Folder.Name
	}elseif($env:computername -eq "candace"){
		$driveletter = "H:\"
		$ToBeRemovedFolder = Join-path "Z:\ToBeRemoved2" $Folder.Name
	}
	
	
	$ConversionToFolder = Join-path ($driveletter + "Handbrake\ConversionTo") $Folder.Name
	$ConversionFromFolder = Join-path ($driveletter + "Handbrake\ConversionFrom") $Folder.Name

	if(!(test-path $ToBeRemovedFolder)){$Null = mkdir $ToBeRemovedFolder}
	if(!(test-path $ConversionToFolder)){$Null = mkdir $ConversionToFolder}
	if(!(test-path $ConversionFromFolder)){$Null = mkdir $ConversionFromFolder}
	if($ItsaFile)
	{
		
		copy-item $File.Fullname $ConversionFromFolder
		move-item $File.Fullname $ToBeRemovedFolder
		$OldFileName = Join-path $ConversionFromFolder $File.Name
		$NewFileName = Join-path $ConversionToFolder $File.Name
		Convert-HandbrakeCommandx265  -From "$OldFileName" -To "$NewFileName" -Quality $Quality -To1080 $To1080
		if((get-item $NewFileName).length -lt ((get-item $OldFileName).length - ((get-item $OldFileName).length/20)))
		{
			write-host "NewFileName size: $((get-item $NewFileName).length) - OldFileName $((get-item $OldFileName).length)" -fore green
			write-host "ItsaFile move-item $NewFileName $($Folder.FullName)" -fore green
			move-item $NewFileName $Folder.FullName
			write-host "ItsaFile remove-item $OldFileName" -fore green
			remove-item $OldFileName
		}else{
			write-host "newfile size: $((get-item $NewFileName).length)) - old file size: $((get-item $OldFileName).length))" -fore red
			write-host "ItsaFile move-item $OldFileName $($Folder.FullName)" -fore green
			move-item $OldFileName $Folder.FullName
			write-host "new file is larger!" -fore red
		}
		
	}else{
		$SubFolders = get-childitem $FolderName -Directory
		if(!$SubFolders)
		{
			$SubFolders = $Folder
		}
		Foreach($SubFolder in $SubFolders)
		{
			$ToBeRemovedSubFolder = Join-path $ToBeRemovedFolder $SubFolder.Name
			$ConversionFromFolderSubFolder = Join-path $ConversionFromFolder $SubFolder.Name
			$ConversionToFolderSubFolder = Join-path $ConversionToFolder $SubFolder.Name
			if(!(test-path $ToBeRemovedSubFolder)){$Null = mkdir $ToBeRemovedSubFolder}
			if(!(test-path $ConversionFromFolderSubFolder)){$Null = mkdir $ConversionFromFolderSubFolder}
			if(!(test-path $ConversionToFolderSubFolder)){$Null = mkdir $ConversionToFolderSubFolder}
			$Files = get-childitem $SubFolder.FullName -File | where-object {!(($_.name.endswith(".srt")) -or ($_.name -match "265"))}
			$i = 0
			Foreach($File in $Files)
			{
				$OldFileName = Join-path $ConversionFromFolderSubFolder $File
				$NewFileName = Join-path $ConversionToFolderSubFolder $File
				if($onlyover1gb)
				{	
					if($File.length -le 1073741824)
					{
						write-host "$File is less than 1GB, skip."
						continue
					}
				}
				
				if(test-path $OldFileName)
				{
					write-host "$OldFileName already exists" -fore red
					return
				}
				write-host "copy-item $($File.Fullname) $ConversionFromFolderSubFolder" -fore green
				copy-item $File.Fullname $ConversionFromFolderSubFolder
				write-host "move-item $($File.Fullname) $ToBeRemovedSubFolder)" -fore green
				move-item $File.Fullname $ToBeRemovedSubFolder
				
				if(!(test-path $NewFileName))
				{
					write-host "$NewFileName doesn't exist"
					Convert-HandbrakeCommandx265  -From "$OldFileName" -To "$NewFileName" -Quality $Quality -To1080 $To1080
					if((get-item $NewFileName).length -lt ((get-item $OldFileName).length - ((get-item $OldFileName).length/20)))
					{
						write-host "NewFileName size: $((get-item $NewFileName).length) - OldFileName $((get-item $OldFileName).length)" -fore green
						write-host "move-item $NewFileName $($SubFolder.FullName)" -fore green
						move-item $NewFileName $SubFolder.FullName
						write-host "remove-item $OldFileName" -fore green
						remove-item $OldFileName
						$i = 0
					}else{
						write-host "newfile size: $((get-item $NewFileName).length)) - old file size: $((get-item $OldFileName).length))" -fore red
						$i++
						write-host "move-item $OldFileName $($SubFolder.FullName)" -fore green
						move-item $OldFileName $SubFolder.FullName
						if($i -gt 4)
						{
							Start-Pause -message "new file was larger 5x in a row! (might as well stop here)"
						}
					}	
				}else{
					write-host "$NewFileName already exists?" -fore red
					Start-Pause -message "already exists?"
				}
			}
		}
	}
}

Function Convert-HandbrakeCommand
{
param(
$From,
$To,
$Quality
)
	HandBrakeCLI --subtitle 0-99 --quality $quality --two-pass --encoder-preset medium --all-audio --encoder x264 --subtitle-burned=none --output "$To" --input "$From"
	# this one is faster for testing purposes
	#HandBrakeCLI --subtitle 0-99 --quality 19 --two-pass --encoder-preset superfast --all-audio --encoder x264 --subtitle-burned=none --output "$To" --input "$From"
}

Function Convert-HandbrakeCommandx265
{
<#

.SYNOPSIS
	uses HandBrakeCLI to convert a video file to x265.
.DESCRIPTION

.EXAMPLE
	Convert-HandbrakeCommandx265 -From x -To x -Quality 24
.EXAMPLE

.NOTES
	used by ConvertTo-x265. Not really intended to be used as stand alone.
.LINK

#>
param(
$From,
$To,
$Quality,
[switch]$To1080
)
	if($To1080){
		HandBrakeCLI --subtitle 0-99 --quality $quality --two-pass --encoder-preset slower --all-audio --encoder nvenc_h265 --subtitle-burned=none --output "$To" --input "$From" --width 1920 --height 1080
	}else{
		HandBrakeCLI --subtitle 0-99 --quality $quality --two-pass --encoder-preset slower --all-audio --encoder nvenc_h265 --subtitle-burned=none --output "$To" --input "$From"
	}
}

Function Merge-Movies
{
<#

.SYNOPSIS
	merges two or more movie files into one if they are in the same directory.
	
	Names it after the directory.
.DESCRIPTION

.EXAMPLE
	Merge-Movies "\\ferb\Video\Movies\UFC 11 - The Proving Ground (1996)"
.EXAMPLE

	# lines held a copy paste from the radarr table.
	# pretty easy and effective.

	foreach($line in $Lines)
	{
		if($line.startswith("/"))
		{
			$Directory = "\\ferb" + $line.replace("/","\")
			Merge-Movies "$Directory"
		}
	}

.NOTES

.LINK

#>
param($Directory)

	Set-Location $Directory

	$Files = get-childitem $Directory

	if ($files  -is [array])
	{
		$ConcatString = "`"concat:"
		$i = 0
		$TotalLength = 0
		foreach($File in $Files)
		{
			$ConcatString = $ConcatString + $File.Name
			$i = $i + 1
			if($i -lt $Files.Count)
			{$ConcatString = $ConcatString + "|"}else{$ConcatString = $ConcatString + "`""}
			$TotalLength = $TotalLength + $File.Length
		}

		$outputName = $directory.split("\")[-1] + ".avi"


		ffmpeg -i $ConcatString -c copy "$outputName"
		
		$NewFiles = get-childitem $Directory
		$TotalNewLength = 0
		foreach($File in $NewFiles)
		{
			$TotalNewLength = $TotalNewLength + $File.Length
		}
		
		if ($TotalNewLength -ge ($TotalLength * 2))
		{
			foreach($File in $Files)
			{
				remove-item $File
			}
		}else{
			write-host "$TotalNewLength is not twice $TotalLength"
		}
	}
}


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
	if(test-path $MovieFile)
	{
		$Executable = (join-path $PsScriptRoot MediaInfo.exe).tostring()
		$xmldata = new-object "System.Xml.XmlDocument"
		$xmldata.LoadXml((Invoke-Expression "$Executable --Output=XML `"$MovieFile`""))
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







