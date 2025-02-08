# Wilbind
LMAOBOX doesn't have a proper bind manager, only a few options like aimbot are bindable.
Here's my solution that allows to bind **ANYTHING**!
![screen1](https://i.imgur.com/5kQAqP6.png)
## Features
- Config saving system (Team Fortress 2/wilconfigs).
- Enable / Disable binds globally or in menu.
- Different bind modes:
    - Press - Changes value once when bind is pressed.
    - Hold - Changes value and returns old one when button is released.
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
## Known issues
- Menu don't support scrolling. More than 8 binds will out of bounds yours screen.
    - You can manually edit wilconfigs/wilbind.cfg in your TF2 directory and add or edit binds by coping other ones. Try to not brake anything...
- After loading settings bind's "Mode" is always highlighted as "Press", but stored value is correct. Idk how to fix it, it's Menu.lua library issue. It's only cosmetic problem.
## PS
Code is deeply commented so you can easily edit it, and if you find any issues report it to me [here](https://github.com/GNWilber/lmaobox-luas-public/issues).
### Special thanks to
- [LNX](https://github.com/lnx00/) - Menu library
- AI - I used AI when making this bind menu.