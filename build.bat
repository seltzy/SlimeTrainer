@echo off
pushd %~dp0

setlocal
set project_dir=%~dp0
set game_dir=%project_dir%game
set game_name=slime.love

echo Project Directory: %project_dir%
echo Game Directory: %game_dir%
echo Game Name: %game_name%

echo Renaming %game_name% to archive.zip
rename %game_name% archive.zip

pushd %game_dir%

echo Clearing archive file
7z d %project_dir%archive.zip * -r

echo Adding files to archive
7z a -tzip %project_dir%archive.zip *

echo Clearing garbage files
7z d %project_dir%archive.zip *.zip
7z d %project_dir%archive.zip *.bat
7z d %project_dir%archive.zip *.sh
7z d %project_dir%archive.zip *.md
7z d %project_dir%archive.zip .*

pushd %project_dir%
rename archive.zip %game_name%
endlocal

echo Done!