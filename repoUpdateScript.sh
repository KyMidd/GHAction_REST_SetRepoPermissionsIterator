#/bin/bash

# If CSV file doesn't have trailing return, last value will be skipped. Add it to be safe.
echo "" >> repo_info.csv

# Loop over every line in CSV. On valid lines, set all repo permissions
while IFS="," read -r GH_ORG GH_REPO REQUIRED_APPROVERS_COUNT COLLECTION_LEAD_TEAM_GITHUB_SLUG
do
    # Ignore the headers line of the CSV
    if [[ $GH_ORG == "GH_ORG" ]]; then
        continue
    fi

    # Ignore comment lines in the CSV
    if [[ $GH_ORG =~ ^\# ]]; then
        continue
    fi

    # Ignore any blank lines in CSV
    if [[ -z $GH_ORG ]]; then
        continue
    fi

    # If approvers count isn't set, default to 1
    if [ -z "$REQUIRED_APPROVERS_COUNT" ]; then
        REQUIRED_APPROVERS_COUNT=1
    fi

    # Print out info
    echo "⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️ ⚙️"
    echo "Updating settings for $GH_ORG/$GH_REPO"
    echo "Setting required approvers count to: $REQUIRED_APPROVERS_COUNT"
    
    # If COLLECTION_LEAD_TEAM_GITHUB_SLUG blank, skip it
    if [ -z "$COLLECTION_LEAD_TEAM_GITHUB_SLUG" ]; then
        # No collection lead team specified, will skip this step
        echo "COLLECTION_LEAD_TEAM_GITHUB_SLUG is blank, not setting that permission"
    else
        # Collection lead team specified, check if exists
        unset CURL
        CURL=$(curl \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        https://api.github.com/orgs/$GH_ORG/teams/$COLLECTION_LEAD_TEAM_GITHUB_SLUG 2>&1)
        if [[ $(echo "$CURL" | grep -E "Problems|Not Found") ]]; then
            # Team doesn't exist or slug is wrong
            echo "☠️ The collection lead slug isn't correct, that team doesn't exist. Continuing, but won't set this permission. Error message:"
            echo "$CURL"
            # Unset this value so we don't attempt to set this permission below, as it will fail
            unset COLLECTION_LEAD_TEAM_GITHUB_SLUG
        else
            # Leads team specified and does exist
            echo "Setting the collection lead team permissions for team: $COLLECTION_LEAD_TEAM_GITHUB_SLUG"
        fi
    fi

    # Enable github actions on repo
    unset CURL
    CURL=$(curl -s \
    -X PUT \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/repos/$GH_ORG/$GH_REPO/actions/permissions \
    -d '{"enabled":true,"allowed_actions":"selected"}')
    if [[ $(echo "$CURL" | wc -l) -le 1 ]]; then
        echo "💥 Successfully set Actions enabled"
    else
        echo "☠️ Something bad happened setting actions enable, please investigate response:"
        echo "$CURL"
    fi

    # Set repo policies
    unset CURL
    CURL=$(curl -s \
    -X PATCH \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/repos/$GH_ORG/$GH_REPO \
    -d '{"delete_branch_on_merge":true,"private":true,"allow_squash_merge":true}' 2>&1)
    if [[ $(echo "$CURL" | wc -l) -le 1 ]]; then
        echo "☠️ Something bad happened setting repo policies, please investigate response:"
        echo "$CURL"
    else
        echo "💥 Successfully set repo to delete branch on merge"
        echo "💥 Successfully set repo to be private"
        echo "💥 Successfully set repo to enable squash merge"
    fi

    # Grant automationusers team write access
    unset CURL
    CURL=$(curl -s \
    -X PUT \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/orgs/$GH_ORG/teams/automationusers/repos/$GH_ORG/$GH_REPO \
    -d '{"permission":"admin"}' 2>&1)
    if [[ $(echo "$CURL" | grep -E "Problems|Not Found") ]]; then
        echo "☠️ Something bad happened granting automationusers team access to the repo, please investigate response:"
        echo "$CURL"
    else
        echo "💥 Successfully granted automationusers team write access to repo $GH_REPO"
    fi

    # Grant collection leads team admin access
    # If COLLECTION_LEAD_TEAM_GITHUB_SLUG isn't set, skip this section
    if [ -z "$COLLECTION_LEAD_TEAM_GITHUB_SLUG" ]; then
        :
    else
        unset CURL
        CURL=$(curl -s \
        -X PUT \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        https://api.github.com/orgs/$GH_ORG/teams/$COLLECTION_LEAD_TEAM_GITHUB_SLUG/repos/$GH_ORG/$GH_REPO \
        -d '{"permission":"admin"}' 2>&1)
        if [[ $(echo "$CURL" | grep -E "Problems|Not Found") ]]; then
            echo "☠️ Something bad happened granting $COLLECTION_LEAD_TEAM_GITHUB_SLUG admin access to the repo, please investigate response:"
            echo "$CURL"
        else
            echo "💥 Successfully granted $COLLECTION_LEAD_TEAM_GITHUB_SLUG team admin access to repo $GH_REPO"
        fi
    fi

    # Get branches
    curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/repos/$GH_ORG/$GH_REPO/branches 2>&1 > repo_branches
    if [[ $(cat repo_branches | grep -E "\"name\"\: \"master\"") ]]; then
        MASTER_EXISTS=true
    fi
    if [[ $(cat repo_branches | grep -E "\"name\"\: \"develop\"") ]]; then
        DEVELOP_EXISTS=true
    fi

    if [[ "$MASTER_EXISTS" = true ]]; then
        unset BRANCH
        BRANCH=master
        unset CURL
        CURL=$(curl -s \
        -X PUT \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        https://api.github.com/repos/$GH_ORG/$GH_REPO/branches/$BRANCH/protection \
        -d "{\"required_status_checks\":{\"strict\":true,\"checks\":[{\"context\":\"name_of_status_check\"}]},\"restrictions\":{\"users\":[],\"teams\":[],\"apps\":[]},\"required_signatures\":false,\"required_pull_request_reviews\":{\"dismiss_stale_reviews\":true,\"require_code_owner_reviews\":true,\"required_approving_review_count\":$REQUIRED_APPROVERS_COUNT,\"require_last_push_approval\":true,\"bypass_pull_request_allowances\":{\"users\":[],\"teams\":[],\"apps\":[]}},\"enforce_admins\":true,\"required_linear_history\":false,\"allow_force_pushes\":false,\"allow_deletions\":false,\"block_creations\":false,\"required_conversation_resolution\":true,\"lock_branch\":false,\"allow_fork_syncing\":false}" 2>&1)
        if [[ $(echo "$CURL" | grep -E "Problems|Not Found") ]]; then
            echo "☠️ Something bad happened setting branch protections on $BRANCH, please investigate response:"
            echo "$CURL"
        else
            echo "💥 Successfully set branch protections on $BRANCH"
        fi
    fi

    if [[ "$DEVELOP_EXISTS" = true ]]; then
        unset BRANCH
        BRANCH=develop
        unset CURL
        # Jenkins ANY job not enabled, don't require it
        CURL=$(curl -s \
        -X PUT \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        https://api.github.com/repos/$GH_ORG/$GH_REPO/branches/$BRANCH/protection \
        -d "{\"required_status_checks\":{\"strict\":true,\"checks\":[{\"context\":\"name_of_status_check\"}]},\"restrictions\":{\"users\":[],\"teams\":[],\"apps\":[]},\"required_signatures\":false,\"required_pull_request_reviews\":{\"dismiss_stale_reviews\":true,\"require_code_owner_reviews\":true,\"required_approving_review_count\":$REQUIRED_APPROVERS_COUNT,\"require_last_push_approval\":true,\"bypass_pull_request_allowances\":{\"users\":[],\"teams\":[],\"apps\":[]}},\"enforce_admins\":true,\"required_linear_history\":false,\"allow_force_pushes\":false,\"allow_deletions\":false,\"block_creations\":false,\"required_conversation_resolution\":true,\"lock_branch\":false,\"allow_fork_syncing\":false}" 2>&1)
        
        if [[ $(echo "$CURL" | grep -E "Problems|Not Found") ]]; then
            echo "☠️ Something bad happened setting branch protections on $BRANCH, please investigate response:"
            echo "$CURL"
        else
            echo "💥 Successfully set branch protections on $BRANCH"
        fi
    
    # Sleep
    echo "Sleeping for 5 seconds to avoid GitHub API rate-limiting"
    sleep 5

done < repo_info.csv 

exit 0