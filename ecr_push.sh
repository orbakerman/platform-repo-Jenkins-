#!/usr/bin/env bash
set -euo pipefail

# === פרמטרים עם ברירות מחדל (אפשר לדרוס דרך משתני סביבה) ===
REGION="${REGION:-us-east-1}"       # אזור ה-AWS
REPO="${REPO:-orbak-app1}"          # שם ה-ECR repo
TAG="${TAG:-build-$(date +%s)}"     # תגית לאימג' (למשל build-42 או pr-123-7)
LOCAL_IMAGE="${LOCAL_IMAGE:-local:latest}"  # שם האימג' המקומי אחרי build
CONTEXT="${CONTEXT:-.}"             # תיקיית ה-build (ברירת מחדל: הנוכחית)
LATEST="${LATEST:-false}"           # אם true יסמן גם :latest

# === בדיקות מינימום ===
command -v docker >/dev/null || { echo "Docker לא מותקן/זמין"; exit 1; }
command -v aws >/dev/null || { echo "AWS CLI לא מותקן/זמין"; exit 1; }

echo "Region:   $REGION"
echo "Repo:     $REPO"
echo "Tag:      $TAG"
echo "Context:  $CONTEXT"
echo "Latest?:  $LATEST"

# === זיהוי חשבון והרשמה ל-ECR ===
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_URI="${ECR}/${REPO}:${TAG}"

# === יצירת הריפו אם לא קיים ===
if ! aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" >/dev/null 2>&1; then
  echo "Repository $REPO לא קיים – יוצר..."
  aws ecr create-repository --repository-name "$REPO" --region "$REGION" >/dev/null
fi

# === התחברות ל-ECR ===
echo "Logging in to ECR: $ECR"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ECR"

# === Build / Tag / Push ===
echo "Building image: $LOCAL_IMAGE (context: $CONTEXT)"
docker build -t "$LOCAL_IMAGE" "$CONTEXT"

echo "Tagging -> $IMAGE_URI"
docker tag "$LOCAL_IMAGE" "$IMAGE_URI"

echo "Pushing -> $IMAGE_URI"
docker push "$IMAGE_URI"

if [[ "$LATEST" == "true" ]]; then
  echo "Tagging & pushing :latest"
  docker tag "$IMAGE_URI" "${ECR}/${REPO}:latest"
  docker push "${ECR}/${REPO}:latest"
fi

echo "✅ Done. Pushed: $IMAGE_URI"

