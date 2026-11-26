@echo off
if exist user_ams.ini goto skip
copy user.ini user_ams.ini
attrib user_ams.ini +r
:skip
start /min unreal "%1" userini=user_ams.ini
