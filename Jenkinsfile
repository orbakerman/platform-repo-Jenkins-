environment {
  AWS_REGION   = 'us-east-1'
  ECR_REPO     = 'orbak-app1'
}

...

stage('Deploy to Production EC2') {
  when { branch 'main' }
  environment {
    PROD_HOST = 'ec2-user@3.85.84.65'
  }
  steps {
    sshagent (credentials: ['prod-ec2-ssh-key']) {
      sh '''
        ssh -o StrictHostKeyChecking=no "$PROD_HOST" bash -s <<'EOS'
set -euo pipefail
AWS_REGION='"$AWS_REGION"'
ECR_REGISTRY='"$ECR_REGISTRY"'
ECR_REPO='"$ECR_REPO"'
IMAGE_URI="${ECR_REGISTRY}/${ECR_REPO}"
RELEASE_TAG="build-'"$BUILD_NUMBER"'"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker pull "${IMAGE_URI}:${RELEASE_TAG}"
docker rm -f app || true
docker run -d --name app -p 80:8000 --restart=always "${IMAGE_URI}:${RELEASE_TAG}"
EOS
      '''
    }
  }
}

stage('Health Verification') {
  when { branch 'main' }
  environment {
    PROD_URL = 'http://3.85.84.65/health'
  }
  steps {
    sh '''
      echo "Probing $PROD_URL ..."
      for i in $(seq 1 10); do
        if curl -fsS "$PROD_URL" > /dev/null; then
          echo "Health OK"; exit 0
        fi
        echo "Not healthy yet... retry $i/10"
        sleep 3
      done
      echo "Health check failed"; exit 1
    '''
  }
}

