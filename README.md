# Log Archive Tool

A Bash CLI tool that compresses a log directory into a timestamped `tar.gz` archive, stores it in a separate directory, records every run in its own log file, and removes archives older than 7 days. It runs automatically every night with a systemd timer.

This project is my solution to the [Log Archive Tool](https://roadmap.sh/projects/log-archive-tool) challenge on **roadmap.sh**.

Project URL: https://roadmap.sh/projects/log-archive-tool

I built and tested it on my own Ubuntu VPS while learning Linux administration. Before starting I only knew `tar` in theory, so the project became practice in archiving, file permissions, exit codes, scheduling and a clean Git workflow between my laptop and the server.

## Project Requirements

The original challenge asks for a tool that:

- **Runs from the command line** and accepts the log directory as an argument:
  ```bash
  log-archive <log-directory>
  ```
- **Compresses the logs** into a `tar.gz` file and **stores it in a new directory**.
- **Records the date and time** of each archive in a file.
- Uses the naming format `logs_archive_20240816_100648.tar.gz`.
- Archives logs **on a set schedule**.

All of these are implemented.

### What I added beyond the requirements

- **Input validation**: the tool checks that it runs as root, that exactly one argument was given and that the directory exists, and it stops early with a clear message if not.
- **Exit-code handling for `tar`**: it treats tar's warning ("file changed as we read it") separately from a real error.
- **No broken archives left behind**: if `tar` fails, the incomplete archive is deleted.
- **Retention policy**: archives older than 7 days are deleted automatically, but only after a new archive has been created successfully.
- **Scheduling with a systemd timer** instead of cron, with the unit files kept in the repository.
- **Restore test**: I extracted a file from a real archive and compared it byte by byte with the original.

## Project Structure

```text
Log_archive_tool/
├── log-archive.sh              # the tool itself
├── systemd/
│   ├── log-archive.service     # what to run
│   └── log-archive.timer       # when to run it
├── .gitignore
└── README.md
```

## Requirements

- Linux with **GNU** `tar`, `find`, `stat` and `date` (tested on **Ubuntu 24.04 LTS**)
- Bash
- Root privileges (`sudo`)
- systemd, for scheduled runs

macOS is not supported: it ships BSD versions of these utilities with different options (for example, `stat -c` does not exist there).

## Installation

**1. Clone the repository:**

```bash
git clone https://github.com/4erepashkaIT/Log_archive_tool.git
cd Log_archive_tool
```

**2. Make sure the script is executable** (Git keeps the executable bit, so this is usually already done):

```bash
chmod +x log-archive.sh
```

**3. Install it as the `log-archive` command:**

```bash
sudo ln -s "$(pwd)/log-archive.sh" /usr/local/bin/log-archive
which log-archive
```

`/usr/local/bin` is in `PATH`, so the tool can be called by name from any directory.

I used a **symbolic link** instead of copying the file. The command always points to the file in the repository, so after `git pull` the new version is used immediately and nothing needs to be reinstalled.

## Usage

```bash
sudo log-archive <log-directory>
```

Example:

```bash
sudo log-archive /var/log
```

Output (the script's messages are in Russian):

```text
Папка с логами найдена: /var/log
Папка с архивами: /var/log-archive
Архив успешно создан: logs_archive_20261021_111822.tar.gz
Удалено архивов старше 7 дней: 1
```

They mean "log directory found", "archive directory", "archive created successfully" and "archives older than 7 days deleted: 1".

### Error handling

```text
$ log-archive /var/log
Ошибка: этот скрипт должен быть запущен с правами root (sudo).     # must be run as root

$ sudo log-archive
Использование: /usr/local/bin/log-archive <папка-с-логами>        # usage

$ sudo log-archive /nope
Такой папки не существует: /nope                                    # directory does not exist
```

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Archive created. This includes tar's warning (code 1), when some files changed while being read |
| `1` | Not running as root, wrong number of arguments, or the directory does not exist |
| `2` | `tar` failed. The incomplete archive was deleted |

The exit code matters because systemd uses it to decide whether a run succeeded or failed.

## Where Archives Go

All archives and the tool's own log are stored in `/var/log-archive`:

```text
/var/log-archive/
├── archive.log
├── logs_archive_20261021_092924.tar.gz
└── logs_archive_20261021_111822.tar.gz
```

The archive directory is deliberately **outside** `/var/log`. If archives were stored inside the directory being archived, each new archive would include all the previous ones and keep growing.

The archive directory and the retention period are set at the top of the script:

```bash
ARCHIVE_DIR="/var/log-archive"
RETENTION_DAYS=7
```

### The `archive.log` file

Every run appends one or two lines to `/var/log-archive/archive.log`:

```text
2026-10-21 11:18:22 | /var/log -> logs_archive_20261021_111822.tar.gz | Размер архива: 59328358 байт | OK
2026-10-21 11:18:22 | Удалено архивов старше 7 дней: 1 | OK
```

Each line records **when** the run happened, **what** was archived, the **archive name**, its **size** in bytes ("Размер архива") and the **result**. Possible results:

- `OK`: the archive was created.
- `WARNING`: the archive was created, but some files changed while `tar` was reading them.
- `Ошибка tar: код N | Неполный архив удалён`: tar failed with code N and the incomplete archive was removed.

The file is only ever appended to (`>>`), never overwritten, so the full history is kept.

## How It Works

### 1. Checks before doing anything

The script stops with a non-zero exit code if:

- it is not running as root (checked through `$EUID`);
- it did not receive exactly one argument;
- the argument is not an existing directory.

`set -euo pipefail` makes the script stop on unexpected errors and on undefined variables instead of continuing silently.

### 2. Archive name

The timestamp is taken **once**, at the start of the run, and used for both the archive name and the log entry:

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)        # 20261021_111822
LOG_TIME=$(date '+%Y-%m-%d %H:%M:%S')   # 2026-10-21 11:18:22
```

The `year-month-day_hour-minute-second` format means that sorting the names alphabetically (as `ls` does) also sorts them chronologically.

### 3. Creating the archive

```bash
tar -czf "$ARCHIVE_DIR/$ARCHIVE_NAME" -C "$(dirname "$LOG_DIR")" "$(basename "$LOG_DIR")"
```

- `-c` creates an archive, `-z` compresses it with gzip, `-f` sets the file name.
- `-C` changes into the parent directory first. As a result, paths inside the archive start with `log/...` rather than with the full absolute path:

```text
$ sudo tar -tzf /var/log-archive/logs_archive_20261021_092924.tar.gz | head -4
log/
log/bootstrap.log
log/cloud-init-output.log
log/apt/
```

On my VPS, about 300 MB of logs compress into an archive of about 57 MB.

### 4. Handling tar's exit codes

GNU tar has three possible results, and the script handles each of them:

| tar code | What happened | What the script does |
|----------|---------------|----------------------|
| `0` | Success | Logs `OK`, runs cleanup, exits `0` |
| `1` | Some files changed while being read | Logs `WARNING`, keeps the archive, runs cleanup, exits `0` |
| `2` | Fatal error (permissions, no disk space, etc.) | Deletes the incomplete archive, logs the error, exits with tar's code |

Code `1` is expected to happen on my server sooner or later. It has no rsyslog, so almost all logs live in the systemd journal (`/var/log/journal`), which is written to constantly. The archive is still valid, so treating this as a failure would only cause false alarms.

Code `2` needs the cleanup step because `tar` does not stop at the first unreadable file: it archives everything it can and fails at the end. Without cleanup, an archive that looks normal but is missing logs would stay on disk.

### 5. Retention: deleting old archives

```bash
find "$ARCHIVE_DIR" -maxdepth 1 -type f \
    -name "logs_archive_*.tar.gz" \
    -mtime +"$RETENTION_DAYS" \
    -print -delete | wc -l
```

- `-maxdepth 1`: only look in the archive directory itself, not in subdirectories.
- `-type f`: regular files only.
- `-name "logs_archive_*.tar.gz"`: only this tool's archives. `archive.log` and any other file are never touched.
- `-mtime +7`: last modified more than 7 *full* days ago, which in practice means 8 days or older. About 8 recent daily archives are kept.
- `-print -delete | wc -l`: delete the matching files and count them for the log.

All conditions must match at the same time (logical AND), so each one acts as an extra safety filter. `-delete` comes last on purpose: `find` evaluates its arguments left to right.

**Cleanup runs only after a successful archive (OK or WARNING).** If archiving broke for a week and cleanup still ran every night, it would gradually delete every good archive and leave nothing behind.

**Why 7 days.** Every archive is a *full* snapshot of the log directory, including the whole systemd journal, so consecutive archives mostly contain the same data. Keeping a month of them would mean 30 copies of nearly identical logs. A week is enough to notice a problem and go back to an earlier state, and it takes about 0.5 GB on my 20 GB disk. Without cleanup, a 57 MB daily archive would use up the free space in a few months, and sooner as the journal grows.

## Scheduling with a systemd Timer

My VPS uses a minimal Ubuntu image **without cron**. Instead of installing it, I used a **systemd timer**, the scheduler the system already uses for its own regular jobs (`apt-daily`, `dpkg-db-backup`, `fstrim`).

A timer needs two unit files, both stored in the `systemd/` directory.

**`log-archive.service`** describes *what* to run:

```ini
[Unit]
Description=Archive logs from /var/log

[Service]
Type=oneshot
ExecStart=/usr/local/bin/log-archive /var/log
```

`Type=oneshot` means the job runs, finishes and stops, unlike a long-running service such as `ssh`. System services run as root by default, so no `sudo` is needed here.

**`log-archive.timer`** describes *when* to run it:

```ini
[Unit]
Description=Run log-archive daily

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

- `OnCalendar=*-*-* 03:00:00`: every day at 03:00 server time (UTC on my VPS).
- `Persistent=true`: if the server was off at 03:00, the missed run starts right after boot.

### Install the timer

```bash
sudo cp systemd/log-archive.service systemd/log-archive.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now log-archive.timer
```

### Check it

```bash
systemd-analyze calendar "*-*-* 03:00:00"         # validate the schedule
systemctl list-timers log-archive.timer           # next and last run
sudo systemctl start log-archive.service          # run it right now
systemctl status log-archive.service --no-pager   # result of the last run
journalctl -u log-archive.service --no-pager      # everything the script printed
```

A successful run looks like this:

```text
Process: 122730 ExecStart=/usr/local/bin/log-archive /var/log (code=exited, status=0/SUCCESS)
```

The script's output goes straight to the systemd journal, so no extra redirection to a log file is needed.

### After changes

- **Script changed** (for example after `git pull`): nothing to do. The service calls `/usr/local/bin/log-archive`, which is a symlink to the file in the repository.
- **Unit files changed**: copy them again and reload systemd:
  ```bash
  sudo cp systemd/log-archive.service systemd/log-archive.timer /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl restart log-archive.timer
  ```

### Alternative: cron

On a system that has cron, the same schedule is a single line in `sudo crontab -e`:

```text
0 3 * * * /usr/local/bin/log-archive /var/log >> /var/log-archive/cron.log 2>&1
```

Cron needs the full path to the command and an explicit redirect, otherwise the output is lost.

## Testing

These are the checks I ran on the VPS.

**Syntax check before every commit:**

```bash
bash -n log-archive.sh && echo "Syntax OK"
shellcheck log-archive.sh
```

**Invalid input:**

```bash
log-archive; echo "exit code: $?"          # not root      -> 1
sudo log-archive; echo "exit code: $?"     # no argument   -> 1
sudo log-archive /nope; echo "exit code: $?"   # no such directory -> 1
```

**Archive contents and restore.** An archive that has never been restored is not a real backup, so I extracted one file and compared it with the original:

```bash
mkdir -p /tmp/restore
sudo tar -xzf /var/log-archive/logs_archive_20261021_092924.tar.gz -C /tmp/restore log/alternatives.log
sudo cmp /tmp/restore/log/alternatives.log /var/log/alternatives.log && echo "Files match"
```

**Retention, without waiting a week.** `touch -d` creates empty files with an old modification time:

```bash
sudo touch -d "10 days ago" /var/log-archive/logs_archive_20261011_030000.tar.gz
sudo touch -d "3 days ago"  /var/log-archive/logs_archive_20261018_030000.tar.gz

# preview what would be deleted (nothing is removed yet)
sudo find /var/log-archive -maxdepth 1 -type f -name "logs_archive_*.tar.gz" -mtime +7

sudo systemctl start log-archive.service
ls -l /var/log-archive
```

Result: the 10-day-old file was deleted, the 3-day-old file and the real archives were kept, and `archive.log` recorded `Удалено архивов старше 7 дней: 1` ("archives older than 7 days deleted: 1").

## Restoring Logs

Extract a whole archive:

```bash
mkdir -p /tmp/restore
sudo tar -xzf /var/log-archive/logs_archive_YYYYMMDD_HHMMSS.tar.gz -C /tmp/restore
```

Extract a single file:

```bash
sudo tar -xzf /var/log-archive/logs_archive_YYYYMMDD_HHMMSS.tar.gz -C /tmp/restore log/dpkg.log
```

The systemd journal files are binary. Read them from the restored directory with `journalctl -D`:

```bash
sudo journalctl -D /tmp/restore/log/journal/<machine-id> -u ssh --no-pager
```

## Limitations

- **Every run is a full copy**, not an incremental one: each archive contains the entire log directory.
- **The original logs are not removed or truncated.** That is the job of `logrotate` and of journald's own size limits. Deleting a file that a running service is still writing to can cause problems, so the tool does not touch the source directory.
- **Archives are readable by all local users.** They are created with the default permissions (`644`, directory `755`), while some of the original logs (`btmp`, parts of the journal) are readable only by root or specific groups. On my single-user VPS this is acceptable, but on a shared server the archive directory should be restricted.
- **There is no protection against archiving a parent directory.** Running `sudo log-archive /var` would include `/var/log-archive` itself, so old archives would end up inside the new one. The timer always uses `/var/log`, so scheduled runs are not affected.
- The archive directory and retention period are set in the script, not through command-line options.
- Linux only. It relies on GNU tools and was tested on Ubuntu 24.04 LTS.

In production I would solve this problem differently: `logrotate` for text logs, journald settings (`SystemMaxUse`, `journalctl --vacuum-time`) for the journal, and shipping logs to a central system such as Loki or ELK. This tool was built for learning, to understand what those systems do under the hood.

## Possible Improvements

- Restrict permissions on archives (`umask 077` in the script, `chmod 700` on the archive directory).
- Refuse to run if the archive directory is inside the directory being archived (using `realpath`).
- Command-line options with `getopts`, for example `-d <destination>` and `-r <days>`.
- Copy each new archive to a remote server with `rsync` over SSH, or to S3-compatible storage.
- Send a Telegram notification when a run fails.

## What I Learned

This project gave me hands-on practice with:

- Writing a Bash CLI tool that validates its input, prints usage and returns meaningful exit codes
- Archiving and compression with `tar` and gzip, including relative paths inside an archive and restore checks
- Handling exit codes in scripts and understanding why systemd, cron and monitoring depend on them
- Linux permissions in practice: why root is needed and how directory permissions decide who can delete a file
- Using `find` with combined conditions to delete files safely, and testing it with fake files created by `touch -d`
- systemd services and timers: `oneshot` services, `OnCalendar`, `Persistent`, `daemon-reload`, `journalctl`
- How `PATH`, `/usr/local/bin` and symbolic links turn a script into a command
- How Linux logging works on a modern server: text logs, the systemd journal and `logrotate`
- Debugging real issues, such as a shebang that was not on the first line (so `sudo` ran the script with `dash`) and a broken symlink
- A Git workflow where I edit and push from my laptop and the server only runs `git pull`

## Environment

- **OS:** Ubuntu 24.04 LTS (VPS, no rsyslog, no cron)
- **Shell:** Bash
- **Tools:** GNU `tar`, `gzip`, `find`, `stat`, `date`, systemd timers, `journalctl`

No additional packages required.

---

Built as part of the roadmap.sh DevOps projects: https://roadmap.sh/projects/log-archive-tool
