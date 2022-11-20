# GitHub Repo Permission Setter

This repo and automation in it are designed to set all GitHub repo permissions required for a new repo. 

To use it, update the "repo_info.csv" file with any new repos with a PR. When the PR is merged, the github action will read this file and update permissions on each repo in sequence, top to bottom. 

# Permission Collisions

This script sets specific settings directly. If there are direct colissions, this app will update them to what it shows. If a repo has a setting that is getting over-written and shouldn't be, remove it from the repo_info.csv file, and it will no longer be updated in future when this automation runs. 

# Triggers

The automation will run when the PR is merged or can be run manually on the github web console. 

