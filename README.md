# Bash Student Attendance Tracker

A single shell script, `setup_project.sh`, that **bootstraps** a complete Student Attendance Tracker workspace in seconds.

## How to run

Clone the repository

```bash
git clone https://github.com/deze-alu/deploy_agent_deze-alu.git
cd deploy_agent_deze-alu
```

Make the file executable and then run

```bash
chmod +x setup_project.sh     # once, to make it executable
./setup_project.sh
```

You'll be prompted for:

- **Workspace name** — e.g. typing `2026` creates `attendance_tracker_2026/`.
- **Update thresholds?** — answer `y` to set custom Warning/Failure percentages,
  or press Enter / `n` to keep the defaults (75% / 50%).

When it finishes, run the generated app:

```bash
cd attendance_tracker_<input>
python3 attendance_checker.py
```

## Requirements

- `bash`, `sed`, `tar` (standard on Linux/macOS)
- `python3` to actually run the generated attendance checker

## Video Recording

- [YouTube Explaination](https://youtu.be/ozuL5F8Vlz8)
- [Google Drive Link](https://drive.google.com/file/d/1uZDBO7TAP6gGmpga4SQPsSBzKcXc7Qem/view?usp=sharing)
