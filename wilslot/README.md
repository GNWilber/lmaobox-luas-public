# Wilslot
Amalgam have this epic feature to bind something to selected weapon slot or class. For example you have different aimbot for soldier rocket launcher and shotgun. I thought that it would be cool to have this for LMAOBOX and here we are.
## Features
- Config saving system (Team Fortress 2/wilconfig).
- Enable / Disable all binds. 
- Bind something to class or weapon slot, or both. 
## Requirements
- [Menu.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/Menu.lua)
    - It's my fork of [LNX's](https://github.com/lnx00/) [Menu.lua](https://github.com/lnx00/Lmaobox-Lua/blob/main/src/MenuLib/Menu.lua).
        - I added support for typing '(' or ')'.
        - Menu shows up with LMAOBOX's menu on INSERT - original shows up on main/pause menu.
    - Feel free to use original one, but my forks will give the best experience.
## Known issues
- Menu don't support scrollin
- After loading settings class or weapon from drop list is always highlighted as "Any", but stored value is correct. Idk how to fix it, it's Menu.lua library issue.
### Special thanks to
- [LNX](https://github.com/lnx00/) - Menu library
- AI - I used AI when making this bind menu.