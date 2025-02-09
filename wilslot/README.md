# Wilslot
Amalgam have this epic feature to bind something to selected weapon slot or class. For example you have different aimbot for soldier rocket launcher and shotgun. I thought that it would be cool to have this for LMAOBOX and here we are.

![screen1](https://i.imgur.com/sPvMCdz.png)
## Features
- Config saving system (Team Fortress 2/wilconfig).
- Enable / Disable all binds. 
- Bind something to class, weapon slot or both. 
## Requirements
- [Menu.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/Menu.lua)
    - It's my fork of [LNX's](https://github.com/lnx00/) [Menu.lua](https://github.com/lnx00/Lmaobox-Lua/blob/main/src/MenuLib/Menu.lua).
        - I added support for typing '(' or ')'.
        - Menu shows up with LMAOBOX's menu on INSERT - original shows up on main/pause menu.
    - Feel free to use original one, but my forks will give the best experience.
## How to use
- Put [wilslot.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilslot/wilslot.lua) & [Menu.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/Menu.lua) to your %LOCALAPPDATA%.
- Refresh and load wilslot in LUA tab in LMAOBOX.
- Add bind and select desired conditions to activate bind and type "Option Name" from LMAOBOX's menu and "Value" for it.
    - Example: Scout > 2 > aim method > silent - When you play scout and switch to pistol, your aim method will be switched to silent and returns back when conditions are not met.
## Known issues
- Menu don't support scrolling. More than 8 binds will out of bounds yours screen.
    - You can manually edit wilconfigs/wilslot.cfg in your TF2 directory and add or edit binds by coping other ones. Try to not brake anything...
- After loading settings "Class" or "Weapon Slot" from drop list is always highlighted as "Any", but stored value is correct. Idk how to fix it, it's Menu.lua library issue.
- Name of binds next to checkboxes only update when you are connected to server.
## PS
- Please also check [WilBind](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilslot/README.md), my other keybinds manager.
- When you are typing anything always open a console in the game, because some letters like 'M' can open a menu.
- Code is deeply commented so you can easily edit it, and if you find any issues report it to me [here](https://github.com/GNWilber/lmaobox-luas-public/issues).
### Special thanks to
- [LNX](https://github.com/lnx00/) - Menu library
- AI - Helped me with comments and code