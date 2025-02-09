# Wilbind
LMAOBOX doesn't have a proper bind manager, only a few options like aimbot are bindable.
Here's my solution that allows you to bind **ANYTHING**!

![screen1](https://i.imgur.com/5kQAqP6.png)
## Features
- Config saving system (Team Fortress 2/wilconfig).
- Different bind modes:
    - Press - Changes value once when bind is pressed.
    - Hold - Changes value and returns old one when button is relased.
    - Toggle - Changes value and returns old one on second button press.
- To toggle between options type "increment [start] [end] [step]"
    - Aim method switching example:
        - Option Name: "aim method"
        - Value: "increment 1 5 1"
## Requirements
- [Menu.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/Menu.lua)
    - It's my fork of [LNX's](https://github.com/lnx00/) [Menu.lua](https://github.com/lnx00/Lmaobox-Lua/blob/main/src/MenuLib/Menu.lua).
        - I added support for typing '(' or ')'.
        - Menu shows up with LMAOBOX's menu on INSERT - original shows up on main/pause menu.
    - Feel free to use original one, but my fork will give the best experience.
## How to use
- Put [wilbind.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilbind/wilbind.lua) & [Menu.lua](https://github.com/GNWilber/lmaobox-luas-public/blob/main/Menu.lua) to your %LOCALAPPDATA%.
- Refresh and load wilbind in LUA tab in LMAOBOX.
- Add bind and select desired key & mode and type "Option Name" from LMAOBOX's menu and "Value" for it.
    - Example: H > Toggle > aim bot > 1 - You can toggle your aimbot with 'H' key.
## Known issues
- Menu don't support scrolling. More than 8 binds will out of bounds yours screen.
    - You can manually edit wilconfigs/wilbind.cfg in your TF2 directory and add or edit binds by coping other ones. Try to not brake anything...
- After loading settings bind's "Mode" is always highlighted as "Press", but stored value is correct. Idk how to fix it, it's Menu.lua library issue. It's only cosmetic problem.
## PS
- Please also check [WilSlot](https://github.com/GNWilber/lmaobox-luas-public/blob/main/wilslot/README.md), my other Class / Weapon binds manager.
- When you are typing anything always open a console in the game, because some letters like 'M' can open a menu.
- Code is deeply commented so you can easily edit it, and if you find any issues report it to me [here](https://github.com/GNWilber/lmaobox-luas-public/issues).
### Special thanks to
- [LNX](https://github.com/lnx00/) - Menu library
- AI - Helped me with comments and code