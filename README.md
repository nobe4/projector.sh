# `projector.sh`

> Projects manager at the speed of light.

https://github.com/nobe4/projector.sh/assets/2452791/c5606191-0539-41ee-aaad-d03e964ab943

Go to `nobe4/projector.sh`, go to `nobe4/gh-edit`, go back, go to `cli/cli`, and show the folder structure.

---

If you work with many projects, you can understand the struggle to keep
everything organized and tidy. If you like to have one session per project, you
know it can become a mess.

`projector.sh` replaces all the commands you would usually run to switch/manage
projects, such as:
- `git clone $project`
- `switch to project` (cd, tmux, etc.)
- `mv path/to/$project`
- `rm path/to/$project`

It assumes a strong relationship between:
```
GitHub repo  <=> local folder <=> session
```

E.g. with [`tmux.sh`](./switchers/tmux.sh) configured:

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

- [`fzf`](https://github.com/junegunn/fzf)
- [`gh`](https://github.com/cli/cli)

## Usage

Calling the script with no arguments is what you want to start with.

```bash
projector.sh
```

See full help in [`./projector.sh`](./projector.sh) or with `projector.sh -h`.

### Switchers

To keep `projector.sh` as small as possible, the switching logic is decoupled
and left to the reader for implementation. The default is to create a new shell
in the project's directory.

Use the `PR_SWITCHER` environment variable to reference which switcher you want
to use.

See [./switchers/](./switchers/) for examples.
New switchers PRs are welcomed.
