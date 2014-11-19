setlocal
set game_name=slime.love
rename %game_name% archive.zip
7z d archive.zip * -r
7z a -tzip archive.zip *
7z d archive.zip *.zip
rename archive.zip %game_name%
endlocal