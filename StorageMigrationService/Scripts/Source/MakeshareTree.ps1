function make-file 
{
    param (
        [int] $quan,
        [string] $Qual,
        [string] $path
    )

    if ($qual -notmatch "kb|mb")
    {
        $qual = 'kb'
    }

    $1kb = 'x' * 1024
    $1mb = $1kb * 1024

    switch ($qual)
    {
        'kb'
        {
            $1kb * $quan | out-file $path
        }
        'mb'
        {
            $1mb * $quan | out-file $path
        }
        Default {}
    }
}

Mkdir c:\Files

$root = @('Accounting','Marketing','Ops','Sales','IT','Executive','Boston','Chicago')

$subfolders = @('Gene','bob', 'weekend', 'job 1', 'job 2', 'job 3', 'VP Info', 'folder 01', 'New Folder', 'very impportant', 'notes', 'deleteme', 'movies', 'pictures', 'assets', 'music','I don''t know', 'something else')


# $root = @('r1', 'r2', 'r3', 'r4')
# $subfolders = @('s1', 's2', 's3', 's4', 's5', 's6')

$Folderpaths = foreach ($rootfolder in $root)
{
    $rootfolderCount = get-random -Maximum 10 -Minimum 1
    $subfolderCount = get-random -Maximum 20 -Minimum 1

    "c:\Files\$rootfolder"

    foreach ($n in 1..$rootfoldercount)
    {
        $Folders = @("c:\Files\$rootfolder")
        1..$subfolderCount | % { $Folders += $($subfolders | get-random); $folders -join '\' }
    }

}

$Folderpaths = $folderpaths | sort -Unique

foreach ($folderpath in $folderpaths)
{
    $null = mkdir $folderpath

    $NumberOfFiles = get-random -min 0 -maximum 12

    1..$numberOffiles | % {make-file -quan $(get-random -min 10 -max 30) -Qual $('kb','mb' | get-random) -path "$folderpath\file$(get-random -min 1000 -max 99999)`.txt"}
}
