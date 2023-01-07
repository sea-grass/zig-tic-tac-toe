The program can be run using `zig build run`.

Tests can be run using `zig test ./src/main.zig`.

Code coverage can be measured using `kcov`.

When you start the program, a game will look like this:

```
☓ Tic Tac Toe ◯


  0   1   2  

  3   4   5  

  6   7   8  

☓, it's your turn.

Remaining spots: 0 1 2 3 4 5 6 7 8 
☓ 0 

☓ Tic Tac Toe ◯


  ☓   1   2  

  3   4   5  

  6   7   8  

Moves: ☓0 
◯, it's your turn.

Remaining spots: 1 2 3 4 5 6 7 8 
◯  3

☓ Tic Tac Toe ◯


  ☓   1   2  

  ◯   4   5  

  6   7   8  

Moves: ☓0 ◯3 
☓, it's your turn.

Remaining spots: 1 2 4 5 6 7 8 
☓ 4

☓ Tic Tac Toe ◯


  ☓   1   2  

  ◯   ☓   5  

  6   7   8  

Moves: ☓0 ◯3 ☓4 
◯, it's your turn.

Remaining spots: 1 2 5 6 7 8 
◯ 7

☓ Tic Tac Toe ◯


  ☓   1   2  

  ◯   ☓   5  

  6   ◯   8  

Moves: ☓0 ◯3 ☓4 ◯7 
☓, it's your turn.

Remaining spots: 1 2 5 6 8 
☓ 8

☓ Tic Tac Toe ◯


  ☓   1   2  

  ◯   ☓   5  

  6   ◯   ☓  

Moves: ☓0 ◯3 ☓4 ◯7 ☓8 
The game's over. ☓ wins!
```
