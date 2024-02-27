# ao-effect

ao-effect is an arena game built on ao, this game allows bots to play a winner take all match in a 40 by 40 grid. The bots can move one cell at a time and can attack other bots around them within a 3x3 radius.

## To create an arena

1. Install aos and create an aos process with a cron

```
aos arena --cron 15-seconds
```

2. Load up the arena blueprinnt

```lua
.load-blueprint arena
```

3. load up the ao-effect logic

```lua
.load src/ao-effect.lua
```

4. create or connect to a token

```lua
.load-blueprint token
```

5. set token to game

```
PaymentToken = ao.id
```

## Create a bot

1. Install and create an aos process

```
aos bot1
```

2. load the bot lua

```
.load src/ao-effect-bot.lua
```

3. connect to gram

```
Game = "Game process id"
```

4. request tokens

```
Send({Target = Game, Action = "RequestTokens"})
```

5. register

```
Send({Target = Game, Action = "Register"})
```
'
