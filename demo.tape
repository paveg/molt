Output demo.gif

Set Shell "zsh"
Set Width 900
Set Height 500
Set FontSize 14
Set FontFamily "JetBrains Mono"
Set Theme "Catppuccin Mocha"
Set Padding 20

# Assumes `molt --serve 127.0.0.1:9999` is running in another terminal
Type "molt --no-tui -c 10 -d 5s http://127.0.0.1:9999/"
Sleep 500ms
Enter
Sleep 7s
