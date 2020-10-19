if($pdir = $PWD.Path -notmatch "test$") {
	Push-Location ".\test"
}

function done() {
	if($pdir) {
		Pop-Location
	}
}

$dirs = Get-ChildItem -Directory
$maxDirLen = ($dirs | ForEach-Object {$_.BaseName.Length} | Measure-Object -Maximum).Maximum

foreach($_dir in $dirs) {
	$dir = ([System.IO.DirectoryInfo]$_dir)
	$dirName = $dir.BaseName

	($in, $out) = ("reon", "json")
	if($dir.GetFiles("input.reon").Count -eq 0) {
		($out, $in) = ($in, $out)
	}

	$fmt = "{0,-${maxDirLen}} ($in -> $out)" -f $dirName
	
	$output = (node "..\bin\reon" "to-$out" ".\$dirName\input.$in" -o "output")
	if($output -cmatch "^Wrote to .+$") {
		Write-Output "PASSED: $fmt"
	} else {
		Write-Output "FAILED: $fmt"
		done
		exit
	}
}

done