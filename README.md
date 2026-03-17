# android-home
A dotfiles collection for my android terminal, managed by [Dorothy](https://github.com/bevry/dorothy).

## Setup

Run the following in [Termux](https://termux.dev) (or any Android terminal that provides `bash` and `curl`) to initialize Dorothy and clone this dotfiles repository:

```bash
bash <(curl -fsSL 'https://raw.githubusercontent.com/danielbodnar/android-home/HEAD/init.sh')
```

The script will:
1. Install prerequisites (`bash`, `curl`, `git`) via Termux's `pkg` package manager (or `apt-get` as a fallback).
2. Download and run the [Dorothy installer](https://github.com/bevry/dorothy#install), pre-configured to use this repository as the Dorothy User Configuration.

After installation, open a new terminal session and run `dorothy commands` to verify the setup.
