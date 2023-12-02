# `projector.sh`

> Projects manager at the speed of light.

If you work with many projects, you can understand the struggle to keep
everything organized and tidy. If you like to have one tmux session per project,
you know it can become a mess.

`projector.sh` replaces all the commands you would usually run to switch/manage
projects, such as:
- `git clone $project`
- `tmux new-session -t $project`
- `tmux switch-session -t $project`
- `mv path/to/$project`
- `rm path/to/$project`

It assumes a strong relationship between:
```
GitHub repo  <=> local folder <=> tmux session
```

E.g.:

```bash
projector.sh
# select nobe4/projector.sh and press <CR>
# => clones in ~/dev/nobe4/projector.sh
# => creates a tmux session called nobe4/projector_sh
# => switch to the session called nobe4/projector_sh
```

## Install

- Add [`./projector.sh`](./projector.sh) somewhere in your path.
- `chmod +x projector.sh`

That's it :tada:

## Requirements

- [`tmux`](https://github.com/tmux/tmux)
- [`fzf`](https://github.com/junegunn/fzf)
- [`gh`](https://github.com/cli/cli)

## Usage

Calling the script with no arguments is what you want to start with.

```bash
projector.sh
```

See full help in [`./projector.sh`](./projector.sh) or with `projector.sh -h`.
