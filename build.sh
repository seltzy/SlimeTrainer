#!/bin/bash
cd $(dirname $0)

project_dir="$(dirname $0)"
game_dir="$project_dir/game"
game_name="slime.love"
temp_name="archive.zip"

echo "Project Directory: $project_dir"
echo "Game Directory: $game_dir"
echo "Game Name: $game_name"

echo "Renaming $game_name to archive.zip"
mv $game_name $temp_name

cd $game_dir

echo "Clearing archive file"
7z d $project_dir/$temp_name * -r

echo "Adding files to archive"
7z a -tzip $project_dir/$temp_name *

echo "Clearing garbage files"
7z d $project_dir/$temp_name *.zip
7z d $project_dir/$temp_name *.bat
7z d $project_dir/$temp_name *.sh
7z d $project_dir/$temp_name *.md
7z d $project_dir/$temp_name .*

cd $project_dir

mv $temp_name $game_name


