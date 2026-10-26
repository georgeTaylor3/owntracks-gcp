#!/usr/bin/env bash
# One-time project setup that Terraform does not manage:
# create the project, link billing, enable APIs, create a budget alert.
#
# Usage: scripts/bootstrap.sh <project-id> <billing-account-id> [budget-usd]
set -euo pipefail

project="${1:?usage: bootstrap.sh <project-id> <billing-account-id> [budget-usd]}"
billing="${2:?usage: bootstrap.sh <project-id> <billing-account-id> [budget-usd]}"
budget="${3:-5}"

if gcloud projects describe "$project" >/dev/null 2>&1; then
  echo "Project $project exists; skipping create."
else
  gcloud projects create "$project" --name="OwnTracks"
fi

gcloud billing projects link "$project" --billing-account="$billing"

gcloud services enable --project="$project" \
  compute.googleapis.com \
  iap.googleapis.com \
  oslogin.googleapis.com \
  billingbudgets.googleapis.com

if gcloud billing budgets list --billing-account="$billing" \
     --format='value(displayName)' | grep -qx "owntracks"; then
  echo "Budget 'owntracks' exists; skipping."
else
  gcloud billing budgets create --billing-account="$billing" \
    --display-name="owntracks" --budget-amount="${budget}USD" \
    --filter-projects="projects/$project" \
    --threshold-rule=percent=0.5 --threshold-rule=percent=1.0
fi

echo
echo "Project $project ready. Next:"
echo "  cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
echo "  vim terraform/terraform.tfvars     # set project_id = \"$project\""
