#!/usr/bin/env bash
DATE=`date '+%Y-%m-%d'`
git status | grep "modified:"| awk -F ":" '{print $2}' | xargs git add
git commit -m "$(DATE)"
git push
