# 🛠️ PRO Log Inspector (Bash Script)

A modular and powerful log inspection tool written in pure Bash for Linux systems. It can categorize critical events, scrub sensitive data, and export structured JSON reports.

## ✨ Features
- 🔍 Categorized analysis (auth failures, crashes, kernel panics, etc.)
- 📊 JSON export for integration into pipelines
- 🧼 Scrubbing of usernames, hostnames, and paths
- 🧠 Timestamp clustering + top repeated logs
- 🛠️ Custom modes: full, minimal, syslog

## 🚀 Usage

<pre> ```bash ./pro_log_inspector.sh -f /var/log/syslog -m full -s -j ``` </pre>

## Options:
-f FILE → Log file to analyze

-m MODE → full, minimal, custom, syslog

-s → Scrub sensitive data

-j → Generate JSON summary

-v → Verbose mode

-h → Help

## 📁 Output
Reports saved to ~/log_reports with timestamped names.
